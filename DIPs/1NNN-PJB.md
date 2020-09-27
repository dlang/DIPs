# @nodiscard

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | (number/id -- assigned by DIP Manager)                          |
| Review Count:   | 0 (edited by DIP Manager)                                       |
| Author:         | Paul Backus (snarwin@gmail.com)                                 |
| Implementation: | <https://github.com/dlang/dmd/pull/11765>                       |
| Status:         | Draft                                                           |

## Abstract

This DIP proposes a new attribute, `@nodiscard`, that allows the programmer to
make ignoring a function's return value into a compile-time error. It can be
used to implement alternative error-handling mechanisms for code that cannot
use exceptions, and to prevent bugs when interfacing with external functions
that report errors via their return values.

## Contents
* [Rationale](#rationale)
* [Prior Work](#prior-work)
* [Description](#description)
* [Breaking Changes and Deprecations](#breaking-changes-and-deprecations)
* [Reference](#reference)
* [Copyright & License](#copyright--license)
* [Reviews](#reviews)

## Rationale

### Error handling without exceptions

Currently, in D, if a function wants to send a signal to its caller that the
caller cannot ignore, the only way to do so is to throw an exception. For a
variety of reasons, however, the use of exceptions is not always possible or
desirable. Examples of code that may want or need to avoid exceptions include:

* Code that is written in a language other than D (e.g., C or C++).
* Code written in D that may be called from another language.
* Code that does not want to depend on the D runtime.
* Code that cannot afford the runtime performance overhead of exceptions.

These use-cases represent a minority of code, but not a negligible one. Of the
1868 packages on [code.dlang.org][Dub] at the time of writing:

* 273 (14%) are categorized as "D language bindings" (that is, code written in other
languages).
* 93 (5%) are categorized as "optimized for fast execution" (that is, code
  that cannot afford extra runtime performance overhead).
* 54 (3%) are categorized as "suitable for `@nogc` use," the closest category
  available to "usable without the D runtime" or "`-betterC` compatible."

The total number of packages in these categories, filtered for duplicates, is
384, or 20% of registered packages. This suggests that roughly one in five D
projects have at least one reason to be interested in an error-handling
mechanism that does not use exceptions.

#### Alternatives

One possible alternative to exceptions, [proposed by Vladimir
Panteleev][SuccessType], is for a function to return an error code wrapped in a
`struct` that `assert`s (or `throw`s) in its destructor at runtime if it has
not been used (where "using" means calling a particular method). While this
addresses some of the use-cases above, it has several shortcomings compared to
`@nodiscard`.

1. It reports ignored errors at runtime rather than compile time.
2. It cannot be used directly with functions written in other languages.
3. It requires additional syntax in both the callee and its callers to wrap
   and unwrap the error code.

By contrast, `@nodiscard` can be used without caveats to provide compile-time
protection against ignored errors in all of the use-cases listed above.

[Dub]: https://code.dlang.org/

### Functions without specified side effects

Some functions have side effects, but are nevertheless unlikely to be called
for those side effects alone. Examples of such functions include:

* Functions that acquire resources, such as `malloc` and `mmap`.
* Functions that generate random numbers, such as `rand` and `uniform`.
* Generic functions that may or may not cause side effects in order to produce
  a particular result, such as `filter` and `map`.

What these functions have in common is that their side effects, if any, are
considered implementation details, rather than being part of their documented
behavior. As a result, calling code cannot rely on them to cause any *specific*
side effects without risking breakage if and when those implementation details
change.

While ignoring the return values of these functions is unlikely to result in
disaster, it is still a probable programming mistake, which `@nodiscard` could
help guard against.

This DIP does not recommend adding `@nodiscard` to any existing functions in
Phobos or the D runtime, since doing so would constitute a breaking API change.
However, authors of new code would still benefit from having `@nodiscard` in
the language, and existing projects (including Phobos and the D runtime) could
adopt `@nodiscard` on a case-by-case basis if the benefit were judged to be
worth the potential for breakage.

## Prior Work

### In D

The D compiler already warns about discarding the value of an expression with
no side effects, including a call to a strongly-`pure` and `nothrow` function.
An attribute that would allow the programmer to mark specific functions or
types as non-discardable has been proposed several times on the D issue tracker
and forums; see the [Reference](#reference) section below for details.

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

An expression is considered to be discarded if and only if either of the
following is true:

* It is the top-level *Expression* in an *ExpressionStatement*, or
* It is the *AssignExpression* on the left-hand side of the comma in a
  *CommaExpression*.

It is a compile-time error to discard an expression if either of the following
is true:

* It is a call to a function whose declaration is annotated with
  `@nodiscard`, or
* It is not an assignment expression, and its type is an aggregate (a `struct`,
  `union`, `class`, or `interface`) whose declaration is annotated with
  `@nodiscard`.

Note that the former is a syntax-level check, while the latter is a type-level
check. This means that the *value* returned from a `@nodiscard` function may in
fact be discarded, as long as the function call itself is enclosed in some
other expression. For example:

```d
// un-annotated type
struct Result { int n; }

// @nodiscard function
@nodiscard Result func() { return Result(0); }

void main()
{
    import std.stdio: writeln;

    // no error: the return value of func is "used" by the comma expression
    (writeln("side effect"), func());
}
```

By contrast, a value of a `@nodiscard` type will always cause an error if it is
discarded, regardless of the expression that discards it:

```d
// @nodiscard type
@nodiscard struct Result { int n; }

// un-annotated function
Result func() { return Result(0); }

void main()
{
    import std.stdio: writeln;

    // error: the return type of func is also the type of the comma expression
    (writeln("side effect"), func());
}
```

In all cases, an error resulting from `@nodiscard` can be suppressed by
prepending `cast(void)` to the offending expression, since a *CastExpression*
is not a function call, and `void` is not an aggregate type annotated with
`@nodiscard`.

Using `@nodiscard` has no effects on the semantics of a program other than the
ones described above. In particular:

* `@nodiscard` is not part of the type of any symbol it is applied to, and does
  not participate in name mangling.
* `@nodiscard` does not apply to declarations inside the body of a `@nodiscard`
  aggregate or function declaration (that is, it does not "flow through" from
  outer scopes to inner ones).
* `@nodiscard` has no semantic effect on declarations other than aggregate and
  function declarations.

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
* [Vladimir Panteleev's `Success` type.][SuccessType]

[Issue3882]: https://issues.dlang.org/show_bug.cgi?id=3882
[Issue5464]: https://issues.dlang.org/show_bug.cgi?id=5464
[Issue20165]: https://issues.dlang.org/show_bug.cgi?id=20165
[Thread1]: https://forum.dlang.org/thread/ih7sfi$1q6f$1@digitalmars.com
[Thread2]: https://forum.dlang.org/thread/rzfshzfrxrlbxyvcngke@forum.dlang.org
[Thread3]: https://forum.dlang.org/thread/hhpqmifgjslpzbzfauab@forum.dlang.org
[SuccessType]: https://forum.dlang.org/thread/apphidjekselhhctclgr@forum.dlang.org#post-fttcdxppydmkvusmrdgh:40forum.dlang.org

## Copyright & License
Copyright (c) 2020 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## Reviews
The DIP Manager will supplement this section with a summary of each review stage
of the DIP process beyond the Draft Review.

