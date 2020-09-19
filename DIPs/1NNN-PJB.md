# @nodiscard

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | (number/id -- assigned by DIP Manager)                          |
| Review Count:   | 0 (edited by DIP Manager)                                       |
| Author:         | Paul Backus \<snarwin@gmail.com\>                               |
| Implementation: | <https://github.com/dlang/dmd/pull/11765>                       |
| Status:         | Will be set by the DIP manager (e.g. "Approved" or "Rejected")  |

## Abstract

Required.

Short and concise description of the idea in a few lines.


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
no side effects, including the return value of a `pure` function. Several
possible enhancements to this feature were discussed in the comments on [issue
3882](https://issues.dlang.org/show_bug.cgi?id=3882), and an enhancement
request for a `@nodiscard` attribute that would turn discarded return values
into errors was submitted as [issue 5464](https://issues.dlang.org/show_bug.cgi?id=5464).

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

### Syntax

`@nodiscard` is an [attribute][Attribute] that can be applied to individual
declarations, to a block (`@nodiscard { }`), or to all subsequent declarations
in the current scope (`@nodiscard:`).

`@nodiscard` is not a [type constructor][TypeCtor] or a [storage
class][StorageClass].

[Attribute]: https://dlang.org/spec/attribute.html
[TypeCtor]: https://dlang.org/spec/grammar.html#TypeCtor
[StorageClass]: https://dlang.org/spec/grammar.html#StorageClass

### Semantics

It is a compile-time error to discard an expression if:

* It is a call to a function whose declaration is annotated with `@nodiscard`.
* Its type is an [aggregate type][AggregateDeclaration] whose declaration is
  annotated with `@nodiscard`.

An expression is considered to be discarded if and only if:

* It is the top-level *Expression* in an *ExpressionStatement*.
* It is the *AssignExpression* on the left-hand side of a *CommaExpression*.

`@nodiscard` does not modify the type of any aggregate or function it is
applied to, and does not participate in name mangling.

`@nodiscard` does not apply to declarations inside the body of a `@nodiscard`
aggregate or function declaration.

`@nodiscard` has no effect on declarations other than aggregate and function
declarations.

[AggregateDeclaration]: https://dlang.org/spec/grammar.html#AggregateDeclaration

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
This section is not required if no breaking changes or deprecations are anticipated.

Provide a detailed analysis on how the proposed changes may affect existing
user code and a step-by-step explanation of the deprecation process which is
supposed to handle breakage in a non-intrusive manner. Changes that may break
user code and have no well-defined deprecation process have a minimal chance of
being approved.

## Reference
Optional links to reference material such as existing discussions, research papers
or any other supplementary materials.

## Copyright & License
Copyright (c) 2020 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## Reviews
The DIP Manager will supplement this section with a summary of each review stage
of the DIP process beyond the Draft Review.

