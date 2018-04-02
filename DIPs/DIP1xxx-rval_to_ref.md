# `ref const(T)` should receive r-values

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | (number/id -- assigned by DIP Manager)                          |
| Review Count:   | 0 (edited by DIP Manager)                                       |
| Author:         | Manu Evans (turkeyman@gmail.com)                                |
| Status:         | Draft                                                           |

## Abstract

A recurring complaint from users when interacting with functions that receive arguments by `ref` is that given an rvalue as argument, the compiler is unable to create an implicit temporary to perform the function call, and presents the user with a compile error instead.
This situation leads to a workaround where function parameters must be manually assigned to temporaries prior to the function call, which many users find frustrating.

Another further issue is that because they require special-case handling, this may introduce semantic edge-cases and necessitate undesirable compile-time logic invading the users code, particularly into generic code.

`ref` args are not as common in conventional idiomatic D as they are in some other languages, but they exist and appear frequently in niche circumstances. As such, this issue is likely to disproportionately affect subsets of users who find themselves using ref arguments more than average.

The choice to receive an argument by value or by reference is a detail that the API *author* selects with respect to criteria relevant to their project or domain, however, the semantic impact is not worn by the API author, but rather by the API user, who may be required to jump through hurdles to interact the API with their local code.
It would be ideal if the decision to receive arguments by value or by reference were a detail for the API, and not increase the complexity of the users code.

Here is proposed a strategy to emit implicit temporaries to conveniently interact with APIs that use ref arguments.

### Reference

Nothing here yet...

## Contents
* [Rationale](#rationale)
* [Proposal](#proposal)
* [Temporary destruction]()
* [`@safe`ty implications](#safety_implications)
* [Why not `auto ref`?](#auto_ref)
* [Key use cases](#use_cases)
* [Reviews](#reviews)

## Rationale

Many functions receive arguments by reference. This may be for a variety of reasons.
One reason is that the function may want to mutate the caller's data directly or return data via `out` parameters due to ABI limitations regarding multiple return values, another common case is that the cost of copying large structs via the parameter list is expensive, so struct parameters may be received by reference to mitigate this cost.
In that case, it is conventional to mark the argument `const`, enforcing that the argument is not to be modified by the function and received purely as input.

When calling functions that receive ref args, D prohibits supplying rvalues as arguments because an rvalue theoretically doesn't have an address, and it doesn't make much sense for a function to mutate a temporary whose life will not extend beyond the function in question.
While these are sensible defense mechanisms for functions that receive arguments by mutable or `out` ref, it can be very inconvenient where functions receive arguments by `const ref` as pure inputs.

Consider the example:
```d
void fun(int x);

fun(10); // <-- this is how simple calling a function should be
```
But when a const-ref is involved:
```d
void fun(ref const(int) x);

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
The work-around can bloat the number of lines around the call-site significantly, and the user needs to declare names for all the temporaries, polluting the local namespace, and often for moments in calculations (expressions) where no meaningful name exists.

This work-around damages readability and brevity, and it's frustrating to implement repeatedly.

## Proposal

Calls with `ref const(T)` arguments supplied with rvalues are effectively rewritten to emit a temporary automatically, for example:
```d
fun(10);
```
Is rewritten:
```d
{
  T __temp0 = void;
  fun(__temp0 := 10);
}
```
Where `T` is the function argument type.

To mitigate confusion, I have used `:=` in this example to express the initial construction, and not a copy operation as would be expected if this code were written with an `=` expression.

In the edge case where a function initialises an output variable:
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

It is important that `T` be defined as the argument type, and not `auto`, because it will allow for implicit conversions to occur naturally as if the argument was not a ref.
The user should not experience edge cases, or differences in functionality when calling `fun(const(int) x)` vs `fun(ref const(int)x)`.

## Temporary destruction

Destruction of any temporaries occurs naturally at the end of the scope, as usual.

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
void fun(ref const(int) x);
ref const(int) gun(return ref const(int) y);

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

## Interaction with other attributes

Interactions with other attributes should follow all existing rules.
Any code that wouldn't compile in the event the user were to perform the rewrite manually will fail the same way, emitting the same error messages the user would expect.

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
fun(10);            // choose A
fun(const int(10)); // choose B
fun(t);             // choose C
fun(u);             // choose D
```
This follows existing language rules. No change is proposed here.

Overloading with `auto ref` equally preserves current rules, which is to emit an ambiguous call when it collides with an explicit overload:
```d
void fun(const(int));            // A
void fun(ref const(int));        // B
void fun()(auto ref const(int)); // C

int t = 10;
fun(10);    // error: ambiguous call between A and C
fun(t);     // error: ambiguous call between B and C
```

## Default arguments

In satisfying the statement above "The user should not experience edge cases, or differences in functionality...", it should be that default args are applicable to ref args as with non-ref args.

If the user does not supply an argument and a default arg is specified, the default arg is selected as usual and populates a temporary, just as if the user supplied a literal manually.

In this case, an interesting circumstantial opportunity appears where the compiler may discern that construction is expensive, and construct a single static instance intended for reuse.
This shall not be specified functionality, but it may be a nice opportunity nonetheless.

## `@safe`ty implications

There are no implications on `@safe`ty. There are no additions or changes to allocation or parameter passing schemes.
D already states that arguments received by ref shall not escape, so passing temporaries is not dangerous from an escaping/dangling-reference point of view.

The user is able to produce the implicit temporary described in this proposal manually, and pass it with identical semantics; any potential safety implications are already applicable to normal stack args. This proposal adds nothing new.

## Why `const`?

Due to the nature of D's restrictive `const`, this proposal has been criticised as being so restrictive to inhibit some potentially useful programs.

I suggest this proposal only applies to `const ref` arguments, because it's a guarantee that the parameter is used strictly as an input argument, rather than some form of output.
In the case where the parameter is used as an output argument, this proposal doesn't make sense because the output would be immediately discarded; such a function call given an rvalue as argument likely represents an accidental mistake on the users part, and we can catch that invalid code.

That said, D has the `out` attribute, which is a semantic statement of this intent. It could be that this proposal is amended to include non-const ref arguments, expecting that `out` shall be used exclusively to mark this intent.
If we assume that world, and `out` is deployed appropriately, there are 2 cases where mutable-ref may be used:
 1. When the function *modifies* the input; not a strict output parameter, but still outputs new information
 2. Still used as input, but a user is trying to subvert the restrictiveness of D's `const`

The proposal could be amended to accept mutable ref's depending on the value-judgement balancing these 2 use cases.
Sticking with `const` requires no such value judgement to be made at this time, and it's much easier to relax the spec in the future with emergence of evidence to do so.

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

By comparison, C++ has a very high prevalence of `const&` args and classes with virtual functions, and when interfacing with C++, those functions are mirrored to D. The issue addressed in this DIP becomes magnified significantly to this set of users.

The D community has invested significant resources in improving interaction with C++; either co-existing or simplifying a migration, and thereby make D attractive to the C++ audience.
The importance of this initiative is widely agreed; it has featured prominently in the bi-annual game-plans documents, and comprehensive interaction with even the C++ standard library has attracted funding from the D foundation.
This DIP offers a lot for interaction with C++ APIs.

This issue is also likely to appear more frequently for vendors with tight ABI requirements.
Users of closed-source libraries distributed as binary libs, or libraries distributes as DLLs are more likely to encounter these challenges interacting with those APIs as well.

Another high-probability occurrence is OOP, where virtual function APIs inhibit the use of templates.

## Anecdotes

As a user with numerous counts of attempted C++ interactions and migrations in the workplace, and in my own projects, I can add some anecdotal observations.
My attempts to introduce D to the workplace are interesting, because they involve building interest and selling D's merits to my colleagues in order to be successful. Expansion of D in my workplaces depends on this target audience assessing that D is a superior choice compared to the de-facto establishment of C++. There are some major factors that will motivate this opinion, but mostly it is an aggregate of minor improvements, coupled with satisfaction that existing comforts and workflow will be left mostly unchanged.

With respect to this issue, in all attempts, I have quickly demonstrated that the work-around presented above severely impact the quality of users experience with D when interacting with C++.
A large bulk of any migration task tends to involve responding to ongoing compile errors by copy-pasting function arguments to lines above the call, and assigning them temporary names. The resulting code is unappealing, bloated, and the experience is unsatisfying.
The take-away from this experience to a C++ programmer who is investigating D, is that the equivalent D code is objectively worse than the C++ code, and strongly undermines our ability to make a positive impression on that audience during the critical 'first-5-minutes'.
In my experience, this issue is almost enough on its own to call for immediate dismissal. Often expressed with vibrantly colourful language.

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
Complex objects are likely to be fetched via getters/properties. Simple objects like math vectors/matrices are likely to be called with literals, or properties.