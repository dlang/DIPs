# The Copy Constructor

| Field           | Value                                                                           |
|-----------------|---------------------------------------------------------------------------------|
| DIP:            | (number/id -- assigned by DIP Manager)                                          |
| Review Count:   | 0 (edited by DIP Manager)                                                       |
| Authors:        | Razvan Nitu - razvan.nitu1305@gmail.com, Andrei Alexandrescu - andrei@erdani.com|
| Implementation: | (links to implementation PR if any)                                             |
| Status:         | Will be set by the DIP manager (e.g. "Approved" or "Rejected")                  |

## Abstract

This document proposes the copy constructor semantics as an alternative
to the design flaws and inherent limitations of the postblit.

### Reference

* [1] https://github.com/dlang/dmd/pull/8032

* [2] https://forum.dlang.org/post/p9p64v$ue6$1@digitalmars.com

* [3] http://en.cppreference.com/w/cpp/language/copy_constructor

* [4] https://dlang.org/spec/struct.html#struct-postblit

* [5] https://news.ycombinator.com/item?id=15008636

* [6] https://dlang.org/spec/struct.html#struct-constructor

* [7] https://dlang.org/spec/struct.html#field-init

## Contents
* [Rationale and Motivation](#rationale-and-motivation)
* [Description](#description)
* [Breaking Changes and Deprecations](#breaking-changes-and-deprecations)
* [Acknowledgements](#acknowledgements)
* [Reviews](#reviews)

## Rationale and Motivation

This section highlights the existing problems with the postblit and motivates
why the implementation of a copy constructor is more desirable than an attempt
to fix all the postblit issues.

### Overview of this(this)

The postblit function is a non-overloadable, non-qualifiable
function. However, the compiler does not reject the
following code:

```D
struct A { this(this) const {} }
struct B { this(this) immutable {} }
struct C { this(this) shared {} }
```

Since the semantics of the postblit in the presence of qualifiers was
not defined and most likely not intended, this led to a series of problems:

* `const` postblits are not able to modify any fields in the destination
* `immutable` postblits never get called (resulting in compilation errors)
* `shared` postblits cannot guarantee atomicity while blitting the fields

#### `const`/`immutable` postblits

The solution for `const` and `immutable` postblits is to type check them as normal
constructors where the first assignment of a member is treated as an initialization
and subsequent assignments are treated as modifications. This is problematic because
after the blitting phase, the destination object is no longer in its initial state
and subsequent assignments to its fields will be regarded as modifications making
it impossible to construct `immutable`/`const` objects in the postblit. In addition,
it is possible for multiple postblits to modify the same field. Consider:

```D
struct A
{
    immutable int a;
    this(this)
    {
        this.a += 2;  // modifying immutable or ok?
    }
}

struct B
{
    A a;
    this(this)
    {
        this.a.a += 2;  // modifying immutable error or ok?
    }
}

void main()
{
    B b = B(A(7));
    B c = b;
}
```

When `B c = b;` is encountered, the following actions are taken:

1. `b`'s fields are blitted to `c`
2. A's postblit is called
3. B's postblit is called

After `step 1`, the object `c` has the exact contents as `b` but it is not
initialized (the postblits still need to fix it) nor uninitialized (the field
`B.a` does not have its initial value). From a type checking perspective
this is a problem because the assignment inside A's postblit is breaking immutability.
This makes it impossible to postblit objects that have `immutable`/`const` fields.
To alleviate this problem we can consider that after the blitting phase the object is
in a raw state, therefore uninitialized; this way, the first assignment of `B.a.a`
is considered an initialization. However, after this step, the field
`B.a.a` is considered initialized, therefore how is the assignment inside B's postblit
supposed to be type checked ? Is it breaking immutability or should
it be legal? Indeed it is breaking immutability because it is changing an immutable
value, however being part of initialization (remember that `c` is initialized only
after all the postblits are ran) it should be legal, thus weakening the immutability
concept and creating a different strategy from the one that normal constructors
implement.

#### Shared postblits

Shared postblits cannot guarantee atomicity while blitting the fields because
that part is done automatically and it does not involve any
synchronization techniques. The following example demonstrates the problem:

```D
shared struct A
{
    long a, b, c;
    this(this) { ... }
}

A a = A(1, 2, 3);

void fun()
{
    A b = a;
    /* do other work */
}
```

Let's consider the above code is ran in a multithreaded environment
When `A b = a;` is encountered the following actions are taken:

* `a`'s fields are copied to `b`
* the user code defined in this(this) is called

In the blitting phase no synchronization mechanism is employed, which means
that while the copying is done, another thread may modify `a`'s data resulting
in the corruption of `b`. In order to fix this issue there are 4 possibilities:

1. Make shared objects larger than 2 words uncopyable. This solution cannot be
taken into account because it imposes a major arbitrary limitation: almost all
structs will become uncopyable.

2. Allow incorrect copying and expect that the user will
do the necessary synchronization. Example:

```D
shared struct A
{
    Mutex m;
    long a, b, c;
    this(this) { ... }
}

A a = A(1, 2, 3);

void fun()
{
    A b;
    a.m.acquire();
    b = a;
    a.m.release();
    /* do other work */
}
```

Although this solution solves our synchronization problem it does it in a manner
that requires unencapsulated attention at each copy site. Another problem is
represented by the fact that the mutex release is done after the postblit was
ran which imposes some overhead. The release may be done right after the blitting
phase (first line of the postblit) because the copy is thread-local, but then
we end up with non-scoped locking: the mutex is released in a different scope
than the scope in which it was acquired. Also, the mutex is automatically
(wrongfully) copied.

3. Introduce a preblit function that will be called before blitting the fields.
The purpose of the preblit is to offer the possibility of preparing the data
before the blitting phase; acquiring the mutex on the `struct` that will be
copied is one of the operations that the preblit will be responsible for. Later
on, the mutex will be released in the postblit. This approach has the benefit of
minimizing the mutex protected area in a manner that offers encapsulation, but
suffers the disadvantage of adding even more complexity on top of existing one by
introducing a new concept which requires typecheking of disparate sections of
code (need to typecheck across preblit, mempcy and postblit).

4. Use an implicit global mutex to synchronize the blitting of fields. This approach
has the advantage that the compiler will do all the work and synchronize all blitting
phases (even if the threads don't actually touch each other's data) at the cost
of performance. Python implements a global interpreter lock and it was proven
to cause unscalable high contention; there are ongoing discussions of removing it
from the Python implementation [5].

### Introducing the copy constructor

As stated above, the fundamental problem with the postblit is the automatic blitting
of fields which makes it impossible to type check and cannot be synchronized without
additional costs.

As an alternative, this DIP proposes the implementation of a copy constructor. The benefits
of this approach are the following:

* it is a known concept. C++ has it [3];
* it can be typechecked as a normal constructor (since no blitting is done, the data is
initialized as if it were in a normal constructor); this means that `const`/`immutable`/`shared`
copy constructors will be type checked exactly as their analogous constructors
* offers encapsulation

The downside of this solution is that the user must do all the field copying by hand
and every time a field is added to a struct, the copy constructor must be modified.
However, this can be easily bypassed by D's introspection mechanisms. For example,
this simple code may be used as a language idiom or library function:

```D
foreach (i, ref field; src.tupleof)
    this.tupleof[i] = field;
```

As shown above, the single benefit of the postblit can be easily substituted with a
few lines of code. On the other hand, to fix the limitations of the postblit it is
required that more complexity is added for little to no benefit. In these circumstances,
for the sake of uniformity and consistency, replacing the postblit constructor with a
copy constructor is the reasonable thing to do.

## Description

This section discusses all the technical aspects regarding the semantics
of the copy constructor.

### Syntax

The following link exhibits the proposed syntax and the necessary grammar changes in order to support
the copy construct:

https://github.com/dlang/dlang.org/pull/2414

A declaration is a copy constructor declaration if it is a constructor declaration annotated with
the `@implicit` attribute and takes only one parameter by reference that is of the same type as
`typeof(this)`. `@implicit` is a compiler recognised attribute like `@safe` or `nogc` and it can be
syntactally used the same as the others. `@implicit` can be legally used solely to mark the declaration
of a copy constructor; all other uses of this attribute will result in a compiler error. The proposed syntax
benefits from the advantage of declaring the copy constructor in an expressive manner without adding
additional complexity to the existing syntax.

The copy constructor needs to be annotated with `@implicit` in order to distinguish a copy
constructor from a normal constructor and avoid silent modification of code behavior. Consider
this example:

```d
import std.stdio;
struct A {
    this(ref immutable A obj) { writeln("x"); }
}
void main()
{
    immutable A ia;
    A a = A(ia);
    A b = ia;
}
```

With the current state of the language, `x` is printed once. with the addition of the copy constructor without
`@implicit`, `x` would be printed twice, thus modifying the semantics of existing code.

The argument to the copy constructor is passed by reference in order to avoid infinite recursion (passing by
value would require a copy of the `struct` which would be made by calling the copy constructor, thus leading
to an infinite chain of calls).

The type qualifiers may be applied to the parameter of the copy constructor, but also to the function itself
in order to facilitate the ability to describe copies between objects of different mutability levels. The type
qualifiers are optional.

### Semantics

This sections discusses all the aspects regarding the semantic analysis and interaction with other
components of the copy constructor

#### Copy constructor usage

The copy constructor is implicitly used by the compiler whenever a struct variable is initialized
as a copy of another variable of the same unqualified type:

1. When a variable is explicitly initialized:

```d
struct A
{
    @implicit this(ref A another) {}
}

void main()
{
    A a;
    A b = a; // copy constructor gets called
    b = a;   // assignment, not initialization
}
```

2. When a parameter is passed by value to a function:

```d
struct A
{
    @implicit this(ref A another) {}
}

void fun(A a) {}

void main()
{
    A a;
    fun(a);    // copy constructor gets called
}
```

3. When a parameter is returned by value from a function:

```d
struct A
{
    @implicit this(ref A another) {}
}

A fun()
{
    A a;
    return a;
}

void main()
{
    A a;
    a = fun();   // copy constructor gets called
}
```

#### Requirements

1. The type of the parameter to the copy constructor needs to be identical to `typeof(this)`; an error is issued
otherwise:

```d
struct A
{
    int a;
    string b;
}

struct C
{
    A a;
    string b;
    @implicit this(ref C another)       // ok, typeof(this) == C
    {
        this.a = another.a;
        this.b = another.b;
    }

    @implicit this(ref A another)       // error typeof(this) != C
    {
        this.a = another;
        this.b = "hello";
    }
}

void main()
{
    C c;
    C d = c;   // ok
    A a;
    C e = a;   // error
}
```
2. It is illegal to declare a copy constructor for a struct that has a postblit defined and vice versa:

```d
struct A
{
    this(this) {}
    @implicit this(ref A another) {}        // error, struct A defines a postblit
}
```

Note that structs that do not define a postblit explicitly but contain fields that
define one have a generated postblit. From the copy constructor perspective it makes
no difference whether the postblit is user defined or generated:

```d
struct A
{
    this(this) {}
}

struct B
{
    A a;                                // A has a postblit -> __fieldPostblit is generated for B
    @implicit this(ref B another) {}    // error, struct B defines a postblit
}
```

#### Type checking

The copy constructor typecheck is identical to the constructor one [[6](https://dlang.org/spec/struct.html#struct-constructor)]
[[7](https://dlang.org/spec/struct.html#field-init)].

The copy constructor overloads can be explicitly disabled:

```d
struct A
{
    @disable @implicit this(ref A another)
    @implicit this(ref immutable A another)
}

void main()
{
    A b;
    A a = b;     // error: disabled copy construction

    immutable A ia;
    A c = ia;  // ok

}
```

In order to disable copy construction, all copy constructor overloads need to be disabled.
In the above example, only copies from mutable to mutable are disabled; the overload for
immutable to mutable copies is still callable.

#### Overloading

The copy constructor can be overloaded with different qualifiers applied to the parameter
(copying from qualified source) or to the copy constructor itself (copying to qualified
destination):

```d
struct A
{
    @implicit this(ref A another) {}                        // 1 - mutable source, mutable destination
    @implicit this(ref immutable A another) {}              // 2 - immutable source, mutable destination
    @implicit this(ref A another) immutable {}              // 3 - mutable source, immutable destination
    @implicit this(ref immutable A another) immutable {}    // 4 - immutable source, immutable destination
}

void main()
{
    A a;
    immutable A ia;

    A a2 = a;      // calls 1
    A a3 = ia;     // calls 2
    immutable A a4 = a;     // calls 3
    immutable A a5 = ia;    // calls 4
}
```
The proposed model enables the user to define the copying from an object of any qualified type
to an object of any qualified type: any combination of 2 between mutable, `const`, `immutable`, `shared`,
`const shared`.

The `inout` qualifier may be used for the copy constructor parameter in order to specify that mutable, `const` or `immutable` types are
treated the same:

```d
struct A
{
    @implicit this(ref inout A another) immutable {}
}

void main()
{
    immutable A c, r1, r2, r3;

    // All call the same copy constructor because `inout` acts like a wildcard
    A a = r1;
    const A b = r2;
    immutable A c = r3;
}
```

In case of partial matching, the existing overloading and implicit conversions
apply to the argument.

#### Copy constructor call vs. Standard copying (memcpy)

When a copy constructor is not defined for a struct, initializations are treated
by copying the contents from the memory location of the right-hand side expression
to the memory location of the left-hand side one (called "standard copying"):

```d
struct A
{
    int[] a;
}

void main()
{
    A a = A([7]);
    A b = a;                 // mempcy(&b, &a)
    immutable A c = A([12]);
    immutable A d = c;       // memcpy(&d, &c)
}
```

In C++, when a copy constructor is defined, initializations which fall under the stated categories
are lowered to a copy constructor call. If this design would be implemented, situations like these
would occur:

```d
struct A
{
    int[] a;
    @implicit this(ref immutable A) {}
}

void fun(A a)
{}

void main()
{
    A a;
    A b = a;    // error: cannot call `@implicit this(immutable(A))` with type `A`
    fun(a)      // ditto
}
```

Because all expressions that result in initialization by copying are lowered to a copy
constructor call, by defining a specific copy constructor the struct loses the posibility
of any standard copying. This is not acceptable, because we want the user to define only
the situations that are of interest and have the compiler generate the code for the default
cases.

In order to solve this problem, there are 2 solutions:

1. When at least one copy constructor is defined by a user, generate all copy constructors
with the signature `@implicit this(ref $q S) $q`. This solution has the advantage that
all initializations by copying can be directly lowered to a copy constructor call without
any other checks, but has the disadvantage that for any struct that defines one copy
constructor, another 8 have to be generated (mutable, `const`, `const inout`, `inout`, `immutable`,
`const inout shared`, `inout shared`, `const shared`, `shared`), regardless of the fact that
none might be used. This can be optimized by generating a templated copy constructor which will
be instantiated depending on the use case, but this still is not optimal in terms of compilation
time.

2. Whenever an initialization by copying is encountered, a call to a copy constructor is tried
and if a matching copy constructor is found it is used, otherwise if no copy constructor is
suitable, standard copying is employed (and if that also fails, an error is issued).
This solution has the advantage that no copy constructor is generated `apriori` and all
undefined copies are treated by the standard copying (if possible). This solution is optimal
in terms of compilation time, since no code is generated at all, therefore it is the one
chosen in the design of the copy constructor.

#### Overload resolution in the presence of parameters with copy constructors

For a function in an overload set each argument is matched against the parameter the following way:

1. Check if the argument type is a direct match to the parameter type.
2. If not, check if the argument type is implicitly convertible to the parameter type.
3. If not, check if the argument has a copy constructor that converts it to the parameter type.

In the first 2 situations, if the check is true for a specific overload and that overload
is selected to be called, if any of the parameters have a matching copy constructor, it will get called,
otherwise, standard copying is employed. In the third situation, the overload is matched based on the
conversion resulted from the copy constructor, therefore it the copy constructor will surely get called:

```d
struct A
{
    int[] a;
    @implicit this(ref shared A) immutable {}
}

void fun(const A a) {}                  // 1
void fun(immutable A a) {}              // 2

struct B
{
    int a[];
    @implicit this(ref A) shared {}             // ctor1
    @implicit this(ref A) const {}              // ctor2
    @implicit this(ref shared A) shared {}      // ctor3
    @implicit this(ref immutable A) const {}    // ctor4
}

void gun(shared A) {}    // 3
void gun(const A) {}     // 4

void main()
{
    A a;
    fun(a);             // calls 1 - conversion to const match; standard copying

    const A a1;
    fun(a1);             // calls 1 - direct match; standard copying

    shared A a2;
    fun(a2);             // calls 2 - conversion with copy ctor match; call copy ctor on parameter

    B b;
    fun(b);              // error: both gun functions match, because copy
                         // ctor matches both ctor1 and ctor2

    const B b1;
    fun(b1)               // calls 4 - direct match; standard copying

    immutable B b2;
    fun(b2);              // calls 4 - conversion to const match; call ctor4

    shared B b3;
    fun(b3);              // calls 4 - direct match; call ctor3
}
```

#### Interaction with `alias this`

There are situations in which a struct defines both an `alias this` and a copy constructor, and
for which assignments to variables of the struct type may lead to ambiguities:

```d
struct A
{
    int a;
    immutable(A) fun()
    {
        return immutable A(7);
    }

    alias fun this;

    @implicit this(ref A another) immutable {}
}

struct B
{
    int a;
    A fun()
    {
        return A(7);
    }

    alias fun this;

    @implicit this(ref B another) immutable {}

}

void main()
{
    immutable A ia;
    A a = ia;            // 1 - calls copy constructor

    B bc;
    B b = bc;            // 2 - b is evaluated to B.fun
}
```

In situations where both the copy constructor and `alias this` are suitable
to solve the assignment (1), the copy constructor takes precedence over `alias this`
because it is considered more specialized (the sole purpose of the copy constructor is to
create copies). However, if no copy constructor in the overload set matches the exact
qualified types of the source and the destination, the `alias this` is preferred (2).

#### Generating copy constructors

A copy constructor is generated for a `struct` S  if one of S's fields defines
a copy constructor that S does not define.

A field of a `struct` may define multiple copy constructors. In this situation,
a copy constructor is generated for each overload.

```d
struct M
{
    @implicit this(ref immutable M) {}
    @implicit this(ref immutable M) shared {}
}

struct S
{
    M m;
    @implicit this(ref shared S) {}
    /* The copy constructors with the following signatures are generated:
        @implicit this(ref immutable S)
        @implicit this(ref immutable S) shared
     */
}
```

The body of all the generated copy constructors does memberwise initialization for all
the fields:

```d
{
    this.field1 = s.field1;
    this.field2 = s.field2;
    ...;
}
```

Inside the body of the generated copy constructors, for the fields that define a copy
constructor, the assignment will be rewritten to a call to it; for those that do not,
standard copying is employed, if possible. If certain fields cannot perform copies
(for example: the copy constructor is disabled), the generated copy constructor will be
annotated with `@disable`.

If copy constructors for fields intersect, a single copy constructor is generated:

```d
struct A
{
    int a;
    @implicit this(ref A rhs)
    {
        this.a = rhs.a;
    }
}

struct B
{
    int[] b;
    @implicit this(ref B rhs)
    {
        this.b = rhs.b.dup;
    }
}

struct C
{
    A a;
    B b;
    /* the following copy constructor is generated for C:

    @implicit this(ref C rhs)
    {
        this.a = rhs.a;       // which, in turn, is lowered to a.__copyCtor(rhs.a);
        this.b = rhs.b;       // which, in turn, is lowered to b.__copyCtor(rhs.b);
    }
    */
}
```

#### Generating `opAssign` from a copy constructor

The copy constructor is used to initialize an object from another object, whereas `opAssign` is
used to copy an object to another object that has already been initialized:

```d
struct A
{
    int a;
    immutable int id;
    this(int a, int b)
    {
        this.a = a;
        this.b = b;
    }
    @implicit this(ref A rhs)
    {
        this.a = rhs.a;
        this.b = rhs.b;
    }
    void opAssign(A rhs)
    {
        this.a = rhs.a;
    }
}

void main()
{
    A a = A(2);
    A b = a;      // calls copy constructor;
    b = a;        // calls opAssign;
}
```

The reason why both the copy constructor and the `opAssign` method are needed is because
the two are type checked differently: `opAssign` is type checked as a normal function whereas
the copy constructor is type checked as a constructor (where the first assignment of non-mutable
fields is allowed). However, in the majority of cases, the copy constructor body is identical
to the `opAssign` one:

```d
struct A
{
    int a;
    this(int a)
    {
        this.a = a;
    }
    @implicit this(ref A rhs)
    {
        this.a = rhs.a;
    }
    void opAssign(S rhs)
    {
        this.a = rhs.a;
    }
}

void main()
{
    A a = A(2);
    A b = a;      // calls copy constructor;
    b = a;        // calls opAssign;
}
```

In order to avoid the code duplication resulting from such situations, ideally, the user could
define a single method that deals with both copy construction and normal copying. This is possible
in certain situations which will be discussed below:

1. If the struct contains any `const`/`immutable` fields, it is impossible to use the copy constructor
for `opAssign`, because the copy constructor might initialize them. Even if the copy constructor doesn't
modify the `const`/`immutable` fields the compiler has to analyze the function body to know that, which
is problematic in situations when the body is missing. In conclusion, `opAssign` can be generated from the
copy constructor when the `struct` contains only assignable (mutable) fields.

2. The copy constructor signature is : `@implicit this(ref $q1 S rhs) $q2`, where `q1` and `q2` represent the
qualifiers that can be applied to the function and the parameter (`const`, `immutable`, `shared`, etc.). The
problem that arises is: depending on the values of `$q1` and `$q2` what should the signature of `opAssign` be?

A solution might be to generate for every copy constructor its counterpart `opAssign`: `void opAssign(ref $q1 S rhs) $q2`.
However, when is a `const`/`immutable` `opAssign` needed? There might be obscure cases when that is useful, but those are
niche situations where the user must step it and clarify what the desired outcome is and define its own `opAssign`. For
the sake of simplicity, `opAssign` will be generated solely for copy constructors that have a missing `$q2`.

3. If the struct that has a copy constructor does not define a destructor, it is easy to create the body of the
above-mentioned `opAssign`:

```d
void opAssign(ref $q1 S rhs)    // version 1
{
    S tmp = rhs;        // copy constructor is called
    memcpy(this, tmp);  // blit it into this
}
```

If the `struct` does define a destructor, it has to get called on the destination:

```d
 void opAssign(ref $q1 S rhs)   // version 2
{
    this.__dtor;           // ensure the dtor is called
    memcpy(this, S.init)   // bring the object in the initial state
    this.copyCtor(rhs);    // call constructor on object in .init state
}
```

The problem with the above solution is that it does not take into account the fact
that the copyCtor may throw and if it does, then the object will be in a partially
initialized state. In order to overcome this, two temporaries are used:

```d
void opAssign(ref $q1 S rhs)    // version 3
{
    S tmp1 = rhs;                // call copy constructor
    S tmp2;

    // swapbits(tmp1, this);
    memcpy(tmp2, this);
    memcpy(this, tmp1);
    memcpy(tmp1, tmp2);

    tmp1.__dtor();
}
```

In this version, if the copy constructor throws the object will still be in a valid state.

If the copy constructor is marked `nothrow` and the struct defines a destructor, then
`version 2` is used, otherwise `version 3`. If the `struct` does not define a destructor,
`version 1` is used.

The generated `opAssign` functions inffer their attributes based on the copy constructor
and destructor attributes.

## Breaking Changes and Deprecations

1. The parameter of the copy constructor is passed by a mutable reference to the
source object. This means that a call to the copy constructor may legally modify
the source object:

```d
struct A
{
    int[] a;
    @implicit this(ref A another)
    {
        another.a[2] = 3;
    }
}

void main()
{
    A a, b;
    a = b;    // b.a[2] is modified
}
```

A solution to this might be to make the reference `const`, but that would make code like
`this.a = another.a` inside the copy constructor illegal. Of course, this can be solved by means
of casting : `this.a = cast(int[])another.a`.

2. If `@implicit` is used in existing code for a constructor, the constructor will be silently changed
to a copy constructor:

```d
enum implicit = 0;
struct C
{
    @implicit this(ref C another) {}    // normal constructor before DIP, copy constructor after
}
```

3. With this DIP `@implicit` becomes a compiler recognised attribute that can be used solely to
distinguish copy constructors from normal constructors. This will break code that used `@implicits`
as a used defined attribute:

```d
enum implicit = 0;
@implicit void foo() {}     // error: `@implicit is used solely to mark the definition of a copy constructor`
```

## Copyright & License

Copyright (c) 2018 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## Review

The DIP Manager will supplement this section with a summary of each review stage
of the DIP process beyond the Draft Review.
