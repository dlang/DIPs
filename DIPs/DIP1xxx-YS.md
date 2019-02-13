# Named arguments lite

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | 1xxx                                                            |
| Review Count:   | 0                                                               |
| Author:         | Yuxuan Shui (yshuiv7@gmail.com)                                 |
| Implementation: | N/A                                                             |
| Status:         | Draft                                                                |

## Abstract

This document proposes an approach to allowing named arguments, i.e. the annotatation of function arguments with the corresponding parameter names, in the D programming language. Naming arguments can clarify an argument's intended purpose and improve code readability.

### Reference

Various solutions have been suggested in the D forums at  [1](https://forum.dlang.org/post/khcalesvxwdaqnzaqotb@forum.dlang.org) and [2](https://forum.dlang.org/post/n8024o$dlj$1@digitalmars.com).

Several library solutions have been attempted. See [1](https://forum.dlang.org/post/awjuoemsnmxbfgzhgkgx@forum.dlang.org) and [2](https://github.com/CyberShadow/ae/blob/master/utils/meta/args.d).

Another proposal has been put forth concurrently by
[rikkimax](https://github.com/rikkimax/DIPs/blob/named_args/DIPs/DIP1xxx-RC.md).

There is also an inactive proposal in [DIP88](https://wiki.dlang.org/DIP88).

## Contents
* [Rationale](#rationale)
* [Description](#description)
* [Breaking Changes and Deprecations](#breaking-changes-and-deprecations)
* [Reviews](#reviews)
* [Appendix](#appendix-grammar-changes)

## Rationale

Named arguments can be found as a language feature in several common programming
languages, such as Python, Lua, and Swift.

The motivation of this DIP is primarily to improve readability. The proposal does not address all
possibilities that are opened by the implementation of named arguments as found in other languages.
However, this DIP does not preclude such features from being implemented in a future extension of
the language.

Consider the following example of a function invocation in D:

```d
DecimalNumber product = CalculateProduct(values, 7, false, null);
```

It is difficult to decipher the meaning of each argument. Though some readers may intuit the meaning
of `values` or `7`, there is no way to know at the call site what `false` or `null` refer to.
One must consult the function's documentation. This is a real problem for which even Google's 
C++ coding style guide provides a solution in the form of using comments to annotate the 
arguments [0](https://google.github.io/styleguide/cppguide.html#Function_Argument_Comments), an approach the DIP author finds insufficient (and is addressed later in this proposal).

In addition, this proposal has the added benefit of protecting against silent breakage in cases when
a function's parameters are repurposed and renamed. For example:

```d
// Previous API: void drawRect(int x, int y, int width, int height);
// New API:
void drawRect(int x0, int y0, int x1, int y1);
```

Here, the previous `drawRect` interprets `x` and `y` as the top left
corner of a rectangle, and `width` and `height` as its dimensions. The new `drawRect` instead
uses the coordinates of the top left and the bottom right corner of the
rectangle. Without named arguments, old code will still compile because the types of the arguments
are still the same, but the parameters will be interpreted differently, thereby causing silent
breakage.

## Description

In function calls, allow a function's arguments to be annoted with a label matching the corresponding parameter name, like this: 

```d
void drawRect(int x, int y, int width, int height);

drawRect(x: 0, y: 0, width: 1, height: 1);
```

When the label and the corresponding parameter name mismatch, the compiler will generate an
error of the following nature: "Named argument 'foo' does not match function parameter name 'bar'."

### Completeness

When more than one argument exists in an argument list, either all arguments must be annotated or none at all. Given an argument list of length `len` and the number of named arguments `n`, the compiler
should generate an error when `n > 0 && n < len`.

### Ordering of arguments

Named arguments should be treated as unordered arguments, meaning they can be arranged in any order
in the argument list. For example, `drawRect` above could be called in the following manner:

```d
drawRect(width: 1, height: 1, x: 0, y: 0);
```

### Parameter name lock-in

This seems to be the biggest concern among people who are against named arguments. It is perceived
that once named arguments are applied in a function invocation, there will be no way to change
function parameter names without causing breakage. 

As suggested in the rationale, such breakage can be desired when the function parameters have been
not just renamed, but repurposed. Not all name refactorings correspond with repurposing, so it is
useful to allow for such circumstances when breakage is undesirable. This DIP supplies two tools
toward that end.

**Opt-in:** Calling a function with named arguments is opt-in on the callee side. This DIP introduces a new function attribute, `@named`, for this purpose. This attribute doesn't participate in name mangling. Only functions annotated with this attribute can be called with named arguments.

**Forward declaration with different names:** Forward declarations with different parameter names are allowed, and the caller can use names matching either of the forward declarations, as long as they are marked as `@named`. For example:

```d
int add(int x, int y);
@named:
int add(int c, int d);
int add(int b, int a) { ... }
void main() {
add(a: 1, b: 1); // fine
add(b: 1, a: 1); // fine too
add(d: 0, c: 10); // fine
add(x: 1, y: 1); // error
add(x: 1, b: 1); // error
}

```

With this, backward compatibility can be maintained after changing parameter names by keeping the
old prototype around.

### Overloading and name mangling

The usual overload set will first be filtered by the names in the argument list. If a function in
the overload set does not contain all names the caller specified, it is removed from the overload
set.

```d
int add(int a, int b) {...}
int add(int c, int d) {...} // not in the overload set
void main() {
add(a: 1, b: 2);
}
```

It might be useful to have parameter names included in the mangled name of a function, so changing the ordering of parameters won't break existing binaries. Such is beyond the scope of this DIP. A future DIP may address this issue, so as a provision for this future change, it should be prohibited to define two `@named` functions with parameter lists that are a reordering of each other. For example:

```d
@named:
int add(int a, int b) { ... }
int add(int b, int a) { ... }
```

## Alternatives

There are several library-only alternatives, however, they generally add noise to function calls, and/or require fundamental changes to how functions are defined.

For example, in one of the proposed solutions, it is necessary to call functions like so:

```d
args!(add, a=>1, b=>1);
```

This has too much noise and, moreover, does not allow for the use of Uniform Function Call Syntax (UFCS).

Another solution, as employed by the Google style guide, is to use inline comments:

```d
add(/* a */ 1, /* b */ 2);
```

Such comments contain noise in the form of the opening `/*` and closing `*/`, which arguably
decrease readability. Moreover, this approach does not allow for unordered arguments and the
compiler cannot guarantee that parameters of the same (or implicitly convertible) type are
actually being called in the expected order, e.g. `b, a` as opposed to `a, b`.

## Future changes

This DIP does not prohibit future proposals for adding partially-specified parameter names with reordering, nor does it prohibit the inclusion of parameter names as part of mangled function names. Named template arguments should also remain a future possibility.

## Breaking Changes and Deprecations

No breaking changes are expected.

## Copyright & License

Copyright (c) 2018 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## Reviews

The DIP Manager will supplement this section with a summary of each review stage
of the DIP process beyond the Draft Review.

## Appendix: Grammar Changes
```diff
ArgumentList:
+    NamedArgument
+ NamedArgument:
+    Identifier: AssignExpression

AtAttribute:
+    @ named
```
