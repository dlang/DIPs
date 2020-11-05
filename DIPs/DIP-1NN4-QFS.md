# Attributes for Higher-Order Functions

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | (number/id -- assigned by DIP Manager)                          |
| Review Count:   | 0 (edited by DIP Manager)                                       |
| Author:         | Quirin F. Schroll (@Bolpat) qDOTschrollATgmailDOTcom            |
| Implementation: | *none*                                                          |
| Status:         | Draft                                                           |

## Abstract

Functions that have function pointers or delegates as parameters are a breakpoint in `pure`, `nothrow`, `@safe`, and `@nogc` code.
This DIP proposes to change what the attributes `pure`, `nothrow`, `@safe`, and `@nogc` formally mean.
It will only affect aforementioned functions.
The goal is to make the compiler accept more code that behaves in accordance to the attributes.

### Reference

1. [Wikipedia: Higher-order function](https://en.wikipedia.org/wiki/Higher-order_function)
1. [D Language Specification: `opApply`](https://dlang.org/spec/statement.html#foreach_over_struct_and_classes)
1. [D Language Specification: Lazy Parameters](https://dlang.org/spec/function.html#lazy-params)
1. [D Language Specification: Lazy Variadic Functions](https://dlang.org/spec/function.html#lazy_variadic_functions)
1. [Discussion: `opApply` with Type Inference and Templates?](https://forum.dlang.org/post/zkovjshfktznepertjay@forum.dlang.org)
1. [Discussion: Parameterized delegate attributes](https://forum.dlang.org/post/ovitindvwuxkmbxufzvi@forum.dlang.org)
1. [Discussion: `@nogc` with `opApply`](https://forum.dlang.org/thread/erznqknpyxzxqivawnix@forum.dlang.org)

## Contents

* [Rationale](#rationale)
* [Description](#description)
* [Breaking Changes and Deprecations](#breaking-changes-and-deprecations)
* [Copyright & License](#copyright--license)
* [Reviews](#reviews)

## Terms and Definitions

The attributes `pure`, `nothrow`, `@safe`, and `@nogc` will be called *warrant attributes* in this DIP.
In (pseudo) code, `@attribute` means any subset of `pure`, `nothrow`, `@safe`, and `@nogc`.
Notably absent are `@system` and `@trusted` as they do not warrant anything.

A *higher-order function*, or *functional* for short, is a function (in the concrete case of the D programming language: anything that can be called, including functions, function pointers, delegates, and `opCall`) that takes takes one or more functions (in the concrete case of the D programming language: function pointers or delegates) as arguments.

In the context of a higher-order function, that function may also be referenced as *the functional*.
Its parameters, which happen to be function pointers or delegates, are called *parameter functions*, or *callbacks* for short.
When the functional is called, the arguments on parameter functions are called *argument functions*.

## Rationale

<sub>
A short motivation about the importance and benefits of the proposed change.
An existing, well-known issue or a use case for an existing projects can greatly increase the
chances of the DIP being understood and carefully evaluated.
</sub>

----

Non-template higher-order functions are a blocker in a warrant attribute context, especially in libraries.
A program provably satisfying the conditions of a warrant attribute may be rejected by the compiler
because the notions of the warrant attributes are too strictly enforced.

### Illustration

The following code ([this file](DIP-1NNN-QS_example_lazy.d)) using `lazy` compiles.
Note that the calls `fst()` and `snd()` are not necessarily `pure` as seemingly required by the signature of `secondTry`:

```d
module test;

int secondTry(lazy int fst, lazy int snd) pure
{
    if (auto result = fst()) return result;
    return snd();
}

int pureExample() pure
{
    return secondTry(1 - 1, 2);
}

int impureExample()
{
    int readInt()
    {
        import std.stdio : write, readf;
        write("value: ");
        int result;
        if (readf!" %s"(result)) return result;
        assert(0);
    }
    return secondTry(readInt(), readInt());
}
```

This is because
* All operations in the definiton of `secondTry` comply with the conditions of `pure`,
* *under the assumption* that evaluations of `lazy` parameters comply with the conditions of `pure`.

Marking `impureExample` with `pure` will cause an error.
However, the error is issued in `impureExample`, and not in `secondTry`.
The compiler pretends the calls of `readInt` to be happening at `return secondTry(readInt(), readInt());` while they actually do not.
This is exactly the interpretation this DIP proposes for parameter functions.
The `lazy` parameters are just a special case of delegates with syntactic sugar.

The equivalent code shown below ([this file](DIP-1NNN-QS_example_dels.d)) using a variadic array of delegates does not compile.
Note that lazy variadic functions use an array of delegates.
While the calling of the variadic functional has syntactic sugar,
inside the functional, the callbacks are not treated any different from regular delegates
(see [this file](DIP-1NNN-QS_example_dels.d)).

```d
module test;

int secondTry(int delegate()[] tries...) pure
{
    foreach (tr; tries)
        if (auto result = tr())
            return result;
    return 0;
}

int pureExample() pure
{
    return secondTry(1 - 1, 2);
}

int impureExample()
{
    int readInt()
    {
        import std.stdio : write, readf;
        write("value: ");
        int result;
        if (readf!" %s"(result)) return result;
        assert(0);
    }
    return secondTry(readInt(), readInt());
}
```
There is no way to apply `pure` to `secondTry` and its parameter functions that makes the example compile:

* With `pure` absent from the signature of `secondTry` ([this file](DIP-1NNN-QS_example_impure.d)), the compiler states:
```
Error: pure function test.pureExample cannot call impure function test.secondTry
```
* With `pure` attached to `secondTry` but absent from its callbacks ([this file](DIP-1NNN-QS_example_pure1.d)), the compilation fails, too:
```
Error: pure function test.secondTry cannot call impure delegate fst
Error: pure function test.secondTry cannot call impure delegate snd
```
* With `pure` attached to `secondTry` and its callbacks ([this file](DIP-1NNN-QS_example_pure2.d)), the error is
```
Error: function test.secondTry(int delegate() pure fst, int delegate() pure snd) is not callable \
           using argument types (int delegate() @system, int delegate() @system)
       cannot pass argument &readInt of type int delegate() @system to parameter int delegate() pure fst
```

## Description

<sub>
Detailed technical description of the new semantics. Language grammar changes
(per https://dlang.org/spec/grammar.html) needed to support the new syntax
(or change) must be mentioned. Examples demonstrating the new semantics will
strengthen the proposal and should be considered mandatory.
</sub>

----

It takes into account that it is *known at compile-time* whether the functional is being called with argument callbacks which comply with `@attribute`.
By this proposal, the definition of an `@attribute` functional must *conserve* `@attribute`
rather than *bluntly comply* with `@attribute`:

For `@attribute` *argument* functions, calling the functional complies with `@attribute`;
for non-`@attribute` *arguments*, the call might not complies with `@attribute`,
even though `@attribute` is attached to the declaration of the functional.

----

For any funcion, a warrant attribute should require:

* All operations in the definiton comply with the conditions of the warrant attribute,
* *under the assumption* that calls to any parameter functions comply with the conditions of the warrant attribute.

In fact, `lazy` parameters behave already like that;
under the hood, `lazy` parameters are delegates.

The assumption is worthless for functions that are not functionals.

REVISE

Similar to unique construction: a pure function can be strongly or weakly pure.

Functionality of `opApply`, which the range constructs (`empty`, `front`, `popFront`) cannot replace, are e.g.:
* Varying number of variables (like one with index and one without);
[`std.range : enumerate`](https://dlang.org/library/std/range/enumerate.html) cannot help every time and
it is clumbersome to use compared to arrays and slices.
* Recursive `opApply`s.

We will stick to `opApply` as an example, because for indexed iteration, there is currently no alternative to `opApply`.
Consider a construct using `opApply` like this:
```d
struct Example(T)
{
    void opApply(scope int delegate(size_t, T) callback)
    {
        size_t index;
        T value;
        // implemenation
        if (auto result = callback(index, value)) return result;
        // implemenation
        return 0;
    }
}
```
Note that while the surrounding `struct` is a template, `opApply` is not.
The `callback` is implicitely declared `@system` and with no other attributes,
and because `opApply` calls it, it will itself be `@system` and with no other attributes.

Currently, attaching `@attribute` to `opApply` requires to also attach `@attribute` on the callback (or more) to compile.

In a closed context, this may be an option.
As soon as `opApply` is being called from different `@attribute` contexts,
one currently has no solution to that but to overload `opApply`
with the same implementation only differing in attributes on `opApply` and the `callback`; or
to make `opApply` a template, which disables type inference of the iteration variables declared in `foreach`.

### Proposed solution

For code generation and optimizations of the functional, the compiler can only rely on the attributes in the `@attribute`s in the intersection of the functional and the `callback`s. (For functions without function parameters, the intersection is exactly the `@attribute`s of the function.)

### Examples

### General Case

In almost all cases, a part of a program cannot be marked with `@attribute` when a functional is part of the program.
The cases excluded from the aforementioned are those where:
* the parameter function *must* have the desired attributes anyway, or
* the parameter function is not being called by the functional.

Those cases are rare. Usually, the functional includes calles of its parameter functions.

In case of a library, espacially including Phobos, it is necessary to support any `@attribute` when reasonably possible.

### Callbacks with attributes

There are still cases, where callbacks with attributes would be used. E.g. a functional may special case (i.e. require in the concrete overload) an `@attribute` callback.

```d
void functional(void delegate() callback, ref string[] log) pure nothrow
{
    // still necessary, callback need not be pure or nothrow
    log ~= "call functional";
    try
    {
        callback();
    }
    catch (Exception e)
    {
      log ~= "Exception: " ~ e.msg;
      throw e;
    }
}

// optimized: no try overhead; actually is nothrow in any case
void functional(void delegate() callback nothrow, ref string[] log) pure nothrow
{
    log ~= "call functional";
    callback();
}
```

### Workarounds

Let `R` be a type and `Types` be a sequence of types; consider
```d
auto functional(R delegate(Types) paramFunction);
```
for the following examples of workarounds.

#### Not use attributes at all

While obvious, this is being mentioned because many projects actually choose this option.
One goal of this DIP is to make attributes more applicable and increase the advantages of using them.

#### Overloads

There are currently up to 16 overloads to make.
While `mixin` is an option for avoiding repetition,
changes in the code, which make some `@attribute` invalid,
have to be accompanied with removal of the overloads.
Changes in the code that make some `@attribute` valid,
must be accompanied by addition of suitable overloads.
Such code has low maintainablilty.

One could generate the overloads based on the `@attribute`s of the `mixin` code
under the initially stated assumption.
That creates even more obfuscation.

#### Templates

As templates have attributes inferred, functional-templates are not considered by this DIP.

A possible workaround for is
```d
auto functional(DelegateType : R delegate(Types))(DelegateType paramFunction);
```
The `DelegateType` template parameter will bind any `R delegate(Types) @attribute`.

Templates are no panacea; they have drawbacks that on varios occasions cannot be taken.
The autor considers it beyond this DIP to describe the general drawbacks of templates.
Note especially that one may decide not to write templates in a project at all.

One particular drawback is that type inference of `foreach` variables is only possible
when `opApply` is not a template.

While conveniance may step behind, template-code that uses `foreach` without explicit types
and Voldemort types rise the need for type inference.

## Breaking Changes and Deprecations

This section is not required if no breaking changes or deprecations are anticipated.

Provide a detailed analysis on how the proposed changes may affect existing
user code and a step-by-step explanation of the deprecation process which is
supposed to handle breakage in a non-intrusive manner. Changes that may break
user code and have no well-defined deprecation process have a minimal chance of
being approved.

----

There is possible breakage by functionals that don't call the callback.
An example could be:
```d
int delegate() transform(int function() func) @nothrow pure @safe
{
    return { func(); };
}
```
A `@safe` function can call `transform` with a `@system` argument.
As it cannot call the result (it is implicitely `@system`) ...

Breakage could be avoided by introducing new (weak) attributes with the described meaning of conserving.
They would mean the same as the current (strong) attributes for non-higher-order functions.
The DIP autor considers this option to be less desirable because the weak attributes
* need new syntax,
* have a very limited scope, therfore
* fear to have almost no adoption by developers.

## Copyright & License

Copyright (c) 2018 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## Reviews

The DIP Manager will supplement this section with a summary of each review stage
of the DIP process beyond the Draft Review.
