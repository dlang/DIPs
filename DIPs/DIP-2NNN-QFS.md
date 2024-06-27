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
    * [Maximal Munch Exception](#maximal-munch-exception)
    * [Linkage](#linkage)
    * [Side-effects](#side-effects)
    * [Drawbacks](#drawbacks)
* [Breaking Changes and Deprecations](#breaking-changes-and-deprecations)
* [Copyright & License](#copyright--license)
* [Reviews](#history)

## Rationale

Not every type that the compiler can represent internally is expressible using exisiting D syntax.
For instance, when `pragma(msg)`, `stringof`, or diagnostics serialize a type,
the programmer should be able to copy and paste this type and not get parsing errors.
Semantic problems may still arise due to visibility.
The main culprits are function pointers and delegates that return by reference.
To use those as function parameter or return types,
programmers are compelled to use a separate alias declaration.
Alias declarations only support them by special-casing them.
This has been filed as [Issue 2753][issue-2753] *(Cannot declare pointer to function returning `ref`).*

Another point of contention is an asymmetry between types and expressions:
For an expression <code>*e*</code>, also <code>(*e*)</code> is an expression and is functionally identical,
but for a type <code>*T*</code>, the token sequence <code>(*T*)</code> does not denote a type.
For expressions, the grammar rule saying that if <code>*e*</code> is an expression, so is <code>(*e*)</code>,
is referred to as *primary expression.*
This DIP proposes the same mechanism for types, hence the title includes *primary types.*
In the D grammar and this document, the term *basic type* is used.
In short, part of the proposed changes is making basic types be primary types.

While these issues may seem unrelated, resolving the asymmetry significantly simplifies the resolution of
[Issue 2753][issue-2753]:
If <code>(*T*)</code> were a basic type for every type *`T`*
and <code>ref *R* function(…)</code> were a type (albeit no basic type),
<code>(ref *R* function(…))</code> could be used anywhere a basic type is required.
That is, in particular, as a function return type or a parameter type,
and there would be no ambiguity what `ref` refers to.
Additionally, in places where a general type is expected
(e.g. <code>is(*T*)</code> tests, template parameters/&ZeroWidthSpace;arguments/&ZeroWidthSpace;constraints/&ZeroWidthSpace;defaults, and `pragma(msg)`),
<code>ref *R* function(…)</code> can be used even without parentheses.  
Of course, everything said about `function` types also applies to `delegate` types.
Also, everything said about `ref` here also applies to linkage,
except that linkage has no ambiguity problem for function parameters.

The current D syntax almost supports primary type syntax:
There exists a grammar rule that says:
If <code>*T*</code> denotes a type and <code>*q*</code> is a type qualifier, then <code>*q*(*T*)</code> denotes a type.
In fact, <code>*q*(*T*)</code> is even a *basic type,*
which, simply put, means that unlike <code>*q* *T*</code>,
it can be used everywhere where a type is expected.
If the type qualifier in this rule were optional,
D would already have primary types.

Another related issue is [24007][issue-24007] *(Function/&ZeroWidthSpace;delegate literals cannot specify linkage).*
It can be solved with a simple addition to the grammar,
which is in the same spirit as the primary proposal.

## Prior Work

This DIP addresses specific shortcomings of D’s syntax.

Possibly, something like this solution was conceputalized in-passing by Jonathan M. Davis in [a forum post](https://forum.dlang.org/post/mailman.287.1336121273.24740.digitalmars-d@puremagic.com) from 2012.

## Description

### Grammar Changes

> [!NOTE]
> Optional grammar entities are represented by `?` here.

Because this DIP is aimed at the grammar only,
contrary to as is customary in DIPs that propose grammar changes,
the grammar changes are given primary focus.

The following addresses the [function literal](https://dlang.org/spec/expression.html#FunctionLiteral) syntax.

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
+       TypeCtors? ref TypeCtors? BasicType TypeSuffixes
+       TypeCtors? LinkageAttribute ref? TypeCtors? BasicType TypeSuffixes

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
* The next change makes the type qualifier (*`TypeCtor`* in the grammar) optional in the rule that now introduces primary type syntax.

After a *`LinkageAttribute`* and/or a `ref`,
exactly one of the *`TypeSuffixes`* must start with `function` or `delegate`.
Expressing this in the grammar is possible,
but makes it harder to understand with little benefit,
as such a provision can be expected.

> <details>
> <summary>Show/Hide grammar which formally expresses that exactly one of the <i><code>TypeSuffixes</code></i> must start with <code>function</code> or <code>delegate</code>.</summary>
>
> ```diff
>     Type:
>         TypeCtors? BasicType TypeSuffixes?
> +       TypeCtors? ref TypeCtors? BasicType NonCallableSuffixes? CallableSuffix NonCallableSuffixes?
> +       TypeCtors? LinkageAttribute ref? TypeCtors? BasicType NonCallableSuffixes? CallableSuffix NonCallableSuffixes?
> 
>     TypeSuffixes:
>         TypeSuffix TypeSuffixes?
> 
> +   NonCallableSuffixes:
> +       NonCallableSuffix NonCallableSuffixes?
> +
>     TypeSuffix:
> +       NonCallableSuffix
> +       CallableSuffix
> +
> +   NonCallableSuffix:
>         *
>         [ ]
>         [ AssignExpression ]
>         [ AssignExpression .. AssignExpression ]
>         [ Type ]
> +
> +   CallableSuffix:
>         delegate Parameters MemberFunctionAttributes?
>         function Parameters FunctionAttributes?
> ```
> That is a lot of noise for little gain.
> </details>

> [!NOTE]
> Implementations are encouraged, but not required,
> to offer all possible ways add clarifying parentheses.
> For example:
> ```
> Error: `ref` could refer to more than one `function` or `delegate` here.
>        Suggested clarifying parentheses:
>           `ref (int function()) function()`
>        or `(ref int function()) function()`
> ```
> The implementation in [DMD PR 15269][impl-pr] produces this error message
> on `ref int function() function()`.

Initial type qualifiers refer to the whole type produced,
whereas type qualifiers after linkage or `ref` refer to the return type only:
`const ref immutable int[] function()[]` is the same as `const(ref immutable(int[]) function()[])`.

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

### Maximal Munch Exception

Lexing and parsing, for the most part, follow the maximal munch pinciple.
(The only exception the author is aware of is lexing floating point numbers.)
Maximal munch is the following general rule:
> If the lexer or parser can meaningfully interpret the next entity as part of what it tries to match,
> it will.
> Only if it can’t,
> it considers that the end of the current match if possible,
> or issues an error.

The only currently-existing exception the author is aware of is [lexing floating point numbers][max-munch-exception].
As of this writing, there is [an open Pull Request][deprecate-trailing-dot] to deprecate this exception.

For backwards compatibility, this DIP proposes to add another exception to maximal munch:
Whenever an opening parenthesis follows a type qualifier,
this is considered effectively one token and refers to the *`BasicType`* rule.

The excpetion is required so that e.g. the follwing declaration keeps the meaning it currently has:
```d
void f(const(int)[]);
```
In current-day D, the `const` in the parameter list would be first parsed as a storage class,
but that fails because the opening parenthesis can neither belong to another storage class nor a basic type.
Therefore, the parser backtracks and succeeds to parse `const` as part of a basic type.
With the proposed grammar changes, the failure on the opening parenthesis doesn’t happen anymore
because `(int)` denotes a basic type.
In total, that would render the parameter type equivalent to `const(int[])`.

However, unless misleading spaces are inserted between the type qualifier and the operning parenthesis,
this exception follows mathematical conventions and programmers’ intuition:
Normally, mathematicians write “sin&nbsp;2*k*π”
with the clear understanding that the sine function applies to the whole 2*k*π.
However, were it written sin(2)*k*π, it is clear that the sine function applies only to 2.
(Notably, WolframAlpha agrees with this notion: cf. [sin 2*k*π][sin-2kpi] vs. [sin(2)*k*π][sin-2-kpi].)

D’s type qualifiers will work like that:
In a type denoted as `const int[]`, the `const` applies to everything that comes after it,
extending as far to the right as possible,
but in `const(int)[]`, because an opening parenthesis immediately follows,
the `const` only applies to `int`.

### Linkage

The discussion about `ref` is much more relevant than that of linkage as pass-by-reference is commonplace,
whereas linkage is niche in comparison.

A function pointer type with non-default linkage
can likewise not be expressed by the grammar,
and contrary to `ref` return, cannot even be specified for a literal.

> [!WARNING]
> While the [provided implementation][impl-pr] can *parse* linkages as part of function pointer and delegate types and literals,
> it does not semantically apply them to the type yet.
>
> Help is needed on this.

The proposed grammar rules formally do not allow linkage as the first tokens of a function pointer or delegate type,
however, the provided implementation allows omitting parentheses for function pointer or delegate types with linkage,
so that e.g. the first of the two following declarations is accepted, too, and equivalent to the second:
```d
void takesCppFunction( extern(C++) ref int function()  fp) { }
void takesCppFunction((extern(C++) ref int function()) fp) { }
```
Unlike with `ref`, this possible for linkage because linkages are not a parameter storage classes and in all likelihood never will be.
If the linkage is followed up by a `ref`,
because linkage starts a type,
it’s clear that `ref` must be part of the function pointer type syntax,
and isn’t a parameter storage class.

Whether this “unbureaucratic” handling of linkage in parameters of function pointer or delegate type with explicit linkage is desirable
should be discussed by the community.

Expressing parameters of function pointer or delegate type with non-default linkage without parentheses requires this grammar addition
to the [*`Parameter`*](https://dlang.org/spec/function.html#Parameter) grammar:
```diff
    Parameter:
        ParameterDeclaration
        ParameterDeclaration ...
        ParameterDeclaration = AssignExpression

    ParameterDeclaration:
        ParameterAttributes? BasicType Declarator
+       ParameterAttributes? LinkageAttribute ref? TypeCtors? BasicType Declarator
        ParameterAttributes? Type

    Declarator: 
        TypeSuffixes? Identifier
```

In the *`Declarator`* of the added clause,
*`TypeSuffixes`* would be required (not optional)
and exactly one of them would have to be starting with `function` or `delegate`.
The case without a parameter name is already handled by *`Type`*.

### Side-effects

A notable side-effect is that `(const int)` is now a basic type.
The author expects this to be somewhat controversial.
Some programmers will prefer the more consistent new style to the old style,
leading to something like the head-const (`const T`) vs tail-const (`T const`) style discussions in C++.

Another side-effect is that there will be a discrapancy between function pointer and delegate type declarations and member function declarations.
On a member function declaration, type qualifiers and `ref` commute and qualifiers refer to the implicit `this` parameter,
whereas on function pointer and delegate types,
any qualifiers before `ref` refer to the whole type
and any qualifiers after `ref` refer to the return type of the function pointer or delegate type.

A third side-effect is that `extern` will not be available as a parameter storage class.

### Drawbacks

A naïve programmer might assume that `const (shared int)*` is equivalent to `const ((shared int)*)`, but it really is equivalent to `(const shared int)*`.
This is intentional due to the requirement that the changes in syntax be backwards compatible.

## Breaking Changes and Deprecations

For a symbol <code>*s*</code>,
in present-day D, the token sequence <code>(*s*)</code> only parses as an expression.
With the changes proposed by this DIP,
it also parses as a type,
which is a meaningful difference in <code>__traits(isSame, (*s*))</code>.
These can be remedied using a cast instead of (mis-)using parentheses to force parsing as an expression:
<code>cast(typeof(*s*))(*s*)</code>.

A possibly breaking change of [the provided implementation][impl-pr] specifically is
that the serialization of nested function types uses parentheses around the return type,
even in cases where no `ref` or linkage is involved that would require parentheses:
```d
static assert(int function() function().stringof == "int function() function()");
```
This passes with the present-day implementation,
but fails with the provided implemenation,
as it serializes the type as `"(int function()) function()"`.

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
[max-munch-exception]: https://dlang.org/spec/lex.html#source_text
[deprecate-trailing-dot]: https://github.com/dlang/DIPs/pull/233

[sin-2kpi]: https://www.wolframalpha.com/input/?i=sin+2k%CF%80
[sin-2-kpi]: https://www.wolframalpha.com/input/?i=sin%282%29k%CF%80

[cc-0]: https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt
