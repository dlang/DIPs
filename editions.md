# Editions: breaking changes to the language that don't break anything.

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | (number/id -- assigned by DIP Manager)                          |
| Review Count:   | 0 (edited by DIP Manager)                                       |
| Author:         | Átila Neves (atila dot neves at gmail)                          |
| Implementation: | (links to implementation PR if any)                             |
| Status:         | Draft                                                           |

## Abstract

A way for the language to evolve and correct mistakes of the past with
breaking changes that does not affect code that has already been
written.


## Contents
* [Rationale](#rationale)
* [Prior Work](#prior-work)
* [Description](#description)
* [Breaking Changes and Deprecations](#breaking-changes-and-deprecations)
* [Reference](#reference)
* [Copyright & License](#copyright--license)
* [Reviews](#reviews)

## Rationale

Although D was written as a language that had learned the mistakes
made by other languages, it of course ended up making a few of its
own. There are many things that we would like to change about the
language but are not allowed to given the likelihood, or in some cases
the certainty, that existing code will no longer compiler. Worse still
is code that compiles under the new language rules but that behaves
differently.

In order to not be limited by the decisions of the past and only be
able to make additive changes to the language, this document proposes
a mechanism to make breaking changes that would only apply to code
that *has not yet been written*. In this way the language can evolve
and become simpler while catering to the existing D codebases out
there.


## Prior Work

[Rust editions](https://rust-lang.github.io/rfcs/2052-epochs.html).
[Epochs in C++](https://www.open-std.org/jtc1/sc22/wg21/docs/papers/2019/p1881r0.html).


## Description
A D *edition* is a set of changes to the D programming language
defined by the D Language Foundation. These changes are allowed to be
breaking changes in the sense that they would, if applied, be able to
cause existing D code that compiles to no longer do so, or change its
semantics should it still compile. In order to be able to try out
individual changes that make up an edition, each one of them would be
implemented already and gated behind a `-preview=` flag in the
compiler. After giving these changes time to mature, an edition would
be defined as a set of approved preview flags that have proven
themselves to be useful.

This DIP proposes that D modules be able to optionally declare a D
edition that they target. Existing modules without this optional
declaration but that have a module declaration are considered to
target the current original edition. That is: they will be compiled as
if the editions feature did not exist. Modules without a module
declaration would be considered to be using the latest edition unless
the default edition is specified explicitly with a command line
argument.

Modules that opt-in to an edition will be compiled as if the compiler
had been invoked with the set of preview flags of the edition.

Opting in to an edition is part of the module declaration:

```Grammar
ModuleDeclaration:
    ModuleAttributes(opt) module ModuleFullyQualifiedName Edition(opt);
Edition:
    DecimalInteger
```

To aid in transitioning existing code to a new edition, it will also
be possible to change the default edition being used with a compiler
flag such as `-edition=2024`. This would only affect modules that have
a module declaration but no edition.

Another compiler switch to aid transitioning that this DIP recommends
is a `-E` switch which would function like `-I` for imports but would
allow the user to specify what the edition should be for those
imports.

This DIP proposes that editions can only be officially released,
i.e. finalised, when druntime and phobos can be transitioned to it.

The feature is meant to be backwards and forwards compatible: D
modules of different editions should be able to import each other.
Templates would obey the rules of the edition of the module they
are defined in, not the module where they are instantiated.

What could editions do?

### Deleting existing features

This would be the easiest change that could be made in D editions,
since it would forbid D code written in the future from using features
considered to be deprecated. Besides keeping the frontend code for
those features, there would be no impact.

### Adding new features

Editions are not necessary for adding new features that do not
interact with existing ones. This document does not propose excluding
prior editions and in fact encourages said features to be back ported
to them where possible.

### Changing defaults

Defaults matter since they encourage and nudge behaviour. Newer editions
could change defaults such as `@system`/`@safe` and others.

### Changing semantics

An edition could make it so that:

```d
shared int i;
i += 5;
```

would be lowered to:

```d
shared int i;
i.atomicOp!"+="(1);
```

## Examples

The following are examples of what editions could achieve, but this
DIP is not arguing for or against any one of them.

### `@safe` by default

There was an
[attempt](https://github.com/dlang/DIPs/blob/master/DIPs/rejected/DIP1028.md)
to make `@safe` the default that failed. It is likely that problems
would have been found in its implementation had it succeeded, since
all current D code assumes that `@system` is the default unless
inferred. Making this change in an edition would side-step that issue.

### `private` by default

The default is currently `public`, which makes it easier to write
short scripts and requires less typing. Experience has shown however
that in larger codebases it encourages client code to depend on what
should have been implementation details and makes refactoring more
cumbersome. Defaults matter, and changing the default to `private`
would result in less coupled, more maintainable code.

### No exceptions

An edition could replace exception handling with an alternative way
of dealing with errors such as sum types.

### No more `lazy`

The `lazy` feature complicates the language and the compiler for
little benefit: users can use an explicit lambda instead.

### No more `alias this`

`alias this` can be used with classes to implement multiple inheritance,
which the language otherwise expressly forbids. A future edition could
remove this feature.

### Change class ABI (monitor) and/or hierarchy

An edition could change the ABI of classes in D, possibly removing the
monitor. Alternatively, it could introduce a new base class of
`Object` as has been proposed before.


## Drawbacks and possible issues

### Compiler complexity

While this feature will simplify D code yet to be written, it will
make the compiler more complicated by having to be able to deal with
every different edition of the language. One possibly way to bound
this complexity could be to only support the last N editions, for
N < 5.


### Would editions mean splitting the language into different dialects?

In short, no. It can be argued that this is the current situation with
preview switches, in that their existence has already divided the
language into 2^N dialects, with N being the number of switches that
can be turned on. Edition would actually improve the situation by
presenting a monotonic sequence of language features and changes
without providing the opportunity of cherry-picking which ones a user
wants.


## Breaking Changes and Deprecations

The editions feature is explicitly designed with the goal of not
introducing any breaking changes or deprecations. Existing D code that
does not opt-in will continue to compile as behave as before.

Opting in, however, can make the code no longer compile, and that is a
choice to be made by the programmer in question. It is hoped that tooling
can be written to aid in this process.


## Reference

Optional links to reference material such as existing discussions,
research papers or any other supplementary materials.


## Copyright & License

Copyright (c) 2024 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)


## Reviews

The DIP Manager will supplement this section with a summary of each review stage
of the DIP process beyond the Draft Review.
