# In-place struct initialization

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | 1002                                                            |
| Author:         | Cédric Picard (cpicard@openmailbox.org)                         |
| Implementation: | N/A                                                             |
| Status:         | N/A                                                             |

## Abstract

Structs support static initialization. This DIP proposes to extend this
initialization to in-place struct declaration. This change could notably be
used to mimic keyword arguments and make argument manipulations at runtime
easier.

### Links

- [Language specs on structs](https://dlang.org/spec/struct.html)

## Description

Let S be a struct defined as:

    struct S {
        uint a;
        long b;
        int  c;
    }

The proposed change is to make the following syntax legal

    auto s = S(a:42, b:-5);

and in all points equivalent to what follows

    S s = { a:42, b:-5 };

This equivalence standing, the following must compile:

    S s = S(b:-5);
    S s = S(b: -5, a :42);

On the contrary the following must not compile:

    auto s = S(32, b:23);
    auto s = S(a:32, b:23, d:43);

    struct T {
        int a;
        string s;

        @disable this();
        this(string _s) { s = _s };
    }

    auto t = T(a:4);
    auto t = T("test", a:4);

### Rationale

Static struct initialization has great properties:

- It is explicit using named attributes
- Order of declaration doesn't matter
- Not all attributes have to be specified

No function call provide those properties, and consequently no constructor
can benefit from it either. Authorizing such struct initialization makes the
language more orthogonal and opens new doors.

The most interesting is to use structs to mimic keyword arguments for
functions. By encapsulating possible arguments in a struct it is possible to
use in-place initialization to provide a clean interface very similar to
keyword arguments such as seen in python or ruby.

As it stands now the way to provide complex argument set to a function is
either to generate lots of constructors for the different cases which is
messy or by setting a struct up before passing it to the function in a C-way
fashion. This change provides ways to design better high-level interfaces.

Besides the change is completely retrocompatible in a nice way: the library
itself is just defining an argument struct and using it in its function
interface. Code using older compilers can setup the struct without in-place
initialization and modern compilers benefit from a cleaner interface.

This change also helps interfacing C code that uses structs.

### Breaking changes / deprecation process

No code breakage is expected as all changes are additive.

### Examples

    struct totalArgs {
        int tax;
        int discount;
    }

    int total(int subtotal, totalArgs args = totalArgs.init) {
        return subtotal + args.tax - args.discount;
    }

    unittest {
        assert(total(42) == 42);
        assert(total(42, totalArgs(tax: 50)) == 92);
        assert(total(42, totalArgs(discount: 20, tax: 50)) == 72);

        int defaultTotal(int subtotal) {
            immutable defaultSet = totalArgs(tax: 20);
            return total(subtotal, defaultSet);
        }
    }

## Copyright & License

Copyright (c) 2016 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

### Reviews

N/A
