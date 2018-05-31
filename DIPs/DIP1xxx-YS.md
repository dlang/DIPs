# Named arguments lite

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | 1xxx                                                            |
| Review Count:   | 0                                                               |
| Author:         | Yuxuan Shui (yshuiv7@gmail.com)                                 |
| Implementation: | N/A                                                             |
| Status:         |                                                                 |

## Abstract

Named arguments adds a way to annotate the arguments passed to functions. It makes the intention of passed arguments more clear, which should results in code been more readable.

### Reference

Various solutions have been suggested in the NewsGroup,  [1](https://forum.dlang.org/post/khcalesvxwdaqnzaqotb@forum.dlang.org) and [2](https://forum.dlang.org/post/n8024o$dlj$1@digitalmars.com).

Library only solutions have also been attempted multiple times, see [1](https://forum.dlang.org/post/awjuoemsnmxbfgzhgkgx@forum.dlang.org) and [2](https://github.com/CyberShadow/ae/blob/master/utils/meta/args.d).

There are also a couple DIPs proposed or in development, see [DIP88](https://wiki.dlang.org/DIP88) and [rikkimax](https://github.com/rikkimax/DIPs/blob/named_args/DIPs/DIP1xxx-RC.md)

## Contents
* [Rationale](#rationale)
* [Description](#description)
* [Breaking Changes and Deprecations](#breaking-changes-and-deprecations)
* [Reviews](#reviews)
* [Appendix](#appendix)

## Rationale

Named arguments is a common programming language feature found in various dynamic or compiled languages. There are various motivation behind that, such as to make code more readable, and to pass arguments in arbitrary order.

Unlike named arguments in other languages and previous DIPs, this DIP only aim to address the readability issue. This is to increase the chance of adaptation, while still keeping one of the major niceties of this feature.

Consider this example:

```d
// What are these arguments?
DecimalNumber product = CalculateProduct(values, 7, false, null);
```

It is really difficult to decipher what each argument actually means. This is a real existing problem. As even Google's C++ coding style guide tries to provide a solution for that (they suggest using comments, we will discuss later).

This DIP also has the added benefits of preventing silent breakage when the meanings of function parameters changed, but their type don't (assuming the meanings are reflected in the names). For example:

```d
// Previous API: void draw_rect(int x, int y, int width, int height);
// New API:
void draw_rect(int x0, int y0, int x1, int y1);
```

## Description

The bird's eye view of this change is simple. In function calls, the arguments passed can be prefixed with a name, like this: `draw_rect(x: 0, y: 0, width: 1, height: 1)`. And when names mismatch, errors will be generated.

However, there are quite a bit of details that need to be nailed down.

### Ordering of arguments

As stated before, this DIP only tries to address the readability issue, therefore passing arguments in different order than in the function definition is not allowed. All arguments have to be passed in the same order as defined in function parameter list, optionally they can be prefixed with a name.

### Overloading and name mangling

Two functions with only their parameter names different is **not** considered to be different during overload resolution, even when called with named parameters. For example:

```d
int add(int a, int b) {...}
int add(int b, int a) {...}
void main() {
    add(a: 1, b: 2); // Error: 'add' called with arguments types '(int, int)' matches both
}

// However, forward declarations with different parameter names are fine
// Importance of this will become clear later
int add(int a, int b);
int add(int b, int a) { ... }
```

Because of this, parameter names don't need to participate in name mangling.

### Parameter name lock in

This seems to be the biggest concern among people who are against named arguments. It is perceived that once named arguments is implemented, there will be no way to change function parameter names without causing breakage. This DIP supplies two tools to combat that.

**Opt-in:** Calling function with named arguments is opt-in on the callee side. This DIP introduces a new function attribute, `@named`, for this purpose. This attribute doesn't participate in name mangling. Only functions annotated with this attribute can be called with named arguments.

**Forward declaration with different names:** Forward declarations with different parameter names are allowed, and the caller can use names matching either of the forward declarations, as long as they are marked as `@named`. For example:

```d
int add(int x, int y);
@named:
int add(int a, int b);
int add(int b, int a) { ... }
void main() {
    add(a: 1, b: 1); // fine
    add(b: 1, a: 1); // fine too
    add(x: 1, y: 1); // error
    add(x: 1, b: 1); // error
}

```

With this, backward compatibility can be maintained after changing parameter names by keeping the old prototype around.

## Alternatives

There are several library only alternatives, however, they generally adds a lot of noise to function calls, and/or requires fundamental changes to how functions are defined.

For example, in one of the proposed solutions, you have to call functions like this:

```d
args!(add, a=>1, b=>1); // Too much noises, and no UFCS
```

Another solution is to use comments. However, comments still contain noise (i.e. opening and closing comment blocks). And there is no guarantee enforced by the compiler that arguments aren't passed with a wrong order.

## Breaking Changes and Deprecations

No breaking changes are expected.

## Copyright & License

Copyright (c) 2018 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## Review

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
