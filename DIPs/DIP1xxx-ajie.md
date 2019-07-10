# Foreach auto ref

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | (number/id -- assigned by DIP Manager)                          |
| Review Count:   | 0 (edited by DIP Manager)                                       |
| Author:         | Ate Eskola (ajieskola@gmail.com)                                |
| Implementation: | None yet                                                        |
| Status:         | Draft                                                           |

## Abstract

This DIP proposes that foreach loops with `ref` keyword should only be legal when
the elements of the range have memory addresses. It also proposes that for the current behaviour
of `ref`, the loop can be annotated as `auto ref` instead.

This is to enable the programmer to make sure that `foreach` will iterate by reference,
while still allowing iteration over a range of non-copyable elements without explicit need
to adapt the code for that [4].

### Reference

- [1] A pull request for DMD to disallow iteration by reference when the aggregate
 does not support it:
    * https://github.com/dlang/dmd/pull/8437

- [2] Emsi-containers GitHub repository
    * https://github.com/dlang-community/containers

- [3] Meaning of rvalues and lvalues explained
    * http://ddili.org/ders/d.en/lvalue_rvalue.html

- [4] A request for this feature in bugzilla:
    * https://issues.dlang.org/show_bug.cgi?id=4707

- [5] std.algorithm.iteration.each documentation
    * https://dlang.org/phobos/std_algorithm_iteration.html#.each
    
- [6] `auto ref` language specification for function return values:
	* https://dlang.org/spec/function.html#auto-ref-functions

## Contents
* [Rationale](#rationale)
* [Description](#description)
* [Alternatives](#alternatives)
* [Copyright & License](#copyright--license)
* [Reviews](#reviews)

## Rationale

There are curently two ways to iterate over a range using foreach loop: By value and
by reference.

One is forced to iterate the range by reference if the element type is a `struct` with
a disabled postblit, since iteration by value constructs the iteration variable by
copy. As of DMD 2.087.0, you can iterate any range by reference, but there already
was a pull request [1] to disallow such iteration for ranges whose `front` is
an rvalue [3]. That pull request did not end up disabling such an iteration due to
practical issues, but was approved by Andrei Alexandrescu, implying that at the concept
of `ref` meaning iteration by any method was officially considered a weakness.

The reason this behaviour is a weakness is that the user cannot rely that `foreach(ref ...)`
will iterate by reference. If a range with non-reference semantics is accidently
passed to such a loop, it will be iterated by value, which is likely to be unexcepted.

But in cases where the programmer does not modify the iteration variable, he/she does
not care whether the iteration is done by reference or by value. Thus, when iterating
by reference, the programmer should be able to choose whether the program will fallback
to iteration by value when iteration by reference cannot be implemented, or just fail
to compile.

For function return values with a similar problem, there is already the differentation between
`ref` and `auto ref` keywords[6]. For consistency, `auto ref` keyword for `foreach` loop
variables can be considered the best canditate to become a way to iterate when fallback
to iteration by value is desired, and `ref` when the fallback is not desired.

Non-copyable `struct`s are an excellent aid when designing containers for RAII (Resource-
Acquisition-Is-Initialization) principle. EMSI-Containers [2] are good examples of such
non-copyable RAII containers. When one has many of those containers, it is natural to
put them in a range. And with ranges comes the need to iterate.

The iteration can be done in a general way with the current rules (see alternatives),
or by always annotating/unannotating the iteration variable manually based on what is
iterated over. But all of the former have their disadvantages, and the latter leads
to needless changes in code when maintenance is done.

## Description

This DIP also proposes that, when encountering a `foreach` loop with `ref` keyword (example):
```D
foreach (ref loopVariable1; aggregate)
{
    loopVariable.doSomething();
}
```

then, if and only if, elements of `aggregate` are rvalues [3], a deprectation
message must be emitted, suggesting to annotate `loopVariable1` with
`auto ref` keyword instead, explained below. The DIP does not propose a length
for the deprectation period.

This DIP also proposes, that when the compiler encounters a foreach statement:
(example)

```D
foreach (auto ref loopVariable2; aggregate)
{
    loopVariable.doSomething();
}
```

...then if, and only if, elements of `aggregate` are lvalues [3], the the
above statement has exactly the same meaning as if it was written like this:

```D
foreach (ref loopVariable2; aggregate)
{
    loopVariable.doSomething();
}
```

Otherwise, the statement is interpreted as:

```D
foreach (loopVariable2; aggregate)
{
    loopVariable.doSomething();
}
```

`auto ref` should work in both generic and non-generic functions, and also when iterating
over a tuple. It should also be allowed to be used in `static foreach`, but with no
effect, as elements of compile-time aggregates can never be lvalues.

## Example, using EMSI-Containers [2]

Briefly, containers.DynamicArray is an array that automatically allocates
and deallocates memory it uses without relying on garbage collector. It
does not allow copying itself, to protect the memory from being accidently
aliased into a dangling reference.

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

    // prints 45, deprectated by this DIP
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

- `ref` keyword could retain the current behaviour, and some other syntax could be used
	for what `ref` should do according to this proposal. The advantage is that no
	deprectation period is required. The disadvantage is that semantics of the `ref`
	keyword will remain inconsistent between function signatures and `foreach` loops.

- Programmers could be instructed to use introspection to select whether to iterate by
    reference or by value. This will make coding general-purpose non-mutating loops a
    lot more difficult compared to this proposal, and greatly decreases the likelihood
    of third-party code accepting ranges with non-copyable members.

- `for` loops could be instructed to be used instead of `foreach`. The disadvantages
    are same as with the previous alternative.

- A library solution could be made that takes an `alias` compile-time parameter and
    chooses the iteration method on behalf of the programmer.
    `std.algorithm.iteration.each` [5] would be a good canditate to become one. This
    concept has the following disadvantages:
    - Error messages become harder to read than with normal loops,
    - Using `goto`, labeled `break` and `continue`, and `return` inside the loop
        to normal termination becomes impossible with current rules of the language.
    - Needless heap allocations are caused if local variables outside the loop body
        are accessed.

- The compiler could try to detect if a `foreach` loop by value can be silently rewritten
    with reference semantics without effect to program output, and allow non-copyable
    range elements if this is the case. This was originally suggested by this DIP, but it
    was found that this approach cannot be practically implemented without restricting
    otherwise valid code in the `foreach` body.
    


## Copyright & License

Copyright (c) 2018 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## Reviews

The DIP Manager will supplement this section with a summary of each review stage
of the DIP process beyond the Draft Review.
