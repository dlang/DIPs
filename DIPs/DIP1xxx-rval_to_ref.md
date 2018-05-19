# `ref T` accepts r-values

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | (number/id -- assigned by DIP Manager)                          |
| Review Count:   | 0 (edited by DIP Manager)                                       |
| Author:         | Manu Evans (turkeyman@gmail.com)                                |
| Status:         | Draft                                                           |

## Abstract

A recurring complaint from users when interacting with functions that receive arguments by `ref` is that given an rvalue as argument, the compiler is unable to create an implicit temporary to perform the function call, and presents the user with a compile error instead.
This situation leads to a workaround where function parameters must be manually assigned to temporaries prior to the function call, which many users find frustrating.

A further issue is that because this situation require special-case handling, this may introduce semantic edge-cases and necessitate undesirable compile-time logic invading the users code, particularly into generic code.

`ref` args are not as common in conventional idiomatic D as they are in some other languages, but they exist and appear frequently in niche circumstances. As such, this issue is likely to disproportionately affect subsets of users who find themselves using ref arguments more than average.

The choice to receive an argument by value or by reference is a detail that the API *author* selects with respect to criteria relevant to their project or domain, however, the semantic impact is not worn by the API author, but rather by the API user, who may be required to jump through hurdles to interact the API with their local code.
It would be ideal if the decision to receive arguments by value or by reference were a detail for the API, and not increase the complexity of the users code.

Here is proposed a strategy to emit implicit temporaries to conveniently interact with APIs that use ref arguments.

### Reference

Forum threads:

Issues:


