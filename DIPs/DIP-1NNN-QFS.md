# Compile-time Indexing Operators

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | (number/id -- assigned by DIP Manager)                          |
| Review Count:   | 0 (edited by DIP Manager)                                       |
| Author:         | Quirin F. Schroll (q.schroll@gmail.com)                         |
| Implementation: | (links to implementation PR if any)                             |
| Status:         | Will be set by the DIP manager (e. g. "Approved" or "Rejected") |

## Abstract

In the current state of the D Programming Language, a user-defined type can only
define indexing operators with function parameters.
This DIP proposes additional compiler-recognized member names for implementing indexing
where the indexing parameters are required to be – or handled differently when – known at compile-time.

## Contents
* [Rationale](#rationale)
* [Description](#description)
* [Alternatives](#alternatives)
* [Breaking Changes and Deprecations](#breaking-changes-and-deprecations)
* [References](#references)
* [Copyright & License](#copyright--license)
* [Reviews](#reviews)

## Rationale

Implementing heterogeneous structures like tuples, indexing syntax can only be implemented in a very narrow way
(cf. [Current State Alternatives](#current-state).
Given a user-defined tuple type, sophisticated indexing would require handling the indexing parameters as
compile-time values to determine even the type of the indexing expression.

With the additions proposed by this DIP, it would be possible to make
e. g. slices of Phobos’ `Tuple` return a `Tuple` again.

With what this DIP proposes, custom types can provide the full range of syntactic possibilities of dynamic indexing
also for the cases when the indexing parameters (the stuff in square brackets) be determined at compile-time
and made available to the handling members as template parameters instead of function parameters.

As an example, the expression `object[i]` would be rewritten as `object.opStaticIndex!i` first.
If that succeeds, the handling member `opStaticIndex` can use the value of `i` as a compile-time value.
If that fails, `object[i]` will be rewritten as `object.opIndex(i)`, where `i` is a function parameter.

As an additional benefit, even if not required, the custom type can check compile-time known indexing parameters
for validity by overloading both dynamic and static indexing operators.
This is what the compiler does for static arrays:
While, formally, indexing is a run-time operation, when using a compile-time known index that is out of bounds,
the compiler will report an error.

## Description

When a user-defined type has any of the following compiler-recognized members
* `opIndex`,
* `opIndexUnary`,
* `opIndexAssign`,
* `opIndexOpAssign`,
* `opSlice`, and
* `opDollar`

the compiler generates appropriate rewrites using the aforementioned members
to provide indexing for that type when using indexing syntax.[⁽¹⁾]

These member functions, except `opDollar`, will be called *dynamic indexing operators* in the following,
in contrast to the *static indexing operators* proposed by this DIP.

The DIP proposes to add the following names to the compiler-recognized member names for operator overloading:
* `opStaticIndex`
* `opStaticIndexUnary`
* `opStaticIndexAssign`
* `opStaticIndexOpAssign`
* `opStaticSlice`

Notably absent is the name `opStaticDollar`.
The rewrite of `$` remains unchanged,
as `opDollar` does not require any function parameters.

The DIP proposes that rewriting indexing expressions as per the spec,[⁽¹⁾]
the compiler will first try static indexing operators,
and if that fails, try dynamic indexing operators.

The DIP does not propose to change the rewrites to dynamic indexing operators.

The rewrites to static indexing operators is completely analogous to the dynamic ones,
with the only difference being that the arguments inside the square brackets will be
used as template parameters instead of function parameters.

* The expression `op object[indices]`, where `op` is some overloadable unary operator,
is rewritten as `object.opStaticIndexUnary!(op, indices)`.
* The expression `object[indices] = rhs`
is rewritten as `object.opStaticIndexAssign!(indices)(rhs)`.
If `indices` is the empty sequence and this rewrite fails, the expression
is rewritten as `object.opStaticIndexAssign(rhs)`,
i. e. without template instantiation syntax.
* The expression `object[indices] op= rhs`, where `op` is some overloadable binary operator,
is rewritten as `object.opStaticIndexOpAssign!(op, indices)(rhs)`.
* The expression `object[indices]` if not preceded by a unary operator or preceded by some assignment operator, or
if so, but the above rewrites failed, will be rewritten as `object.opStaticIndex!(indices)`.
If `indices` is the empty sequence and this rewrite fails, the expression
is rewritten as `object.opStaticIndex`,
i. e. without template instantiation syntax.

* In any case, if some of the `indices` are of the form `lower .. upper`, that part
is rewritten as `object.opStaticSlice!(i, lower, upper)`,
where `i` is the 0-based index of the slice in the square brackets.
If this rewrite fails, the part
is rewritten as `object.opStaticSlice!(lower, upper)`,
i. e. without the index.

If the static rewriting detailed above ultimately fails, rewriting with dynamic indexing operators is done.

## Alternatives

### Current State

Currently, the only way to mimic indexing is using alias this to a compile-time sequence (generated e. g. by Phobos’ `AliasSeq` template[⁽³⁾]).
In Phobos, `Tuple` does exactly that.[⁽²⁾]
This has several limitations:

1. While it is possible to have alias this to the sequence and the compiler-recognized member `opIndex` in place,
the index syntax is not forwarded to the alias this’d sequence anymore
even if the rewrite with `opIndex` fails.
Phobos’ `Tuple` does not overload `opIndex` and therefore does not suffer from this problem.[⁽²⁾]
2. Even if 1. were resolved, the result of a slice (e. g. `object[l .. u]`) would be a sequence.
There is no way to hook in and make it evaluate to something different than a sequence, e. g. a user-defined type.
Consequently, Phobos’ `Tuple` when sliced, does not return a `Tuple` but a sequence.[⁽²⁾]
3. The sequence cannot be protected from modifications.
It is fully exposed without any possibility to manage access to it.
4. The complete sequence must exist in the first place.
It might be desirable to pretend the existence of a sequence without storing a sequence (cf. Phobos’ `iota`[⁽²⁾]).
5. As alias this is already taken, one cannot alias this something different.

The whole sequence approach can only be used for indexing with exactly one parameter.
Multidimensional (including 0-dimensional) indexing is not possible.

Without indexing syntax, it is necessary to use helper function templates, that take
the indexing parameters as template parameters,
e. g. like `tuple.index!1` or `tuple.slice!(lBound, uBound)`.

The author believes that using those helper templates is less readable than indexing expressions.
More objectively, it does not play well in meta-programming contexts,
where one would like to not have to distinguish the cases of user-defined types,
static arrays and compile-time sequences
the same way, meta-programming code does not have to distinguish
dynamic arrays and user-defined random-access ranges when indexing them.
The current solution is to ignore tuple-like types or to special-case specific ones.

### Compile-time Function Parameters

If some way to discriminate function parameters for their compile-time availableness were implemented,
e. g. by a function parameter storage class,
the functionality would be implementable using the currently available compiler-recognized members for operator overloading.

The author believes that adding such a storage class is a much greater change of the language as
it affects the mechanics of function overloading and makes reasoning about code more difficult.
Detailing out, what that change would exactly entail, is beyond the scope of this DIP.
The author only mentions this alternative as this might encourage that evaluation by someone else.

## Breaking Changes and Deprecations

This change is purely additional.
It only affects custom types that have members named like the aforementioned compiler-recognized member names which is presumed unlikely.
Even then, the change would not actually break that code or change its semantics.

## References

<!--- List of references --->

⁽¹⁾ [D Language Specification on Operator Overloading](https://dlang.org/spec/operatoroverloading.html)

⁽²⁾ [D Library Documentation on std.typecons.Tuple](https://dlang.org/library/std/typecons/tuple.html)

⁽³⁾ [D Library Documentation on std.meta.AliasSeq](https://dlang.org/library/std/meta/alias_seq.html)

⁽⁴⁾ [Alexandrescu at D Language Conference 2017, *Design by Introspection*](https://youtu.be/29h6jGtZD-U)

⁽⁵⁾ [D Language Specification on Implicit Qualifier Conversions](https://dlang.org/spec/const3.html#implicit_qualifier_conversions)

⁽⁶⁾ [D Library Documentation on std.range.iota](https://dlang.org/phobos/std_range.html#.iota)

<!--- Markdown reference definitions --->

[⁽¹⁾]: #references "D Language Specification on Operator Overloading"
[⁽²⁾]: #references "D Library Documentation on std.typecons.Tuple"
[⁽³⁾]: #references "D Library Documentation on std.meta.AliasSeq"
[⁽⁴⁾]: #references "D Language Conference 2017, Talk by Andrei Alexandrescu, Design by Introspection"
[⁽⁵⁾]: #references "D Language Specification on Implicit Qualifier Conversions"
[⁽⁶⁾]: #references "D Library Documentation on std.range.iota"

## Copyright & License

Copyright (c) 2018 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## Reviews

The DIP Manager will supplement this section with a summary of each review stage
of the DIP process beyond the Draft Review.

<!---  ’⁰¹²³⁴⁵⁶⁷⁸⁹⁽⁾ --->
