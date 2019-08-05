# Foreach auto ref

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | (number/id -- assigned by DIP Manager)                          |
| Review Count:   | 0 (edited by DIP Manager)                                       |
| Author:         | Ate Eskola (ajieskola@gmail.com)                                |
| Implementation: | None yet                                                        |
| Status:         | Draft                                                           |

## Abstract

This DIP proposes that foreach loops with the `ref` keyword applied to the element variable should only be legal when
the elements of the range have memory addresses. It also proposes that the current behavior of `ref`,
may be retained by annotating as `auto ref` instead.

This is to ensure that `foreach` will iterate by reference,
while still allowing iteration over a range of non-copyable elements without explicit need to adapt the code[[4](#issue4707)].

## Contents
* [Rationale](#rationale)
* [Description](#description)
* [Alternatives](#alternatives)
* [Copyright & License](#copyright--license)
* [Reviews](#reviews)

## Rationale

There are currently two ways to iterate over a range with `foreach`: by value and by reference.

One is forced to iterate the range by reference if the element type is a `struct` with
a disabled postblit, since iteration by value attempts to copy the element variable.
As of DMD 2.087.0, any range can be iterated by reference, but a pull request[[1](#pr)]
was submitted to disallow such iteration for ranges whose `front` is
an rvalue[[3](#rvalues). That pull request did not end up disabling such an iteration due to
practical issues, but was approved by Andrei Alexandrescu, implying that at the concept
of `ref` meaning iteration by any method was officially considered a weakness.

The reason this behavior is a weakness is that the user cannot be sure that `foreach(ref ...)`
will iterate by reference. If a range with non-reference semantics is accidently
passed to such a loop, it will be iterated by value, which is likely to be unexpected.

In cases where one does not modify the iteration variable, one does
not care whether the iteration is done by reference or by value. Thus, when iterating
by reference, the programmer should be able to choose whether the program will fall back
to iteration by value when iteration by reference cannot be implemented, or just fail
to compile.

For function return values with a similar problem, there is already the differentiation between
`ref` and `auto ref`[6]. For consistency, `auto ref` applied to the element variable of a `foreach` loop
should be considered the best candidate as a means to ensure correct behavior when falling back
to iteration by value is desired, and `ref` should be used when fallback is not desired.

Non-copyable `struct`s are an excellent tool when designing containers adhering to the RAII (Resource-
Acquisition-Is-Initialization) principle. The EMSI-Containers package[[2](#emsi) provides good examples of such non-copyable RAII containers. It is natural to use ranges to iterate over such containers.

Iteration can be performed in a general way with the current rules (see alternatives),
or by always annotating/unannotating the element variable manually based on the types
being iterated. The former approach has disadvantages, and the latter leads
to needless changes in code when maintenance is done.

## Description

This DIP proposes that, when encountering a `foreach` loop with the `ref` keyword applied to the element variable, as in:
```D
foreach (ref loopVariable1; aggregate)
{
    loopVariable1.doSomething();
}
```

...then iff one or more elements of `aggregate` are rvalues[[3](#rvalues)], a deprecation
message must be emitted including the suggestion to annotate `loopVariable1` with the
`auto ref` keyword instead.

This DIP also proposes that when the compiler encounters a `foreach` statement
such as this:

```D
foreach (auto ref loopVariable2; nonAliasSeqAggregate)
{
    loopVariable2.doSomething();
}
```

...then iff elements of `aggregate` are lvalues [3], the
above loop has exactly the same semantics as if it were written like this:

```D
foreach (ref loopVariable2; nonAliasSeqAggregate)
{
    loopVariable2.doSomething();
}
```

Otherwise, the statement is interpreted as:

```D
foreach (loopVariable2; nonAliasSeqAggregate)
{
    loopVariable2.doSomething();
}
```

If the compiler encounters a `foreach` statement such as this:

```D
foreach (auto ref loopVariable3; anAliasSequence)
{
	loopVariable3.doSomething();
}
```

...then it must check that all members of `anAliasSequence` are values
(as opposed to, e.g., type names or module names). If that check fails,
an error message must result. Otherwise, each iteration in whic `loopVariable3`
aliases to an lvalue must be compiled with reference semantics, and each iteration
where `loopVariable3` aliases to an rvalue must be compiled as if written like this:

```D
foreach (__HIDDEN_ALIAS; anAliasSequence)
{
	auto loopVariable3 = __HIDDEN_ALIAS;
	loopVariable3.doSomething();
}
```

Note that the above behavior for rvalues is intentionally different from the
behavior of `foreach` without `ref` or `auto ref`. These semantics are
proposed by this DIP because they allow `loopVariable3` to always be an
lvalue from the user's perspective.

`auto ref` should work in both templated and non-templated functions. It should
be allowed in `static foreach`, but with no effect, as elements
of compile-time aggregates can never be lvalues.

## Example, using EMSI-Containers [2]

Briefly, `containers.DynamicArray` is an array that automatically allocates
and deallocates the memory it requires without relying on garbage collector. It
does not allow itself to be copied in order to protect the memory from being accidently
aliased to a dangling reference.

```D
import std.algorithm;
import std.range;
import std.stdio;
import containers;

// A helper function to construct an EMSI containers dynamic array
// within a single statement
auto dynamicArray(R)(R range)
{   auto result = DynamicArray!(ElementType!R).init;
    foreach(el; range) result.put(el);
    return result;
}

void writeDeepLengthA(Roi)(Roi rangeOfIterables)
{   typeof(rangeOfIterables.front.front) sum;
    foreach(iterable; rangeOfIterables) sum += iterable.length;
    sum.writeln;
}

void writeDeepLengthB(Roi)(Roi rangeOfIterables)
{   typeof(rangeOfIterables.front.front) sum;
    foreach(ref iterable; rangeOfIterables) sum += iterable.length;
    sum.writeln;
}

//Enabled by this DIP
void writeDeepLengthC(Roi)(Roi rangeOfIterables)
{   typeof(rangeOfIterables.front.front) sum;
    foreach(auto ref iterable; rangeOfIterables) sum += iterable.length;
    sum.writeln;
}

void main(){
    // Elements of this range can be copied but have no address
    auto unaddressedElements = iota(0, 10).map!(i => iota(0, i));
    // Vice-versa
    auto uniqueElements =
    [   only(7, 2, 29, 30).dynamicArray,
        only(11, 9, 0).dynamicArray,
        takeNone!(int[]).dynamicArray,
        only(3, 30, 14, 19, 4, 0, 9).dynamicArray
    ];

    // Ok, prints 45
    unaddressedElements.writeDeepLengthA;
    // Error: struct `containers.dynamicarray.DynamicArray!(int, Mallocator, false).DynamicArray`
    // is not copyable because it is annotated with @disable
    uniqueElements.writeDeepLengthA;

    // prints 45, deprecated by this DIP
    unaddressedElements.writeDeepLengthB;
    // Ok, prints 14
    uniqueElements.writeDeepLengthB;

    // Ok, prints 45
    unaddressedElements.writeDeepLengthC;
    // Ok, prints 14
    uniqueElements.writeDeepLengthC;
}
```

## Alternatives

- `ref` could retain the current behavior and a different syntax could be used
	to do what `ref` should do according to this proposal. The advantage is that no
	deprecation period is required. The disadvantage is that the semantics of `ref`
	will remain inconsistent between function signatures and `foreach` loops.

- Programmers could be instructed to use introspection to select when to iterate by
    reference or by value. This will make coding general-purpose non-mutating loops a
    lot more difficult compared to this proposal, and greatly decreases the likelihood
    of third-party code accepting ranges with non-copyable members.

- `for` could be preferred over `foreach`. The disadvantages are the same as with the preceding alternative.

- A library solution could be implemented that takes an `alias` compile-time parameter and
    chooses the iteration method on behalf of the programmer.
    `std.algorithm.iteration.each` [[5](#algo)] would be a good candidate. This
    concept has the following disadvantages:
    - Error messages become harder to read than with normal loops,
    - Using `goto`, labeled `break` and `continue`, and `return` inside the loop
        to normal termination becomes impossible with the current rules of the language.
    - Needless heap allocations are caused if local variables outside the loop body
        are accessed.

- The compiler could try to detect if a `foreach` loop by value can be silently rewritten
    with reference semantics without effect to program output and allow non-copyable
    range elements if this is the case. This was originally suggested by this DIP, but it
    was determined that this approach cannot be practically implemented without restricting
    otherwise valid code in the `foreach` body.

## Reference

- <a name="pr"></a>A pull request for DMD to disallow iteration by reference when the aggregate
 does not support it:
    * https://github.com/dlang/dmd/pull/8437

- <a name="emsi"></a>Emsi-containers GitHub repository
    * https://github.com/dlang-community/containers

- <a name="rvalues"></a>Meaning of rvalues and lvalues explained
    * http://ddili.org/ders/d.en/lvalue_rvalue.html

- <a name="issue4707"></a>A request for this feature in bugzilla:
    * https://issues.dlang.org/show_bug.cgi?id=4707

- <a name="algo"></a>std.algorithm.iteration.each documentation
    * https://dlang.org/phobos/std_algorithm_iteration.html#.each

- <a name="autoref"></a>`auto ref` language specification for function return values:
	* https://dlang.org/spec/function.html#auto-ref-functions

- <a name="aliasseq"></a>specification of iteration over alias sequences:
	* https://dlang.org/spec/statement.html#foreach_over_tuples

## Copyright & License

Copyright (c) 2019 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## Reviews

The DIP Manager will supplement this section with a summary of each review stage
of the DIP process beyond the Draft Review.
