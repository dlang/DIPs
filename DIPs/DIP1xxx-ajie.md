# Inferred foreach ref variable

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | (number/id -- assigned by DIP Manager)                          |
| Review Count:   | 0 (edited by DIP Manager)                                       |
| Author:         | Ate Eskola (ajieskola@gmail.com)                                |
| Implementation: | None yet                                                        |
| Status:         | Draft                                                           |

## Abstract

This DIP proposes that foreach loops should infer ref for their element variables when
it has no effect on semantics.

This is to allow iteration over a range of non-copyable elements without explicit need
to adapt the code for that.

### Reference

- [1] A pull request for DMD to disallow iteration by reference when the aggregate
 does not support it:
    * https://github.com/dlang/dmd/pull/8437

- [2] Emsi-containers GitHub repository
    * https://github.com/dlang-community/containers

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
copy. As of DMD 2.082.0, you can iterate any range by reference, but there already
is a pull request [1] to disallow such iteration for ranges which's front returns
by value. That pull request is approved by Andrei Alexandrescu, implying that
at least the underlying concept there is officially accepted.

But in cases where the programmer does not modify the iteration variable, he/she does
not care whether the iteration is done by reference or by value. Thus, there should
be a way to iterate that works both with elements that are iterable only by
value, and with non-copyable elements that can be iterated by reference.

Since `foreach` by value is considered the de-facto default loop, it can be considered
the best canditate to become such a way. With high likelihood many existing `foreach`
loops will start to function with non-copyable `struct`s without changes.

Non-copyable `struct`s are an excellent aid when designing containers for RAII (Resource-
Acquisition-Is-Initialization) principle. EMSI-Containers [2] are good examples of such
non-copyable RAII containers. When one has many of those containers, it is natural to
put them in a range. And with ranges comes the need to iterate.

The iteration can be done in a general way with the current rules (see alternatives),
or by always annotating/unannotating the iteration variable manually based on what is
iterated over. But all of the former have their disadvantages, and the latter leads
to needless changes in code when maintenance is done.

## Description

This DIP proposes, that when the compiler encounters a foreach statement
(example)

```D
foreach (loopVariable; range)
{
    loopVariable.doSomething();
}
```

...that satisfies the following conditions:

1. `loopVariable` is not annotated with `ref`.
2. `typeof(loopVariable)` is a `struct` with a disabled (1: postblit or 2:
    [copy constructor](https://github.com/dlang/DIPs/pull/129) ) that prevents
    compilation with value semantics.
3. If `loopVariable` had `ref` annotation added, the code would compile.
4. The compiler can prove foreach body does not mutate `loopVariable`. Mutation
    of memory referred by `loopVariable` members should be allowed through, if there
    are no other langague constructs that prevent that, such as `loopVariable` being
    annotated as `const`.
5. `loopVariable` is not `shared` and annotating `loopVariable` with `ref` will
    not make it `shared`.

...the compiler must implicitly annotate `loopVariable` with `ref`.

This DIP realizes that with type system of the D programming language, checking
`loopVariable` against mutation while still allowing mutating data by indirection
via it may be difficult to implement. The paper accepts transitive check against
mutation by `const` as a temporary solution.

## Alternatives

- The plan to disable by-reference iteration of rvalue ranges [1] could be cancelled.
    This has the disadvantage that it encourages annotating `foreach` loop variables
    with `ref` needlessly, which increases risk of accidental mutation of the `foreach`
    aggregate. The purpose of the loop will become harder to see because one cannot
    assume that `ref` means that the loop might change something. Additionally, it's
    slightly more verbose than the proposed solution.

- Programmers could be intstructed to use introspection to select whether to iterate by
    reference or by value. This will make coding general-purpose non-mutating loops a
    lot more difficult compared to this proposal, and greatly decreases the likelihood
    of third-party code accepting ranges with non-copyable members.

- `for` loops could be instructed to be used instead of `foreach`. The disadvantages
    are same as above.

- A library solution could be made that takes an `alias` compile-time parameter and
    chooses the iteration method on behalf of the programmer.
    [`std.algorithm.iteration.each`](https://dlang.org/phobos/std_algorithm_iteration.html#.each)
    would be a good canditate to become one. This concept has the following disadvantages:
    - Error messages become harder to read than with normal loops,
    - Using `goto`, labeled `break` and `continue`, and `return` inside the loop to exit
        it becomes impossible.
    - Needless heap allocations are caused if local variables outside the loop body
        are accessed.


## Copyright & License

Copyright (c) 2018 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## Reviews

The DIP Manager will supplement this section with a summary of each review stage
of the DIP process beyond the Draft Review.
