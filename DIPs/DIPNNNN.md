# "future symbol" compiler concept

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | NNNN                                                            |
| RC#             | 0                                                               |
| Author:         | Mihails Strasuns (public@dicebot.lv)                            |
| Status:         | Draft                                                           |

* [Abstract](#abstract)
 * [Links](#links)
* [Description](#description)
 * [Problem 1: import clash](#problem-1-import-clash)
 * [Problem 2: override clash](#problem-2-override-clash)
 * [Existing solutions](#existing-solutions)
    * [Using more obscure name](#using-more-obscure-name)
    * [Emulating namespaces](#emulating-namespaces)
    * [Deprecations](#deprecations)
 * [Proposal](#proposal)
 * [Rationale](#rationale)
 * [Comparison against other languages](#comparison-against-other-languages)
 * [Breaking changes / deprecation process](#breaking-changes--deprecation-process)
 * [Examples](#examples)
* [Copyright &amp; License](#copyright--license)

## Abstract

It is currently not possible to introduce new symbols to D libraries without at
least some risk of breaking user code. This is more important concern for
libraries with increased stability requirements like druntime. Existing
`deprecated` keyword is only applicable for removing symbols, not adding new
ones.

This document proposes possible new language semantics to enable solving the
problem for those who find it important.

## Description

### Problem 1: import clash

Consider maintaining simple library, `foo`, which was released with following
code:

```D
module foo;
void someFunction () {}
```

It get widely used, with a typical import pattern looking like this:

```D
void main ()
{
    import foo;
    someFunction();
}
```

Now maintainer of the library adds a new feature to the same library:

```D
module foo;
void someFunction () {}
void someOtherFunction () {}
```

Surprisingly, it may break existing project if it was already using another
library defining same function:

```D
void main ()
{
    import foo;
    import bar; // defined `someOtherFunction` before it was present in foo
    someFunction();
    someOtherFunction(); // after upgrading foo, symbols will clash here
}
```
### Problem 2: override clash

Consider another simple library, `baz`, which defines some class:

```D
class Base
{
}
```

At some point maintainer of the library wants to add a new method to this
class, `void method()`, but doing so risks breaking user code too:

```D
class Derived : Base
{
    void method(bool) { }
}
```

If method with same name was already present in derived class, it will error out
because of either missing `override` keyword or attempt on non-covariant override.

### Existing solutions

For many libraries both mentioned problems are of very low importance. These are
widely known properties of D symbol resolution and normally projects upgrading
their dependencies to new feature release do expect some minor maintenance
effort.

However, there are also certain libraries that set an extremely high stability
expectations, with most notable example being [druntime](https://github.com/dlang/druntime),
D standard runtime library. Even very minor breakage coming from such project
can affect many users and is likely to come unexpected.

In such projects, there are few existing approaches to reduce the negative
impact of adding new symbols:

#### Using more obscure name

Most common approach is to simply pick names that are less likely to be already
used in downstream projects. It is simple and practical solution that doesn't
require any language support but it has obvious scalability issues:

- Results in unnecessarily baroque names, harming learning curve
- Picking unused names becomes harder as amount of downstream projects grow
- Adding new symbol has high chance of being blocked on naming debate

#### Emulating namespaces

Another form of name obfuscation is using "namespace" aggregates:

```D
final abstract class Foo
{
    static:

    void foo() {};
}
```

It makes naming clashes even less likely and resulting names more obvious
but suffers from different important issues:

- Can't be used for new symbols only, fundamental library API design decision
- Does not leverage D module system
- Can't be use to solve [Problem 2](#problem-2-override-clash)

#### Deprecations

Contrary to adding new symbol, removing or renaming one is much easier task
because D supports `deprecated` keyword, ensuring that users of the library
will get early notification about to-be-removed symbol before it is actually
gone.

Similar warning should also be suitable for adding new symbols in critical
libraries but language currently lack a way to express such semantics.

### Proposal

Introduce new symbol kind concept into compiler, *future symbol*. This term does
not refer to any language syntax and is intended to represent new concept in
compiler internals. It has to have special treatment during semantic analysis:

1. If any symbol resolution ends up in *future symbol* being present among
   valid candidates, deprecation message has to be printed and symbol
   resolution continues after that as if it didn't exist.
2. Any form of static reflection, for example `__traits(allMembers)`, has to
   ignore any *future symbol* completely.
3. Detecting both *future symbol* and normal symbol with the same name at the
   same time must result in compilation error.

As first implementation step this functionality should only be available as a
hard list of symbols built into compiler itself and reserved for druntime
usage. See [breaking changes section](#breaking-changes--deprecation-process)
for detailed reasoning.

Once concept proves itself with druntime, it should be proposed as an actual
language feature for mass usage - by either updating this DIP or proposing new
one.

### Rationale

1. Currently there is no way to warn users of a library about planned addition
   of new symbol.
2. Existing workarounds don't eliminate risk of breakage completely and all
   suffer from some practical drawbacks.
3. Described problems make it very hard to add new symbols to
   `object.d` because it is implicitly imported in all D module of all D
   projects, increasing the chance of name clash as D userbase grows.
4. Proposed change is not argued to be of notable importance for many D
   projects. Instead, it is proposed on the basis of being very important for
   few most widely used one, making most of its impact transitively.
5. Having simple and reliable way to add new symbols to runtime will reduce
   amount of time spent in naming debates and improve readability of resulting
   APIs.
6. Attempt to introduce proposed functionality is not a one way ticket because
   it is intended to not be exposed for public usage initially and thus can
   be judged (and possibly reverted) again when the time comes.

As an extra benefit, such facility can provide a deprecation path for
introducing new language keywords if the need arises, though this use case is
beyond the scope of this DIP and won't be evaluated in details.

### Comparison against other languages

Existing programming languages can be separated in 3 main groups in regards
of this issue:

#### With single global namespace

Examples: C, early PHP

Such languages tend to rely on [using obscure names](#using-more-obscure-name)
that makes symbol clash less likely but in general problem is still present.
When the problem manifests, situation becomes much worse than in D, because such
languages lack tools to disambiguate name clash explicitly.

#### With namespaces, allowing non-qualified access

Examples: C++, C#

This category is most simple to D, meaning that language provides tools to
disambiguate any names but at the same time allows imports with non-qualified
access to imported symbols.

In D this is default `import` behavior.

In C++ : `using namespace Namespace.Subnamespace`.

In C# : `using Namespace.Subnamespace`

Importance of problem varies depending on idiomatic code style dominant for the
language and other available tools. For example, C# documentation
[recommends](https://msdn.microsoft.com/en-us/library/dfb3cx8s.aspx) using
dedicated namespace access operator `::` instead of uniform `.` to reduce the
risk of clashes.

However, there are few D specifics that make issues somewhat more important:

- In all mentioned languages but D it is common convention to
  only use unqualified access for symbols in standard library. In D plain
  `import` is most widespread way to use all libraries, including dub registry.
- D runtime features module `object.d` which is implicitly imported everywhere,
  greatly increasing chance for name clash for any symbol in it.

#### With namespaces, restricted non-qualified access

Examples: Rust, Go

In both Rust and Go normal imports still require using module name for
qualification. For example, in Rust `use Namespace::Subnamespace::Module` still
requires to explicitly write `Module::foo()` to call `foo` function.

Both languages provide a way to enable unqualified access (`import . "Module"`
in Go, `use Namespace::Module::*` in Rust) but this feature is heavily
discouraged from usage in production projects exactly because of problems
described in this DIP.

This completely solves the issue described in this DIP but is too different
to established idiomatic D coding style to be considered.

### Breaking changes / deprecation process

Proposed semantics are purely additive and can't affect existing code. However,
this DIP expects high chance of introducing bugs during initial implementation
because symbol resolution in D is non-trivial.

Because of that, intended implementation approach is to initially introduce
proposed concept as a feature internal to compiler and use for druntime symbols
only. Otherwise there is a certain chance of releasing feature with bug in
symbol resolution semantics which will become relied upon and widely used as
a feature, preventing from easily fixing to act as intended later.

Once implementation is confirmed to be solid, adding actual syntax support is
much more trivial and less bug-prone task.

### Examples

This proposal comes from Sociomantic attempt to enhance `Throwable` definition
in druntime to match internal changes:
https://github.com/dlang/druntime/pull/1445

The change itself was trivial (adding one new method to `Throwable` class) but
has resulted in at least [one reported
regression](https://issues.dlang.org/show_bug.cgi?id=15555) because of the
override clash problem.

With the change proposed in this document it will become possible to add such
method by initially marking it as *future symbol* in one DMD release and
actually adding new method in the release after.

## Copyright & License

Copyright (c) 2016 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)
