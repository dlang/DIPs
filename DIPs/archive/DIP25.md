# Sealed references

| Section        | Value                                  |
|----------------|----------------------------------------|
| DIP:           | 25                                     |
| Status:        | Implemented                            |
| Author:        | Walter Bright and Andrei Alexandrescu  |

## Abstract

D offers a number of features aimed at systems-level coding, such as
unrestricted pointers, casting between integers and pointers, and the
[`@system`](http://dlang.org/function.html#system-functions) attribute. These
means, combined with the other features of D, make it a complete and expressive
language for systems-level tasks. On the other hand, economy of means should be
exercised in defining such powerful but dangerous features. Most other features
should offer good safety guarantees with little or no loss in efficiency or
expressiveness. This proposal makes `ref` provide such a guarantee: with the
proposed rules, it is impossible in safe code to have `ref` refer to a
destroyed object. The restrictions introduced are not entirely backward
compatible, but disallow code that is stylistically questionable and that can
be easily replaced either with equivalent and clearer code.

### Links

* [DIP71: 'noscope' and 'out!param' attributes](http://wiki.dlang.org/DIP71)

## Description

### In a nutshell

This DIP proposes that any `ref` parameter that a function received and also
wants to return must be also annotated with `return`. Annotation are deduced
for templates and lambdas, but must be explicit for all other declarations.

Example:

``` D
@safe:
ref int fun(ref int a) { return a; } // ERROR
ref int gun(return ref int a) { return a; } // FINE
ref T hun(T)(ref T a) { return a; } // FINE, templates use deduction
```

### Detailed Description

Currently, D has some provisions for avoiding dangling references:

``` D
ref int fun(int x) {
  return x; // Error: escaping reference to local variable x
}

ref int gun() {
  int x;
  return x; // Error: escaping reference to local variable x
}

struct S {
    int x;
}

ref int hun() {
  S s;
  return s.x; // see https://issues.dlang.org/show_bug.cgi?id=13902
}

ref int iun() {
  int a[42];
  return a[5]; // see https://issues.dlang.org/show_bug.cgi?id=13902
}
```

However, this enforcement is shallow (even after fixing [issue
13902](https://issues.dlang.org/show_bug.cgi?id=13902)). The following code
compiles and allows reads and writes through defunct stack locations, bypassing
scoping and lifetime rules:

``` D
ref int identity(ref int x) {
  return x; // pass-through function that does nothing
}

ref int fun(int x) {
  return identity(x); // escape the address of a parameter
}

ref int gun() {
  int x;
  return identity(x); // escape the address of a local
}

struct S {
    int x;
    ref int get() { return x; }
}

ref int hun(S x) {
  return x.get; // escape the address of a part of a parameter
}

ref int iun() {
  S s;
  return s.get; // escape the address of part of a local
}

ref int jun() {
  return S().get; // worst contender: escape the address of a part of an rvalue
}
```

The escape patterns are obvious in these simple examples that make all code
available and use no recursion, and may be found automatically. The problem is
that generally the compiler cannot see the body of `identity` or `S.get()`. We
need to devise a method that derives enough information for safety analysis
only given the function signatures, not their bodies.

This DIP devises rules that allow passing objects by reference *down* into
functions, and return references *up* from functions, whilst disallowing cases
such as the above when a reference passed up ends up referring to a deallocated
temporary.

### Adding `return` as a parameter attribute

The main issue is typechecking functions that return a `ref` `T` and accept
some of their parameters by `ref`. Those that attempt to return locals or parts
thereof are already addressed directly, contingent to [Issue
13902](https://issues.dlang.org/show_bug.cgi?id=13902). The one case remaining
is allowing a function returning `ref` `T` to return a (part of a) parameter
passed by `ref`.

The key is to distinguish legal from illegal cases. One simple but overly
conservative option would be to simply disallow returning a `ref` parameter or
part thereof. That makes `identity` impossible to implement, and as a
consequence accessing elements of a container by reference becomes difficult or
impossible to typecheck properly. Also, heap-allocated structures with
deterministic destruction (e.g. reference counted) must insert member copies
for all accesses.

This proposal promotes adding `return` as an attribute that propagates the
lifetime of a parameter to the return value of a function. With the proposed
semantics, a function is disallowed to return a `ref` parameter or a part
thereof UNLESS the parameter is also annotated with `return`. Under the
proposed semantics `identity` will be spelled as follows:

``` D
@safe ref int wrongIdentity(ref int x) {
    return x; // ERROR! Cannot return a ref, please use "return ref"
}
@safe ref int identity(return ref int x) {
    return x; // fine
}
```

Just by seeing the signature `ref` `int` `identity(return` `ref` `int` `x)` the
compiler assumes that the result of identity must have a shorter or equal
lifetime than `x` and typechecks callers accordingly. Example (given the
previous definition of `identity`):

``` D
@safe ref int fun(return ref int x) {
    int a;
    return a; // ERROR per current language rules
    static int b;
    return b; // fine per current language rules
    return identity(a); // ERROR, this may escape the address of a local
    return x; // fine, propagate x's lifetime to output
    return identity(x); // fine, propagate x's lifetime through identity to the output
    return identity(identity(x)); // fine, propagate x's lifetime twice through identity to the output
}

@safe ref int gun(ref int input) {
    static int[42] data;
    return data[input]; // works, can always return static-lived data
}

@safe struct S {
    private int x;
    ref int get() return { return x; } // should work, see next section
}
```

### Interaction with `auto` `ref`

Syntactically it is illegal to use `auto` `ref` and `return` `ref` on the same
parameter. Deduction of the `return` attribute still applies as discussed
below.

### Deduction

Deduction of the `return` attribute will be effected under the same conditions
as for `pure` (currently for generic and lambda functions). That means the
generic `identity` function does not require the `return` attribute:

``` D
auto ref T identity(auto ref T x) {
    return x; // correct, no need for return
}
```

### Types of Result vs. Parameters

Consider:

``` D
@safe ref int fun(return ref float x);
```

This function arguably cannot return a value scoped within the lifetime of its
argument for the simple reason it's impossible to find an `int` somewhere in a
`float` (apart from unsafe address manipulation). However, this DIP ignores
types; if a parameter is `return` `ref`, it is always considered potentially
escaped as a result. It is in fact possible that the author of `fun` wants to
constrain its output's lifetime for unrelated reasons.

Future versions of this DIP may relax this rule.

### Multiple Parameters

If multiple `return` `ref` parameters are present, the result's lifetime is
conservatively assumed to be enclosed in the lifetime of the shortest-lived of
those arguments.

### Member Functions

Member functions of `struct`s must qualify `this` with `return` if they want to
return a result by `ref` that won't outlive `this`. Example:

``` D
@safe struct S {
    static int a;
    int b;
    ref int fun() { return a; } // fine, callers assume infinite lifetime
    ref int gun() { return b; } // ERROR! Cannot return a direct member
    ref int hun() return { return b; } // fine, result is scoped within this
}
```

### `@safe`

For the initial release, the requirement of returns for `ref` parameter data to
be marked with `return` will only apply to `@safe` functions. The reasons for
this are to avoid breaking existing code, and because it's not yet clear
whether this feature will interfere with valid constructs in a system language.

``` D
@safe   ref int fun(ref int x)        { return x;} // Error
@safe   ref int gun(return ref int x) { return x;} // OK
@system ref int hun(ref int x)        { return x;} // OK for now, @system code.
@system ref int jun(return ref int x) { return x;} // preferred, gives more hints to compiler for lifetime of return value
```

## Copyright & License

Copyright (c) 2016 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)
