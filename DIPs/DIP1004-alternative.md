# Inherited Constructors

| Section         | Value                                                      |
|-----------------|------------------------------------------------------------|
| DIP:            | 1004-alternative                                           |
| Author:         | Andrej Mitrović                                            |
| RC#             | 0                                                          |
| Implementation: |                                                            |
| Status:         | Draft                                                      |

## Table of Contents

- [Abstract](#abstract)
- [Rationale](#rationale)
- [Description](#description)
  - [Explanation of the problem](#explanation-of-the-problem)
  - [Existing workarounds](#existing-workarounds)
- [Proposed changes](#proposed-changes)
  - [Implicit constructor inheritance for derived classes with no constructors](#implicit-constructor-inheritance-for-derived-classes-with-no-constructors)
  - [Syntax for inheriting base class constructors for derived classes](#syntax-for-inheriting-base-class-constructors-for-derived-classes)
- [Examples from existing projects](#examples-from-existing-projects)
  - [Sociomantic tango/ocean](#sociomantic-tangoocean)
  - [Phobos](#phobos)
- [Breaking changes](#breaking-changes)
- [Links and Previous discussions](#links-and-previous-discussions)

## Abstract

A derived class is currently instantiable by client-code using its base class
constructor only if the base class has a default constructor and the derived
class does not define any constructors of its own.

If the designer of the derived class wants to allow construction of the
derived class by using any of its base class constructors, then this support
must be added manually by writing forwarding constructors.

This DIP attempts to alleviate the problem by introducing two features:

- [Implicit constructor inheritance for derived classes with no constructors](#implicit-constructor-inheritance-for-derived-classes-with-no-constructors)
- [Selective inheritance of constructors](#selective-inheritance-of-constructors)

## Rationale

The process of manually writing forwarding constructors is tedious and
error-prone. It's possible to automate it using mixins, but this may not be a
reliable solution. The drawbacks of Existing workarounds are explained in more
details in [the following section](#existing-workarounds).

## Description

### Explanation of the problem

Currently a derived class is constructible by client code via its base class
constructor only if both of the following are true:

- The derived class does not define any of its own constructors
- The base class constructor has a default constructor

**Example:**

```D
class Base
{
    this ( ) { }
}

class Derived : Base { }

void main ( )
{
    auto d = new Derived;  // ok: Derived class doesn't define custom constructors
}
```

However, if the base class constructor is a non-default constructor,
it's hidden when instantiating a derived class type:

```D
class Base
{
    this ( int ) { }
}

class Derived : Base { }

void main ( )
{
    // Error: class Derived cannot implicitly generate a default ctor when
    // base class Base is missing a default ctor
    auto d = new Derived(42);
}
```

Even if the base class has a default constructor and the derived class defines
a constructor of its own, the base class constructor is still hidden when
instantiating the derived class type:

```D
class Base
{
    this ( ) { }
}

class Derived : Base
{
    this (int, int) { }
}

void main ( )
{
    // Error: constructor Derived.this (int _param_0, int _param_1) is not
    // callable using argument types ()
    auto d = new Derived();
}
```

The rationale for this current limitation is the following: if the `Derived`
object was constructible by calling its base class constructor,
then the `Derived` object itself could be left in a partially-constructed state,
as any of its own constructors would be circumvented by not being called.

For example:

```D
class Base
{
    int r;
    this ( ) { this.r = 1; }
}

class Derived : Base
{
    int g, b;
    this (int g, int b) { this.g = g; this.b = b; }
}

void main ( )
{
    // currently an error
    auto d = new Derived();
}
```

If the above instantiation was allowed, the `Derived`'s `g` and `b` fields
would be left in their default state, rather than being forced to be initialized
via the `this (int g, int b)` constructor.

However, the class designer of `Derived` may want to explicitly allow the usage
of its base-class constructors. This DIP attempts to add language support to
make this workflow easier.

### Existing workarounds

Currently, if the author of the `Derived` class wants to allow construction via
the base class constructor, then this support must be added explicitly by
writing forwarding constructors:

```D
class Base
{
    this ( int ) { }
}

class Derived : Base
{
    this ( )
    {
        super(42);
    }

    this ( int x )
    {
        super(x);
    }
}

void main ( )
{
    auto d1 = new Derived();  // ok
    auto d2 = new Derived(43);  // ok
}
```

This approach is tedious and time-consuming, and may be prone to coding
mistakes. However, workarounds to aleviate this manual work are possible:

An example library solution for inheriting constructors via mixins is provided
[here](https://gist.github.com/AndrejMitrovic/72a08aa2c078767ea4c35eb1b0560c8d).

There are a number of drawbacks with the above implementation:

- It relies on string mixins to generate the code, which can slow down
  compilation speed.
- It does not currently handle default values.
- It does not have the ability to selectively inherit specific
  constructors, it instead inherits them all, potentially causing clashes
  with existing hand-written constructors.
- The use of self-reflection can potentially create semantic analysis cycles and
  is fragile against changes in the compiler internals.

## Proposed changes

This DIP proposes two independent language changes. Combined, those should
fix the aforementioned issues in a way that integrates into the existing
definition of the D language without being obtrusive.

### Implicit constructor inheritance for derived classes with no constructors

If a derived class does not define any new constructors of its own, all
base class constructors of the parent class should be available for use
when the derived class is being instantiated.

**Examples:**

**Before:**

```D
class ParseException : Exception
{
}

void parseArgs ( string[] args )
{
    if (args < 2)
    {
        // Error: class ParseException cannot implicitly generate a default ctor
        // when base class object.Exception is missing a default ctor
        throw new ParseException("Expected at least one argument");
    }
}
```

**After:**

```D
class ParseException : Exception
{

}

void parseArgs ( string[] args )
{
    if (args < 2)
    {
        // ok, ParseException inherited all constructors from its base class
        throw new ParseException("Expected at least one argument");
    }
}
```

**Rationale**: The designer of the derived class has not defined any of its own
constructors, therefore this object cannot be left in a partially-initialized
state of one of its base class constructors are used. Should a designer really
want to prohibit the construction of `ParseException`, they should either
mark the class as `abstract`, or define a private constructor.

If the derived class does define a constructor of its own, then this will
automatically hide all the base-class constructors. This is the current
behaviour in the language and will remain the same.

**Example:**

```D
class ParseException : Exception
{
    // Explicit constructor definition, prevents implicit inheriting
    // of constructors defined in the base class:
    this ( ) { super(""); }
}

void parseArgs ( string[] args )
{
    if (args < 2)
    {
        // Error: constructor ParseException.this () is not callable using
        // argument types (string)
        throw new ParseException("Expected at least one argument");
    }
}
```

Forwarding constructors are most prominent in long class hierarchies,
such as Exception subclasses.

### Syntax for inheriting base class constructors for derived classes

A class designer may wish to add a custom constructor in a derived class,
but still have the ability for users to construct such a class type with one
or more of the base class constructors.

The DIP proposes adding an ability to selectively inherit base-class
constructors, similar to the way base-class method overloads are re-introduced
via the `alias` feature. See the [Function Inheritance and Overriding](http://dlang.org/spec/function.html#function-inheritance), and the section titled
`To consider the base class's functions in the overload resolution process`
for more info on this existing feature.

The DIP proposes extending the existing `alias super.<symbol> this` syntax by
allowing to specify the constructor as the target of the aliased symbol.

For example: `alias super.this(Parameters...) this;`

When such an alias to the base constructor is declared, it would be interpreted
as an explicit request to inherit the matching base class constructor.

**Examples:**

**Before:**

```D
enum ErrorCode
{
    FileNotFound,
    OutOfFDs
}

class FileException : Exception
{
    this ( ErrorCode error_code, string file = __FILE__, size_t line = __LINE__ )
    {
        super(error_code.to!string, file, line);
    }
}

void main ( string[] args )
{
    // ok
    throw new FileException(ErrorCode.FileNotFound);

    // error, base class constructor is hidden
    throw new FileException("Something went wrong");
}
```

**After:**

```D
enum ErrorCode
{
    FileNotFound
}

class FileException : Exception
{
    this ( ErrorCode error_code, string file = __FILE__, size_t line = __LINE__ )
    {
        super(error_code.to!string, file, line);
    }

    // inherit this specific constructor
    alias super.this(string, size_t) this;
}

void main ( string[] args )
{
    // using the FileException's constructor
    throw new FileException(ErrorCode.FileNotFound);

    // using the Exception's constructor
    throw new FileException("Something went wrong");
}
```

As aformentioned, this feature is similar to D's existing feature for
re-introducing base class methods to allow overloading of a base class method:

```D
class Base
{
    int sum ( int x, int y ) { return x + y; }
}

class Derived : Base
{
    // re-introduces base class method to allow overloading
    alias super.sum sum;

    // overload of the base class sum method
    float sum ( float x, float y ) { return x + y; }
}

void main ( string[] args )
{
    auto d = new Derived;
    d.sum(int(1), int(2));
    d.sum(float(1), float(2));
}
```

## Examples from existing projects

The most common example in library code is an Exception class hierarchy.
Typically each new inherited class has to define forwading constructors in
order to make it fully usable.

### Sociomantic tango/ocean

An example of an exception class hierarchy can be found
[here](https://github.com/sociomantic-tsunami/ocean/blob/6500d67e630de1d05adc510e1572bee26fe3985c/src/ocean/core/Exception_tango.d).

Note that
[wrapped constructor](https://github.com/sociomantic-tsunami/ocean/blob/6500d67e630de1d05adc510e1572bee26fe3985c/src/ocean/core/Exception_tango.d#L91-L97)
definition is actually incorrect and ignores file/line parameters, most likely
because of developers reluctance to write required boilerplate:

```D
class PlatformException : Exception
{
    this( istring msg )
    {
        super( msg );
    }
}
```

With this DIP features, it would look like this:

```D
class PlatformException : Exception { }
```

That is both shorter and more correct as it is guarantees to use the same
constructor definition. It also has the benefit of being more future-proof
against base constructor definition changes.

### Phobos

The D standard library also defines a helper mixin to make it easier to define
your own exception class
[here](https://github.com/dlang/phobos/blob/bf61ad682f3f9c35a16c79180941ffd902ab9758/std/exception.d#L2159), indicating it is a common task.

However, this mixin is not used consistently even within the standard library.
An incomplete list of examples are provided below:

- [std.concurrency](https://github.com/dlang/phobos/fa54b85dd97598f3cf775a1b36bc0d8944f45f18/master/std/concurrency.d#L224)
- [std.json](https://github.com/dlang/phobos/blob/fa54b85dd97598f3cf775a1b36bc0d8944f45f18/std/json.d#L1295)
- [std.zip](https://github.com/dlang/phobos/blob/fa54b85dd97598f3cf775a1b36bc0d8944f45f18/std/zip.d#L78)
- [std.stdio](https://github.com/dlang/phobos/blob/fa54b85dd97598f3cf775a1b36bc0d8944f45f18/std/stdio.d#L4266)

Examples of incorrect forwarding code present even in the standard library shows
that writing forwarding constructors can be an error-prone process, which
this DIP attempts to alleviate.

## Breaking changes

The vast majority of code should not be affected by the changes in this proposal.

Code which uses introspection to check whether a class is instantiable with a
list of arguments would be the most affected by this change.  For example, an
`is(typeof( new Derived(...) ))` check may currently be false, but would change
to true if constructors were implicitly inherited as per
[feature #1](#implicit-constructor-inheritance-for-derived-classes-with-no-constructors)

## Links and Previous discussions

* [Issue 9066: Add constructor inheritance feature](https://issues.dlang.org/show_bug.cgi?id=9066)
* [Previous discussion about constructor inheritance in D](http://forum.dlang.org/post/f3pisd$4vi$3@digitalmars.com)
* [C++11: What is constructor inheritance?](http://stackoverflow.com/a/9979249/279684)
* [C++11: Draft 3337 - Page 269 - Constructor Inheritance (PDF warning)](http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2012/n3337.pdf)
* [C++11: Object construction improvements](https://en.wikipedia.org/wiki/C%2B%2B11#Object_construction_improvement)

## Copyright & License

Copyright (c) 2016 - 2017 by the D Language Foundation

Licensed under [Creative Commons Zero
1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)
