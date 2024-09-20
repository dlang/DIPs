# Primary Type Syntax


| Field           | Value                                                   |
|-----------------|---------------------------------------------------------|
| DIP:            | *TBD*                                                   |
| Review Count:   | 0                                                       |
| Author:         | Quirin F. Schroll ([@Bolpat](https://github.com/Bolpat))|
| Implementation: | [dlang.org PR 3616][spec-pr] • [DMD PR 15269][impl-pr]  |
| Status:         | Draft                                                   |

## Abstract

The objective of this proposal is to ensure that every type
that can be expressed within the D programming language’s type system
has a corresponding representation as a sequence of D tokens.
Currently, the type constructs that lack such a representation are function pointer types and delegate types that return by reference or possess non-default linkage.

## Contents

* [Rationale](#rationale)
* [Prior Work](#prior-work)
* [Description](#description)
    * [Grammar Changes](#grammar-changes)
    * [String Representation](#string-representation)
    * [Basic Examples](#basic-examples)
    * [Maximal Munch Exception](#maximal-munch-exception)
    * [Linkage](#linkage)
* [Possible Problems](#possible-problems)
    * [Side-effects](#side-effects)
    * [Drawbacks](#drawbacks)
    * [Breaking Changes](#breaking-changes)
    * [Deprecations](#deprecations)
* [Copyright & License](#copyright--license)
* [Reviews](#history)

## Rationale

Not every type that the compiler can represent internally is expressible using existing D syntax.
For instance, when `pragma(msg)`, `stringof`, or diagnostics serialize a type,
the programmer should be able to copy and paste this type and not get parsing errors.
Semantic problems may still arise, e.g. due to visibility.

The main culprits are function pointers and delegates that return by reference.
To use those as function parameter or return types,
programmers are compelled to use a separate alias declaration.
Alias declarations only support them by special-casing them.
This has been filed as [Issue 2753][issue-2753] *(Cannot declare pointer to function returning `ref`).*

Another point of contention is an asymmetry between types and expressions:
For an expression <code>*e*</code>, also <code>(*e*)</code> is an expression and is functionally identical,
but for a type <code>*T*</code>, the token sequence <code>(*T*)</code> does not denote a type.
For expressions, the grammar rule stating that if <code>*e*</code> is an expression, so is <code>(*e*)</code>,
is referred to as *primary expression.*
This DIP proposes the same mechanism for types, hence the title includes *primary types.*
In the D grammar and this document, the term *basic type* is used.
In short, part of the proposed changes is making basic types be primary types.

The current D syntax almost supports primary type syntax:
There exists a grammar rule that states:
If <code>*T*</code> denotes a type and <code>*q*</code> is a type qualifier, then <code>*q*(*T*)</code> denotes a type.
In fact, <code>*q*(*T*)</code> is even a *basic type,*
which, simply put, means that unlike <code>*q* *T*</code>,
it can be used everywhere where a type is expected.
If the type qualifier in this rule were optional,
D would already have primary types.

While these issues may seem unrelated,
adding primary types to the D grammar allows a particularly pleasant resolution of [Issue 2753][issue-2753]:
If <code>(*T*)</code> were a basic type for every type *`T`*
and <code>ref *R* function(…)</code> were a type (albeit no basic type),
<code>(ref *R* function(…))</code> could be used anywhere a basic type is required;
that is, in particular, as a function return type or a parameter type,
and there would be no ambiguity what `ref` refers to,
and the `ref` is at a place where programmers expect it to be.
Additionally, in places where a general type is expected
(e.g.
<code>is(*T*)</code> tests,
the <code>cast(*T*)</code> operator,
the <code>typeid(*T*)</code> operator,
template type parameters/&ZeroWidthSpace;arguments/&ZeroWidthSpace;constraints/&ZeroWidthSpace;defaults,
template value parameter types,
and `pragma(msg)`),
<code>ref *R* function(…)</code> can be used even without parentheses.  
Of course, everything said about `function` types also applies to `delegate` types.
Also, everything said about `ref` here also applies to linkage,
except that linkage has no ambiguity problem for function parameters.

Another related issue is [24007][issue-24007] *(Function/&ZeroWidthSpace;delegate literals cannot specify linkage).*
It can be solved with a simple addition to the grammar,
which is in the same spirit as the primary proposal.

> [!WARNING]
> While the [provided implementation][impl-pr] can *parse* linkages as part of lambda expressions,
> it does not semantically apply them to the type yet.
>
> Help is needed on this.

## Prior Work

This DIP addresses specific shortcomings of D’s syntax.

Possibly, something like this solution was conceptualized in-passing by Jonathan M. Davis in [a forum post](https://forum.dlang.org/post/mailman.287.1336121273.24740.digitalmars-d@puremagic.com) from 2012.

## Description

### Grammar Changes

> [!NOTE]
> Optional grammar entities are represented by `?` here.

Because this DIP is aimed at the grammar primarily,
contrary to as is customary in DIPs that propose grammar changes,
the grammar changes are given primary focus.

The following addresses the [function literal](https://dlang.org/spec/expression.html#FunctionLiteral) syntax.

```diff
    FunctionLiteral:
-       function RefOrAutoRef? Type? ParameterWithAttributes? FunctionLiteralBody
-       delegate RefOrAutoRef? Type? ParameterWithMemberAttributes? FunctionLiteralBody
+       function LinkageAttribute? RefOrAutoRef? Type? ParameterWithAttributes? FunctionLiteralBody
+       delegate LinkageAttribute? RefOrAutoRef? Type? ParameterWithMemberAttributes? FunctionLiteralBody
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
> to offer all possible ways clarifying parentheses could be added.
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

### String Representation

To align string representations with code,
`ref` must be prefixed in the output of `pragma(msg)`, `stringof`, and error messages.
If a function pointer or delegate type that returns by reference is a function parameter or return type,
that type must be in parentheses.

While linkage is already prefixed in string representations of function pointer and delegate types with non-default linkage,
parentheses have to be used when a function pointer or delegate type with non-default linkage is a function return type.
When a function pointer or delegate type with non-default linkage is a function parameter type,
no parentheses are needed.
This is outlined in [§ Linkage](#linkage) below.

> [!NOTE]
> The [provided implementation][impl-pr] does this correctly,
> however, it also inserts parentheses in some places where they are optional.

### Basic Examples

#### Declaring a function pointer variable

In present-day D, one cannot spell out a function pointer type when the function returns by reference.
As a workaround, one can use an alias or indirect methods such as using `typeof` on an appropriate expression.
With the changes proposed by this DIP, this is how it’s done:
```d
(ref int function() @safe) fp = null;
```
Here, `fp` is variable of function pointer type.
The function returns its result by reference.
Omitting parentheses would render `fp` a [reference variable][ref-var-dip] of type `int function() @safe`.
A reference variable of type `ref int function() @safe` would be declared like this:
```d
ref (ref int function() @safe) fp = *null;
```

The parentheses are required in this case as well;
otherwise, the second `ref` would be considered referring to the variable like the first,
and redundant storage classes are an error in D.

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

Lexing and parsing, for the most part, follow the maximal munch principle.
Maximal munch is the following general rule:
> If the lexer or parser can meaningfully interpret the next character or token, respectively, as part of what it tries to match,
> it will.
> Only if it can’t,
> it considers that the end of the current match if possible,
> or issues an error.

The only currently-existing exception the author is aware of is [lexing floating point numbers][max-munch-exception].
As of this writing, there is [an open Pull Request][deprecate-trailing-dot] to deprecate this exception.

For backwards compatibility, this DIP proposes to add another exception to maximal munch:
Whenever an opening parenthesis follows a type qualifier,
this is considered effectively one token and refers to the *`BasicType`* rule.

The exception is required so that e.g. the following declaration keeps the meaning it currently has:
```d
void f(const(int)[]);
```
In current-day D, the `const` in the parameter list would be first parsed as a storage class,
but that fails because the opening parenthesis can neither belong to another storage class nor a basic type.
Therefore, the parser backtracks and succeeds to parse `const` as part of a basic type.
With the proposed grammar changes, the failure on the opening parenthesis doesn’t happen anymore
because `(int)` denotes a basic type.
In total, that would render the parameter type equivalent to `const(int[])`.

However, unless misleading spaces are inserted between the type qualifier and the opening parenthesis,
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

In short, the changes proposed in this subsection make the following valid syntax:
```d
void f(extern(C) int function() fp) { }
if (extern(C) int function() fp = null) { }
foreach (extern(C) int function() fp; [ ]) { }
```

The underlying idea is that in those places,
because linkage is currently invalid
and would stay invalid given the proposed changes up to this point,
linkage can be explicitly allowed to introduce a type,
even if a general type is not allowed and cannot be allowed
because `ref` already has meaning in these contexts.

These proposed changes are not needed for the primary goal of the DIP,
which is to make these types canonically expressible,
and can instead be considered as convenience and, in fact, consistency features.

#### Parameters

The proposed grammar up to this point does not allow linkage as the first tokens of a function pointer or delegate type parameter,
and requires explicit parentheses to form a basic type,
however, the provided implementation allows omitting those parentheses,
so that the first of the two following declarations is accepted, too, and equivalent to the second:
```d
void takesCppFunction( extern(C++) ref int function()  fp) { }
void takesCppFunction((extern(C++) ref int function()) fp) { }
```
Unlike with `ref`, this possible for linkage because linkages are not parameter storage classes and in all likelihood never will be.
If the linkage is followed up by a `ref`,
because linkage starts a type,
it’s clear that `ref` must be part of the function pointer type syntax,
and isn’t a parameter storage class.

This kind of handling of linkage is derived from how linkage is serialized in the current state of the language.

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
If this change were rejected, leaving the *`Type`* rule as-is would lead to an inconsistency:
Unnamed parameters would be allowed to omit parentheses, but not named ones.

#### Conditions

Similar to linkage in function parameter declarations,
conditions of `if`, `while`, and `switch` can declare variables.
There, `ref` can’t be the first token of a function or delegate type because of reference variables,
but linkage is unambiguous.

Therefore, add to the [*`IfCondition`*](https://dlang.org/spec/statement.html#IfConddition) grammar:
```diff
    IfCondition:
        IfConditionStorageClasses Identifier = Expression
        IfConditionStorageClasses? BasicType Declarator = Expression
+       IfConditionStorageClasses? LinkageAttribute ref? TypeCtors? BasicType Declarator = Expression

    Declarator:
        TypeSuffixes? Identifier
```

As before, in the *`Declarator`* of the added clause,
*`TypeSuffixes`* would be required (not optional)
and exactly one of them would have to be starting with `function` or `delegate`.

#### Loop Variables

Similar to linkage in conditions,
loop variables for `foreach` and `foreach_reverse` can declare variables.
There, too, requiring parentheses to form a basic type is not really necessary,
so allowing to omit them is warranted.

Therefore, add to the [*`ForeachType`*](https://dlang.org/spec/statement.html#ForeachType) grammar:

```diff
    ForeachType:
        ForeachTypeAttributes? BasicType Declarator
+       ForeachTypeAttributes? LinkageAttribute ref? TypeCtors? BasicType Declarator
        ForeachTypeAttributes? Identifier
        ForeachTypeAttributes? alias Identifier

    Declarator:
        TypeSuffixes? Identifier
```

As always, in the *`Declarator`* of the added clause,
*`TypeSuffixes`* would be required (not optional)
and exactly one of them would have to be starting with `function` or `delegate`.

## Possible Problems

### Side-effects

This is a list of otherwise unrelated observations that the author made when developing this DIP.

#### New kind of basic type

With the changes proposed by this DIP, `(const int)` denotes a basic type.
The author expects this to be somewhat controversial.
Some programmers will prefer the more consistent new style to the old style,
leading to something like the [east-const vs west-const style](https://hackingcpp.com/cpp/design/east_vs_west_const.html) discussions in C++.

#### Function pointer and member function declaration discrapancy

There will be a discrepancy between function pointer and delegate type declarations and member function declarations.
On a member function declaration, type qualifiers and `ref` commute and qualifiers refer to the implicit `this` parameter,
whereas on function pointer and delegate types,
any qualifiers before `ref` refer to the whole type
and any qualifiers after `ref` refer to the return type of the function pointer or delegate type.

#### Parameter storage class `extern`

The keyword `extern` will not be available as a parameter storage class.
Introducing it will likely require another excpetion to Maximum Munch to distinguish linkage from sole `extern`.

#### Lambdas with unnamed parameters

Lambdas with unnamed parameters are easier to write:
```d
struct S {}
auto fp = (S) => 0; // Error: […] type `void` is inferred from initializer […]
// With this proposal:
auto fp = ((S)) => 0;
// typeof(fp) == int function(S __param_0) pure nothrow @nogc @safe
```
This is because in `(S) => 0`, `S` does not refer to the struct type, but is a fresh variable name.
In `((S)) => 0`, however, the part `(S)` cannot be a variable name, thus it’s treated as a parameter type,
and as such, refers to the struct `S`.

### Drawbacks

A naïve programmer might assume that `const (shared int)*` is equivalent to `const ((shared int)*)`, but it really is equivalent to `(const shared int)*`.
This is intentional due to the requirement that the changes in syntax be backwards compatible.

### Breaking Changes

#### Symbols

For a symbol <code>*s*</code> that holds a value of some type,
in present-day D, the token sequence <code>(*s*)</code> only parses as an expression.
With the changes proposed by this DIP,
it also parses as a type,
which is a meaningful difference in <code>__traits(isSame, (*s*), …)</code>
because the `isSame` trait preferentially parses its arguments as types.
This can be remedied using a cast to unambiguously force parsing as an expression:
<code>cast(typeof(*s*)) *s*</code>.

The same does not apply to template alias and squence parameters bound to <code>(*s*)</code>
with <code>*s*</code> a symbol that holds a value of some type.
That is because there, <code>(*s*)</code> is treated identical to <code>*s*</code>.
It is noteworthy, though, that for template alias and squence parameters,
the expression <code>cast(typeof(*s*)) *s*</code> is identical to the symbol <code>*s*</code>,
and that non-symbol expressions do not bind to template sequence parameters,
and the only reliable way to force binding a template alias parameter to the value of a symbol,
and not the symbol itself, is using an expression that produces a new value.

#### String Representations

Another breaking change is with the string representation of function pointer and delegate types
that return by reference.
Those will be rendered the same as they would be written in code,
but currently, the `ref` is suffixed with other attributes,
whereas with this DIP, `ref` will of course be prefixed.

A breaking change of [the provided implementation][impl-pr] specifically is
that the serialization of nested function pointer and/or delegate types uses parentheses around the return type,
even in cases where no `ref` or linkage is involved that would require parentheses:
```d
static assert(int function() function().stringof == "int function() function()");
```
This passes with the present-day implementation,
but fails with the provided implementation,
as it serializes the type as `"(int function()) function()"`.
However, the D Language Specification does not mandate specific string representations of types:
[“The string representation for a type or expression can vary.”](https://dlang.org/spec/property.html#stringof)

### Deprecations

Even if there is breakage possible,
that is deemed so niche and generally unlikely,
that no deprecation is proposed.

## Copyright & License

Copyright © 2024 by Quirin F. Schroll

Licensed under [Creative Commons Zero 1.0][cc-0]

## History

The DIP Manager will supplement this section with links to forum discussions and a summary of the formal assessment.


[spec-pr]: https://github.com/dlang/dlang.org/pull/3616
[impl-pr]: https://github.com/dlang/dmd/pull/15269

[issue-2753]: https://issues.dlang.org/show_bug.cgi?id=2753
[issue-24007]: https://issues.dlang.org/show_bug.cgi?id=24007

[ref-var-dip]: https://github.com/dlang/DIPs/blob/master/DIPs/accepted/DIP1046.md
[max-munch-exception]: https://dlang.org/spec/lex.html#source_text
[deprecate-trailing-dot]: https://github.com/dlang/DIPs/pull/233

[sin-2kpi]: https://www.wolframalpha.com/input/?i=sin+2k%CF%80
[sin-2-kpi]: https://www.wolframalpha.com/input/?i=sin%282%29k%CF%80

[cc-0]: https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt
