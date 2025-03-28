# Add Bitfields to D

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | (number/id -- assigned by DIP Manager)                          |
| Review Count:   | 0 (edited by DIP Manager)                                       |
| Author:         | walter@walterbright.com                                         |
| Implementation: | https://github.com/dlang/dmd/pull/16084                         |
| Status:         | Will be set by the DIP manager (e.g. "Approved" or "Rejected")  |

## Abstract

This proposal is for supporting bitfields in D the same way they are supported in C.


## Contents

* [Rationale](#rationale)
* [Prior Work](#prior-work)
* [Description](#description)
* [Breaking Changes and Deprecations](#breaking-changes-and-deprecations)
* [Reference](#reference)
* [Copyright & License](#copyright--license)
* [Reviews](#reviews)


## Rationale

Implementing bitfields was necessary for implementing ImportC. Since the sematic
code is shared between D and ImportC, the bitfield implementation is available to
D "for free". It has been made available for a couple years behind the `-preview=bitfields"
switch without issue.

Bitfield implementations vary between C compilers, typically in an underdocumented or
simply undocumented way. This means that for D code that must interface with C code,
it can be difficult to match the C compiler's behavior. This problem has been resolved
with ImportC, making such interfacing painless.

The usual way to do bitfields is (culled from the DMD compiler source):
```
struct S
{
    enum Flags : uint
    {
        isnothrow       = 0x0001, // nothrow
        isnogc          = 0x0002, // is @nogc
        isproperty      = 0x0004, // can be called without parentheses
        isref           = 0x0008, // returns a reference
        isreturn        = 0x0010, // 'this' is returned by ref
        isscope         = 0x0020, // 'this' is scope
        isreturninferred= 0x0040, // 'this' is return from inference
        isscopeinferred = 0x0080, // 'this' is scope from inference
        islive          = 0x0100, // is @live
        incomplete      = 0x0200, // return type or default arguments removed
        inoutParam      = 0x0400, // inout on the parameters
        inoutQual       = 0x0800, // inout on the qualifier
    }

    Flags flags;
}
```

accessed by:

```
S s;
s.flags |= S.Flags.isthrow;
s.flags &= ~S.Flags.isproperty;
```

It gets worse with multi-bit fields. For example:

```
struct S
{
    int flags;
}
```

To extract 3 bits that are 5 bits in:

```
int i = ((s.flags << 24) >> 29) & 7;
```

To set those 3 bits:

```
s.flags = (s.flags & ~(7<<5)) | ((i & 7) << 5);
```

Of course, one would hide this in a function.

Other ways are noted below. But that's the usual way. The verbosity and klunkiness
of it is obvious. With this proposal:

```
struct S
{
  uint
    isnothrow       : 1, // nothrow
    isnogc          : 1, // is @nogc
    isproperty      : 1, // can be called without parentheses
    isref           : 1, // returns a reference
    isreturn        : 1, // 'this' is returned by ref
    isscope         : 1, // 'this' is scope
    isreturninferred: 1, // 'this' is return from inference
    isscopeinferred : 1, // 'this' is scope from inference
    islive          : 1, // is @live
    incomplete      : 1, // return type or default arguments removed
    inoutParam      : 1, // inout on the parameters
    inoutQual       : 1; // inout on the qualifier
   uint a : 5, flags : 3;
}
```

accessed by:

```
S s;
s.isthrow = true;
s.isproperty = false;
s.flags = 4;
```

It's hard to imagine a more concise, direct to-the-point syntax, with no extraneous
symbols. This syntax encourages experimentation with them.

### Usage

The main purposes of bitfields are:

1. Reduction in memory consumption by packing data.
2. Interoperation with C bitfields, as a program can consist of both C and D code.
3. Conformance with an externally imposed layout, such as bits in a hardware register
or bitfields in an externally specified data structure.

### Experience

There is over 40 years experience with bitfields in C, and around 35 years in
C++. I've seen plentiful use of it, and have not seen much "do not use bitfields" programming
guidelines. The most cogent thread about it is by Linux Torvalds:
https://yarchive.net/comp/linux/bitfields.html
where he points out the problems with Usage No. 1 listed above.


### ImportC

Since bitfields are supported in ImportC, C bitfields could be supported by importing a C
file with the bitfield declarations. While this will work, it's awkward and has a workaround
aura about it.

### Cross-Compiling, Bootstrapping

The bitfield layout, like struct alignment and code generation, is determined by the selected
target machine, not the host machine.

## Prior Work

Bitfields are implemented in every C Standard compliant C compiler, including ImportC.

Bitfields are implemented in every C++ compiler in an identical fashion as its
associated C compiler. This sort of compatibilty was instrumental to C++'s early
success.

Bitfields can be done via std.bitmanip.bitfields in Phobos:
https://dlang.org/phobos/std_bitmanip.html#bitfields
however, they are not compatible with C bitfields.

Another implementation is used in dmd:
https://github.com/dlang/dmd/blob/master/compiler/src/dmd/common/bitfields.d
which only works for single bit flags.

Bit Fields in Zig:
https://andrewkelley.me/post/a-better-way-to-implement-bit-fields.html

Bit Fields in C3:
https://c3lang.github.io/c3docs/types/#bitstructs

## Description

### Binary Compatibility

The specific layout of bitfields in C is implementation-defined, and varies between
the Digital Mars, Microsoft, and gdc/ldc compilers. gdc/lcd are lumped together because
they produce identical results on the same platform.

In practice, however, if one sticks to `int`, `uint`, `long` and `ulong` bitfields, they are laid out the same.

The layout of the other fields of a struct is implementation-defined in C, and it does
vary between the Digital Mars, Microsoft, and gdc/ldc compilers. The endianess is also
implementation defined.

The size of an `int` is also implementation-defined according to the C Standard. But
in practice, it is the same across 32 and 64 bit machines.

Pedantically, this is all implementation-defined, and so impairs binary portability
between systems. As a practical matter, D already deals with this with the other implementation-defined
C size and layout behaviors, and the difficulties are easily avoided.

Use of std.bitmap.bitfields is binary compatible across platforms, but that makes it also
incompatible with C bitfields.

The solution is to pick the right implementation for the desired purpose:

1. use builtin bitfields for reducing memory consumption
1. use builtin bitfields for interoperability with the associated C compiler
2. use std.bitmap.bitfields for compatibility with externally imposed data layouts
or hardware registers


### Symbolic Debug Info

Symbolic C code debuggers are ubiquitous, and they support symbolic debugging of
bitfields. Without semantic knowledge of what is
a bitfield, the compiler cannot generate symbolic debug information for them,
and the user experience with them is degraded.
By being compatible with the associated C compiler, existing symbolic debuggers will work
smoothly with D bitfields.


### Reference to Bitfield

One cannot take a reference to or the address of a bitfield. This cannot be done
with bit flags or std.bitmap.bitfields either. (For std.bitmap.bitfields, the
error message "cannot infer type from overloaded function symbol `&bb.b`" appears.)


### Introspection

Using __traits:

```
import std.stdio;
import std.bitmanip;


struct B { int a; int b:3, c:2; }

struct C {
    int a;
    mixin(bitfields!(
        int, "b", 3,
        int, "c", 2,
        int, "d", 11)); // filling out to 16 bits is required
}

void main()
{
    auto b = [ __traits(allMembers, B) ];
    writeln(b);

    auto c = [ __traits(allMembers, C) ];
    writeln(c);
}
```

produces:

```
["a", "b", "c"]
["a", "_b_c_d_bf", "b", "b_min", "b_max", "c", "c_min", "c_max", "d", "d_min", "d_max"]
```

There isn't a specific trait for "is this a bitfield". However, a bitfield can be detected
by taking the address of it being a compile time error.

#### .max and .min

```
writeln(B.b.min, " ", B.b.max);
writeln(B.c.min, " ", B.c.max);
```

correctly produces:

```
-4 3
-2 1
```

which, along with testing to see if the address of a field can be taken,
enables discovery of a bitfield.

The values of .max or .min enable determining the number of bits in a bitfield.

#### Trait `isBitField`

Using `__traits(isBitField, symbol)` can be used to distinguish a bitfield from a regular field.

#### .offsetof and .alignof

When applied to a bitfield produces values for the field type that encloses the bitfield.

#### Bit Offset of Bitfield

The bit offset can be determined with the property `.bitoffsetof`.

#### Width of Bitfield

The number of bits in a bitfield can be determined with the property `.bitwidth`.

### Shared Bitfields

All bitfield schemes share a warning about use by multiple threads - updating one
field may alter its neighbors in a race condition. The entire collection of
fields must be locked to access a bitfield in a shared environment.

Atomic operations will not work on bitfields, as there are no CPU instructions
capable of doing it.

### `typeof`

The type of a bitfield is the type that precedes the bitfield declaration.

### `.sizeof`

The value returned by .sizeof is the same as `typeof(bitfield).sizeof`.

### `shared`, `const`, `immutable`, `__gshared`, `static`, `extern`

Are not allowed for bitfields.

## Breaking Changes and Deprecations

A bitfield can be detected by not being able to take the address of it.

Introspection code that relies on taking the address of or reference to fields will break
with bitfields. Introspection code that relies on `.offsetof` and `.sizeof` will see bitfields
as a union of the bitfields with the same `.offsetof`, `.sizeof` and `typeof`.

## Controversy

Most of the objections revolve around discomfort with the layout being implementation-defined
by the associated C compiler. Many methods were proposed to deal with this. The only time
the layout matters is with Usage No. 3, where the layout is imposed externally. For Usage Nos.
1 and 2, the particular layout does not matter. When it does matter, many alternatives are
available:

1. Use https://dlang.org/phobos/std_bitmanip.html#bitfields
2. If one sticks with one field type (such as `int`), then the layout is predictable in practice,
although not in specification
3. Use custom functions to encode/decode fields
4. A bit of testing will show what a particular layout is, after which it will be reliable

The alternatives are easy enough, and Usage No. 3 is unusual enough, that the extra language complexity
to support multiple layouts is not worth it. Note that the author would use a lot more bitfields
if they were in the language.

## Reference

Documentation pull request:
https://github.com/dlang/dlang.org/pull/3190

PR to add instrospection abilities:
https://github.com/dlang/dmd/pull/16444

Newsgroup discussion:
https://www.digitalmars.com/d/archives/digitalmars/dip/development/DIP_add_Bit_Fields_2.html

## Copyright & License
Copyright (c) 2024 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## Reviews

The DIP Manager will supplement this section with a summary of each review stage
of the DIP process beyond the Draft Review.
