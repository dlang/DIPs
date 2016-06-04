# Provide pragma to control function inlining

| Section         | Value                   |
|-----------------|-------------------------|
| DIP:            | 56                      |
| Status:         | Implemented             |
| Author:         | Walter Bright           |
| Implementation: | <https://github.com/dlang/dmd/pull/4723> |

## Abstract

This proposal uses pragmas to add inlining instructions to the compiler.

## Description

This adds a pragma 'inline', which is followed by an optional boolean
expression, which influences the inlining of the function it appears in. An
evaluation of 'true' means always inline, 'false' means never inline, and no
argument means the default behavior, as indicated in the command line.

If this pragma is outside of a function, it affects the functions in the block
it encloses.

Nested pragmas override the outer ones.

If there are multiple pragmas inside a function, the lexically last one that is
semantically analyzed controls the behavior.

If the pragma is versioned out or in a false static if conditional, it is
ignored.

If a pragma specifies always inline, and the compiler cannot inline it, a
warning will be generated. Implementations will likely vary in their ability to
inline.

These are not attributes because they should not affect the semantics of the
function. In particular, the function signature must not be affected.

### Rationale

Sometimes generating better code requires runtime profile information. But
being a static compiler, not a JIT, the compiler could use such hints from the
programmer.

### Semantics

With the `-inline` compiler flag:

`pragma(inline, true)` always inlines

`pragma(inline, false)` never inlines

`pragma(inline)` inlines at compiler's discretion

Without the `-inline` compiler flag:

`pragma(inline, true)`    always inlines

`pragma(inline, false)`   never inlines

`pragma(inline)`          never inlines

## Copyright & License

Copyright (c) 2016 by the D Language Foundation
Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)
