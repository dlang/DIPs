
| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            |                                                                 |
| Review Count:   | 0                                                               |
| Authors:        | Robert Aron, Eduard Staniloiu, Razvan Nitu                      |
| Implementation: |                                                                 |
| Status:         | Draft                                                           |

## Abstract

Every class defined in the D language has `Object` as the root ancestor. Object defines four methods: `toString`, `toHash`, `opCmp`, and `opEquals`; at a first glance, their presence might not strike you with much, but they are doing more harm than good. Their signatures predate the introduction of the `@nogc`, `nothrow`, `pure`, and `@safe` function attributes, and also of the `const`, `immutable`, and `shared` type qualifiers. As a consequence, these methods make it difficult to use `Object` with qualifiers or in code with properties such as `@nogc`, `pure`, or `@safe`. We propose the introduction of a new class, `ProtoObject`, as the root class and ancestor of `Object`. `ProtoObject` defines no method and requires the user to implement the desired behaviour through interfaces: this approach enables the user to opt-in for the behaviour that makes sense for his class and the design is flexible enough to allow future attributes and language improvements to be used without breaking code.

## Contents
* [Rationale](#rationale)
* [Prior Work](#prior-work)
* [Description](#description)
* [Breaking Changes and Deprecations](#breaking-changes-and-deprecations)
* [Reference](#reference)
* [Copyright & License](#copyright--license)
* [Reviews](#reviews)

### Rationale
The current definition of `Object` is:
```D
class Object
{
    private __ImplementationDefined __mutex;
    string toString();
    nothrow @trusted size_t toHash();
    int opCmp(Object o);
    bool opEquals(Object o);
    static Object factory(string classname);
}
```

This definition is missing a number of desirable attributes and qualifiers. It is possible to define an improved class that inherits `Object` and overrides these primitives as follows:
```D
class ImprovedObject
{
const override pure @safe:
    string toString();
    nothrow size_t toHash();
    int opCmp(const Object);
    bool opEquals(const Object);
}
```

`ImprovedObject` may be defined in user code (or even in the core runtime library) and inherited from in all user-defined classes in a project for a better experience. However, `ImprovedObject` still has a number of issues:
* The hidden member `__mutex`, needed for `synchronized` sections of code, is still present whether it is used or not. The standard library uses `synchronized` for 6 class types out of the over 70 classes it introduces. At best, the mutex would be opt-in.
* The `toString` method cannot be implemented meaningfully if `@nogc` is required for it. This is because of its signature—constructing a `string` and returning it will often create garbage by necessity. A better implementation would accept an output range in the form of a `delegate(scope const(char)[])` that accepts, in successive calls, the rendering of the object as a string.
* The `opCmp` and `opEquals` objects need to take `const Object` parameters, not `const ImprovedObject`. This is because overriding with covariant parameters would be unsound and is therefore not allowed. Using the weaker type `const Object` in the signature defers checks to runtime that should be done during compilation.
* Overriding `opEquals` must also require the user to override `toHash` accordingly: two objects that are equal, must have the same hash value.
* `opCmp` reveals an outdated design and implementation. Its presence was historically required by built-in associative arrays, which used binary trees needing ordering. The current implementation of associative arrays uses hashtables that lift the requirement. In
addition, not all objects can be meaningfully ordered, so the best approach is to make comparison opt-in. Ordering comparisons in other class-based languages are done by means of interfaces, e.g. [`Comparable<T>` (Java)](https://docs.oracle.com/javase/7/docs/api/java/lang/Comparable.html) or [`IComparable<T>` (C#)](https://msdn.microsoft.com/en-us/library/4d7sx9hd.aspx).
* The static method `factory` is a global dependency sink because it allows creating an instance of any class in the application from a string containing its name. Currently there is no way for a class to opt out. This feature creates [code bloat](https://forum.dlang.org/post/mr6bl7$26f5$1@digitalmars.com) in the generated executable. At best, class factory registration should be opt-in because only a small number of classes (none in the standard library) require the feature.
* The current approach doesn't give the user the chance to opt in or out of certain functions (behaviours). There can be cases where the imposed methods don't make sense for the class type: ex. not all abstractions are of comparable types.
* Because of the hidden `__mutex` member, and the fact that the D programming language supports function attributes, the design of `Object` is susceptible to the Fragile Base Class [Problem](https://www.javaworld.com/article/2073649/why-extends-is-evil.html): this states that a small and seemingly unrelated change in the Base class can lead to bugs and breakages in the Derived classes.

To provide a real example of the proble the following code compiles:
```D
class C { int a; this(int) @safe {} }

void main()
{
    C c = new C(1);
    C[] a = [c, c, c];
    assert(a == [c, c, c]);
}
```
whereas the next section of code fails to compile with the message "incompatible types for array comparison: `C[]` and `C[3]`":
```D
class C { int a; this(int) @safe {} }

@safe void main()
{
    C c = new C(1);
    C[] a = [c, c, c];
    assert(a == [c, c, c]);
}
```
It fails because the non-safe `Object.opEquals` method is called in a safe function. In fact, just comparing 2 classes with no user-defined opEquals - `assert (c == c)` - will issue an error in @safe code: "`@safe` function `D main` cannot call `@system` function `object.opEquals`".

To make it work, a new root of all classes (in our case `ProtoObject`) and the `Equals` interface are needed, as well as an implementation for a mixin template that provides the implementation for opEquals. Then the `C` class must inherit from them and it must contain the mixin template as a field:
```D
class C : ProtoObject, Equals
{
    int a;
    this(int) @safe {}
    mixin ImplementEquals;
}
```
In druntime/object.d:
```D
class ProtoObject {  }

interface Equals
{
    const @nogc nothrow pure @safe scope
    int equals(scope const ProtoObject rhs);
}

mixin template ImplementEquals(M...)
{
    // Equals mixin template implementation
}
...
```

The final points are of crucial importance:
*  must be backwards compatible. The introduction of ProtoObject must not break code
* The user must be allowed to chose what methods he desires to implement
* Root objects must work in attributed code without issues. Since we, sadly, can't predict the future and know if and what attributes and qualifiers will be available in the language, this is yet another argument to have a ProtoObject with no methods.

## Prior Work
Both Java and C# have an `Object` class as the superclass of all classes. For both languages, `Object`
defines a set of default methods, with Java baking into `Object` much more than C# does.

#### Java

Java's `java.lang.Object` defines the following methods:

| Method name                                                   | Description |
| ------------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| `boolean equals(Object o);`                                   | Gives generic way to compare objects|
| `Class getClass();`                                           | The Class class gives us more information about the object|
| `int hashCode();`                                             | Returns a hash value that is used to search objects in a collection|
| `void notify();`                                              | Used in synchronizing threads|
| `void notifyAll();`                                           | Used in synchronizing threads|
| `String toString();`                                          | Can be used to convert the object to String|
| `void wait();`                                                | Used in synchronizing threads|
| `protected Object clone() throws CloneNotSupportedException;` | Return a new object that are exactly the same as the current object|
| `protected void finalize() throws Throwable;`                 | This method is called just before an object is garbage collected |

Each object also has an `Object` monitor that is used in Java `synchronized` sections. Basically it is a semaphore, indicating if a critical section code is being executed by a thread or not. Before a critical section can be executed, the thread must obtain an Object monitor. Only one thread at a time can own that object's monitor.

We can see that there are quite a few similarites between D and Java:
* both define `opEquals` and `getHash`
* `getClass` is similar to `typeid(obj)`
* `clone` gives us access to a `Prototype` like creation pattern; in D we have the `Factory Method`
* both have an `object monitor`

#### C#

C#'s `System.Object` defines the following methods that will be inherited by every C# class:

| Method name     | Description |
| --------------- | ----------- |
| `GetHashCode()` | Retrieve a number unique to that object. |
| `GetType()`     | Retrieves information about the object like method names, the objects name etc. |
| `ToString()`    | Convert the object to a textual representation - usually for outputting to the screen or file. |

C# stripped a lot from it's `Object`, comparint to Java, and it comes a lot closer to what we desire:
* Firstly, there is no builtin monitor. The [Monitor](https://docs.microsoft.com/en-us/dotnet/api/system.threading.monitor?view=netframework-4.7.2)
object is implemented as a separate class that inherits from `Object` in the `System.Threading` namespace.
* Secondly, C# has a smaller number of *imposed* methods, but they are still imposed, and `toString` will continue to be GC dependent.

#### Rust

Rust has a totally different approach: data aggregates (structs, enums and tuples) are all unrelated types.
A developer can define methods on them, and make the data itself private, all the usual tactics of encapsulation, but there is no subtyping and
no inheritance of data.

The relationships between various data types in Rust are established using traits.
Rust `Traits` are like interfaces in OOP languages, and they must be implemented, using `impl`, for the desired type.
```Rust
trait Quack {
    fn quack(&self);
}

struct Duck ();

impl Quack for Duck {
    fn quack(&self) {
        println!("quack!");
    }
}
```

After looking at how Java, C#, and Rust have tackled the same problem, we are confident that the proposed solution is a good one:
define an empty root object and define Interfaces that expose what is the desired behaviour of the class(es) that implement it.
It can be argued that one is not really interested what type an object is, but rather if it can do a certain action (has a certain
behaviour). A key requirement in the design is that existing code must continue to work, and new code should start using `ProtoObject`
and reaping the benefits.


## Description
We propose a simple, economic, and backward-compatible approach for code to avoid `Object`: define simpler types as supertypes of `Object`, as follows:

```D
class ProtoObject
{
    // no monitor, no primitives
}
class SynchronizedProtoObject : ProtoObject
{
    private __ImplementationDefined __mutex;
}
class Object : SynchronizedProtoObject
{
    ... definition unchanged ...
}
```

This reconfiguration makes `ProtoObject`, not `Object`, the ultimate root of all classes. Classes that don't specify a base still inherit `Object` by default, thus preserving backward compatibility. But new code has the option (and will be well advised) to use `ProtoObject` as an explicit base class.

This proposal is based on the following key insight. Currently, `Object` has two roles: (a) the root of all classes, and (b) the default supertype of class definitions that don't specify one. But there is no requirement that these two roles are fulfilled by the same type. This proposal keeps `Object` the default supertype in class definitions, which preserves existing code behavior. The additional supertypes of `Object` only influence newly-introduced code that is aware of them and uses them.

The recommended way of going forward with types that inherit from `ProtoObject` is write and implement interfaces that expose the desired behaviour for the type that it supports. It can be argued that one is not really interested what type an object is, but rather what actions it can perform: what types can it act like? In this regard, an object of type T can be treated as a Collection, a Range, or a Key in map, provided that it implements the right interfaces.

The GoF Design Patterns book talks at length about prefering implementing interfaces to inheriting from concrete classes, and why we should **favor object composition over class inheritance**. Extending from concrete classes is usually seen as a form of code reuse, but this is easly overused by programmers and can lead to the fragile base class problem. The same code reuse can be achieved through composition and delegation schemes: we are already doing this with `structs` and `Design by Introspection`.

As stated earlier, the users will be required to implement specific interfaces that define methods corresponding to the ones in `Object`
| Interface   | Method name                   |
| ----------- | ----------------------------- |
| `Stringify` | `string toString();`          |
| `Hash`      | `size_t toHash();`            |
| `Ordered`   | `int opCmp(const Object);`    |
| `Equals`    | `bool opEquals(const Object);`|

#### Ordering

In order to be able to compare two objects, we define the `Ordered` interface.
```D
interface Ordered
{
    const @nogc nothrow pure @safe scope
    int cmp(scope const ProtoObject rhs);
}
```

The `cmp` function takes a `ProtoObject` argument. This is required so we can compare two instances of `ProtoObject`. Let's see the example

```D
int __cmp(ProtoObject p1, ProtoObject p2)
{
    if (p1 is p2) return 0;
    Ordered o1 = cast(Ordered) p1;
    if (o1 is null) return -1; // we can't compare
    return o1.cmp(p2);
}
```
As one can see in the example, if we can't dynamic cast to `Ordered`, then we can't compare the instances. Otherwise, we can safely call the `cmp` function and let dynamic dispatch do the rest.

Any other class, `class T`, that desires to be comparable, needs to extend ProtoObject and implement `Ordered`.
```D
class Book : ProtoObject, Ordered
{
    enum BookFormat { pdf, epub, paperback, hardcover }

    ulong isbn;
    BookFormat format;

    int cmp(scope const ProtoObject rhs)
    {
        auto rhsBook = cast(Book) rhs;
        if (rhs is null) return 1;
        return this.isbn - rhs.isbn;
    }
}
```

`Ordered` implies that implementing types form a total order.
An order is a total order if it is (for all a, b and c):
* total and antisymmetric: exactly one of a < b, a == b or a > b is true; and
* transitive, a < b and b < c implies a < c. The same must hold for both == and >.
 
As one can expect, most of the classes that desire to implement `Ordered` will have to write some boilerplate code. Inspired by Rust's `derive`, we implemented `ImplementOrdered(M...)` template mixin. This provides the basic implementation for `Ordered` and more.
 
At it's most basic form, `mixin`g in `ImplementOrdered` will go through all the members of the implementing type and compare them with `rhs`

```D
@safe unittest
{
    class Book : ProtoObject, Ordered
    {
        mixin ImplementOrdered;
        enum BookFormat { pdf, epub, paperback, hardcover }

        ulong isbn;
        BookFormat format;

        this(ulong isbn, BookFormat format)
        {
            this.isbn = isbn;
            this.format = format;
        }
    }
    
    auto b1 = new Book(12345, Book.BookFormat.pdf);
    auto b2 = new Book(12345, Book.BookFormat.paperback);
    assert(b1.cmp(b2) != 0);
}
```
In the case above, comparing the two books, `b1` and `b2`, won't result in an equivalence order (cmp -> 0), even if they should as a book is identified by `isbn` regardless of the format it's in. This is because, as previously stated, by default `ImplementOrdered` will go through all the members of the class and compare them.

This is why `ImplementOrdered` allows you to specify the only members that you wish to compare.
```D
@safe unittest
{
    class Book : ProtoObject, Ordered
    {
        mixin ImplementOrdered!("x");
        enum BookFormat { pdf, epub, paperback, hardcover }

        ulong isbn;
        BookFormat format;

        this(ulong isbn, BookFormat format)
        {
            this.isbn = isbn;
            this.format = format;
        }
    }
    
    auto b1 = new Book(12345, Book.BookFormat.pdf);
    auto b2 = new Book(12345, Book.BookFormat.paperback);
    assert(b1.cmp(b2) == 0);
}
```
 
To maximize the flexibility of the user, `ImplementOrdered` also accepts the comparator function to apply on the members.
```D
@safe unittest
{
    class Widget : ProtoObject, Ordered
    {
        mixin ImplementOrdered!("x", "y", (int a, int b) => a - b, "z", (int a, int b) => a - b + 1, "t");
        int x, y, z, t;
        /* code */
    }
}
```

There are cases where it is desirable to implement the default comparison operation on almost all the fields of the aggregate. In such cases, especially if there are a lot of member fields, it would be unpleasant to pass `ImplementOrdered` the name of all the fields we want to take into account while comparing; it would be cleaner and easier to inform it about the exceptions. This is why we defined `ImplementOrderedExcept`.
```D
@safe unittest
{
    class Widget : ProtoObject, Ordered
    {
        mixin ImplementOrderedExcept!("unorderableField");
        int x, y, z, t;
        size_t unorderableField;
        /* code */
    }
}
```

#### Equality

Checking for equality follows in the footsteps of ordering, and requires the user to implement the `Equals` interface.
```D
interface Equals
{
    const @nogc nothrow pure @safe scope
    int equals(scope const ProtoObject rhs);
}
```

Again, as it is the case with ordering, `rhs` is a `ProtoObject` so we can treat the worst-case scenario: compare two objects and all we know is that they are `ProtoObject`s.

```D
bool __equals(ProtoObject p1, ProtoObject p2)
{
    if (p1 is p2) return true;
    Equals o1 = cast(Equals) p1;
    Equals o2 = cast(Equals) p2;
    if (o1 is null || o2 is null) return false;
    return o1.equals(o2) && o2.equals(o1);
}
```

An important note: it isn't sufficient for `o1` to say it's equal to `o2`; `o2` must also agree. Think about comparing a `Base` and a `Derived` instance. The base could be equal to the derived, but the derived might have some extra data so it won't be equal to the base instance.

As it was the case with `Ordered`, to aid the user with the boilerplate code, we provide `ImplementEquals` and `ImplementEqualsExcept` that respect the same design. "Consistency, consistency, consistency" (Scott Meyers).

#### Hashing

The user must implement the `Hash` interface if he desires to provide a hashable behaviour.
```D
interface Hash
{
    const @nogc nothrow pure @safe scope
    size_t toHash();
}
```

Again, we provide the user with default implementations for a hashing function in the form of `ImplementHash` and `ImplementHashExcept`.

Implementations of `Ordered`, `Equals`, and `Hash` must agree with each other. That is, `a.cmp(b) == 0` if and only if `(a == b) && (a.toHash == b.toHash)`. It's easy to accidentally make them disagree by mixing in some of the interface implementations and manually implementing others.


### Breaking Changes and Deprecations
No breaking changes are anticipated because this provides an alternative for users, not a complete redesign of the class hierarchy.

### Acknowledgments
This DIP is based upon the idea proposed by Andrei Alexandrescu and previously worked on by Eduard Staniloiu.

## Reference
#### Eduard Staniloiu on the default class hierarchy
- [From DConf 2017](https://gist.github.com/edi33416/0e592f4afbeb2fb81d3abf235b9732ce)

## Copyright & License

Copyright (c) 2021 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## Reviews
