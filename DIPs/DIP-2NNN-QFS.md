# Primary Type Syntax


| Field           | Value                                                   |
|-----------------|---------------------------------------------------------|
| DIP:            | *TBD*                                                   |
| Review Count:   | 0                                                       |
| Author:         | Quirin F. Schroll ([@Bolpat](https://github.com/Bolpat))|
| Implementation: | [dlang.org PR 3616][spec-pr] • [DMD PR 15269][impl-pr]  |
| Status:         | Draft                                                   |

## Abstract

This proposal aims to ensure that every type
expressible in D’s type system
has a corresponding representation as a sequence of D tokens.
Currently, the type constructs that lack such a representation
are function pointer types and delegate types that return by reference
or possess non-default linkage.

## Contents

* [Rationale](#rationale)
* [Prior Work](#prior-work)
* [Description](#description)
    * [Grammar Changes](#grammar-changes)
    * [String Representation](#string-representation)
    * [Basic Examples](#basic-examples)
    * [Maximal Munch Exceptions](#maximal-munch-exceptions)
    * [Ambiguities Left to Maximal Munch](#ambiguities-left-to-maximal-munch)
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
programmers should be able to copy and paste this type without encountering parse errors.
Semantic problems may still arise, e.g., due to visibility.

The primary concern are function pointers and delegates that return by reference.
To use these as function parameter or return types,
programmers are compelled to use a separate alias declaration.
Alias declarations only support them by special-casing them.
This has been filed as [Bugzilla Issue 2753][issue-2753] *(Cannot declare pointer to function returning `ref`).*

Another point of contention is this asymmetry between types and expressions:
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
adding primary types to the D grammar allows a particularly pleasant resolution of [Bugzilla Issue 2753][issue-2753]:
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

Another related issue is [Bugzilla Issue 24007][issue-24007] *(Function/&ZeroWidthSpace;delegate literals cannot specify linkage).*
It can be solved with a simple addition to the grammar,
which is in the same spirit as the primary proposal.

> [!NOTE]
> The [proof-of-concept implementation][impl-pr] includes almost all of the proposed changes.
> The only proposed feature the author did not implement is linkage of template lambda expressions
> that are not the right-hand side of an alias declaration.
> The implementation could *parse* those linkages,
> but the author found no way to semantically apply them to the type of the lambda.
> Therefore, the implementation makes this a compile error for the time being.
>
> Example:
> ```d
> algo!(function extern(C) (x) => x);
> //             ~~~~~~~~~
> // error: Explicit linkage not supported for template lambda, except for alias.
> ```
>
> Help is needed on this.

## Prior Work

This DIP addresses specific shortcomings of D’s syntax.

Possibly, something like this solution was conceptualized in-passing by Jonathan M. Davis in [a forum post](https://forum.dlang.org/post/mailman.287.1336121273.24740.digitalmars-d@puremagic.com) from 2012.

## Description

### Grammar Changes

> [!NOTE]
> Optional grammar entities are represented by `?` here.

Because this DIP is focused primarily on the grammar,
contrary to what is customary in DIPs that propose grammar changes,
the grammar changes are given primary focus.

The following addresses the [function literal](https://dlang.org/spec/expression.html#FunctionLiteral) syntax.

```diff
    FunctionLiteral:
-       function RefOrAutoRef? BasicTypeWithSuffixes? ParameterWithAttributes? FunctionLiteralBody
-       delegate RefOrAutoRef? BasicTypeWithSuffixes? ParameterWithMemberAttributes? FunctionLiteralBody
+       function LinkageAttribute? RefOrAutoRef? BasicTypeWithSuffixes? ParameterWithAttributes? FunctionLiteralBody
+       delegate LinkageAttribute? RefOrAutoRef? BasicTypeWithSuffixes? ParameterWithMemberAttributes? FunctionLiteralBody
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
Expressing this formally in the grammar is possible,
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
> The [proof-of-concept implementation][impl-pr] produces this error message
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
> The [proof-of-concept implementation][impl-pr] does this correctly,
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

The parentheses are also required here.
Otherwise, the second `ref` would be interpreted as referring to the variable like the first,
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

### Maximal Munch Exceptions

Lexing and parsing, for the most part, follow the maximal munch principle.
Maximal munch is the following general rule:
> If the lexer or parser can meaningfully interpret the next character or token, respectively, as part of what it tries to match,
> it will.
> Only if it can’t,
> it considers that the end of the current match if possible,
> backtracks,
> or issues an error.
>
> See also: [Wikipedia on *Maximal munch*](https://en.wikipedia.org/wiki/Maximal_munch) 

The only currently-existing exception the author is aware of is [lexing floating point numbers][max-munch-exception].
As of this writing, there is [an open Pull Request][deprecate-trailing-dot] to deprecate this exception.

The following exceptions to maximal munch are being proposed for backwards compatibility.

#### Qualifiers stick to open parentheses

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

#### Lambda return type versus parameter list

In function literal expressions starting with `function` or `delegate`,
both the return type (the [*`BasicTypeWithSuffixes`*](https://dlang.org/spec/expression.html#BasicTypeWithSuffixes)) and the parameter list are optional.

With the changes proposed by this DIP,
because a basic type can start with an opening parenthesis,
this would render some lambda expressions ambiguous,
and if maximal munch were used to disambiguate,
existing code may change meaning.

For example:
```d
auto fp = function (int) => 0;
```

Currently, `(int)` is an argument list,
but with the proposed changes without the following exception,
it would become the return type.

Therefore, another exception to maximal munch is proposed:
In function literal expressions starting with `function` or `delegate`,
if there is exactly one set of same-level parentheses between the introductory keyword
and the first contract or (if no contracts are given) the function literal body,
those parentheses denote the parameter list.

If a programmer intends to specify a return type that starts with an opening parenthesis,
a parameter list must be specified, even if it is empty and would be optional otherwise.

For example:
```d
auto fp1 = function (ref int function())    => null;
auto fp2 = function (ref int function()) () => null;
```

The function pointer `fp1` takes one parameter by reference which is of function pointer type.
Its return type is `typeof(null)` by inference.

The function pointer `fp2` takes takes no parameters and returns a function pointer;
the returned function pointer returns an `int` by reference.

The author was made aware of this by the D Forum user named Tim in [this thread](https://forum.dlang.org/post/gitxzhsdymuehuakdvew@forum.dlang.org)
and thanks Tim for his help.

#### Scope guards

As statements,
scope guards conflict with declarations of `scope` variables
whose type is expressed starting with an opening parenthesis.

The goal of the following design is to allow this code with the noted meaning:
```d
// scope variable:
scope (ref int delegate()) dg = &obj.foo;

// scope guard:
scope(exit) dg = null;

// scope guard (hypothetical future example):
scope(failure, FormatException e) { log(e.msg); }
```

Conceptually, distinguish between *simple* scope guards and *elaborate* scope guards.

Simple scope guards have a single token argument: <code>scope(*Token*)</code>.
All three currently existing scope guards are simple
and the token is always an identifier.
Simple scope guards are followed by a [*`NonEmptyOrScopeBlockStatement`*](https://dlang.org/spec/statement.html#NonEmptyOrScopeBlockStatement).

Elaborate scope guards, of which none currently exist,
use more than one token as their argument.
This DIP proposes they require a [*`BlockStatement`*](https://dlang.org/spec/statement.html#BlockStatement).
This removes no design space with respect to arguments of future elaborate scope guards,
only the option to use a [*`NonEmptyStatementNoCaseNoDefault`*](https://dlang.org/spec/statement.html#NonEmptyStatement).

This compromise works because no single-token type requires parentheses (and likely none ever will)
and <code>scope(*Tokens*) { … }</code> is not meaningful as a statement other than a scope guard.

> [!NOTE]
> The restriction to a *`NonEmptyStatement`* is to make the implementation easier.
> A more thorough analysis yields the following list of *`NonEmptyStatementNoCaseNoDefault`* cases
> that cannot be a declaration and are unlikely to ever be:
> *`IfStatement`*,
> *`WhileStatement`*,
> *`DoStatement`*,
> *`ForStatement`*,
> *`ForeachStatement`*,
> *`SwitchStatement`*,
> *`FinalSwitchStatement`*,
> *`WithStatement`*,
> *`SynchronizedStatement`*,
> *`TryStatement`*,
> *`AsmStatement`*,
> *`ForeachRangeStatement`*,
> *`ConditionalStatement`*,
> *`StaticForeachStatement`*, and
> *`ImportDeclaration`*
>
> These begin with certain keywords that can easily be recognized.
> However, actually recognizing them makes the language more complicated.
>
> Absent are:
> *`LabeledStatement`* leads to weird syntax.
> *`ExpressionStatement`* is possibly ambiguous.
> *`DeclarationStatement`* is possibly ambiguous.
> *`ContinueStatement`* / *`BreakStatement`* / *`ReturnStatement`* / *`GotoStatement`* are not allowed in a scope guard.
> *`ScopeGuardStatement`* makes no sense.
> *`MixinStatement`* closes a gap possibly useful for future proposals.
> *`PragmaStatement`* closes a gap possibly useful for future proposals.
>
> Should an elaborate scope guard be proposed,
> that proposal can address adding e.g. <code>scope(*Tokens*) if (…) …</code>
> for its convenience.

The author was made aware of possible problems with `scope` by the D Forum user named Tim in [this Forum post](https://forum.dlang.org/post/gitxzhsdymuehuakdvew@forum.dlang.org)
and thanks Tim for his help.

### Ambiguities Left to Maximal Munch

The following are observed consequences of the proposed changes.

#### Anonymous nested classes

Anonymous nested class expressions have two optional constructs possibly surrounded by parentheses:
The arguments passed to the anonymous nested class’s constructor
and the first base class or implemented interface.

Applying maximal munch, the first parentheses denote the argument list.
Yet, similar to the case of function literals,
if a programmer wanted to enclose the first base class or interface with parentheses,
an explicit argument list must be provided.

In practice, this is not a problem because no base class requires parentheses around it.
It is very unlikely that programmers actually write `new class (MyBaseClass) {}`,
and even if they do, the code likely ends up being semantically invalid.

The author suggests to disallow <code>(*Type*)</code>
for the list of base class and interfaces.
This is, however, not part of what this DIP proposes.

The author was made aware of this ambiguity by the D Forum user named Tim in [this Forum post](https://forum.dlang.org/post/gitxzhsdymuehuakdvew@forum.dlang.org)
and thanks Tim for his help.

#### Align and Extern

The `align` keyword always introduces the `align` attribute that sets alignment.
The alignment can be optionally stated in parentheses, e.g. `align(8)`,
and without arguments, `align` is equivalent to `align(default)` specifying to use default alignment.

The `extern` keyword can be the `extern` attribute which is used to mark (variable) declarations as declarations that are not also definitions and has no arguments.
It is also used to introduce linkage, and in that case, has an opening parenthesis following it.

The ambiguous parses are:
* <code>align ( *Tokens* )</code> when *`Tokens`* could both be an *`AssignExpression`* or a *`Type`*.
* <code>extern ( *Tokens* )</code> when *`Tokens`* could both be a linkage or a *`Type`*.

Maximal munch dictates that if a parenthesis follows `align`, that is the alignment argument,
and if a parenthesis follows `extern`, it is a linkage specification.

When `align` is followed by what the programmer intended to be a type that happens to start with a in parenthesis,
a possible solution is to use `align(default)` instead.

When `extern` is followed by what the programmer intended to be a type that happens to start with a in parenthesis,
a possible solution is to add explicit linkage, e.g. `extern extern(D)`.
All entities that support `extern` naturally have a linkage.

The `align`, `extern`, and linkage attributes are not storage classes,
therefore if they treat what was intended as a type as their argument,
that means to the parser expects a *`BasicType`* later,
but none is found; usually for `align` and definitely for `extern`.

For the code to be unintentionally semantically valid,
a storage class (e.g. `static`) must be present to allow for type deduction.
Storage classes and attributes can be interchanged.
If the storage class is lexically behind the attribute,
e.g. `align (…) static` or `extern (…) static`,
the programmer cannot have intended the parentheses denote a type
because types are denoted after the last storage class or attribute.

In case the storage class is first,
e.g. `static align (…)` or `static extern (…)`,
only `align` succeeds.
That is because an `extern` variable must not have an initializer,
but type inference requires one.

What remains is something like <code>static align (*Tokens*) x = …;</code>,
where *`Tokens`* parse as an *`AssignExpression`* and a *`Type`*.
It is unlikely that code like already exists because of [GitHub Issue 20727][issue-20727]:
For a local variable, the alignment is not applied,
and for any other variable, it is a parse error.
Lastly, that *`Tokens`* is valid as an *`AssignExpression`* and a *`Type`* semantically
is unlikely to begin with.
One would have to use a type that has a `static` indexing operator
that returns an integral value;
the evaluation must succeed at compile-time and result in a valid argument to `align`,
and the argument to that indexing operator (if any) must therefore be known at compile-time
or semantically be valid as a type itself.
This is simplest way to trigger this oddity:
```d
struct MyType { static size_t opIndex() => 4; }
void f()
{
    static align (MyType[]) x = [MyType()];
}
```

The author found no type that *requires* an initial parenthesis
*and* is valid as an *`AssignExpression`*.

The author was made aware of these ambiguities by the D Forum user named Tim in [this Forum post](https://forum.dlang.org/post/gitxzhsdymuehuakdvew@forum.dlang.org)
and thanks Tim for his help.

### Linkage

In short, the changes proposed in this subsection make the following syntax valid:
```d
void f(extern(C) int function() fp) { }
if (extern(C) int function() fp = null) { }
foreach (extern(C) int function() fp; [ ]) { }
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
possibly leading to something like the [east-const vs west-const style](https://hackingcpp.com/cpp/design/east_vs_west_const.html) discussions in C++.

#### Function pointer and member function declaration discrepancy

There will be a discrepancy between function pointer and delegate type declarations and member function declarations.
On a member function declaration, type qualifiers and `ref` commute and qualifiers refer to the implicit `this` parameter,
whereas on function pointer and delegate types,
any qualifiers before `ref` refer to the whole type
and any qualifiers after `ref` refer to the return type of the function pointer or delegate type.

#### Parameter storage class `extern`

The keyword `extern` will not be easily available as a parameter storage class.
Introducing it will likely require another exception to maximal munch to distinguish linkage from sole `extern`.

#### Lambdas with unnamed parameters

Lambdas with unnamed parameters are easier to write:
```d
struct S {}
auto fp = (S) => 0; // Error: […] type `void` is inferred from initializer […]
// With this proposal:
auto fp = ((S)) => 0;
// typeof(fp) == int function(S __param_0) pure nothrow @nogc @safe
```
This is because in `(S) => 0`, the identifier `S` does not refer to the struct type, but is a fresh variable name.
In `((S)) => 0`, however, the part `(S)` cannot be a variable name, thus it is treated as a parameter type,
and as such, refers to the struct `S`.

### Drawbacks

A naïve programmer might think that `const (shared int)*` is the same as `const ((shared int)*)`,
but it actually equals `(const shared int)*`.
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

The same does not apply to template alias and sequence parameters bound to <code>(*s*)</code>
with <code>*s*</code> a symbol that holds a value of some type.
That is because there, <code>(*s*)</code> is treated identical to <code>*s*</code>.
It is noteworthy, though, that for template alias and sequence parameters,
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
However, the [D Language Specification](https://dlang.org/spec/property.html#stringof) does not mandate specific string representations of types:
“The string representation for a type or expression can vary.”

### Deprecations

Even if there is breakage possible,
that is deemed so niche and generally unlikely,
that no deprecation is proposed.

## Copyright & License

Copyright © 2024–2025 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0][cc-0]

## History

The DIP Manager will supplement this section with links to forum discussions and a summary of the formal assessment.


[spec-pr]: https://github.com/dlang/dlang.org/pull/3616
[impl-pr]: https://github.com/dlang/dmd/pull/15269

[issue-2753]: https://github.com/dlang/dmd/issues/17505
[issue-24007]: https://github.com/dlang/dmd/issues/20304
[issue-20727]: https://github.com/dlang/dmd/issues/20727

[ref-var-dip]: https://github.com/dlang/DIPs/blob/master/DIPs/accepted/DIP1046.md
[max-munch-exception]: https://dlang.org/spec/lex.html#source_text
[deprecate-trailing-dot]: https://github.com/dlang/DIPs/pull/233

[sin-2kpi]: https://www.wolframalpha.com/input/?i=sin+2k%CF%80
[sin-2-kpi]: https://www.wolframalpha.com/input/?i=sin%282%29k%CF%80

[cc-0]: https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt
