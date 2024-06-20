# Primary Type Syntax


| Field           | Value                                                   |
|-----------------|---------------------------------------------------------|
| DIP:            | *TBD*                                                   |
| Review Count:   | 0                                                       |
| Author:         | Quirin F. Schroll ([@Bolpat](github.com/Bolpat))        |
| Implementation: | [dlang.org PR 3616][spec-pr] • [DMD PR 15269](impl-pr)  |
| Status:         | Draft                                                   |

## Abstract

The objective of this proposal is to ensure that every type,
which can be expressed within the D programming language’s type system,
has a corresponding representation as a sequence of D tokens.
Currently, the type constructs that lack such a representation are function pointer types and delegate types that return by reference or possess non-default linkage.

## Contents

* [Rationale](#rationale)
* [Prior Work](#prior-work)
* [Description](#description)
    * [Grammar Changes](#grammar-changes)
    * [Basic Examples](#basic-examples)
    * [Corner Cases](#corner-cases)
    * [Max Munch Exception](#max-munch-exception)
    * [Alternative Preserving Max Munch](#alternative-preserving-max-munch)
    * [Linkage](#linkage)
    * [Side-effects](#side-effects)
    * [Drawbacks](#drawbacks)
* [Breaking Changes and Deprecations](#breaking-changes-and-deprecations)
* [Copyright & License](#copyright--license)
* [Reviews](#history)

## Rationale

Not every type that the compiler can represent internally is expressible using exisiting D syntax.
For instance, when `pragma(msg)`, `.stringof`, or diagnostics serialize a type,
the programmer should be able to copy and paste this type and not get parsing errors.
Semantic problems may still arise due to visibility.

The main culprits are function pointers and delegates that return by reference.
To use those as function parameter or return types,
programmers are compelled to use a separate alias declaration.
Alias declarations only support them by special-casing them.

Another point of contention is an asymmetry between types and expressions:
For an expression <code>*e*</code>, also <code>(*e*)</code> is an expression and is functionally identical,
but for a type <code>*T*</code>, the token sequence <code>(*T*)</code> does not denote a type.

For expressions, the grammar rule saying that if <code>*e*</code> is an expression, so is <code>(*e*)</code>,
is referred to as *primary expression.*
This DIP proposes the same mechanism for types, hence the term *primary types.*

While these issues may seem unrelated, resolving the asymmetry significantly simplifies the resolution of
[Issue 2753][issue-2753] *(Cannot declare pointer to function returning `ref`).*

The current D syntax almost supports primary type syntax:
There exists a grammar rule that says:
If <code>*T*</code> denotes a type and <code>*q*</code> is a type qualifier, then <code>*q*(*T*)</code> denotes a type.
In fact, <code>*q*(*T*)</code> is even a *basic type.*
If the type qualifier in this rule were optional,
D would already support primary types.

Another related issue is [24007][issue-24007] *(Function/delegate literals cannot specify linkage).*
It can be solved with a simple addition to the grammar,
which is in the same spirit as the primary proposal.

## Prior Work

This DIP addresses specific shortcomings of D’s syntax.

## Description

### Grammar Changes

Because this DIP is aimed at the grammar only,
contrary as is usual in DIPs that propose grammar changes,
the grammar changes are given primary focus.

The following addresses the [function literal](https://dlang.org/spec/expression.html#FunctionLiteral) syntax.

> [!NOTE]
> Optional grammar entities are represented by `?` here.

```diff
    FunctionLiteral:
-       function RefOrAutoRef? Type? ParameterWithAttributes? FunctionLiteralBody2
-       delegate RefOrAutoRef? Type? ParameterWithMemberAttributes? FunctionLiteralBody2
+       function LinkageAttribute? RefOrAutoRef? Type? ParameterWithAttributes? FunctionLiteralBody2
+       delegate LinkageAttribute? RefOrAutoRef? Type? ParameterWithMemberAttributes? FunctionLiteralBody2
```

The following addresses the [type grammar](https://dlang.org/spec/type.html#Type).

```diff
    Type:
        TypeCtors? BasicType TypeSuffixes?
+       ref TypeCtors? BasicType TypeSuffixes
+       LinkageAttribute ref? TypeCtors? BasicType TypeSuffixes

    BasicType:
        FundamentalType
        . QualifiedIdentifier
        QualifiedIdentifier
        Typeof
        Typeof . QualifiedIdentifier
-       TypeCtor ( Type )
+       TypeCtor? ( Type )
        Vector
        TraitsExpression
        MixinType

    TypeSuffixes:
        TypeSuffix TypeSuffixes?

    TypeSuffix:
        *
        [ ]
        [ AssignExpression ]
        [ AssignExpression .. AssignExpression ]
        [ Type ]
        delegate Parameters MemberFunctionAttributes?
        function Parameters FunctionAttributes?
```

* The first two additions introduce grammar rules that allow `ref` and linkage to be part of a function pointer or delegate type.
* The next change makes the type qualifier (`TypeCtor` in the grammar) optional in the rule that now introduces primary type syntax.

To become a well-formed type,
after a `ref` or `LinkageAttribute`,
exactly one of the `TypeSuffixes` must be a `function` or `delegate` one.
Expressing this in the grammar is possible,
but makes it much harder to understand.

> [!NOTE]
> Implementations are encouraged, but not required,
> to offer all possible ways add clarifying parentheses.
> For example:
> ```
> Error: `ref` is ambiguous in `ref int function() function() function()`. Use clarifying parentheses:
>        either `(ref int function()) function() function()`
>        or     `(ref (int function()) function()) function()`
>        or     `(ref (int function() function()) function()`
> ```

### Basic Examples

#### Declaring a function pointer variable

In present-day D, one cannot even spell out a `ref` returning function pointer type, except using an alias.
With the changes proposed by this DIP, this is how it’s done:
```d
(ref int function() @safe) fp = null;
```
Here, `fp` is variable of function pointer type.
The function returns its result by reference.
Omitting parentheses is an error:
Not allowing `ref` without parentheses here not only clarifies intent,
it keeps `ref` variables open for the future.
As of writing this, Walter Bright has a proposal draft for `ref` variables [here][ref-var-draft].

#### Declaring a function that returns a function pointer

What if we want to return a function pointer like `fp` by reference from a function?
```d
ref (ref int function() @safe) returnsFP() @safe => fp;
```
The function `returnsFP` returns a function pointer by reference.
The function pointer returns an `int` by reference.
The first `ref` refers to `returnsFP` and signifies that it returns its result by reference.
The second `ref` (inside parentheses) is part of the function pointer type,
i.e. the return type of `returnsFP`.

While one might think the parentheses are or should be optional, they are not, and shouldn’t be:
Without the parentheses around the return type,
the second `ref` would also be parsed as another storage class attribute to `returnsFP`,
and the redundant `ref` is an error.

#### Declaring a function that takes a function pointer parameter

What if we want to take a function pointer like `fp` as a parameter passed by reference?
```d
void takesFP(ref (ref int function() @safe) f) @safe { f() = 3; f = fp; }
```
The function `takesFP` takes a parameter of function pointer type by reference.
The function pointer parameter returns its result by reference.
The first `ref` refers to the parameter `f` making it pass-by-reference.
The second `ref` refers to the type of `f`, a function pointer type, and
signifies that `f` returns its result by reference.

While one might think the parentheses are optional, they are not.
Without the parentheses around the type of `f`,
the second `ref` would also be parsed as part of the parameter storage classes of `f`,
and the redundant `ref` is an error.

### Max Munch Exception

Lexing and parsing, for the most part, follow the max munch pinciple.
(The only exception the author is aware of is lexing floating point numbers.)
Max munch is the following general rule:
> If the parser can meaningfully parse the next tokens as part of what it tries to parse, it will;
> only if it can’t, depending on context, it either tries to close the current entity and go to the previous level or issue a parse failure.

For backwards compatibility, this DIP proposes to add an/another exception to max munch:
Whenever an opening parenthesis follows a type qualifier,
this is considered effectively one token and refers to the basic type rule.

The excpetion is required so that e.g. the follwing declaration keeps the meaning it currently has:
```d
void f(const(int)[]);
```
In current-day D, the `const` in the parameter list would be first parsed as a storage class,
but that fails because the opening parenthesis can neither belong to another storage class or a basic type.
Therefore, the parser backtracks and succeeds to parse `const` as part of a basic type.
With the proposed grammar changes, the failure on the opening parenthesis doesn’t happen anymore
because `(int)` denotes a basic type.
In total, that would render the parameter type equivalent to `const(int[])`.

However, unless misleading spaces are inserted between the type qualifier and the operning parenthesis,
this exception follows mathematical conventions and programmers’ intuition:
Normally, mathematicians write “sin&nbsp;2*k*π”
with the clear understanding that the sine function applies to the whole 2*k*π.
However, were it written sin(2)*k*π, it is clear that the sine function applies only to 2.
(Notably, WolframAlpha agrees with this notion: [sin 2π][sin-2pi] vs. [sin(2)π][sin-2-pi].)

D’s type qualifiers will work like that:
In a type denoted as `const int[]`, the `const` applies to everything that comes after it,
extending as far to the right as possible,
but in `const(int)[]`, the `const` only applies to `int`.

### Alternative Preserving Max Munch

There is a [proposal][deprecate-trailing-dot] to deprecate and remove the currently existing exception regarding floating-point number literals,
so that parsing is truly max munch.
In this spirit, adding a different exception to max munch might seem undesireable.

To avoid the aforementioned exception to max munch,
an option would be, for every type qualifier <code>*q*</code>,
to make <code>*q*(</code> a single token not conceptually, but *formally.*
It nests with closing <code>)</code>,
but is distinct from a <code>*q*</code> followed by an opening parenthesis
with some kind of token separation between them.

One consequence would be that the aforementioned misleading space becomes meaningful instead:
With this alternative, `const (int)` and `const(int)` would be parsed differently,
and, depending on context, can make an entity have a different type.

The viability of this alternative depends on how prevalent the misleading space is in current code.
The author hopes that community discussion will reveal that.

The author believes that the exception to the max munch principle is not inherently bad,
but a necessary rule to keep the change backwards compatible.

The rationale for deprecating the max munch exception comes from issues with simple syntax highlighters
which trip on `a[1..2]` because they lex it as `a` `[` `1.` `.2` `]` instead of `a` `[` `1` `..` `2` `]`.
However, no matter whether a simple syntax highlighter lexes `const(int)` as `const` `(` `int` `)` or `const(` `int` `)`,
it would want to style `const` as a keyword and handle the parentheses separately.
On the other hand, if `const(int)` means something different than `const (int)`,
programmers could even want a syntax highlighter to point out the difference
and style `const` differently depending on whether a parenthesis immediately follows it,
something a *simple* syntax highlighter cannot do:
It either must look forward one character and “see” the opening parenthesis, rendering the `const` different to ordinary `const`,
or implement `const(` as a single token,
which in case of a *simple* syntax highlighter cannot be styled heterogeneously, i.e. the `const` part differently from the parenthesis.

In total, the argument for changing the language removing the max munch exception on floating-point literals
directly leads to an exception in this case.

### Linkage

The discussion about `ref` is much more relevant than that of linkage as pass-by-reference is commonplace,
whereas linkage is niche in comparison.

However, a function pointer type with non-default linkage
(depending on context, the default is usually `extern(D)`, but can be `extern(C)` e.g. in `betterC` mode),
can likewise not be expressed by the grammar,
and contrary to `ref` return, cannot even be specified for a literal.

> [!WARNING]
> While the current implementation can *parse* linkages as part of function pointer and delegate types,
> it does not semantically apply them to the type yet.
>
> The function pointer and delegate literal syntax with `LinkageAttribute` aren’t currently implemented yet.
>
> Help is needed on this.

The proposed grammar rules formally do not allow linkage as the first tokens of a function pointer or delegate type,
however, the provided implementation allows omitting parentheses for function pointer or delegate types with linkage,
so that e.g. the first of the two following declarations is accepted and equivalent to the second:
```d
void takesCppFunction( extern(C++) ref int function()  fp) { }
void takesCppFunction((extern(C++) ref int function()) fp) { }
```
This is because linkage is not a parameter storage class and in all likelihood,
isn’t ever meaningful as one.
If the linkage is followed up by a `ref`,
because linkage starts a type,
it’s clear that `ref` must be part of the function pointer type syntax,
and isn’t a parameter storage class.

Whether this “unbureaucratic” handling of linkage in parameters of function pointer or delegate type with explicit linkage is desirable
should be discussed by the community.

### Side-effects

A notable side-effect is that `(const int)` is now a basic type.
The author expects this to be somewhat controversial.
Some programmers will prefer the more consistent new style to the old style,
leading to something like the head-const (`const T`) vs tail-const (`T const`) style discussions in C++.

### Drawbacks

A naïve programmer might assume that `const (shared int)*` is equivalent to `const ((shared int)*)`, but it really is equivalent to `(const shared int)*`.
This is intentional due to the requirement that the changes in syntax be backwards compatible.

## Breaking Changes and Deprecations

For a symbol <code>*s*</code>,
in present-day D, the token sequence <code>(*s*)</code> only parses as an expression.
With the changes proposed by this DIP,
it also parses as a type,
which is a meaningful difference in `__traits(isSame)`.
These can be remedied using a cast instead of (mis-)using parentheses to force parsing as an expression.

## Copyright & License
Copyright © 2024 by Quirin F. Schroll

Licensed under [Creative Commons Zero 1.0][cc-0]

## History
The DIP Manager will supplement this section with links to forum discsusionss and a summary of the formal assessment.


[spec-pr]: https://github.com/dlang/dlang.org/pull/3616
[impl-pr]: https://github.com/dlang/dmd/pull/15269

[issue-2753]: https://issues.dlang.org/show_bug.cgi?id=2753
[issue-24007]: https://issues.dlang.org/show_bug.cgi?id=24007

[ref-var-draft]: https://github.com/WalterBright/documents/blob/master/varRef.md
[deprecate-trailing-dot]: https://github.com/dlang/DIPs/pull/233

[sin-2pi]: https://www.wolframalpha.com/input/?i=sin+2%CF%80
[sin-2-pi]: https://www.wolframalpha.com/input/?i=sin%282%29%CF%80

[cc-0]: https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt
