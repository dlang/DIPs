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
 * [Problem 2: override clash](#problem-2-clash-of-overriden-methods)
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
least some risk of breaking user code. Existing `deprecated` keyword is only
applicable for removing symbols, not for adding new ones.

For many libraries these problems are of very low importance as normally
projects upgrading their dependencies to new feature release are expected to do
some minor maintenance effort.

However, there are also certain libraries that set an extremely high stability
expectations, with most notable example being [druntime](https://github.com/dlang/druntime),
D standard runtime library. Even very minor breakage coming from such project
can affect many users and is likely to come unexpected.

### Links

* https://dlang.org/spec/function.html#overload-sets

## Description

### Problem 1: import clash

Consider maintaining a simple library, `foo`, which was released with the
following code:

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

Now the maintainer of the library adds a new feature to the same library:

```D
module foo;
void someFunction () {}
void someOtherFunction () {}
```

Surprisingly, the addition may break (render uncompilable) an existing project
if it was already using another library which defined a function with the same
name:

```D
void main ()
{
    import foo;
    import bar; // defined `someOtherFunction` before it was present in foo
    someFunction();
    someOtherFunction(); // after upgrading foo, symbols will clash here
}
```
### Problem 2: clash of overriden methods

Consider another simple library, `baz`, which defines some class:

```D
class Base
{
}
```

At some point the maintainer of the library wants to add a new method to this
class, `void method()`, but doing so risks breaking user code too:

```D
class Derived : Base
{
    void method(bool) { }
}
```

If a method with the same name was already present in derived class, it will not
compile because of either missing `override` keyword (if the signatures are
compatible) or attempt on non-covariant override (if the signatures are
unrelated).

### Existing solutions

There are few existing approaches to reduce the negative impact of adding new
symbols:

#### Using a more obscure name

The most common approach is to simply pick names that are less likely to be
already used in downstream projects. It is a simple and practical solution that
doesn't require any language support but has obvious scalability issues:

- Results in unnecessarily baroque names, harming the learning curve
- Picking unused names becomes harder as the number of downstream projects grows
- Adding a new symbol has high chance of being blocked on naming debates

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
- Can't be use to solve [Problem 2](#problem-2-clash-of-overriden-methods)

#### Deprecations

Contrary to adding a new symbol, removing or renaming one is a much easier task
because D supports the `deprecated` keyword, ensuring that library users
will get early notification about to-be-removed symbol before it is actually
gone.

Similar warnings should also be suitable for adding new symbols to critical
libraries but the language currently lacks a way to express such semantics.

### Proposal

This document proposes the introduction of new symbol kind concept into
compiler, *future symbol*. In terms of DMD compiler internals it can be defined
simply as an additional Boolean field added to `DSymbol` indicating if the
symbol is *future* or not.

To make examples more readable, imaginary `@future` attribute may be used to
mark such symbols, for example `@future void foo()`. However introducing such an
attribute (or any other) is NOT part of the proposal and serves only
illustration purposes.

Symbols marked as *future* must have special treatment during semantic analysis:

1. Whenever the compiler performs a symbol lookup, if has to check if *future
   symbol* is present in the result. If present, deprecation message shall be
   printed and everything else should continue as if it wasn't present.

   ```D
   import moda; // provides foo
   import modb; // provides @future foo

   foo(); // Deprecation: upcoming adddition of modb.foo will result in a symbol
          // clash, please disambugate
   ```

2. Whenever compiler has to check for the presence of a symbol, if there is a match
   which is *future symbol*, deprecation message has to be printed and
   everything else should continue as if the respective declaration wasn't present.

   ```D
   class A
   {
       void foo() @future;
   }

   class B
   {
       void foo(); // Deprecation: upcoming addition of A.foo will result in a
                   // symbol clash, please adjust
   }
   ```

3. References to *future symbol* within the module it is declared in should not
   result in any deprecation messages because the module can be adjusted at the
   same time symbol is actually added.

   ```D
   void foo (long a);
   void foo (int a) @future;

   foo(42); // No point in printing deprecation here as it will keep compiling
            // even when @future is removed
   ```

4. Any form of static reflection that provides a sequence of results, for example
   `__traits(allMembers)` or `.tupleof`, shall ignore any *future symbol*
   completely. Such code does not normally rely on the presence of any specific
   symbol and thus addition of a new one is unlikely to cause problems. On the
   other hand, deprecation warning issues from such contexts cannot be addressed
   by adjusting client code.

5. Any form of static reflection that implies access to a specific symbol,
   for example, `__traits(getMember)`, should still print the deprecation
   message.

As a first implementation step, this functionality should only be available as a
hard list of symbols built into compiler itself and reserved for druntime
usage. See [breaking changes section](#breaking-changes--deprecation-process)
for a detailed rationale.

Once the concept is proved with druntime, it should be proposed as an actual
language feature - by either updating this DIP or proposing new
one. For example, one can simply expose it with a new attribute called `@future`.

### Rationale

1. Currently there is no way to warn users of a library about planned addition
   of new symbols.
2. Existing workarounds don't eliminate risk of breakage completely and all
   have various practical drawbacks.
3. Described problems make it difficult to add new symbols to
   `object.d` because it is implicitly imported in all D modules of all D
   projects, increasing the chance of name clashes as the D userbase grows.
4. The proposed change is not deemed of high importance for many D
   projects. Instead, it is proposed on the basis of being very important for
   few that are in heavy use, making most of its impact indirectly.
5. Having a simple and reliable way to add new symbols to runtime will reduce
   the amount of time spent in naming debates and improve the readability of
   resulting APIs.
6. Making new functionality available only to compiler developers initially will
   make it possible to adjust semantics or even completely revert the feature
   based on practical experience - without any risk that it will affect other
   users of the feature.

As an extra benefit, such a facility can provide a deprecation path for
introducing new language keywords if the need arises, though this use case is
beyond the scope of this DIP and won't be evaluated in detail.

### Comparison against other languages

Existing programming languages can be separated in 3 main groups with regard
to this issue:

#### With single global namespace

Examples: C, early PHP

Such languages tend to rely on [using obscure names](#using-more-obscure-name)
that makes symbol clash less likely but in general the problem is still present.
When the problem manifests, situation becomes much worse than in D, because such
languages lack tools to disambiguate name clash explicitly.

#### With namespaces, allowing non-qualified access

Examples: C++, C#

This category is most similar to D, meaning that the language provides tools to
disambiguate any names but at the same time allows imports with non-qualified
access to imported symbols.

In D this is default `import` behavior.

In C++ : `using namespace Namespace.Subnamespace`.

In C# : `using Namespace.Subnamespace`

The importance of problem varies depending on the prevalent idioms used in the
language and other available tools. For example, C# documentation
[recommends](https://msdn.microsoft.com/en-us/library/dfb3cx8s.aspx) using
dedicated namespace access operator `::` instead of uniform `.` to reduce the
risk of clashes.

However, there are a few aspects specific to D that make issues somewhat more
important:

- In all mentioned languages but D, a common convention is to
  only use unqualified access for symbols in standard library. In D plain
  `import` is the most widespread way to use all libraries, including the dub
  registry.
- The D runtime features the module `object.d` which is implicitly imported
  everywhere, greatly increasing chance for name clashes for any symbol in it.

#### With namespaces, restricted non-qualified access

Examples: Rust, Go

In both Rust and Go normal imports still require using module name for
qualification. For example, in Rust `use Namespace::Subnamespace::Module` still
requires to explicitly write `Module::foo()` to call `foo` function.

Both languages provide a way to enable unqualified access (`import . "Module"`
in Go, `use Namespace::Module::*` in Rust) but this feature is heavily
discouraged from usage in production projects exactly because of the problems
described in this DIP.

Using qualified lookuos consistently solves the issue described in this DIP but
such an approach is too different to established idiomatic D coding style to be
considered.

### Breaking changes / deprecation process

The proposed semantics are purely additive and do not affect existing code.
However, this DIP is likely to cause bugs during initial implementation because
symbol resolution in D is non-trivial.

Because of that, the intended implementation approach is to initially introduce
the proposed concept as a feature internal to compiler and use for druntime symbols
only. Otherwise there is a certain chance of releasing feature with bugs in
symbol resolution semantics, which will become relied upon and widely used as
a feature. If that happens, it will be much more difficult to fix the
implementation to act as intended.

Once the implementation is confirmed to be working, adding actual syntax support
is a trivial task unlikely to cause subsequent bugs.

### Examples

This proposal comes from Sociomantic's attempt to enhance the definition of
`Throwable` in druntime to match internal changes:
https://github.com/dlang/druntime/pull/1445

The change itself was trivial (adding one new method to `Throwable` class) but
has resulted in at least [one reported
regression](https://issues.dlang.org/show_bug.cgi?id=15555) because of the
override clash problem.

With the change proposed in this document it will become possible to add such
method by initially marking it as *future symbol* in one DMD release and
actually adding new method in the release after.

## Copyright & License

Copyright (c) 2017 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)
