# Attribute propagation consistency

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | (number/id -- assigned by DIP Manager)                          |
| Review Count:   | 0 (edited by DIP Manager)                                       |
| Author:         | Neia Neutuladh <neia@ikeran.org>                                |
| Implementation: | (links to implementation PR if any)                             |
| Status:         | Will be set by the DIP manager (e.g. "Approved" or "Rejected")  |

## Abstract

`@nogc`, `nothrow`, and `pure` attributes should propagate into aggregates, consistent with `@system`, `@safe`, and `@trusted`.

### Reference

With [issue 5110](https://issues.dlang.org/show_bug.cgi?id=5110), the set of attributes that propagated was curtailed; it made no sense for `override` to propagate, and the author of the PR thought it was awkward for `pure` and `nothrow` to propagate because they could not be turned off.

[DIP 1012](DIP1012.md) addresses the issue of disabling `@nogc`, `pure`, and `nothrow`.

[Issue 7616](https://issues.dlang.org/show_bug.cgi?id=7616) tracks this feature request.

## Contents
* [Rationale](#rationale)
* [Description](#description)
* [Breaking Changes and Deprecations](#breaking-changes-and-deprecations)
* [Copyright & License](#copyright--license)
* [Reviews](#reviews)

## Rationale

Currently, it is simple to make all your code `@safe`: you add `@safe:` at the top of a module. The same is not true of `pure`, `@nogc`, and `nothrow`. You can mark all functions at top level that way, but it doesn't propagate to members of structs, classes, etc.

Even without DIP1012, here are three ways to remove propagation from a specific declaration:

1. Move that declaration above the `@nogc nothrow pure:` line.
2. Use `@nogc nothrow pure {}` and terminate the block before the declaration that it should not apply to.
3. Apply `@nogc nothrow pure` to declarations individually.

These solutions have been considered not so bad for free functions as to merit urgent revision, and the workaround of declaring functions inside structs to avoid attribute propagation is at best marginal.

## Description

`@nogc`, `nothrow`, and `pure` will propagate into aggregates in the same way as `@safe`, `@trusted`, and `@system`.

See https://github.com/dlang/dmd/pull/9076 for a way to do this in a brute force manner.

## Breaking Changes and Deprecations

To ease the breakage, this will happen in phases:

1. A deprecation warning will be issued for code where an aggregate's methods will have `@nogc`, `pure`, or `nothrow` propagate to them and those methods are not currently marked to match.
2. An appropriate `-transition=dip1xxx` flag will be added. When it is set, the relevant attributes will propagate and no deprecation warnings will be emitted.
3. After the period described in the deprecation process, the default behavior will be changed to match the behavior with the `-transition=dip1xxx` flag.


## Copyright & License

Copyright (c) 2018 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## Reviews

The DIP Manager will supplement this section with a summary of each review stage
of the DIP process beyond the Draft Review.
