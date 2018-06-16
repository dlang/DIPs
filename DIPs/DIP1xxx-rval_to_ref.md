# `ref T` accepts r-values

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | (number/id -- assigned by DIP Manager)                          |
| Review Count:   | 0 (edited by DIP Manager)                                       |
| Author:         | Manu Evans (turkeyman@gmail.com)                                |
| Status:         | Draft                                                           |

## Abstract

Functions that receive arguments by `ref` do not accept rvalues.

This leads to edge-cases in calling code with respect to parameter passing semantics, requiring an assortment of workarounds and user-intervention which may be frustrating, and pollute _client-side_ code clarity.

Here is proposed a strategy to emit implicit temporaries to conveniently and uniformly interact with APIs that use `ref` arguments.

## Reference

There is a lot of prior discussion on this topic. Much is out of date now due to recent language evolution.  
Prior discussion involving `scope`, and `auto ref` as solutions are out of date; We have implemented `scope`, `auto ref`, and we also have `return ref` now, which affects prior conversation.

Forum threads:  
https://forum.dlang.org/thread/mailman.3720.1453131378.22025.digitalmars-d@puremagic.com  
https://forum.dlang.org/thread/rehsmhmeexpusjwkfnoy@forum.dlang.org  
https://forum.dlang.org/thread/mailman.577.1410180586.5783.digitalmars-d@puremagic.com  
https://forum.dlang.org/thread/km4rtm$239e$1@digitalmars.com  
https://forum.dlang.org/thread/kl4v8r$tkc$1@digitalmars.com  
https://forum.dlang.org/thread/ylebrhjnrrcajnvtthtt@forum.dlang.org  
https://forum.dlang.org/thread/ntsyfhesnywfxvzbemwc@forum.dlang.org  
https://forum.dlang.org/thread/uswucstsooghescofycp@forum.dlang.org  
https://forum.dlang.org/thread/zteryxwxyngvyqvukqkm@forum.dlang.org  
https://forum.dlang.org/thread/yhnbcocwxnbutylfeoxi@forum.dlang.org  
https://forum.dlang.org/thread/tkdloxqhtptpifkhvxjh@forum.dlang.org  
https://forum.dlang.org/thread/mailman.1478.1521842510.3374.digitalmars-d@puremagic.com  
https://forum.dlang.org/thread/gsdkqnbljuwssslxuglf@forum.dlang.org  

Issues:  
https://issues.dlang.org/show_bug.cgi?id=9238  
https://issues.dlang.org/show_bug.cgi?id=8845  
https://issues.dlang.org/show_bug.cgi?id=6221  
https://issues.dlang.org/show_bug.cgi?id=6442  

PRs:  
https://github.com/dlang/dmd/pull/4717  

