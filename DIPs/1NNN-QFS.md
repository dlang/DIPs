# Enum Parameters

| Field           | Value                                            |
|-----------------|--------------------------------------------------|
| DIP:            | (number/id -- assigned by DIP Manager)           |
| Review Count:   | 0 (edited by DIP Manager)                        |
| Author:         | Quirin F. Schroll ([@Bolpat](github.com/Bolpat)) |
| Implementation: | *none*                                           |
| Status:         | Draft                                            |

## Abstract

On function templates, allow `enum` to be used as a parameter storage class and a member function attribute.
Arguments binding to `enum` parameters must be compile-time constants, as if template value parameters.
With `auto enum`, “compile-time-ness” is determined from argument (cf. `auto ref`) and queried via a trait.


## Contents
* [Rationale](#rationale)
* [Prior Work](#prior-work)
* [Description](#description)
* [Breaking Changes and Deprecations](#breaking-changes-and-deprecations)
* [Reference](#reference)
* [Copyright & License](#copyright--license)
* [Reviews](#reviews)

## Rationale

The use-case is a function where it can reasonably expected that a certain parameter position is filled with a constant
and there are preconditions on that parameter or non-trivial optimizations are possible.

Examples include formatting and regular expressions.
* A format is often constant and subject to preconditions:
  E.g. not every sequence of characters is a well-formed format and even a well-formed format string might not be valid for the given arguments and their types.
* A regular expression is often constant and also has preconditions (not every sequence of characters is a valid regular expression),
  but more importantly, if the pattern is known at compile-time, a regular expression can be significantly optimized.

Another example is index bounds checking.
It can only be done at compile-time if the supplied index is known at compile-time,
but `opIndex` cannot be defined to take the value in brackets as a template value parameter.

The compile-time checks and optimizations are something a programmer always wants for the exception of niche cases.
There is almost no downside to it and especially not in view of the benefits.
In its current state, D programmers must remember to use the right syntax.
In a meta-programming context, when the argument might or might not be a compile-time constant, it is even harder.

In principle, users should not need to know to use `format!"%(%s%)"(slice)` versus `format("%(%s%)", slice)`.
Users should not have to remember not to use `regex(r"pattern")`, but `ctRegex!r"pattern"`.
Authors of containers and ranges would want to give users compile errors instead of run-time exceptions when possible.

Another case where `enum` parameters shine, is user-defined types that encapsulate value sequences, e.g. `std.typecons.Tuple`.
One could define `opIndex` as follows:
* If the types have a common type, dynamic indexing is possible and an overload without `enum` parameter is supplied.
  Depending on the types, this can even be a `ref` return: E.g. for `Tuple!(int, immutable int)`, dynamic indexing can safely return `ref const(int)`.
  Even for `Tuple!(ubyte, short)`, a common type is `int`, thus `opIndex` with a run-time index must return by value.
  Index bounds must still be checked at run-time.
* In any case, `ref opIndex(enum size_t index)` can be defined to return a different type depending on the index
  because the index is known at compile-time as if it were a template value parameter.
* Slicing on a tuple is currently not really possible:
  It returns an alias sequence that must be repackaged; if the `Tuple` had names, those are lost.
  With `enum` parameters, all that is needed is to define `opSlice` in terms of [`Tuple.slice`](https://dlang.org/phobos/std_typecons.html#.Tuple.slice):
  ```d
  auto opSlice()(enum size_t l, enum size_t u) => slice!(l, u);
  ```

Today, even if `Tuple` would recognize the compatibility of its types so that dynamic indexing makes sense, it cannot have `opIndex`,
because any `opIndex` shadows the much more important indexing supplied via `alias elements this`.

Even `SumType` could use `opIndex` to extract the current value if supplied and interal index match (and throw an exception otherwise).

<!--
Having `opIndex` with compile-time indexing and slicing available allows for another form of tuple that meaningfully encapsulates its fields,
i.e. a `ReadOnlyTuple` that returns its components by 
-->

## Alternatives

For a unified syntax for compile-time and run-time arguments, one can go the other way around and bind a run-time variable to a template alias parameter. Introspection can then be used to determine if the alias refers to a compile-time constant and choose an algorithm depending on that.

The downsides of that are:
1. Template alias parameters can only bind to symbols; this includes variables with run-time values, but not expressions `i + 1` (unless they happen to be compile-time values). The value has to be stored in a variable to reference it.
2. The overload with the run-time value must be a template (with all the downsides of that).
   Simple overloading is not possible.
3. Does not help operators, first and foremost `opIndex` and `opCall`.

## Prior Work

Walter Bright in a very old talk had a slide with `static` function parameters.
Because `static` has already a lot of meanings and `enum` is clear and even shorter, `enum` was chosen.

### Zig

In the Zig language, the proposed feature essentially exists with the keyword `comptime`:
> A `comptime` parameter means that:
> * At the callsite, the value must be known at compile-time, or it is a compile error.
> * In the function definition, the value is known at compile-time.
>
> — [Zig Language Reference § comptime](https://ziglang.org/documentation/0.9.1/#comptime)

Zig, in contrast to D, has no templates and thus does not separate compile-time and run-time parameters into different parameter lists.
Instead, compile-time parameters are designated as such and may be types, which at compile-time are first-class values in Zig.

### Nim

In the programming language Nim, `static` is a type constructor.
Values of this type are compile-time constants.
As such, parameters of `static`-qualified types must be bound to compile-time values.

> As their name suggests, static parameters must be constant expressions[.]  
> […]  
> For the purposes of code generation, all static params are treated as generic params –
> the proc will be compiled separately for each unique supplied value (or combination of values).
> 
> — [Nim Manual § `static[T]`](https://nim-lang.org/docs/manual.html#special-types-static-t)

## Description

### Syntax

Allow `enum` as a function parameter attribute and a member function attribute.
For the grammar, [see](#grammar) below.

The author regards the keyword `static` as an alternative, but distinctly below `enum`.
Another option would be a compiler-recognized user-defined attribute.
If compile-time values were a new concept, this proposal would suggest `@comptime`,
but `enum` is already established to introduce manifest constants (i.e. compile-time values)
at global, aggregate, and function local scope.
Diverting from that introduces inconsistency.

<!--
Becuase in a future version of D where mutable enums are fixed, it may be that
enum cannot bind to values with indirections,
`static immutable`.
like 
-->

### Semantics

#### Storage Class

The argument binding and overload selection semantics of `enum` bear some similarity to `ref`.

An `enum` parameter binds only to compile-time constants (cf. a `ref` parameter only binds to lvalues).

A non-`enum` parameter binds to run-time and compile-time arguments,
but for compile-time values, `enum` parameters are a better match
(cf. lvalues and rvalues bind to non-`ref` parameters, but `ref` parameters are a better match for lvalues).

An `enum` non-`static` member function template can only be called with a compile-time constant object.
In its body, `this` semantically behaves like a template value parameter, e.g. it can be used as a template argument.
The `enum` member function attribute is incompatible with a [template `this` parameter](https://dlang.org/spec/template.html#template_this_parameter).
Conceptually, an `enum` non-`static` member function template behaves as if implemented as `static` member function template,
with the only difference that the calling syntax is `obj.method(args)` instead of `typeof(obj).method!obj(args)`.

In the function body (including contracts and constraints), an `enum` parameter’s value is a compile-time constant as if it were template value parameter.
The same is true for `this` in an `enum` non-`static` member function body.
The difference between `enum` parameters and template value parameters is only in calling syntax:
`f!ct_value(args)` versus `f(ct_value, args)`.

The `enum` storage class is incompatible with any other storage classes currently in the language except type constructors.
Using them together is a compile error.
This proposal does not define `enum` to be incompatible with potential future storage classes;
it just so happens that all the current parameter storage classes have semnatics that do not apply to compile-time constants.
<!--
The following is wrong, but it could be because of a bug.
Type constructors are allowed, but have no effect
because compile-time values are essentially `immutable`, and for any type constructor `qual` and every type `T`, we have `qual(immutable T)` ≡ `immutable T`).
-->

One can use `auto enum` to infer from the argument wether it is a compile-time constant (cf. `auto ref` to infer the argument’s value category).

The `auto enum` storage class is compatible with all other storage classes except `ref`,
i.e. `auto enum auto ref` is valid, but `auto enum ref` is invalid.
If the argument is a compile-time constant, `auto enum` becomes `enum` and other storage classes (if any) are ignored.
Otherwise, `auto enum` is ignored (cf. binding an rvalue to an `auto ref` parameter) and
the semantics of the aforementioned parameter storage classes (if any) take over.

The rationale making `auto enum` is incompatible with `ref` is
because in almost all cases, the correct way is `auto enum auto ref`, i.e.:
* try binding as compile-time constant;
* if not possible, pass by reference;
* if not possible, pass by value.

What `auto enum ref` would mean is:
* try binding as compile-time constant;
* if not possible, pass by reference;
* otherwise issue a compile error.

If it is really intended, separate overloads can achieve the same.

#### Trait

To effectively test if an `auto enum` parameter is `enum` or not in a particular template instance,
the `isEnum` new trait is added.
The expression `__traits(isEnum, symbol)` returns wether
* the `symbol` refers to a value of an `enum` — or
* the `symbol` refers to an `enum` parameter.

Note that for a type `T`, we already have `is(T == enum)` to test if it is an enumeration type,
which is a rather distinct question from a value being a compile-time constant.
Still, being a compile-time constant is differnt from being an `enum` value,
because although all `enum` values are compile-time constants,
not all compile-time constants are `enum` (e.g. `static immutable` variables),
and thus `__traits(isEnum, symbol)` returns `false` on them.

### Grammar

```diff
    ParameterStorageClass:
        auto
        TypeCtor
        final
        in
        lazy
        out
        ref
        return
        scope
+       enum

    MemberFunctionAttribute:
        const
        immutable
        inout
        return
        scope
        shared
+       enum
        FunctionAttribute
        
    TraitsKeyword:
        …
        isTemplate
        isRef
        isOut
+       isEnum
        isLazy
        …
```

`ParameterStorageClass` was `InOut`, see [Issue 23359](https://issues.dlang.org/show_bug.cgi?id=23359).

## Breaking Changes and Deprecations

None, this is new syntax.

<!--
## Reference
Optional links to reference material such as existing discussions, research papers
or any other supplementary materials.
-->

## Copyright & License
Copyright © 2022 by Quirin F. Schroll

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## Reviews
The DIP Manager will supplement this section with a summary of each review stage
of the DIP process beyond the Draft Review.
