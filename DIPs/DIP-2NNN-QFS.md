# Primary Type Syntax


| Field           | Value                                                   |
|-----------------|---------------------------------------------------------|
| DIP:            | (number/id -- assigned by DIP Manager)                  |
| Review Count:   | 0 (edited by DIP Manager)                               |
| Author:         | Quirin F. Schroll ([@Bolpat](github.com/Bolpat))        |
| Implementation: | [dlang.org PR 3616](https://github.com/dlang/dlang.org/pull/3616) • [DMD PR 15269](https://github.com/dlang/dmd/pull/15269) |
| Status:         | Draft                                                   |

## Abstract

The goal of this proposal is that every type expressible by D’s type system also has a representation as a sequence of D tokens.
The type constructs that lack a representation are function pointer and delegate types that return by reference and/or have a non-default linkage.

## Contents
* [Rationale](#rationale)
* [Prior Work](#prior-work)
* [Description](#description)
* [Breaking Changes and Deprecations](#breaking-changes-and-deprecations)
* [Reference](#reference)
* [Copyright & License](#copyright--license)
* [Reviews](#reviews)

## Rationale

Not every type that the compiler can represent internally is expressible using present-day D syntax.
For example, when `pragma(msg)` or an error messages displays a type,
the programmer should be able to copy and paste this type and not get parsing errors.
(Semantic problems with using the type may exist, such as visibility.)

The primary offender is function pointers and delegates returning by reference.
To use those, programmers are forced to use separate alias declarations,
because they support such types by special-casing them.

This kind of workaround is not possible in an error message
and is undesireable at other places.

A separate issue is an asymmetry between types and expressions:
For an expression `e`, also `(e)` is an expression and is for all intents and purposes the same.
For a type `t`, the token sequence `(t)` in general is not a type.

For expressions, the grammar rule saying that if `e` is an expression, so is `(e)`,
is called *primary expression.*
This DIP proposes the same mechanism for types, therefore the name *primary types.*

Present-day D almost has primary type syntax:
There is a grammar rule that says:
If `t` is a type, so is `const(t)`.
In fact, `const(t)` is even a *basic type.*
Of course, there are type constructors other than `const`,
but the grammar rule requires one.
If it didn’t, D would have primary types already.

## Prior Work

None.
This DIP addresses specific shortcomings of D’s syntax.

## Description

### Grammar Changes

Because this DIP is aimed at the grammar only,
contrary as is usual in DIPs that propose grammar changes,
the grammar changes are given primary focus.

Subscript `(opt)` for optional grammar entities is represented by `?` here.
```diff
  Type:
      TypeCtors? BasicType TypeSuffixes?
+     ref TypeCtors? BasicType TypeSuffixes? CallableSuffix NonCallableSuffixes?
+     LinkageAttribute ref? TypeCtors? BasicType TypeSuffixes? CallableSuffix NonCallableSuffixes?

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
+       NonCallableSuffix
+       CallableSuffix
+
+   NonCallableSuffixes:
+       NonCallableSuffix NonCallableSuffixes?
+
+   NonCallableSuffix:
        *
        [ ]
        [ AssignExpression ]
        [ AssignExpression .. AssignExpression ]
        [ Type ]

+   CallableSuffix:
        delegate Parameters MemberFunctionAttributes?
        function Parameters FunctionAttributes?
```

* The first two additions add grammar rules so that `ref` and linkage can be part of a function pointer or delegate type.
  This necessitates that after the `BasicType` that will be the return type of the function pointer or delegate type,
  the `function` or `delegate` keyword and a parameter list follow.
  The fuzz about `NonCallableSuffixes` is to emphasize that the `ref` refers to the outermost `function` or `delegate`.
* The next change makes the type constructor optional in the rule that introduces primary type syntax.
* What remains is mere restructuring so that `NonCallableSuffixes` and `CallableSuffix` are defined.

### Basic Types and General Types

There are places where a `BasicType` plus `TypeSuffixes?` is required;
for example, function return types or function parameter types are basic types followed by type suffixes.
As far as the grammar is concerned, in the following, none of the `const` is part of a basic type:
```d
const int f(const int*);
```
The first `const` isn’t even affecting the return type – it’s a member function attribute and affects the implicit `this` parameter,
and it’s a well-known rookie error to put it in front and misinterpret it as part of the return type.  
The second `const` is a parameter storage class;
as far as the grammar is concerned,
it has nothing to do with the parameter’s type.
Only the semantics of `const` as a parameter storage class is:
Wrap it around the whole parameter’s (basic) type.
This means that the parameter type is equivalent to `const(int*)` and not `const(int)*`,
another well-known rookie error.

Adding only the linkage and `ref` to the grammar would not help much.
If we want to use a non-basic type where a basic type is required,
we need some way to express the same type, but as a basic type.

For parameters and return type/function attributes, there is also a clash with `ref`.
It indicates the parameter is bound by reference or the funcrion returns by reference,
and a parameter or return type of function pointer or delegate that returns by reference must be different.
And it must be clear what is what.

This is why there is the grammar rule that, essentially, says:
“Put parentheses arount it and you’re good to go.”
It solves everything.

### Basic Examples

#### Declaring a function pointer variable

In present-day D, one cannot even spell out a `ref` returning function pointer type, except using an alias.
With the changes proposed by this DIP, this is how it’s done:
```d
(ref int function() @safe) fp = null;
```
Here, `fp` is variable of function pointer type.
The function returns its result by reference.
Omitting parentheses is an error.
Not allowing `ref` without parentheses not only clarifies intent,
it keeps `ref` variables open for the future.
As of writing this, Walter Bright has a proposal draft for `ref` variables [here](https://github.com/WalterBright/documents/blob/master/varRef.md).

#### Declaring a function that returns a function pointer

What if we want to return a function pointer like `fp` by reference from a function?
```d
ref (ref int function() @safe) returnsFP() @safe => fp;
```
The function `returnsFP` returns a function pointer by reference.
The function pointer returns an `int` by reference.
The first `ref` refers to `returnsFP` and signifies that it returns its result by reference.
The second `ref` (in parentheses) is part of the function pointer type that is,
the return type of `returnsFP`.

While one might think the parentheses are optional, they are not.
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

### Corner Cases

Form the outset, in nested function pointer return types,
it is not clear to which of the function pointer types a `ref` should refer.
I.e. given `ref int function() function()`, to which of the folliwing should it be equivalent?
* ` ref (int function()) function()`
* `(ref  int function()) function()`

The author feels that the second option is odd.
The max munch rule would clearly suggest the first option.
Disallowing it is harsh and also non-trivial to implement.
In the author’s opinion, the syntax is not too misleading to be disallowed,
but community discussion might bring more insight.

As per the grammar above, it is the first.
That is because if it were the second, the first `function()`, a `CallableSuffix`,
would be followed up by another `CallableSuffix` – which is expressly not allowed.

### Max Munch Exception

Parsing follows the “max munch rule” (with one excpetion that’s not relevant for this DIP):
If the imaginary parsing cursor can meaningfully parse the next tokens as part of what it tries to parse, it will,
and only if it can’t will it try to close the current entity and go to the previous level.

For backwards compatibility, this DIP proposes to add an exception to max munch:
Whenever a type constructor (`TypeCtor` in the grammar) is followed by an opening parenthesis,
this is considered effectively one token and refers to the `BasicType` rule.

Otherwise, the follwing would change meaning:
```d
void f(const(int)[]);
```
In current-day D, the `const` in the parser parameter list would be tried to be parsed as a storage class,
but that fails because the opening parenthesis cannot be another storage class or a basic type.
Therefore, the parser backtracks and attempts to parse `const` as part of a basic type, which succeeds.  
With the grammar change, the failure on the parenthesis doesn’t happen anymore
because `(int)` parses as a basic type.
That would render the parameter type equivalent to `const(int[])`.

That would break a lot of code.

Intuitively, however, unless misleading spaces are inserted between the type constructor and the operning parenthesis,
this exception follows mathematical conventions:
Normally, mathematicians write “sin 2*k*π”
with the clear understanding that what the sine function applies to is the whole 2*k*π.
However, were it written sin(2)*k*π, it is rather clear that the sine function applies only to 2.
(Notably, WolframAlpha agrees with this notion: [sin 2π](https://www.wolframalpha.com/input/?i=sin+2%CF%80) vs. [sin(2)π](https://www.wolframalpha.com/input/?i=sin%282%29%CF%80))

D’s type constructors will work like that:
In `const int[]`, the `const` applies to everything that comes after it,
extending as far to the right as possible,
but in `const(int)[]` it only applies to `int`.

### Linkage

The discussion about `ref` is much more relevant than that of linkage as pass-by-reference is commonplace,
whereas linkage is niche in comparison.

However, a function pointer type with non-default linkage
(depending on context, the default is usually `extern(D)`, but can be `extern(C)` e.g. in `betterC` mode),
can likewise not be expressed by the grammar.

The proposed grammar rules allow linkage as the first tokens of a function pointer or delegate type.
Most of the parenthesis rules apply the same, except for parameters:
```d
void takesCppFunction(extern(C++) ref int function() fp) { }
```
As `extern` is not a parameter storage class, no parentheses are needed.
Also, if the linkage is followed up by a `ref`,
it is clear that this `ref` is part of the function pointer type syntax.

> [!NOTE]
> While the current implementation can parse linkages as part of function pointer and delegate types,
it does not actually apply them to the type semantically.

### Side-effects

A notable side-effect is that `(const int)` is now a basic type.
The author expects this to be somewhat controversial.
Some programmers will prefer the more consistent new style to the old style,
leading to something like the head-const (`const T`) vs tail-const (`T const`) style discussions in C++.

### Drawbacks

A naïve programmer might assume that `const (shared int)*` is equivalent to `const ((shared int)*)`, but it really is equivalent to `(const shared int)*`.

## Breaking Changes and Deprecations

For a symbol `s`,
in present-day D, the token sequence `(s)` only parses as an expression.
With the changes proposed by this DIP,
it also parses as a type,
which is a meaningful difference in niche constructs such as `__traits(isSame)`.
These can be remedied using a cast expression instead of just parentheses.

## Copyright & License
Copyright © 2024 by Quirin F. Schroll

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## History
The DIP Manager will supplement this section with links to forum discsusionss and a summary of the formal assessment.
