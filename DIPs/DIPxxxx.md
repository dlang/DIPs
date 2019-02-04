# C++ Const Mangling

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | (number/id -- assigned by DIP Manager)                          |
| Review Count:   | 0 (edited by DIP Manager)                                       |
| Author:         | look-at-me                                                      |
| Implementation: | (links to implementation PR if any)                             |
| Status:         | Will be set by the DIP manager (e.g. "Approved" or "Rejected")  |

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

This syntax would keep in line with D's implementation of `const` whereby `const` is applied to the current type and forward. In the following example if there is a pointer to a pointer and `const` is applied to the first pointer. Both pointers will be const and will point to a mutable type.

```D
extern(C++) void foo( char const** ptr ); // mangle to equivalent C++ char *const *const
```

The same will be true if the const is included after the first pointer. Only the second pointer will be const and will point to a mutable pointer type.

```D
extern(C++) void foo( char* const* ptr ); // mangle to equivalent C++ char **const
```

Should only the first pointer be `const` then brackets can be used to identify which pointer should be const.

```D
extern(C++) void foo( char const(*)* ptr );  // mangle to equivalent C++ char *const *
extern(C++) void foo( char const(**)* ptr ); // mangle to equivalent C++ char *const *const *
```

The underlying type will be assigned the most closely equvalent D type. Effectively removing any `const` past the first mutable pointer.

```D
extern(C++) const(char*)*const* p1; // typeof(p1) == const(char*)**
extern(C++) char**const*        p2; // typeof(p2) == char***
```

// TODO

```D
extern(C++) void foo(T)( T const );
foo!(char*)();

// vs

extern(C++) void bar(T)( const T );
bar!(char*)();
```

## Workarounds

A possible workaround that is current being utilized in DRuntime `core.stdcpp.allocator` is the use of `pragma` to include a linker flag with an alternative name for the function. This requires working knowledge of the underlying implementation of C++ mangling to modify the mangle to include the `const`. This also has the usual problems using using pragma for mangling, that it cannot be used with templates.

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
