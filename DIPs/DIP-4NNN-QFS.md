# Add `@gc` as a Function Attribute

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | (number/id -- assigned by DIP Manager)                          |
| Author:         | Quirin F. Schroll ([@Bolpat](github.com/Bolpat))                |
| Implementation: | (links to implementation PR if any)                             |
| Status:         | Draft                                                           |

## Abstract

Add `@gc` as a new function attribute that acts as the inverse of the `@nogc` attribute.

## Contents
* [Rationale](#rationale)
* [Prior Work](#prior-work)
* [Description](#description)
* [Breaking Changes and Deprecations](#breaking-changes-and-deprecations)
* [Reference](#reference)
* [Copyright & License](#copyright--license)
* [Reviews](#reviews)

## Rationale

When the `@nogc` attribute is applied via the syntax `@nogc:` or `@nogc {}`,
possibly among others,
adding a function that may allocate using the garbage collector (GC) requires one of the following:
* The programmer changes where the function is defined.
* The programmer closes the braced declaration block and reopens it after the definition (DRY violation when more attributes are used).
* The programmer changes the colon-syntax to a braced syntax, then applies the aforementioned bullet point.
* The prigrammer eliminates the colon or block syntax and attatches the attributes to every function definition, except the new one.

Such changes make for a bigger diff and are harder to review.

## Prior Work

This proposal is in similar spirit to [DIP 1029](https://github.com/dlang/DIPs/blob/master/DIPs/accepted/DIP1029.md),
which added `throw` as a function attribute / storage class as the inverse of the `nothrow` attribute.

## Description

### Semantics

A `@gc` function is semantically exactly a function that is not `@nogc`.
Anything that can syntactically have the `@nogc` attribute attached can have the `@gc` attribute attached.

```d
@nogc
{
    int[] f()     => [1]; // Error: array literal in `@nogc` function `f` may cause a GC allocation
    int[] g() @gc => [1]; // Okay, `g` is not `@nogc`
}
```

The `@gc` and `@nogc` attributes are mutually exclusive on the same level
exactly like the other pairs of opposing attributes (`@safe` / `@system` and `nothrow` / `throw`) are.

```d
void f() @gc @nogc; // Error: conflicting attributes
```

Like `@system` and `throw`, the `@gc` attribute is contravariant.
```d
void f(void function() @gc callback);
void function(void function() @nogc) fp = &f; // Okay

void g(void function() @nogc callback);
void function(void function() @gc callback) gp = &g; // Error: cannot implicitly convert expression `& g` of type `void function(void function() @nogc callback)` to `void function(void function() @gc callback)`
```
A virtual `@gc` method can be overridden by a `@nogc` method,
but a virtual `@nogc` method cannot be overridden by a `@gc` method.

### Grammar

```diff
    AtAttribute:
        @ disable
        @ __future
        @ nogc
+       @ gc
        @ live
        Property
        @ safe
        @ system
        @ trusted
        UserDefinedAttribute
```

### Scope

This DIP specifically aims to address the lack of a contravariant inverse of an attribute
that can be added easily and with minimal syntactical and naming controvercy.

The only remaining function attribute without a contravariant inverse will be `pure`.
While the lack of an inverse for `pure` is unfortunate and will become more apparent,
adding one is in all likelihood not as uncontroversial as adding `throw` (cf. [DIP 1029](https://github.com/dlang/DIPs/blob/master/DIPs/accepted/DIP1029.md))
or `@gc` (this DIP).

## Breaking Changes and Deprecations

Code that uses `@gc` as a user-defined attribute potentially breaks.
However, such breakage is unlikely because the addition of `@gc` as the opposite of `@nogc` is likely anticipated.
In the unlikely scenario where code breaks,
renaming `gc` to `gc_` as is customary with other keywords fixes the issue.

## Copyright & License
Copyright © 2024 by Quirin F. Schroll

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## History
The DIP Manager will supplement this section with links to forum discsusionss and a summary of the formal assessment.
