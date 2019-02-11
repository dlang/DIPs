# C++ Const Mangling

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | (number/id -- assigned by DIP Manager)                          |
| Review Count:   | 0 (edited by DIP Manager)                                       |
| Author:         | look-at-me                                                      |
| Implementation: | (links to implementation PR if any)                             |
| Status:         | Draft                                                           |

## Abstract

Implementing a new mangle feature to more easily link with C++ which contain `const` pointers to mutable data.

### Reference

[core.stdcpp.allocator Implementation Workaround](https://github.com/dlang/druntime/blob/bc940316b4cd7cf6a76e34b7396de2003867fbef/src/core/stdcpp/allocator.d#L50)

## Contents
* [Rationale](#rationale)
* [Description](#description)
* [Workarounds](#workarounds)
* [Breaking Changes and Deprecations](#breaking-changes-and-deprecations)
* [Copyright & License](#copyright--license)
* [Reviews](#reviews)

## Rationale

As it stands currently D does not allow `const` pointers to mutable data but this is allowed in C++. When trying to link to a C++ symbol that contains this type it can be difficult to do so as D has no way to express this type for use in mangling. This will ease linking with any C++ library that makes use of `const` pointers to mutable data, including the current efforts in DRuntime for `core.stdcpp`.

## Description

This DIP proposes to allow for `const` to be applied to only the pointer and not the type the pointer points to when a symbol is `extern(C++)`. This is in regards to C++ mangling only. This DIP does *not* propose to implement the actual functionality of a `const` pointer to a mutable type.

```D
extern(C++) void foo( char const* ptr );
```

This syntax would keep in line with D's implementation of `const` with the limitation of requiring the use of brackets `const(*)` which will apply `const` to the specified pointers. In the following example if there is a pointer to a pointer and `const` is applied to the first pointer. Both pointers will be const and will point to a mutable type.

```D
extern(C++) void foo1( char const(**) ptr );  // mangle to equivalent C++ char *const *const
extern(C++) void foo2( char const(*)* ptr );  // mangle to equivalent C++ char *const *
extern(C++) void foo3( char const(**)* ptr ); // mangle to equivalent C++ char *const *const *
```

The underlying type will be assigned the most closely equvalent D type. Effectively removing any `const` past the first mutable pointer or type.

```D
extern(C++) const(char*)* const(*) p1; // typeof(p1) == const(char*)**
extern(C++) char** const(*)        p2; // typeof(p2) == char***
extern(C++) char const(***)        p3; // typeof(p2) == char***
```
The tail const will also be allowed to exist to be able to link with C++ templates correctly when the same type is passed through as an argument to the template. For C++ when `const` is applied to a templated type, it is applied like so `T const` where `T` is the templated type. This means the `const` is applied in the exact same manor when `T` is substituted for the actual type.

```C++
template<typename T> void foo( const T ); // equivalent to `T const`
foo<char*>( nullptr );                    // foo( char* const )
```

In the above example when the type `char*` is passed to the template. The function's parameter is assigned the type of `char* const`. But for equivalent D code when using a `const` in such a manner the entire type will be assigned `const`.

```D
extern(C++) void foo(T)( const T );
foo!(char*)( null );                // foo( const(char*) )
```

To maintain backwards compatiblity but to also be able to mangle correctly with C++ in these instances when using `const` with a template. Using a tail `const` will be applied to only to the tail end of the type.

```D
extern(C++) void foo(T)( T const );
foo!(char*)( null );                // foo( char const(*) )
foo!(char**)( null );               // foo( char* const(*) )
foo!(const(char)*)( null );         // foo( const(char*) )
foo!(char)( '0' );                  // foo( const(char) )
```

## Workarounds

A possible workaround that is current being utilized in DRuntime `core.stdcpp.allocator` is the use of `pragma` to include a linker flag with an alternative name for the function. This requires working knowledge of the underlying implementation of C++ mangling to modify the mangle to include the `const`. This also has the usual problems when using pragma for mangling, that it cannot be used with templates, and requires working knowledge of each C++ mangling used.

```D
version (NeedsMangleHack)
{
    // HACK: workaround to make `deallocate` link as a `T * const`
    private extern (D) enum string constHack(string name) = (){
        version (Win64)
            enum sub = "AAXPE";
        else
            enum sub = "AEXPA";
        foreach (i; 0 .. name.length - sub.length)
            if (name[i .. i + sub.length] == sub[])
                return name[0 .. i + 3] ~ 'Q' ~ name[i + 4 .. $];
        assert(false, "substitution string not found!");
    }();
    pragma(linkerDirective, "/alternatename:" ~ deallocate.mangleof ~ "=" ~ constHack!(deallocate.mangleof));
}
```

## Breaking Changes and Deprecations

No breaking changes are to be expected.

## Copyright & License

Copyright (c) 2019 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## Reviews

The DIP Manager will supplement this section with a summary of each review stage
of the DIP process beyond the Draft Review.
