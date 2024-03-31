# Symbol Representation

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            |                                                                 |
| Author:         | Richard (Rikki) Andrew Cattermole (firstname@lastname.co.nz)    |
| Implementation: |                                                                 |
| Status:         | Draft                                                           |

## Abstract

Symbols are the ultimate representation of any native programming language language features. When they are not represented correctly at either the compiler level or language level, things fail to link. This has some serious potential to cause frustration on a level that abandons all hope of a solution working. The purpose of this DIP is to remove common failings that will cause D to not link against and as a shared library on a multitude of platforms and targets.

## Contents
* [Rationale](#rationale)
* [Prior Work](#prior-work)
* [Description](#description)
* [Breaking Changes and Deprecations](#breaking-changes-and-deprecations)
* [Reference](#reference)
* [Glossary](#glossary)
* [Copyright & License](#copyright--license)
* [Reviews](#reviews)

## Rationale

Common use cases not being supported nor workaroundable can be quite frustrating to D users.
Linker errors for those who have not studied linkers can be quite challenging to attempt an understanding of.
With frequent request for help from those that reach them.

A lot of problems with symbol representation can be silently hidden to D users when you only support static libraries and an executable for constructing a process containing D.
However this is not the only configuration that people want or need their binaries to be built as.

Plugins into D, D plugin into another language, replacable binaries are all examples of use cases for where someone may wish to use shared libraries that involve D.

To make D work consistently and easily with a clear story for the user to understand, how symbols are represented in the language must be improved.

The main consideration is to start at the module.
If we know if the module is in the current binary, or outside of it, we can resolve a number of linker issues by default without any further modification.
All other changes can come from this knowledge.

## Prior Work

In 2016 Benjamin Thaut did a talk at DConf [D's Import and Export Business](https://www.youtube.com/watch?v=-vEmOc-WphY) which covered a proposal for improving the language and the implementation details of export and shared libraries.

This DIP, while not directly based upon it and does not touch upon the implementation details, does come to similar conclusions that ``export`` must not be a visibility modifier to make D work when using positive annotation.

A key difference is that Benjamin's talk suggested that ``dllimport`` switch set to all was a good solution of specifying that a symbol is in DllImport mode.
However after many years experience with D and shared libraries, it has been shown in the community usage that this is a source of constant linker errors and so a solution that is finer grained is required.

## Description

### Cornerstone Changes

This section introduces crucial changes for future updates and ensures error-free compilation.

1. External Import Path Switch: A new flag ``-extI`` is added, similar to the ``-I`` switch, marking modules as external to the currently compiling binary. This should be automated by build managers using the knowledge of dependencies being shared libraries to automatically apply it instead of ``-I``.
2. Out-of-Binary Modules: For such modules, all non-templated scopes are interpreted to implicitly have ``extern`` attribute applied to them.
3. Symbol Import: To import a symbol in DllImport mode, use both ``export`` and ``extern``. The function body's status is irrelevant.

In the following sections, the reliability of templates is considered for linking against shared libraries, the D interface generator, different export annotations and inlining.

### Reliability of Templates

Templates are a very easy way to make builds fail to link, due to assumed template instantiations existing.

It is important therefore, that symbols originating from templates are by default not able to be exported or put into dllimport mode.
Instead they must be reinstantiated when they are seen to be outside the binary and placed into target binary with appropriate duplication flags set.
To do this, use the external import path switch flagging per module.

Any compiler that needs to minimize the amount of code generation it performs, may do so by applying a pinning approach.
A template instantiation is said to be pinned, iff it has been referenced by a non-templated symbol in the same module it was declared in.
This includes variable declarations (such as globals) that are not found under a template or function parameters and return types.

Once a template and its symbols has been pinned, the compiler may elide the code generation for these symbols when out of binary, and respect the exportation/dllimport symbol modes.

### D Interface Generator

The D interface generator is an exportation tool provided by the D compiler to omit symbol bodies and output a D file with the ``di`` file extension. It can be used in conjunction with the C parser (``ImportC``) to generate bindings to C libraries.

One area of failure that it currrently has is the incapability to respect symbols modes for exportation. To resolve this the following changes are required:

It must not introduce an ``extern`` attribute on a symbol, but may introduce ``export`` to all non-templated scopes iff the visibility override switch is set to export that module.

This change pairs with the cornerstone changes presented above so that:

1. Given a code base marked with export
2. The ``.di`` generator will not add ``extern`` in addition to what was in the original source
3. Can be passed to the import path switch ``-I`` for a static library or object file
4. Or be passed to the external import path switch ``-extI`` for a shared library dependency

### Symbol Exportation Mode Approaches

Each symbol can be in different symbol modes. These are internal, DllExport and DllImport. An internal symbol is the default symbol mode, it may be accessed by other symbols in the same binary regardless of the module it is defined in. DllExport set that a symbol while compiling should also be accessible to other external binaries. DllImport will intruct the compiler to that a symbol is external to the binary and must have different code generated so that it may be accessed at runtime.

Different strategies for describing how to select DllImport and internal modes, along with DllExport are presented next. These are:

- Positive notation using ``export``. This is the default behavior of a D compiler.
- Negative notation using visibility override switch. By default all symbols are not exported. You can use the visibility override switch to force all symbols to be exported instead. This allows for libraries that are not currently marked with ``export`` to export their symbols.
- Lastly a corner case notation for when you need to determine if a symbol is internal or DllImport depending on build step. Useful for multi-step builds where interesting or conflicting symbols modes are present.

#### Export Annotation

The ``export`` attribute is given an identifier parameter which is interpreted to be a version.

```diff
VisibilityAttribute:
-   export

Attribute:
+   export
+   export ( Identifier )
```

This parameter when the identifier is active (specified by ``-version=ident``) places the symbol when not compiling into internal mode.

When not active it places it into DllImport mode as if ``extern`` was also annotated.

To standardise the identifiers in use, three new prefixes are added to the specification, each will have instances for libc, druntime and Phobos that will be provided by the compiler automatically.

The prefixes are ``Have_``, ``InBinary_``, and ``Compiling_``. The suffixes for these three will be a logical package.

- ``Have_`` is used when a given logical package is available as a dependency during linking.
- ``InBinary_`` is used when a given logical package has its symbols in the currently compiling binary.
- ``Compiling_`` is used when a given logical package is currently being compiled.

Between these three versions it is possible to cover any corner case where a symbol must be viewed internally instead of out of binary.

The D interface generator will need to support the insertion of the version argument ``InBinary_``. This will be needed to accurately represent C files by a D module. The mechanism to specify what the suffix is, is not determined here. It may depend upon C preprocessor capability.

#### Positive Notation

To assign a symbol that it is exported, use the ``export`` attribute to annotate a D symbol as DllExport.

The export annotation must not be a visibility modifier.
If it is a visibility modifier you are required to expose internal implementation details that could result in unsafe operation of a codebase by external parties at the language level.

For a given encapsulation unit (struct, class, union, module), if any members are marked export, then all generated symbols (``TypeInfo``, ``__initZ``, ``opCmp`` ext.) but not ``ModuleInfo`` must also be exported. If generated symbols are not exported when an associated symbol is exported, it will result in linker errors that have no possible solution without the use of a linker script.

By default all symbols are hidden, if you need to explicitly annotate hidden use the UDA provided in ``core.attributes``.
Without this attribute you would have to annotate export on _every_ symbol that you want exported instead of at the scope and then disallow only the ones that are not desired.

#### Negative Notation

The visibility override switch is in use, set to export everything.

To annotate a symbol as hidden use the UDA provided in ``core.attributes``.

Until druntime and Phobos can be fully annotated with export appropriately and tested, this approach will be in use for these libraries.

### Inlining

Consider an out of binary module:

```d
pragma(inline, true)
export extern void inlineable() {
  noInline;
}

@hidden void noInline();
```

In this case, ``noInline`` function is not accessible to ``inlineable`` if it was inlined across binary lines. The result of this would be a linker error.

The compiler must not inline a function from an out of binary module if it refers to non-exported symbols.

### Use Cases

To demonstrate the different scenarios in which this DIP alters, a series of use cases are presented.
First the positive annotation case, which is a scenario you may experience if you need complete control over which symbols get exported.
The second use case demonstrates that you do not need to make any alterations related to the ``DllImport`` status of symbols to use druntime in binary.

#### Positive Annotation

This use case demonstrates positive annotating of ``export`` along with the optional ``.di`` generator.

It uses the Windows nomenclature of file extensions and what files are generated.
They are required to accurately describe what the DIP will result in, and will translate over to other platforms.

Directory layout:

```
dependency/source/library.d
dependency/imports/library.di
dependency/library.dll
dependency/library.lib
dependency/library.exp

executable/source/app.d
executable/app.exe
executable/library.dll
```

Source of ``dependency/source/library.d``:

```d
module library;

export void myLibraryFunction() {
    import std.stdio;
    writeln("Hello from my libraries function!");
}
```

Source of ``dependency/source/library.di`` once generated:

```d
module library;

export void myLibraryFunction();
```

Source of ``executable/source/app.d``:

```d
module app;

void main() {
    import library;
    myLibraryFunction();
}
```

Using shared libraries:

```sh
dmd -of=dependency/library.dll -shared -Hd=dependency/imports dependency/source/library.d
cp dependency/library.dll executable/library.dll

dmd -of=executable/app.exe -extI=dependency/imports executable/soruce/app.d dependency/library.lib
```

Using static libraries:

```sh
dmd -of=dependency/library.lib -Hd=dependency/imports dependency/source/library.d

dmd -of=executable/app.exe -I=dependency/imports executable/soruce/app.d dependency/library.lib
```

Note that the only differences between these two dmd invocations is the missing of ``-shared`` and swapping ``-extI`` to ``-I``.

#### Druntime in Binary

For this use case we consider what happens to place druntime into our resulting binary.
Other libraries such as Phobos are not considered and the switch to pick if druntime is static or shared is compiler specific, it is therefore only a demonstration of what it could look like. 

The use of the dependency while redundant in this particular example, is of real world interest and during the process of creating this DIP, this very scenario has been shown to be problematic currently.

Directory layout:

```
dependency/source/dependency.d
dependency/dependency.lib

mydll/source/api.d
mydll/mydll.dll
mydll/mydll.lib
mydll/mydll.exp
```

Source of ``dependency/source/dependency.d``:

```d
module dependency;

void myLibraryFunction() {
    foreach(m; ModuleInfo) {
        // any symbols that are non-templated will work for this example!
    }
}
```

Source of ``mydll/source/api.d``:

```d
module api;

export void api() {
    import dependency;
    myLibraryFunction();
}
```

Commands to compile it into a shared library, with an intermediary static library step for a dependency:

```sh
dmd -of=dependency/dependency.lib -lib -lib-druntime=static dependency/source/dependency.d
dmd -of=mydll/mydll.dll -shared -I=dependency/source -lib-druntime=static mydll/source/api.d dependency/dependency.lib
```

Of particular interest is what ``-lib-druntime=static`` is adding in addition to the provided arguments.

Typically, when you compile D source code today, it will automatically add some import path switches (``-I``) and some additional static/import libraries.
With this DIP, when you specify you want the shared version of druntime, instead of using ``-I`` and the static library version of druntime, it will provide the import paths via ``-extI``, druntime's import library, and add the ``-dllimport`` override switch set to ``externalOnly``.

This is of particular note for this use case, because typically when you use D shared libraries you will be using a shared druntime not the static one.
Because of the external import path switch, it is possible using the compiler configuration file to entirely hide the difference between a shared and static druntime. 
Currently, druntime is not annotated with export, if it was the addition of ``-dllimport=externalOnly`` would not be required and would not proliferate user code potentially resulting in an attempt to access a non-exported symbol by the linker instead of erroring at the compiler with a nice message.

This use case with this DIP will not result in any linker warnings such as [LNK4217](https://learn.microsoft.com/en-us/cpp/error-messages/tool-errors/linker-tools-warning-lnk4217?view=msvc-170) which is not currently the case.

## Breaking Changes and Deprecations

It is expected that any code that is currently marked with ``export`` could break the visibility of symbols, due to it no longer meaning super-public.

This can be mitigated by placing ``public:`` on preceding line and will work with previous compilers as well as future ones if the new behavior is not desirable.

Otherwise all changes are opt-in via the ``-extI`` compiler switch.

## Reference

In the C and C++ world, the choice to pick [DllExport](https://learn.microsoft.com/en-us/cpp/build/exporting-from-a-dll-using-declspec-dllexport?view=msvc-170) and [DllImport](https://learn.microsoft.com/en-us/cpp/build/importing-into-an-application-using-declspec-dllimport?view=msvc-170) is done via an attribute that gets swapped out by the macro preprocessor. This is tedious as it is something you must configure on a per library basis.

Rust uses an attribute called [link](https://doc.rust-lang.org/reference/items/external-blocks.html#the-link-attribute) - this attribute also includes the library name. It may be configured on the command line to switch the default symbol mode to another during compiling. In this DIP we introduce the version name convention of ``InBinary_`` for specifying if a package is in or out of binary, which fits the existing convention of ``Have_`` by dub and takes advantage of existing mechanics.

Ada (GNAT) supports [DllExport](https://gcc.gnu.org/onlinedocs/gcc-13.2.0/gnat_rm/Pragma-Export_005fFunction.html) via the use of a pragma to explicitly state that a symbol (with different ones per type) is exported. Same situation for [DllImport](https://gcc.gnu.org/onlinedocs/gcc-13.2.0/gnat_rm/Pragma-Import_005fFunction.html). It does not provide any mechanism for Ada only libraries to determine which pragma is in use. The creation of [bindings](https://docs.adacore.com/gnat_ugn-docs/html/gnat_ugn/gnat_ugn/platform_specific_information.html#using-dlls-with-gnat) is a complex endeavor in comparison to D. At the build tool level these appear to be mostly automatable for Ada projects.

# Glossary

Binary: An executable or shared library.

Object file: An intermediary file that contains compiled code that will be later used by a linker to produce a binary.

Out of binary: A symbol that is not located in the currently compiling binary. If set in DllExport mode and accessed via DllImport, it may be accessed the currently compiling binary at runtime.

## Copyright & License
Copyright (c) 2024 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## History
The DIP Manager will supplement this section with links to forum discsusionss and a summary of the formal assessment.