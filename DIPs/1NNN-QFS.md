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

Ideally, users should not need to remember to use `format!"%(%s%)"(slice)` instead of `format("%(%s%)", slice)` to enable checks;
likewise, users should not have to remember not to use `regex(r"pattern")`, but `ctRegex!r"pattern"`, in order to enable optimizations.
Authors of containers and ranges want to give users compile errors instead of run-time exceptions when possible.

Another case where `enum` parameters shine, is user-defined types that encapsulate value sequences, e.g. `std.typecons.Tuple`.
One could define `opIndex` as follows:
* In any case, `ref opIndex()(enum size_t index)` can be defined to return a different type depending on the index
  because the index is known at compile-time as if it were a template value parameter.
* Slicing on a tuple is currently not really possible:
  It returns an alias sequence that must be repackaged; if the `Tuple` had names, those are lost.
  With `enum` parameters, all that is needed is to define `opSlice` in terms of [`Tuple.slice`](https://dlang.org/phobos/std_typecons.html#.Tuple.slice):
  ```d
  auto opSlice()(enum size_t l, enum size_t u) => slice!(l, u);
  ```
* Using Design by Introspeciton, if the types have a common type, dynamic indexing is possible and certain overloads with a non-`enum` index can be supplied.
  Depending on the types, this can even be a `ref` return:  
  For `Tuple!(int, immutable int)`, dynamic indexing can safely return `ref const(int)`;
  in this case, also `opIndex()` can be defined and return `const(int)[]`, i.e. a slice of objects of the common type.
  A tuple of this kind is effectively a static array with more details about individual elements.  
  For `Tuple!(ubyte, short)`, a common type is `int`, thus `opIndex` with a run-time index can return `int` by value (albeit not by `ref`),
  and accordingly a slicing overload cannot be supplied.  
  Index bounds must be checked at run-time.

Today, even if `Tuple` would recognize the compatibility of its types so that dynamic indexing makes sense, it cannot have `opIndex`,
because any `opIndex` shadows the much more important indexing supplied via `alias elements this`.

Even `SumType` could use `opIndex` to extract the current value: If supplied and interal index match returns the value, otherwise throw an exception.

<!--
Having `opIndex` with compile-time indexing and slicing available allows for another form of tuple that meaningfully encapsulates its fields,
i.e. a `ReadOnlyTuple` that returns its components by 
-->

The implementation of a function template with an `enum` parameter might not depend on the value of that parameter.
If it does, it is necessary to generate multuple instances of the function differing only by the value of the `enum` parameter,
resulting in what is colloquially known as “template bloat”.
In cases like `format` and `regex` the compile-time knowledge can be used for speed optimizations,
but a correct implementation might only validate the format string or regular expression at compile-time,
but otherwise resort to a run-time implementation.

Every `enum` parameter falls into exactly one of these categories:
1. Its value is used for Design by Introspection.¹
2. Its value is used only in template constraints and `static assert` statements (or it is not used at all).
3. Its value is used, but only in places where it would be admissible to be a run-time value.

Category 1 is unsolvable: Template bloat cannot be avoided by design.  
Category 2 is solvable as an optimization: A compiler might recognize the lack of uses other than the mentioned
and not generate instances differing only by values of the parameters of this category.  
Category 3 is the sad case because it is not clear if the user inteded different instances or not.

¹ DbI is to be understood loosely.
Here, use of Design by Introspection refers to any use that results in a different implementation,
not counting validity checks (i.e. contracts and asserts) because they produce the same implementation
unless they fail and produce no implementation at all.

A compiler-recognized paramter attribute `@nodbi` serves to distinguish the categories:
* It is an error to use a `@nodbi` `enum` parameter for Design by Introspection.
* A `@nodbi enum` parameter is used as a run-time value in places where it would be admissible to be a run-time value.

From a caller’s perspective, an argument passed to a `@nodbi enum` parameter is a run-time parameter that is subject to compile-time checks:
Overload resolution may take the value into account using template constraints,
and `static assert` statements might use the value both in their condition and error message.

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

#### `enum` Storage Class

The argument binding and overload resolution semantics of `enum` bear some similarity to `ref`.

An `enum` parameter binds only to compile-time constants (cf. a `ref` parameter only binds to lvalues).
When comparing overload candidates in the partial ordering, `enum` is a better match than non-`enum`.
In any case, after sorting out overloads with incompatible number of parameters and parameter types,
if candidates contain `enum` parameters, constant folding must be attempted for them, i.e.
a candidate can only be excluded when an `enum` parameter is bound to an argument for which constant folding failed.

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
because compile-time values are essentially `immutable`,
and for any type constructor `qual` and every type `T`, we have `qual(immutable T)` equal to `immutable T`.
-->

#### `auto enum` Storage Class

One can use `auto enum` to infer from the argument wether it is a compile-time constant (cf. `auto ref` to infer the argument’s value category).

An `auto enum` parameter bindy to any argument of compatible type.
On overload resolution,
when comparing overload candidates in the partial ordering,
`auto enum` is a worse match than `enum` and other non-`auto enum`.
When the best candidate determined by overload resolution contains `auto enum` parameters,
constant folding must be attempted for them, i.e.
`auto enum` only binds the argument as a run-time value after constant folding failed.

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

#### The `@nodbi` Attribute

The token sequence `@` `nodbi` is added to the list of parameter storage classes.

The value of a `@nodbi enum` parameter is treated as if it were a run-time value, except
* inside the template contract of the template it is defined on, or
* top-level `static assert` statements in the body of the function template it is defined on, or
* when the expression that contains it is bound to a `@nodbi enum` or `@nodbi auto enum` parameter
  and it is used for constant-folding only.

*[Example:*
```d
int collatz(int n) => n % 2 ? 3 * n + 1 : n / 2;
void f()(auto enum int x) { static assert(!__traits(isEnum, x), x.stringof ~ " must not be a compile-time constant."); }
void g()(@nodbi enum int i) if (i > 0) { f(collatz(i + 1)); }
void h() { g(1);  g(2); }
```
The function template `g` is well-formed because it uses `i` only in its contract and as a run-time value:
In its invocation of `f`, `x` is inferred non-`enum` and thus the `static assert` does not fail.  
The function `h` calles `g` with two different arguments, but only one `g!().g(int)` will be generated
because the run-time logic of `g` is guaranteed not to depend on the value of `i`.  
The function template `f` in and of itself would be well-formed if `x` were annotated `@nodbi` because it uses `x` only in `static assert`,
but in its invocation in `g`, `x` would be inferred `enum` and the `static assert` would fail.
— *end example]*

*[Example:*
```d
import std.meta : AliasSeq, Stride;
void example()(@nodbi enum size_t n)
    if (is( Stride!(n + 1, int, uint, char, double) == AliasSeq!(int, char) )) // okay, used in contract
{
    auto m = n + 2; // okay, used as run-time value
    enum k = n + 1; // error, used as compile-time constant (counts as Design by Introspection)
    auto xs = new int[n]; // okay, used as a run-time value; same as `new int[](n)`.
    static assert(n < 10); // okay, used in static assert
    int[n + 1] array; // error, used as compile-time constant (counts as Design by Introspection)
    static if (n > 1) { ++m; } // error, same reason
    static foreach (i; 0 .. n) { ++m; } // error, same reason
    enum string s = n.stringof; // okay, results in "n" (details see below)
    /++++/ assert(n.stringof == "n"); // okay, and does not fire (details see below)
    static assert(n.stringof != "n"); // okay, and does not fire (details see below)
    static assert(s == "n"); // okay, `s` can be read at compile-time, and does not fire, because `s` is `"n"`
    int[n.sizeof + n.alignof] a; // okay, `sizeof` and `alignof` depend on type, not value
    
    import std.meta : Alias;
    alias doppelgänger = Alias!n; // okay, a parameter is a symbol and as such can be alias’d
    alias notGood = Alias!(n + 1); // error, `n + 1` is not a symbol, thus uses `n` as a compile-time constant
    alias stride = Stride!(n + 3, int, uint, char, double); // error, used as compile-time constant
    static assert(is( Stride!(n + 2, int, uint, char, double) == AliasSeq!(int, double) )); // okay, used in static assert
    
    // error, value of `n` used in a static assert that is not top-level:
    static if (__traits(compiles, { static assert(n > 0); })) { }
    static if (is(typeof({ static assert(n > 0); }))) { } // error, same reason
    // good guess, but `n.stringof` is `"n"` here and branch is always taken, regardless of the value of `n`:
    static if (__traits(compiles, { static assert(n.stringof != "0"); })) { }
    static if (is(typeof({ static assert(n.stringof != "0"); }))) { } // branch is always taken, same reason
    // Because the value of `n` is used in a contract other than the template that declares it ...
    void exampleImpl(T)() if (T.sizeof == n) { } // this is not well-formed ...
    static if (is(typeof(exampleImpl!bool()))) { } // ... and the branch is never taken.
}
```
* In the assignment of the `enum`s, `n` is treated like a run-time value;
thus, `n + 1` is an error and `n.stringof` evaluates to `"n"`, not its value as a string, exactly as if it were a non-`enum` parameter.
The same would happen if `s` were declared `const` or `immutable` instead.
* In the `assert` statement, `n` is treated like a run-time value;
thus, `n.stringof` evaluates to `"n"` here, like the assignment above it.
* In the `static assert`, `n` is treated like a compile-time constant;
because it is a number, its string representation will never be `"n"` and the assertion never fires.
* In the `static assert` below, `s` can be read at compile-time and its value is `"n"`.
The same would happen if `s` were declared `const` or `immutable` instead.
— *end example]*

*[Note:*
The inconsistent behavior of `stringof` is not introduced by this proposal.
The workaround mentioned in the [Alternatives](#alternatives) section suffers from the same inconsistency.
― *end note]*

The alias declarations could be allowed if they end up being used only in `static asserts`.
The DIP author considers the burden for the compiler to track dependent aliases too large to require it as part of the propsal
while providing a benefit only in very niche cases.

The semantics of `@nodbi auto enum` derive from those of `@nodbi` and `enum`:
If `auto enum` becomes `enum`, it is treated like `@nodbi enum`,
otherwise the parameter is a run-time value already.

An `@nodbi auto enum` parameter cannot produce two distinct tempalte instantiations based on it becoming `enum` or not
because using the “`enum`-ness” for Design by Introspection is invalid.

The author leaves it to the discretion of the language maintainiers,
whether it is an error to attach the `@nodbi` attribute to something other than `enum` or `auto enum` parameters.
Among the following options, the author suggests 2., because it is likely the easiest on the implementation.
1. It could be allowed for any parameter, but on parameters other than `enum` or `auto enum` it would be ignored,
   but an error elsewhere.
2. It could be allowed anywhere, but on anything except parameters other than `enum` or `auto enum` it would be ignored.
3. It could be an error except on parameters other than `enum` or `auto enum`.

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
+       @ nodbi

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
