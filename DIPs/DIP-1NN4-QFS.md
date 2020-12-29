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
1. [Issue: `opApply` and nothrow don't play along](https://issues.dlang.org/show_bug.cgi?id=14196)

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

Higher-order functions are a disruption in a warrant attribute context.
The execution of a context function may provably satisfy the conditions of a warrant attribute,
but is considered illegal because the formal conditions of the warrant attribute not met.

Warrant attributes on a functional (or, in fact, on any function) and on a functional's parameter mean very differnt things:
* On a function, they give rise to a *guarantee* the function makes. E.g. a `@nogc` function will not allocate GC memory.
(When a function returns a delegate or function pointer, warrant attributes on its return type are a guarantee of that function, too.)
* Only on a functional's parameter type, warrant attributes give rise to a *requirement* that the functional *needs* to work properly.
As an example, consider a functional taking a `pure` delegate parameter.
The functional might be to make use of memoization or the fact that its parameter's results are [unique](https://dlang.org/spec/const3.html#implicit_qualifier_conversions).
In the case of memoization, omitting the requirement will not result in a compile error, but unexpected behavior.
In most cases, however, the requirement is merely to match the functionals guarantee.

In the current state of the language,
a funcional cannot have strong guarantees and weak requirements at the same time.
Most programmers opt against warrant attributes, i.e. for weak requirements
and therefore needlessly weaken the guarantees.

The proposed changes lift this restriction.
Attributes on parameter types would only be needed when the requrements are needed
for the implementation of the functional to work as intended.
The case for merely satisfying the guarantee stated by its own attributes will be handled by the type system.

<!--
In the author's estimation, the most well-known functional probaly is [`opApply`](https://dlang.org/spec/statement.html#foreach_over_struct_and_classes).
While some iteration can be done using the range interface (`empty`, `front`, `popFront`),
using `opApply` is far more general in its applications.
(An example, where `opApply` cannot be replaced by the range interface, is [`std.range.lockstep`](https://dlang.org/phobos/std_range.html#lockstep).)
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
-->

At the point where the call expression is, the compiler has all the necessary information via the type system
to determine if the execution of it will comply with the warrant attributes of the context.

## Prior Work

There is no prior work in other languages known to the autor.

The proposed changes are very specific to the D programming language.
Yet they bear some similarity to the relaxation of `pure` allowing `pure` functions to modify
any mutable value reachable through its parameters.
Those `pure` functions are called *weakly pure* in contrast to *strongly pure* ones
that cannot possibly modify values outside of them through their parameters.
The same way letting weakly pure functions be annotated `pure` allowed for more *strongly pure* functions,
the changes proposed by this DIP allow more functions carrying a warrant attribute.

## Description

<sub>
Detailed technical description of the new semantics. Language grammar changes
(per https://dlang.org/spec/grammar.html) needed to support the new syntax
(or change) must be mentioned. Examples demonstrating the new semantics will
strengthen the proposal and should be considered mandatory.
</sub>

----

### Attribute Checking inside Functionals

When the a function is annotated with a warrant attribute, each statement must satisfy certain conditions.
Among those conditions is, for any warrant attribute, that the function may only call functions
(*function* referring to anything callable here)
that are annotated with the same attribute.
Exceptions to this are `debug` blocks and that `@safe` functions may call `@trusted` functions, too.
(Note that from a calling perspective, i.e. from a rquirement perspective, `@trusted` and `@safe` are the same.
For that reason, `@trusted` makes no sense on a parameter delegate or function pointer type.)

This DIP proposes that calls to delegate or function pointer parameter are not to be checked,
i.e. considered to be `pure`, `@safe`, `nothrow`, and `@nogc` regardless of the attributes attatched to the delegate or function pointer type.
(Note that the check omission only applies to parameters to the function; any other delegates and function pointers will be checked as is currently the case.)

### Attribute Inference for Functional Templates

When inferring attributes for function templates,
calls to delegate or function pointer type parameters are considered to be `pure`, `@safe`, `nothrow`, and `@nogc`.
(Note that this only applies to parameters; calling of any other delegates and function pointers will be checked as is currently the case.)

### Attribute Checking inside Contexts

When calling a functional, the type of the delegate and/or function pointer arguments are known.
In the context of a warrant attribute, a call to a functional is legal if, and only if, the functional is annotated with that warrant attibute and all argument types are.
(As in the current state of the language, if a parameter type to the functional is annotated with a warrant attribute, i.e. stating a requirement,
and the supplied argumant fails to have this warrant attribute, it is a type mismatch.)

## Examples

Iterating multiple ranges in lockstep with `ref` access cannot be achived (not easily, at least) using the usual range interface (`empty`, `front`, `popFront`);
it requires `opApply`.
Here we will observe how the naïve approach fairs with respect to warrant attributes and how to make `opApply` admit warrant attributes properly.

The naïve approach (less interesting parts hidden):
```D
struct SimpleLockstep(Ranges...)
{
    struct SimpleLockstep(Ranges...)
{
    Ranges ranges;

    ...
    alias ElementTypes = ...;

    int opApply(const scope int delegate(ref ElementTypes) foreachBody)
    {
        import std.range.primitives : front; // needed for slices to work as ranges
        for (; !anyEmpty; popFronts)
        {
            if (auto result = mixin("foreachBody(", frontCalls, ")"))
                return result;
        }
        return 0;
    }

    bool anyEmpty() { ... }
    static string frontCalls() in (__ctfe) { ... }
    void popFronts() { ... }
}
```

In principle, being member of an aggregate template, `opApply` has its warrant attributes inferred.
Using `anyEmpty` and `popFronts` is unproblematic as they have their warrant attributes inferred, too.
But `opApply` calling its parameter `foreachBody` having a delegate type that is not annotated with any warrant attribute,
attribute inference will yield no warrant attribute for `opApply`, too.

This means that in a context annotated with any warrant attribute,
`SimpleLockstep` cannot be used.
(It can be constructed, but `foreach` through its lowering to `opApply` cannot be called.)
For exaple, a `@safe` context
plugging in ranges with `@safe` (or `@trusted`) interfaces
cannot make use of `SimpleLockstep` because `opApply` is not annotated / inferred `@safe`,
even though all operations being performed are `@safe`.

With this DIP, `opApply` has warrant attributes inferred based on what the range interfaces of the supplied ranges can guarantee.
(This is the best it can theoretically do.)
In the aforementioned case, `opApply` will be inferred `@safe`.
The question whether a call to `opApply` is legal in a `@safe` context is determined by the particular argument.
If a `@safe` context plugs in a `@system` argument, that call

## Alternatives

a

----

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