## Contents
* [Rationale](#rationale)
* [Proposal](#proposal)
* [Temporary destruction]()
* [`@safe`ty implications](#safety_implications)
* [Why not `auto ref`?](#auto_ref)
* [Key use cases](#use_cases)
* [Reviews](#reviews)

## Rationale

When calling functions that receive ref args, D prohibits supplying rvalues. It is suggested that this is to assist the author identifying likely logic errors where an rvalue will expire at the end of the statement, and it doesn't make much sense for a function to mutate a temporary whose life will not extend beyond the function call in question.

However, many functions receive arguments by reference, and this may be for a variety of reasons.
One common reason is that the cost of copying large structs via the parameter list is expensive, so struct parameters may be received by reference to mitigate this cost.
Another common case is that the function may want to mutate the caller's data directly or return data via `out` parameters due to ABI limitations regarding multiple return values. This is the potential error case that the existing design attempts to mitigate, but in D, pipeline programming is vary popular, and contrary to conventional wisdom where the statement is likely to end at the end of the function call, pipeline expressions may result in single statements performing a lot of work, mutating state as it passes down the pipeline.

A related issue is with relation to generic code which reflects or received a function by alias. Such generic code may want to call that function, but it is often the case that details about the ref-ness of arguments lead to incorrect semantic expressions in the generic code depending on the arguments, necessitating additional compile-time logic to identify the ref-ness of function arguments and implement appropriate workarounds on these conditions. This leads to longer, more brittle, and less-maintainable generic code. It is also much harder to write correctly the first time, and such issues may only emerge in niche use cases at a later time.

With these cases in mind, the existing rule feels out-dated or inappropriate, and the presence of the rule may often lead to aggravation while trying to write simple, readable code.
Calling a function should be simple and orthogonal, generic code should not have to concern itself with details about ref-ness of function parameters, and users should not be required to jump through hoops when ref appears in API's they encounter.

Consider the example:
```d
void fun(int x);

fun(10); // <-- this is how simple calling a function should be
```
But when a ref is involved:
```d
void fun(ref int x);

fun(10); // <-- compile error; not an lvalue!!
```
Necessitating the workaround:
```d
int temp = 10;
fun(temp);
```
In practise, the argument would likely be some larger struct type rather than 'int', but the inconvenience applies generally.

This inconvenience also extends more broadly to cases including:
```d
fun(10);       // literals
fun(gun());    // return values from functions
fun(x.prop);   // properties
fun(x + y);    // expressions
fun(my_short); // implicit type conversions (ie, short->int promotion)
// etc... (basically, most things you pass to functions)
```
The work-around can bloat the number of lines around the call-site significantly, and the user needs to declare names for all the temporaries, polluting the local namespace, and often for expressions where no meaningful name exists, leading to.

The generic case may appear in a form like this:
```d
void someMeta(alias userFun)()
{
    userFun(getValue());
}

void fun(int x);
void gun(ref const(int) x);

unittest
{
    someMeta!(fun)(); // no problem
    someMeta!(gun)(); // oh no, can't receive rvalue!
}
```
Necessitating a workaround that may look like:
```d
void someMeta(alias userFun)()
{
    std.algorithm : canFind;
    static if(canFind(__traits(getParameterStorageClasses, userFun, 0), "ref"))
    {
        auto x = getValue();
        userFun(x);
    }
    else
    {
        userFun(getValue());
    }
}
```
This example situation is simplified, but it is often that such issues appear in complex aggregate meta, which may be difficult to understand, or the issue is caused indirectly at some layer the user did not author.

These work-arounds damage readability and brevity, they make authoring correct code more difficult, increase the probability of brittle meta, and it's frustrating to implement repeatedly.

## Proposal

Calls with `ref T` arguments supplied with rvalues are effectively rewritten to emit a temporary automatically, for example:
```d
void fun(ref int x);

fun(10);
```
Is rewritten:
```d
{
  T __temp0 = void;
  fun(__temp0 := 10);
}
```
Where `T` is the *function argument type*.

To mitigate confusion, I have used `:=` in this example to express the initial construction, and not a copy operation as would be expected if this code were written with an `=` expression.

In the case where a function output initialises an variable:
```d
R result = fun(10);
```
Becomes:
```d
R result = void;
{
  T __temp0 = void;
  result := fun(__temp0 := 10);
}
```
Again, where initial construction of `result` should be performed at the moment of assignment, as usual and expected.

It is important that `T` be defined as the argument type, and not `auto`, because it will allow implicit conversions to occur naturally, with identical behaviour as when argument was not a ref. The user should not experience edge cases, or differences in functionality when calling `fun(int x)` vs `fun(ref int x)`.

## Temporary destruction

Destruction of any temporaries occurs naturally at the end of the introduced scope.

## Function calls as arguments

It is important to note that a single scope is introduced to enclose the entire statement. The pattern should not cascade when nested calls exist in the parameter list within a single statement.
For calls that contain cascading function calls, ie:
```d
void fun(ref const(int) x, ref const(int) y);
int gun(ref const(int) x);

fun(10, gun(20));
```
This correct expansion is:
```d
{
    int __fun_temp0 = void;
    int __fun_temp1 = void;
    int __gun_temp0 = void;
    fun(__fun_temp0 := 10, __fun_temp1 := gun(__gun_temp0 := 20));
}
```

## Interaction with `return ref`

Given the expansion shown above for cascading function calls, `return ref` works naturally, exactly as the user expects. The key is that the scope encloses the entire statement, and all temporaries live for the length of the entire statement.

For example:
```d
void fun(ref int x);
ref int gun(return ref int y);

fun(gun(10));
```
This correct expansion is:
```d
{
    int __gun_temp0 = void;
    fun(gun(__gun_temp0 := 10));
}
```
The lifetime of `__gun_temp0` is satisfactory for any conceivable calling construction.

This is particularly useful when pipeline programming.
It is common that functions are invoked which create and return a range which is then used in a pipeline operation:
```d
MyRange makeRange();
MyRange transform(MyRange r, int x);

auto results = makeRange().transform(10).array;
```
But if the transform receives a range by ref, the pipeline syntax breaks down:
```d
MyRange makeRange();
ref MyRange mutatingTransform(return ref MyRange r, int x);

auto results = makeRange().transform(10).array; // error, not an lvalue!

// necessitate workaround:
auto tempRange = makeRange(); // satisfy the compiler
auto results = tempRange.mutatingTransform(10).array;
```
There are classes of range where the source range should be mutated through the pipeline. It is also possible that this pattern may be implemented for efficiency, since copying ranges at each step may be expensive.

It is unfortunate that `ref` adds friction to one of D's greatest programming paradigms this way.

## Interaction with other attributes

Interactions with other attributes should follow all existing rules.
Any code that wouldn't compile in the event the user were to perform the proposed rewrites manually will fail in the same way, emitting the same error messages the user would expect.

## Overload resolution

In the interest of preserving optimal calling efficiency, existing language rules continue to apply; lvalues should prefer by-ref functions, and rvalues should prefer by-value functions.
Consider the following overload set:
```d
void fun(int);            // A
void fun(const(int));     // B
void fun(ref int);        // C
void fun(ref const(int)); // D

int t = 10;
const(int) u = 10;
fun(10);            // rvalue; choose A
fun(const int(10)); // rvalue; choose B
fun(t);             // lvalue; choose C
fun(u);             // lvalue; choose D
```
This follows existing language rules. No change is proposed here.

Overloading with `auto ref` preserves existing rules, which is to emit an ambiguous call when it collides with an explicit overload:
```d
void fun(ref int);        // A
void fun()(auto ref int); // B

int t = 10;
fun(10);    // chooses B: auto ref resolves by-value given an rvalue, prefer exact match as above
fun(t);     // error: ambiguous call between A and B
```
No change to existing behaviour is proposed.

## Default arguments

In satisfying the statement above "The user should not experience edge cases, or differences in functionality...", it should be that default args are applicable to ref args as with non-ref args.

If the user does not supply an argument and a default arg is specified, the default arg is selected as usual and populates a temporary, just as if the user supplied a literal manually.

In this case, an interesting circumstantial opportunity appears where the compiler may discern that construction is expensive, and construct a single immutable instance for reuse.
This shall not be specified functionality, but it may be a nice opportunity nonetheless.

## `@safe`ty implications

There are no implications on `@safe`ty. There are no additions or changes to allocation or parameter passing schemes.
D already states that arguments received by ref shall not escape, so passing temporaries is not dangerous from an escaping/dangling-reference point of view.

The user is able to produce the implicit temporary described in this proposal manually, and pass it with identical semantics; any potential safety implications are already applicable to normal stack args. This proposal adds nothing new.

## Why not `auto ref`?

A frequently proposed solution to this situation is to receive the arg via `auto ref`.

`auto ref` solves a different set of problems; those may include "pass this argument in the most efficient way", or "forward this argument exactly how I received it". The implementation of `auto ref` requires that every function also be a template.

There are many reasons why every function can't or shouldn't be a template.
1. API is not your code, and it's not already `auto ref`
2. Is distributed as a binary lib
3. Is exported from DLL
4. Is virtual
5. Is extern(C++)
6. Intent to capture function pointers or delegates
7. Has many args; unreasonable combinatorial explosion
8. Is larger-than-inline scale; engineer assesses that reducing instantiation bloat has greater priority than maximising parameter passing efficiency in some cases

Any (or many) of these reasons may apply, eliminating `auto ref` from the solution space.

## Key use cases

Pipeline programming expressions often begin with a range returned from a function. There are constructs where transform functions need to take the range by reference. Such cases currently break the pipeline and introduce a temporary. This proposal improves the pipeline-programming experience.

Generic programming is one of D's biggest success stories, and tends to work best when interfaces and expressions are orthogonal and with as few as possible edge-cases. Certain forms of meta find that `ref`-ness is a key edge-case which requires special case handling and may often lead to brittle generic code to be discovered by an unhappy niche user at some future time.

Another high-impact case is OOP, where virtual function APIs inhibit the use of templates (ie, auto ref).

By comparison, C++ has a very high prevalence of `const&` args and classes with virtual functions, and when interfacing with C++, those functions are mirrored to D. The issue addressed in this DIP becomes magnified significantly to this set of users. This DIP reduces inconvenience when interacting with C++ API's.

This issue is also likely to appear more frequently for vendors with tight ABI requirements.
Users of closed-source libraries distributed as binary libs, or libraries distributes as DLLs are more likely to encounter these challenges interacting with those APIs as well.

## Copyright & License

Copyright (c) 2018 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## Review

The DIP Manager will supplement this section with a summary of each review stage
of the DIP process beyond the Draft Review.

## Appendix

A few examples of typical C++ APIs that exhibit this issue:
 - PhysX (Nvidia): http://docs.nvidia.com/gameworks/content/gameworkslibrary/physx/apireference/files/classPxSceneQueryExt.html
 - NaCl (Google): https://developer.chrome.com/native-client/pepper_stable/cpp/classpp_1_1_instance
 - DirectX (Microsoft): https://github.com/Microsoft/DirectXMath/blob/master/Inc/DirectXCollision.h
 - Bullet (Physics Lib): http://bulletphysics.org/Bullet/BulletFull/classbtBroadphaseInterface.html

In these examples of very typical C++ code, you can see a large number of functions receive arguments by reference.
Complex objects are likely to be fetched via getters/properties. Simple objects like math vectors/matrices are likely to be called with literals, properties, or expressions.