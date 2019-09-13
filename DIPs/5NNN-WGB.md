# Make @safe the default

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | (number/id -- assigned by DIP Manager)                          |
| Review Count:   | 0 (edited by DIP Manager)                                       |
| Author:         | Walter Bright walter@digitalmars.com                            |
| Implementation: | (links to implementation PR if any)                             |
| Status:         | Will be set by the DIP manager (e.g. "Approved" or "Rejected")  |

## Abstract

Currently, D functions default to being @system. This proposes changing it to @safe.


## Contents
* [Rationale](#rationale)
* [Prior Work](#prior-work)
* [Description](#description)
* [Breaking Changes and Deprecations](#breaking-changes-and-deprecations)
* [Reference](#reference)
* [Copyright & License](#copyright--license)
* [Reviews](#reviews)

## Rationale

When D was first developed, there was little interest in the extra safety checks
introduced by `@safe`. But as the costs of unsafe code have become ever more apparent
and costlier, and `@safe` has grown more capable, the balance has shifted. People expect
safety to be opt-out, not opt-in.


## Prior Work

* Other languages such as Rust and C# have safety as opt-out, rather than opt-in.
* [@safe-by-default First Draft](https://github.com/dlang/DIPs/pull/153)

## Description

Functions such as template functions, nested functions, and lambdas that are not annotated
currently have their `@safe` / `@system` inferred. This will not change. Other functions that
are not annotated will now be assumed to be `@safe` rather than `@system`.

Because this is expected to break a lot of existing code, it will be enabled with the
compiler switch:

```
-preview=safedefault
```

There are no grammar changes.

## Breaking Changes and Deprecations

This will likely break most code that has not already been annotated with `@safe`,
`@trusted`, or `@system`. Fortunately, the solutions are easy, although tedious. Annotate
the ones that aren't safe with `@trusted` or `@system`.


## Reference

## Copyright & License
Copyright (c) 2019 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## Reviews
The DIP Manager will supplement this section with a summary of each review stage
of the DIP process beyond the Draft Review.