## Contents
* [Rationale](#rationale)
* [Description](#description)
* [Temporary destruction]()
* [`@safe`ty implications](#safety_implications)
* [Why not `auto ref`?](#auto_ref)
* [Key use cases](#use_cases)
* [Reviews](#reviews)

## Rationale

Functions may receive arguments by reference, and this may be for a variety of reasons.  
One common reason is that the cost of copying or moving large structs via the parameter list is expensive, so struct parameters may be received by reference to mitigate this cost.  
Another is that the function may want to mutate the caller's data directly, or return data via `out` parameters due to ABI limitations regarding multiple return values.

A recurring complaint from users when interacting with functions that receive arguments by `ref` is that given an rvalue as argument, the compiler is unable to create an implicit temporary to perform the function call, and presents the user with a compile error instead, invoking the necessity for manual workarounds.

Consider the example:
```d
void fun(int x);

fun(10); // <-- this is how users expect to call a function
```
But when `ref` is present:
```d
void fun(ref int x);

fun(10); // <-- compile error; not an lvalue!!
```
Necessitating the workaround:
```d
int temp = 10;
fun(temp);
```
In practise, the argument is likely a struct type rather than 'int', but the inconvenience applies generally.

This inconvenience extends broadly to every manner of thing you pass to functions with the exception of lvalue instances, including:
```d
fun(10);       // literals
fun(gun());    // return values from functions
fun(x.prop);   // properties
fun(x + y);    // expressions
fun(my_short); // implicit type conversions (ie, short->int promotion)
// etc.
```
The work-around bloats the number of lines around the call-site, and the user needs to declare names for all the temporaries, polluting the local namespace, and often for expressions where no meaningful name exists.

A further issue is that because these situations require special-case handling, they necessitate undesirable and potentially complex compile-time logic being added _prospectively_ to generic code.

An example may be some meta that reflects or receives a function by alias. Such code may want to call that function, but it is often the case that details about the ref-ness of arguments change the way arguments must be supplied, requiring additional compile-time logic to identify the ref-ness of function arguments and implement appropriate action for each case.

The generic case may appear in a form such as:
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
    someMeta!(gun)(); // error: not an lvalue!
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
This example situation is simplified. In practise, such issues are often exposed when composing functionality, where a dependent library author did not correctly support `ref` functions. In that case, the end-user will experience the problem, but it may be difficult to diagnose or understand that the problem is not their direct fault.

In general, these work-arounds damage readability, maintainability, and brevity. They make authoring correct code more difficult, increase the probability of brittle meta, and correct code is frustrating to implement repeatedly.

Importantly, it is not intuitive to library authors that they should need to handle these cases, those who don't specifically test for `ref` are at high risk of failing to implement the required machinery, leaving the library _user_ in the a position of discovering, and dancing around potential unintended edge-cases.

It is worth noting that `ref` args are not so common in conventional idiomatic D, but they appear frequently in niche circumstances. As such, this issue is likely to disproportionately affect subsets of users who find themselves using `ref` arguments more than average.

### Why are we here?

It is suggested that the reason this limitation exists is to assist with identifying 
a class of bug where a function returns state by mutating an argument, but the programmer _accidentally_ passes an expiring rvalue, the function results are discarded, and statement has no effect.

With the introduction of `return ref`, it is potentially possible that a supplied rvalue may by mutated and returned to propagate its affect.

Modern D has firmly embraced pipeline programming. With this evolution, statements are often constructed by chaining function calls, so the presumption that the statement ends with the function is no longer reliable.

This DIP proposes that we reconsider the choice to receive an argument by value or by reference is a detail that the API *author* selects with respect to criteria relevant to their project or domain. Currently the semantic impact is not worn by the API author, but rather by the API user, who may be required to jump through hurdles to interface the API with their local code.

It would be ideal if the decision to receive arguments by value or by reference were a detail for the API, and not increase the complexity of the users code.

## Description

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

It is important that `T` be defined as the argument type, and not `auto`, because it will allow implicit conversions to occur naturally, with identical behaviour as when argument was not `ref`. The user should not experience edge cases, or differences in functionality when calling `fun(int x)` vs `fun(ref int x)`.

### Temporary destruction

Destruction of any temporaries occurs naturally at the end of the introduced scope.

### Function calls as arguments

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

### Interaction with `return ref`

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
But if the transform receives a range by `ref`, the pipeline syntax breaks down:
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

### Interaction with other attributes

Interactions with other attributes should follow all existing rules.  
Any code that wouldn't compile in the event the user were to perform the proposed rewrites manually will fail in the same way, emitting the same error messages the user would expect.

### Overload resolution

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
This follows existing language rules, with one notable change; the text "rvalues should *prefer* by-value functions" allows that rvalues *may* now choose a by-ref function if no by-val overload is present, where it was previously a compile error.

It has been noted that is it possible to perceive the current usage of `ref` in lieu of a by-val overload as an 'lvalues-only restriction', which may be useful in some constructions. That functionality can be preserved using a `@disable` mechanic:
```d
void lval_only(int x) @disable;
void lval_only(ref int x);

int x = 10;
lval_only(x);  // ok: choose by-ref
lval_only(10); // error: literal matches by-val, which is @disabled
```
It may be considered an advantage that using this construction, the intent to restrict the argument in this way is made explicit.  
The symmetrical 'rvalue-only restriction' is also possible to express in the same way.

Overloading with `auto ref` preserves existing rules, which is to emit an ambiguous call when it collides with an explicit overload:
```d
void fun(ref int);        // A
void fun()(auto ref int); // B

int t = 10;
fun(10);    // chooses B: auto ref resolves by-value given an rvalue, prefer exact match as above
fun(t);     // error: ambiguous call between A and B
```
No change to existing behaviour is proposed.

### Default arguments

In satisfying the goal that 'the user should not experience edge cases, or differences in functionality', it should be that default args are applicable to `ref` args as with non-`ref` args.

If the user does not supply an argument and a default arg is specified, the default arg is selected as usual and populates a temporary, just as if the user supplied the argument manually.

In this case, an interesting circumstantial opportunity appears where the compiler may discern that construction is expensive, and construct a single immutable instance for reuse.  
This shall not be specified functionality, but it may be a nice opportunity nonetheless.

### `@safe`ty implications

There are no implications on `@safe`ty. There are no additions or changes to allocation or parameter passing schemes.  
D already states that arguments received by `ref` shall not escape, so passing temporaries is not dangerous from an escaping/dangling-reference point of view.

The user is able to produce the implicit temporary described in this proposal manually, and pass it with identical semantics; any potential safety implications are already applicable to normal stack args. This proposal adds nothing new.

### Why not `auto ref`?

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
8. Is larger-than-inline scale; engineer assesses that reducing instantiation bloat has greater priority than maximising parameter passing efficiency in select cases

Any (or many) of these reasons may apply, eliminating `auto ref` from the solution space.

### Key use cases

Pipeline programming expressions often begin with a range returned from a function (an rvalue). Transform functions may receive their argument by reference. Such cases currently break the pipeline and introduce a manual temporary. This proposal improves the pipeline-programming experience.

Generic programming is one of D's biggest success stories, and tends to work best when interfaces and expressions are orthogonal and with as few as possible edge-cases. Certain forms of meta find that `ref`-ness is a key edge-case which requires special case handling and may often lead to brittle generic code to be discovered by a niche end-user at some future time.

Another high-impact case is OOP, where virtual function APIs inhibit the use of templates (ie, `auto ref`).

By comparison, C++ has a very high prevalence of `const&` args, classes with virtual functions, and default args supplied to ref. When interfacing with C++, those functions are mirrored to D. The issue addressed in this DIP becomes magnified significantly to this set of users. C++ interaction is a key initiative, this DIP reduces inconvenience when interacting with C++ API's, and improves the surface area we are able to express.

This issue is also likely to appear more frequently for vendors with tight ABI requirements.  
Lack of templates at ABI boundary lead to users of closed-source libraries distributed as binary or DLLs being more likely to encounter challenges interacting with such APIs.

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