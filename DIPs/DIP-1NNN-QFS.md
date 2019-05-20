# Compile-time Indexing Operators

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | *TBD by DIP Manager*                                            |
| Review Count:   | 0 (edited by DIP Manager)                                       |
| Author:         | Quirin F. Schroll (q.schroll@gmail.com)                         |
| Implementation: | *none*                                                          |
| Status:         | Draft                                                           |

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
(cf. [Current State Alternatives](#current-state)).
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

It is worth mentioning that this DIP introduces user-defined syntax that changes semantics based on compile-time
availableness of syntactically identical arguments.
It can be used to implement functions that are compile-time to some parameters.

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
There are multiple examples in Phobos defining `opDollar` not by a function,
but e. g. an `enum`.

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

## Examples

### Closed Tuples

Static indexing could be used to implement ecapsulated tuples which do not auto expand (in contrast to Phobos’ `Tuple`[⁽²⁾]).
* The entries can be retrieved, but not (re)assigned after construction.
* Slices (rather sections) of the tuple are tuples again.

```D
struct ReadOnlyTuple(Ts...)
{
    private Ts values;

    Ts[i] opStaticIndex(size_t i)() { return values[i]; }

    static struct Slice { size_t lowerBound, upperBound; }
    alias opSlice = Slice; // Note: opStaticSlice possible, but not necessary
    ReadOnlyTuple!(Ts[slice.lowerBound .. slice.upperBound]) opStaticIndex(Slice slice)()
    {
        return typeof(return)(values[slice.lowerBound .. slice.upperBound]);
    }
}

unittest
{
    alias T4 = ReadOnlyTuple!(int, string, char, ulong);
    T4 tup4 = T4(1, "foo", 'c', ulong.max - 1);
    assert(tup4[0] == 1); // rewrites to assert(tup4.opStaticIndex!(0) == 1);
    alias T2 = ReadOnlyTuple!(string, char);
    auto tup2 = tup4[1 .. 3]; // rewrites to auto tup2 = tup4.opStaticIndex!(tup4.opSlice(1, 3));
    static assert(is(typeof(tup2) == T2));
    assert(tup2[0] == tup4[1]); // rewrites to assert(tup2.opStaticIndex!0 == tup4.opStaticIndex!1);
    assert(tup2[1] == tup4[2]); // rewrites to assert(tup2.opStaticIndex!1 == tup4.opStaticIndex!2);
}
```

### Tuples with Slice Operator

Tuples can have a varying degree of homo-/heterogeneity:
* It can be fully homogeneous, i. e. all the entries have exactly the same type, e. g. a tuple of `int` and `int`.
* It can be unqualified homogeneous, i. e. the unqualified types of the entries are exactly the same type, e. g. a tuple of `int` and `immutable(int)`.
* It can be class homogeneous in the sense that all the entries are of class type and have a common base; that base class can be `Object` but may be more concrete. This is true only if all of the entries are `shared` or all are not `shared`.[⁽³⁾]
* It can be convertible homogeneous, i. e. there is a type that all entries can be converted to. The selection of the common type could allow user-defined conversions, e. g. setting the common type of `int` and `uint` to `ulong`.
* It is fully heterogeneous if it is neither of these.

The homogeneity properties can be made use of via Design by Introspection:[⁽⁴⁾]
* Fully homogeneous tuples are basically static arrays and can be converted by `opIndex` to a slice of the unique underlying type.
* Unqualified homogeneous tuples can be sliced, too: The types hava a common type using implicit qualifier conversions[⁽³⁾] and that type is the underlying type of that slice.

```D
import sophisticated.tuple : Tuple;
import pack.a : A;

alias A2 = Tuple!(A, immutable(A));
// A2 being unqualified homogeneous, provides opIndex() returning const(int)[].
A2 t = int2(A(1), immutable(A)(2));
auto slice = t[]; // rewrites to auto slice = t.opIndex();
static assert(is(typeof(slice) == const(A)[]));

// A2 being unqualified homogeneous, provides opIndex(size_t index) returning const(A) by reference.

inout(A) f(ref inout(A) value);

size_t i = userInput!size_t();
auto x = f(t[i]); // rewrites to auto x = f(t.opIndex(i));
```

* Class homogeneous tuples can be sliced returning `const(Base)[]` or `const(shared(Base))[]` depending on `shared`.
* Convertible homogeneous tuples cannot be sliced in general, but be iterated by value using `opApply`.

```D
import sophisticated.tuple : Tuple;
import pack.a : A;
import pack.b : B;
import pack.c : C;
import sophisticated.tratis : CommonType;

static assert(is(CommonType!(A, B) == C));

alias AB = Tuple!(A, B);

// AB being convertible homogeneous with common type C provides opIndex(size_t i), which converts the
// i-th value at runtime to the common type C, and opApply that walks the iteration variable
// through the conversions of the entries of the tuple to the common type C.

AB ab = AB(A.init, B.init);
foreach (i, c; ab) // non-static loop
{
    static assert(is(typeof(c) == C));
    if (i == 0) assert(ab[0] == ab[i]); // rewrites to assert(ab.opStaticIndex[0] == ab.opIndex[i]);
    if (i == 1) assert(ab[1] == ab[i]); // rewrites to assert(ab.opStaticIndex[1] == ab.opIndex[i]);
    // The last two asserts need not actually hold (cf. conversion from ulong.max to float),
    // but if the conversion from A and B to C is indeed lossless (e.g. the conversion from int to long),
    // it is reasonable to expect them to hold.
}
// As the conversions of the entries are intermediate values, `ref` iteration is not possible.

size_t i = userInput!size_t();
static assert(is(typeof(ab[i]) == C));

void f(ref C value); //1
void f(    C value); //2
auto x = f(ab[i]); // rewrites to auto x = f(ab.opIndex(i)); and calls //2
```

All of this is not possible in the current state of the D Programming Language,
because defining `opIndex` makes the compiler not rewrite the tuple in terms of its alias this.
This is true even if the call to `opIndex` does not compile.

### Compile-time Random-access Ranges

One can implement some kind of compile-time version of Phobos’ `iota`[⁽⁵⁾] and other ranges.
To the outside oberserver, these seem to contain values, but the values are caluclated
from internal state without creating the values beforehand.

```D
template iota(T, T start, T end, T step)
{
    template opStaticIndex(size_t i)
    {
        static assert (start + i * step < end, "static index out of range");
        enum opStaticIndex = start + i * step;
    }
}

alias i = iota!(int, 1, 10 + 1, 2);

static assert(i[0] == 1); // rewrites to static assert(i.opStaticIndex!0 == 1);
static assert(i[1] == 3); // rewrites to static assert(i.opStaticIndex!1 == 3);
```

It could be argued that this semantics can be implemented easily in the current form of the language
and that the proposed static indexing syntax is mere a readability concern,
but syntax is relevant in a meta-programming context.

### Simulate Compile-time Aware Function Parameters

Utilizing `static` members, a type can be defined that

```D
struct format
{
    template opStaticIndex(string fmt)
    {
        static string opStaticIndex(Ts...)(Ts arguments)
        {
            import std.format : format;
            return format!fmt(arguments);
        }
    }

    static auto opIndex(string fmt)
    {
        return Formatter(fmt);
    }

    struct Formatter
    {
        string fmt;
        this(string fmt) { this.fmt = fmt; }

        string opCall(Ts...)(Ts arguments)
        {
            import std.format : format;
            return format(fmt, arguments);
        }
    }
}

unittest
{
    string fmt = "%s";
    auto s = format[fmt](1); // rewritten auto s = format.opIndex(fmt).opCall(1)
    static assert(is(typeof(s) == string));
    assert(s == "1", "s == '" ~ s ~ "'");
}

unittest
{
    enum string fmt = "%s";
    enum s = format[fmt](1); // rewritten enum s = format.opStaticIndex!fmt(1);
    static assert(is(typeof(s) == string));
    static assert(s == "1");
}
```

It can be argued that this usage of the static and dynamic indexing operators is a form of abuse of operator overloading.

## Alternatives

### Current State

Currently, the only way to mimic indexing is using alias this to a compile-time sequence (generated e. g. by Phobos’ `AliasSeq` template[⁽⁶⁾]).
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
It might be desirable to pretend the existence of a sequence without storing a sequence (cf. Phobos’ `iota`[⁽⁵⁾]).
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

### Alternative Syntax

If the language maintainers decide that overloading indexing syntax is not desirable,
the DIP proposes to use the syntax `object![indices]` (note the exclamation mark) for static indexing.
This syntax is is currently an error and therefore a mere addition to the language.
Accordingly, indexing compile-time sequences should also be possible to do with the syntax `sequence![index]`
to cater to meta-programming contexts.

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

 (1) [D Language Specification on Operator Overloading](https://dlang.org/spec/operatoroverloading.html)

 (2) [D Library Documentation of std.typecons.Tuple](https://dlang.org/library/std/typecons/tuple.html)

 (3) [D Language Specification on Implicit Qualifier Conversions](https://dlang.org/spec/const3.html#implicit_qualifier_conversions)

 (4) [Andrei Alexandrescu at D Language Conference 2017: *Design by Introspection*](https://youtu.be/29h6jGtZD-U)

 (5) [D Library Documentation of std.range.iota](https://dlang.org/phobos/std_range.html#.iota)

 (6) [D Library Documentation of std.meta.AliasSeq](https://dlang.org/library/std/meta/alias_seq.html)

<!--- Markdown reference definitions --->

[⁽¹⁾]: #references "D Language Specification on Operator Overloading"
[⁽²⁾]: #references "D Library Documentation on std.typecons.Tuple"
[⁽³⁾]: #references "D Language Specification on Implicit Qualifier Conversions"
[⁽⁴⁾]: #references "D Language Conference 2017, Talk by Andrei Alexandrescu, Design by Introspection"
[⁽⁵⁾]: #references "D Library Documentation on std.range.iota"
[⁽⁶⁾]: #references "D Library Documentation on std.meta.AliasSeq"

## Copyright & License

Copyright (c) 2018 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## Reviews

The DIP Manager will supplement this section with a summary of each review stage
of the DIP process beyond the Draft Review.
