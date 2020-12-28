# Attributes for Higher-Order Functions

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | (number/id -- assigned by DIP Manager)                          |
| Review Count:   | 0 (edited by DIP Manager)                                       |
| Author:         | Quirin F. Schroll (@Bolpat) qDOTschrollATgmailDOTcom            |
| Implementation: | *none*                                                          |
| Status:         | Draft                                                           |

## Abstract

Functions that have function pointers or delegates as parameters are a road-bump in `pure`, `nothrow`, `@safe`, and `@nogc` code.
This DIP proposes to relax the constraints that the attributes `pure`, `nothrow`, `@safe`, and `@nogc` impose.
Practically, it will only affect aforementioned functions with function pointers or delegates as parameters.
The goal is to make the compiler formally accept more code that factually behaves in accordance to the attributes.

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
Notably absent are `@system` and `@trusted` as they do not warrant any compiler-side checks.

A *higher-order function*, or *functional* for short, is anything that can be called
(including any kind of functions, function pointers, delegates, and `opCall`)
that takes one or more function pointers or delegates as arguments.

When a higher-order function is called, there are three notable entities to commonly refer to:
* The *context function,* or *context* for short, is the function that contains the call expresion.
* The *functional* is the higher-order function that is called.
* The *parameter functions* are the variables declared by the functional's parameter list.
* The *argument functions* or *callbacks* are the values plugged-in in the call expression.

Although not an entity in the above sense, the functional's *parameter types* will be commonly referred to as such.

An illustration of these are given in this code snippet:
```D
alias ParameterType = void function();
void functional(ParameterType parameterFunction)
{
    parameterFunction();
}

void context()
{
    alias callback = { };
    functional(callback);
}
```

When referred to one of these entities as having a warrant attribute, this means that attribute is attatched to their declaration or their type.

## Rationale

<sub>
A short motivation about the importance and benefits of the proposed change.
An existing, well-known issue or a use case for an existing projects can greatly increase the
chances of the DIP being understood and carefully evaluated.
</sub>

----

Higher-order functions are a blocker in a warrant attribute context, especially in libraries.
A execution of a context function may provably satisfy the (intuitive) conditions of a warrant attribute, but does not compile
because the formal conditions of the warrant attributes are too narrow and not met.

Warrant attributes on a function(al) and on a functional's parameter mean very differnt things:
* On a function, they give rise to a *guarantee* the function makes, like a `@nogc` function will not allocate GC memory.
(When a function returns a delegate or function pointer, warrant attributes on such a return type are a guarantee of that function, too.)
* Only on a functional's parameter type, warrant attributes give rise to a *requirement* that the functional *needs* to work properly.
As an example, consider a functional requiring a `pure` parameter.
That might be to make use of memoization or the fact that its results are [unique](https://dlang.org/spec/const3.html#implicit_qualifier_conversions).
In the case of memoization, failing the requirement will not result in a compile error, but unexpected behavior.
In most cases, however, the requirement is merely to match the functionals guarantee.

In the current state of the language,
a funcional cannot have strong guarantees and weak requirements at the same time.
Most programmers opt against warrant attributes, i.e. for weak requirements
and therefore needlessly weaken the guarantees.

The proposed changes lift this restriction.
Attributes on parameter types would only be needed when the requrements are needed
for the implementation of the functional to work as intended.
The case for the merely satisfy the guarantee stated by its own attributes will be handled by the type system.

In the author's estimation, the most well-known functional probaly is [`opApply`](https://dlang.org/spec/statement.html#foreach_over_struct_and_classes).
While some iteration can be done using the range interface (`empty`, `front`, `popFront`),
using `opApply` is far more general in its applications.
(An example where `opApply` cannot be replaced by the range interface is [`std.range.lockstep`](https://dlang.org/phobos/std_range.html#lockstep).)
While some issues of `opApply` are specific to it
(like that templated `opApply` cannot be used in `foreach` loops),
the part concerning attributes is not.

In the current state of the language,
a warrant attribute on a functional guarantees that *all* calls of the functional will result in an execution complying to the warrant attribute.
As an example, a call to a `@nogc` annotated `opApply` will not allocate GC memory.
To make that work, the type of the parameter of `opApply` must be a `@nogc` delegate (at least when the parameter is called which it almost always is).
This limits the usage of that `opApply` drastically.
In a context where GC allocation is allowed (i.e. it is not `@nogc`), it cannot allocate in the `foreach` body
even if that would be intuitively unproblematic since the context allowes GC allocation.
The only easy solution is to remove the `@nogc` attribute from `opApply` and its parameter.

Using `lockstep` the indended way prevents any context from carrying any warrant attributes,
i.e. `lockstep` is a blocker when it comes to warrant attributes
due to the conditions of the warrant attributes being too narrow.
The delegate created by the lowering of the `foreach` loop may have any
warrant attributes inferred by the compiler, but `opApply` ignores those in its parameter's type.
Because the parameter function is called, its lack of any warrant attributes necessitates that
the functional (i.e. `opApply` itself) must lack the attributes, too.

The proposed change is similar to the relaxation of `pure` allowing `pure` functions to modify
anything reachable through given parameters.
Those are called *weakly pure* functions.
The way weak purity allowed for more *strongly pure* functions,
the changes proposed by this DIP allow more functions carrying any warrant attribute.

At the point where the call expression is, the compiler has all the necessary information via the type system
to determine if the execution of it will comply with the warrant attributes of the context.

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
