# Add enum E(T) = expression; eponymous template support

| Section         | Value                                                     |
|-----------------|-----------------------------------------------------------|
| DIP:            | 42                                                        |
| Status:         | Implemented                                               |
| Author:         | Walter Bright                                             |
| Implementation: | <https://github.com/D-Programming-Language/dmd/pull/2368> |

## Abstract

Short-hand syntax for templates that evaluate to single `enum`.

## Description

This pattern has become quite common in D:

``` D
template isIntegral(T)
{
    enum isIntegral = is(T : long) || is(T : ulong) || ...;
}
```

Analogously to struct S(T), the enum manifest constant could be written as:

``` D
enum isIntegral(T) = is(T : long) || is(T : ulong) || ...;
```

This is a natural fit for D. It does not break any existing code, and is simple
to implement - it's just a rewrite in the parser.

### Rationale

The pattern is common, and a bit awkward. It's worth supporting the new syntactic sugar.

## Copyright & License

Copyright (c) 2016 by the D Language Foundation
Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)
