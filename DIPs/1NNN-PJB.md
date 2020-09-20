# @nodiscard

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | (number/id -- assigned by DIP Manager)                          |
| Review Count:   | 0 (edited by DIP Manager)                                       |
| Author:         | Paul Backus (snarwin@gmail.com)                                 |
| Implementation: | <https://github.com/dlang/dmd/pull/11765>                       |
| Status:         | Will be set by the DIP manager (e.g. "Approved" or "Rejected")  |

## Abstract

Ignoring the return value of a function is a common programming mistake,
especially when it comes to functions that use their return values to signal
errors. While exceptions allow a function to signal errors that cannot be
ignored, using them has costs that programmers are not always able or willing
to pay. For those use-cases where exceptions are not a good fit, this DIP
proposes a new attribute, `@nodiscard`, that allows the programmer to make
ignoring the return value of a function into a compile-time error.

## Contents
* [Rationale](#rationale)
* [Prior Work](#prior-work)
* [Description](#description)
* [Breaking Changes and Deprecations](#breaking-changes-and-deprecations)
* [Reference](#reference)
* [Copyright & License](#copyright--license)
* [Reviews](#reviews)

## Rationale
Required.

A short motivation about the importance and benefits of the proposed change.  An existing,
well-known issue or a use case for an existing projects can greatly increase the
chances of the DIP being understood and carefully evaluated.

## Prior Work

### In D

The D compiler already warns about discarding the value of an expression with
no side effects, including a call to a strongly-pure function. An attribute
that would allow the programmer to mark specific functions or types as
non-discardable has been proposed several times on the D issue tracker and
forums; see the [Reference](#reference) section below for details.

### In Other Languages

* C++17's [`[[nodiscard]]` attribute][Cpp17Nodiscard].
* Rust's [`#[must_use]` attribute][RustMustUse].
* GCC's [`warn_unused_result` attribute][GccWarnUnusedResult].
* Clang's [`warn_unused_result` attribute][ClangWarnUnusedResult].

[Cpp17Nodiscard]: https://en.cppreference.com/w/cpp/language/attributes/nodiscard
[RustMustUse]: https://doc.rust-lang.org/reference/attributes/diagnostics.html#the-must_use-attribute
[GccWarnUnusedResult]: https://gcc.gnu.org/onlinedocs/gcc/Common-Function-Attributes.html#Common-Function-Attributes
[ClangWarnUnusedResult]: https://clang.llvm.org/docs/AttributeReference.html#nodiscard-warn-unused-result

## Description

An expression is considered to be discarded if and only if:

* It is the top-level *Expression* in an *ExpressionStatement*.
* It is the *AssignExpression* on the left-hand side of the comma in a
  *CommaExpression*.

It is a compile-time error to discard the value of an expression if:

* The expression is a call to a function whose declaration is annotated with
  `@nodiscard`.
* The value's type is an aggregate (a `struct`, `union`, `class`, or
  `interface`) whose declaration is annotated with `@nodiscard`.

The distinction between "expression" and "value" here is significant. In
particular, it means that the *value* returned from a `@nodiscard`
function may discarded as long as the function call is enclosed in some other
*expression*; for example:

```d
struct Result { int n; }
@nodiscard Result func() { return Result(0); }

void main()
{
    import std.stdio: writeln;

    // no error; return value of func is "used" by the comma expression
    (writeln("side effect"), func());
}
```

However, this is not possible if `@nodiscard` is applied to the return type
instead of the function:

```d
@nodiscard struct Result { int n; }
Result func() { return Result(0); }

void main()
{
    import std.stdio: writeln;

    // error; value of comma expression is @nodiscard, because it is a Result
    (writeln("side effect"), func());
}
```

Using `@nodiscard` has no effects on a program other than the ones described
above. In particular:

* `@nodiscard` does not affect the type of any aggregate or function it is
  applied to, and does not participate in name mangling.
* `@nodiscard` does not apply to declarations inside the body of a `@nodiscard`
  aggregate or function declaration (that is, it does not "flow through" from
  outer scopes to inner ones).
* `@nodiscard` has no effect on declarations other than aggregate and function
  declarations.

### Grammar Changes

```diff
AtAttribute:
    @ disable
    @ nogc
    @ live
+   @ nodiscard
    Property
    @ safe
    @ system
    @ trusted
    UserDefinedAttribute
```

## Breaking Changes and Deprecations

Existing code that uses `@nodiscard` as a user-defined attribute may fail to
compile, or may compile but have its meaning silently changed. Therefore,
acceptance of this DIP should be followed by a deprecation period, during which
the use of `nodiscard` as a UDA name is flagged as deprecated by the compiler.
During the deprecation period, the command-line option `-preview=nodiscard`
will enable the new behavior; afterward, the command-line option
`-revert=nodiscard` will disable it.

## Reference

* [Issue 3882 - Unused result of pure functions][Issue3882]
* [Issue 5464 - Attribute to not ignore function result][Issue5464]
* [Issue 20165 - Add standard @nodiscard attribute for functions][Issue20165]
* [xxxInPlace or xxxCopy?][Thread3] (D.General)
* [There is anything like nodiscard attribute in D?][Thread2] (D.Learn)
* [Idiomatic way to express errors without resorting to exceptions][Thread1]
  (D.Learn)

[Issue3882]: https://issues.dlang.org/show_bug.cgi?id=3882
[Issue5464]: https://issues.dlang.org/show_bug.cgi?id=5464
[Issue20165]: https://issues.dlang.org/show_bug.cgi?id=20165
[Thread1]: https://forum.dlang.org/thread/ih7sfi$1q6f$1@digitalmars.com
[Thread2]: https://forum.dlang.org/thread/rzfshzfrxrlbxyvcngke@forum.dlang.org
[Thread3]: https://forum.dlang.org/thread/hhpqmifgjslpzbzfauab@forum.dlang.org

## Copyright & License
Copyright (c) 2020 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## Reviews
The DIP Manager will supplement this section with a summary of each review stage
of the DIP process beyond the Draft Review.

