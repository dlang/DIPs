| Title:         | making export an attribute                                         |
|----------------|--------------------------------------------------------------------|
| DIP:           | 45                                                                 |
| Version:       | 3                                                                  |
| Status:        | Draft                                                              |
| Created:       | 2013-08-27                                                         |
| Last Modified: | 2017-01-30                                                         |
| Author:        | Benjamin Thaut, Martin Nowak, David Nadlinger                      |
| Links:         | <ul><li>[DConf 2016 Talk](https://youtu.be/MQRHxI2SrYM)</li><li>[DIP45: fixing the dllimport/dllexport issue](http://forum.dlang.org/post/kvhu2c$2ikq$1@digitalmars.com)</li><li>[Issue 9816 – Export is mostly broken](https://issues.dlang.org/show_bug.cgi?id=9816)</li>

Abstract
--------

Export and its behavior need to be changed in serveral ways to make it work on Windows and allow better code generation for other plattforms. The Rationale section explains the problems and shows how this DIP solves them.

Description
-----------

-   The **export** protection level should be turned into a **export** attribute.
-   **export** might appear in front of **module** to indicate that the implementation specific module symbols should be exported.
-   If a class is annotated with the 'export' attribute, all of its public and protected functions and members will automatically recieve the 'export' attribute. Also all its hidden compiler specific symbols will recieve the 'export' attribute.
-   There should be only one meaning of 'export'.
-   On \*nix systems default symbol visibility is changed to hidden, and only symbols marked with export become visible.

Rationale
---------

### Turning export into an attribute

Currently **export** is a protection level, the highest level of visibility actually. This however conflicts with the need to export 'protected' and 'private' symbols. Consider a Base class in a shared library.

``` D
module sharedLib;

class Base {
  protected final void doSomething() { ... }
}
```

``` D
module executable;
import sharedLib;

class Derived : Base {
  public void func()
  {
    doSomething();
  }
}
```

In the above example 'doSomething' should only be visible to derived classes but it still needs to be exportable from a shared library. Therefor **export** should become a normal attribute which behaves orthogonal to protection.

Also consider the following example in which the template will access a private function. Because the template is instanced on the user side and not within the shared library it is required to export the private function so that the template can access it from outside the shared library.

``` D
module dll;

void copy(T)(T val)
{
  copyImpl(&val, T.sizeof);
}

export private copyImpl(void* mem, size_t size)
{
  ...
}
```

``` D
module exe;
import dll;

void main(string[] args)
{
  int bar = 0;
  copy(bar); // template will be instanciated in the exe but needs access to the copyImpl function.
}
```

Another special case are voldemord types. If a voldemord type is used it needs to be exported explictily.

``` D
module lib;

export auto makeSomething(int v)
{
  export struct Something
  {
    int i;
  }

  return Something(v);
}
```

At first glance exporting a template doesn't make much sense. But consider the following example:

``` D
module lib;
import std.stdio;

export struct Foo(T)
{
  T value;
  void print() { writefln("%s", value); }
}

__gshared Foo!int g_inst = Foo!int(5);
```

``` D
module exe;
import lib;

void main(string[] args)
{
  auto f = Foo!int(5);
  f.print();
}
```

When compiling the executable module exe which uses the module lib compiled into a dll the compiler will attempt to reuse the instance of Foo!int from the lib module. This however only works if the instance has been exported from the dll. As a result exporting a tempalte should be equivalent to exporting any instance created from this template. In code:

``` D
export struct(T) { ... }

// is equivalent to
template (T)
{
  export struct { ... }
}
```

### Exporting module compiler internal symbols

Each D module has a set of compiler internal symbols which may be referenced. To allow for exporting these symbols **export** is allowed in front of **module** to indicate that the compiler internal symbols should be exported. Example:

``` D
 export module sharedLib;

void testSomething(T)(T val)
{
    assert(T.sizeof > 8);
}
```

Please note that in the above example there is not a single member of the module marked with **export**. But still it is required to export the compiler internal module symbols as the template will be instanciated on the user side of the shared library and thus will access the 'assert' module symbol. If the 'assert' module symbol is not exported this would lead to a linker error. The compiler internal module symbols should not be exported by default. Consider building a D-Dll with a pure C interface. In this case you don't want to export any compiler internal symbols as you want to have a very well defined C interface of your dll.

### export attribute inference

Currently export has to be specified in a lot of places to export all neccessary functions and data symbols. Export should be transitive for aggregate types (structs/classes) so that when exporting a aggregate type export is applied to all public & protected members without the need to add export to every single public and protected member.

``` D
module sharedLib;

export class A                          // compiler internal members should be exported (e.g. vtable, type info)
{
  private:
    int m_a;

    static int s_b;              // should not be exported

    void internalFunc() { ... }  // should not be exported

  protected:
    void interalFunc2() { ... }  // should be exported

  public:
    class Inner                  // compiler internal members should be exported
    {
      __gshared int s_inner;            // should be exported

      void innerMethod() { ... } // should be exported
    }

    void method() { ... }        // should be exported
}
```

### A single meaning of **export**

The classical solution to handle dllexport/dllimport attributes on Windows is to define a macro that depending on the current build setting expands to \_\_declspec(dllexport) or to \_\_declspec(dllimport). This complicates the build setup and means that object files for a static library can't be mixed well with object files for a DLL. Instead we propose that exported data definitions are accompanied with an \_imp\_ pointer and always accessed through them. See the implementation detail section for how this will work for [data symbols](#Data_Symbols "wikilink") and [function symbols](#Function_Symbols "wikilink"). That way a compiled object file can be used for a DLL or a static library. And vice versa an object file can be linked against an import library or a static library.

### Access TLS variables

Currently it is not possible to access TLS variables across shared library boundaries on Windows. This might be implemented in the future. (see [implementation details](#TLS_variables "wikilink") for a proposal).

### Change symbol visibility on \*nix systems

When building shared libraries on \*nix systems all symbols are visible by default. This is a main reason for the performance impact of PIC because every data access and every function call go through the GOT or PLT indirection. It also leads to long loading time because an excessive number of relocations have to be processed. Making all symbols hidden by default significantly reduces the size of the dynamic symbol table (faster lookup and smaller libraries). See <http://gcc.gnu.org/wiki/Visibility> and <http://people.redhat.com/drepper/dsohowto.pdf> for more details.

Also making every symbol accessible can inadvertently cause ABI dependencies making it harder to maintain libraries.

Furthermore, hiding functions by default enables much more aggressive compiler optimizations, to the benefit of both executable performance and code size. Some examples for this are elision of completely inlined functions, optimization of function signatures/calling conventions, partial inlining/constant propagation, … Some of these optimization opportunities also positively affect compile times, as evidenced by an experimental LDC patch (see [LDC \#483](https://github.com/ldc-developers/ldc/pull/483), although LTO is required to fully exploit this).

Implementation Details
----------------------

### Windows

#### Data Symbols

##### Accessing through code

For data symbols the 'export' attribute always means 'dllexport' when defining a symbol and 'dllimport' when accessing a symbol. That is accessing an exported variable is done through dereferencing it's corresponding import symbols. When defining an exported variable the compiler will emit a corresponding import symbol that is initialized with address of the variable. The import symbol can be located in the read only data segment. The mangling of the import symbol consists of the '\_imp\_'/'\_\_imp\_' (Win32/Win64) prefix followed by the mangled name of the variable. Import symbols itself are not exported. When an exported variable of the same module is accessed the compiler might avoid the indirection and perform a direct access.

``` D
module a;

export __gshared int var = 5;
__gshared int* _imp__D1a3vari = &var; // import symbol generated by the compiler

void func()
{
   var = 3; // accesses var directly, because in the same module
}
```

``` D
module b;
import a;

void bar()
{
    var = 5; // accesses through indirection because var is marked as export and in a different module
    // *_imp__D1a3vari = 5; // code generated by the compiler
}
```

##### Referencing in constant data

=

When referencing data symbols in the contents of some other data symbol there will be a additional level of indirection which needs to be removed during program startup.

``` D
module dll;

__gshared int var = 5;
```

``` D
module exe;
import dll;

__gshared int* pvar = &var; // address not known at compile time
```

As the address of var is not known at compile time so pvar will point to the entry in the import table for 'var'. At program startup, before any other D code runs, pvar will be dereferenced once. E.g. the following operation will be executed on pvar.

``` D
pvar = *cast(int**)pvar;
```

This removes the additional indirection added by the import table and correctly initializes the static memory for pvar. This might happen in various other cases, mostly when generating initializers, type infos, vtables, module infos and other static data the compiler produces.

#### Function Symbols

For function symbols the 'export' attribute always means 'dllexport' when defining a function and will be ignored when calling it. Calling an exported function is always done through the original symbol. In an import library the original symbol is defined as trampoline that simply calls the dereferenced \_imp\_ pointer. Thus calling an exported function will be compatible with both import libraries and static libraries, in the later case without indirection.

``` D
module a;

export void func()
{
}

void bar()
{
    func(); // call func; // directly
}
```

``` D
module b;
import a;

void bar()
{
    func(); // call func; // through trampoline
}

// definitions in the import library generated by implib
void func()
{
    asm
    {
        naked;
        jmp [_imp_func];
    }
}
void function() _imp_func = &func; // filled at runtime with the DLL address of func
```

#### TLS variables

Note: This is not implemented at the moment.

For each exported TLS variable the compiler should generate a function that returns the address of the TLS variable in the current thread. These internal methods should have some kind of unified prefix to mark them as TLS import helpers. I propose "\_\_tlsstub\_". These internal methods are also exported. So when accessing an exported TLS variable the compiler will insert a call to '\_imp\_\_D1a15\_\_tlsstub\_g\_tlsFZPi' instead. As an optimization accesses to exported TLS variables within the same module can be performed directly.

``` D
module a;

export int g_tls = 5; // thread local storage

export int* __tlsstub__g_tls() // generated by the compiler
{
    return &g_tls;
}
alias _imp___tlsstub__g_tls = __tlsstub__g_tls; // also generated by the compiler

void func()
{
    g_tls = 3; // direct access because marked as export and in the same module
}
```

``` D
module b;
import a;

void bar()
{
    g_tls = 10; // access through _imp___tlsstub__g_tls function because marked as export and in a different module
    // *_imp___tlsstub__g_tls() = 10; // code generated by the compiler
}
```

### \*nix

Note: This is not yet implemented.

On \*nix systems the default symbols visibility should be changed to hidden, i.e. -fvisibility=hidden argument of gcc. Only symbols marked with **export** should get the attribute visible.

This is trivial to implement on GDC and LDC.

### Linking archives into shared libraries

When linking archives into shared libraries the exported symbols from the archive will also be exported from the resulting shared library. Most often this is unwanted and may lead to inadvertent ABI dependencies. To accomplish this we'll provide a tool that strips export attributes from archives.

Copyright
---------

This document has been placed in the Public Domain.
