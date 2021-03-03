# Copying, Moving, and Forwarding

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | 1040                                                            |
| Review Count:   | 0                                                               |
| Author:         | Max Haughton<br>Walter Bright walter@digitalmars.com            |
| Implementation: |                                                                 |
| Status:         | Draft                                                           |

## Abstract

Introduces the notion of a *Moveable Reference* and
describes a mechanism by which extra copies of an object need not be generated when
passing an object down through layers of function calls, when constructing objects,
and when assigning to objects. Introduces the *Move Constructor* and *Move Assignment*.


## Contents
* [Rationale](#rationale)
* [Prior Work](#prior-work)
* [Description](#description)
* [Breaking Changes and Deprecations](#breaking-changes-and-deprecations)
* [Reference](#reference)
* [Copyright & License](#copyright--license)
* [Reviews](#reviews)


## Rationale

NRVO (Named Return Value Optimization) [1] eliminates redundant copies of objects when
objects are returned from functions. The converse problem, redundant copies of objects
when passing them into functions is only partially resolved by passing them by `ref`.
In particular, when an object is an rvalue, it is usually more efficient to move it to the called
function rather than passing a copy, because copies tend to be less efficient to create
and require an extra destruction. Similarly, if the argument to a function is the last use
of the object, the object can be moved rather than copied.

Equivalently, if an rvalue or a last use is used to construct an object, this can be
more efficiently done using a move constructor rather than a copy constructor. The
same goes for assignments.

Passing an rvalue or last use through multiple function calls should not result in extra
copies of the object being made.

D currently cannot link to C++ functions with C++ rvalue reference parameters, as D has no
notion of rvalue reference parameters.


### Initialization

A variable is initialized by construction, copying a value into it (copy construction)
or moving a value into it (move construction).


### Assignment

Assignment can be divided into two steps:

1. destruction of the existing value

2. initialization, via copy or move, of the new value

Combining the two into one function can result in efficiency gains.


### Parameters

Consider a function f:

```
struct S { ... }
void f(S s);
```
where `s` is constructed into the parameter.

We'd like to move rather than copy, when possible, because it is
more efficient. If it is being called with an rvalue:

```
f(S());
```
it should be a move. If it is called with the last use of an lvalue:
```
S s;
f(s);  // copy
f(s);  // copy
f(s);  // move
```
we should like that last use to be a move. (I.e. being a move should
not be if and only if it is an rvalue.)


### Forwarding

Consider a function `fwd`:

```
ref S fwd(return ref S s) { return s; }
```
which we would like to be used to forward its argument like so:

```
void f(S s);
...
S s;
f(fwd(s));  // copy
f(fwd(s));  // copy
f(fwd(s));  // move
f(fwd(S()); // move
```
and have no extra copies or moves are made as a side effect of this forwarding
process.


### Problems D Doesn't Have

C++ only allows rvalues to be converted to const references:

http://thbecker.net/articles/rvalue_references/section_07.html

which causes half of the perfect forwarding problems. D
doesn't have that problem, as rvalues can be converted
to mutable references.


## Prior Work

### C++

The problem is described as
[The Forwarding Problem in C++](http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2002/n1385.htm).
This problem was addressed in C++ with the addition of *Rvalue References* described
in [Rvalue References Explained](http://thbecker.net/articles/rvalue_references/section_01.html).

### Rust

Rust types aren't annotated as moveable or copiable - moveable is the default,
and copies are only made if the type implements the `Copy` trait. In practice,
how a value gets passed to a function isn't changed when this happens (usually
a memcpy but LLVM can do whatever it wants, including passing a pointer to it).
The only difference is that the variable used as an argument isn't moved from,
which enables the program to use it after the function call. For this reason,
types with a destructor (technically, that implement the `Drop` trait) cannot
implement `Copy`. Furthermore, copy semantics aren't hookable - there's no way
to override how a type is copied via, say, a copy constructor. Likewise for moves.

Functions themselves do not know or care if the argument was copied or moved.

### D

## Existing State in D

1. function templates with auto ref parameters
https://dlang.org/spec/template.html#auto-ref-parameters

2. Existing implementation of rvalues to ref per Andrei's presentation at DConf 2019.
https://gist.github.com/andralex/e5405a5d773f07f73196c05f8339435a
https://digitalmars.com/d/archives/digitalmars/D/Binding_rvalues_to_ref_parameters_redux_325087.html
Implementation: https://github.com/dlang/dmd/pull/9817


## Existing Proposals for D

SAOC 2019 Milestone 1 report
https://gist.github.com/SSoulaimane/1331475240e85c0afa96bb1c495e6155

Move Semantics DIP
https://github.com/RazvanN7/DIPs/blob/Move_Constructor/DIPs/DIP1xxx-rn.md

digitalmars.D - Discussion: Rvalue refs and a Move constructor for D
https://digitalmars.com/d/archives/digitalmars/D/Discussion_Rvalue_refs_and_a_Move_construtor_for_D_330251.html

Martin Kinkerlin's idea for how to represent rvalue refs
https://digitalmars.com/d/archives/digitalmars/D/Discussion_Rvalue_refs_and_a_Move_construtor_for_D_330251.html#N330277




## Description

The design is without additional keywords, attributes, or syntax.


### Move Constructor

A *Move Constructor* is a struct member constructor that moves, rather than copies,
the argument corresponding to its first parameter into the object to be constructed.
The argument is invalid after this move, and is not destructed.

A Move Constructor for `struct S` is declared as:

```
this(S s) { ... }
```

The Move Constructor is always nothrow, even if `nothrow` is not explicitly specified.
A Move Constructor that throws is illegal.

If a Move Constructor is not defined for a struct that has a Move Constructor in
one or more of its fields, a default one is defined, and fields without a Move Constructor
are moved using a bit copy.

If a Move Constructor is not defined for a struct that has a Move Assignment Operator,
a default Move Constructor is defined and implemented as a move for each of its fields,
in lexical order.

The Move Constructor is selected if the argument is an rvalue, or the last use of an lvalue:

```
struct S { ... declare EMO ... }
...
{
  S s = S(); // move constructor
  S u = s;   // copy constructor
  S w = s;   // move constructor
}
```

Both the parameter and the constructor can have type qualifiers. Only combinations where the
parameter's type can be implicitly converted to the constructee's type are allowed.


### Move Assignment Operator

A *Move Assignment Operator* is a struct member assignment operator that moves, rather than copies,
the argument corresponding to its first parameter into the constructed object.
After the move is complete, the destructor is called on the original contents of the constructed
object.
The argument is invalid after this move, and is not destructed.

A Move Assignment Operator for struct S is declared as:

```
void opAssign(S s) { ... }
```

The Move Assignment Operator is nothrow, even if `nothrow` is not explicitly specified.

If a Move Assignment Operator is not defined for a struct that has a Move Assignment Operator in
one or more of its fields, a default one is defined, and fields without a Move Assignment Operator
are moved using a bit copy.

If a Move Assignment Operator is not defined for a struct that has a Move Constructor,
a default Move Assignment Operator is defined and implemented as a move for each of its fields,
in lexical order.

The Move Assignment Operator is selected if the argument is an rvalue, or the last use of an lvalue:

```
struct S { ... declare EMO ... }
...
{
  S s, u, w;
  s = S(); // move assignment
  u = s;   // copy assignment
  w = s;   // move assignment
}
```

Both the parameter and the Move Assignment Operator can have type qualifiers. Only combinations where the
parameter's type can be implicitly converted to the operatee's type are allowed.


### Elaborate Move Object (EMO)

An EMO is a struct that has both a Move Constructor and a Move Assignment Operator.
An EMO defaults to exhibiting move behavior when passed and returned from functions
rather than the copy behavior of non-EMO objects.


### Overloading EMO

EMO objects follow the same overloading rules as non-EMO objects.


### Move Ref

A *Move Ref* is a parameter that is a reference to an EMO. (The `ref`
is not used.)

```
S func(return S s) // parameter is passed by Move Ref, and returned by value
{
    return s;
}

ref S func(return ref S s) // parameter is passed and returned by reference
{
    return s;
}
```
It is not possible to pass
or return a non-EMO object by Move Ref.


### Calling by Move Ref

```
struct S { ... declare EMO ... }

...
func(S()); // S() creates an rvalue, and a reference
           // to that rvalue is passed to func()

void func(S s) // call by Move Ref (not by value)
{
    ...
    // s is destructed here
}
```
The caller has transferred (i.e. moved) responsibility for the destructor call
for the rvalue to the callee `func()`.

```
struct S { ... declare EMO ... }

...
S s;
func(s); // implementation dependent if a copy of s is made to pass to func()
```
If the implementation can determine that `s` in the call to `func(s)` is the
*Last Use* of `s`, then
it can move `s` to `func()` by passing the address of `s`
to it. If it cannot so determine, it will make a copy of `s` using `s`'s copy
constructor, and pass the address of the copy to `func()`.


### Returning an EMO by Value

```
S func()
{
    S s;
    return s;
}
```

This works exactly as it does currently for non-EMO objects. In particular,
the usual NRVO optimizations are done to minimize copying. No moving or
copying is done when NRVO happens, the `s` is constructed directly into
its return value on the caller's stack. If NRVO cannot be performed, `s`
is copied to the return value on the caller's stack.


### Returning an EMO by Move Ref

```
S func(return S s)
{
    return s;
}
```

The `return` on an EMO parameter, and the return type matching the type of the
parameter, indicates that the return is by Move Ref, and behaves equivalently
to the non-EMO semantics of:

```
struct T { } // T is not an EMO

ref T func(return ref T t)
{
    return t;
}
```
The function `func()` does not destruct `s`, that obligation is transferred to
the caller. In this way functions can be "pipelined" together, with the EMO being
moved from one to the next by merely passing along the pointer.


```
S func(return S s)
{
    S s2;
    return s2;  // error, can't return local by Move Ref
}
```

### Returning an EMO by `ref`

Returning a local EMO by `ref` is an error, just as for non-EMO objects.

```
ref S f(S s)
{
    return s; // error
}

ref S g()
{
    S s;
    return s; // error
}
```

### Passing an EMO by `ref`

The semantics of passing an EMO by `ref` are the same as for non-EMO objects.
For example,

```
void func(ref S);
...
S s;
void func(s);
```
is allowed and the responsiblity of destructing `s` remains with the caller.


### Assigning a `ref` EMO to a non-`ref` EMO

Consider:
```
void func(ref S s)
{
    S t;
    t = s;  // `s` is copied, not moved, to `t`
}
```
This is because explicit `ref` to EMOs do not own the object they refer
to, so the only choice is to copy it.

The same semantics apply to passing a `ref` EMO to a non-`ref` parameter:
```
void func(S);

void g(ref S s)
{
    func(s); // a copy of `s` is made
}
```

### Forwarding

Referring back to our desired forwarding function `fwd`:

```
ref S fwd(return ref S s) { return s; }
```
which we would like to be used to forward its argument like so:

```
void f(S s);
...
S s;
f(fwd(s));
f(fwd(S());
```
Ownership of the argument to fwd() is retained by the caller,
and so the caller will be responsible for its destruction.
When the call is made to f(), a copy is made.

If `fwd()` is inlineable, however, the compiler is allowed to examine
its implementation. If implementation actually does return only a ref to the
parameter `s`, the copy can be elided if it was the last use of `s`.
Much like NRVO, it is implementation
dependent whether this copy elision takes place.



### EMO and Garbage Collection

The current semantics are defined so that a naive compacting garbage collector
can move objects with a mere memcpy. The restriction is that no fields of an object
can contain a pointer to that same object. Currently, there isn't a naive compacting
collector for D, so this hasn't been a problem. A collector that tracks where the
pointers are in an object would not have this issue.

Ironically, because move constructors execute arbitrary code, this likely would interfere
with the collector keeping track of the state of memory during a collection cycle,
meaning that objects with move constructors would likely be pinned (treated as immoveable).


### Class Objects

Class objects cannot have move constructors or move assignment operators.


### Last Use

The *Last Use* of an lvalue is the last time in a path of execution that any read
or write is done to the memory region referred to directly by the lvalue. The last use
of variable declarations is identified by doing dataflow analysis on function local
variables and function parameters that are passed by value. Global variables and `ref`
parameters are not checked for last use. For example, for a given function `f`:

```
void fun(S s);
void f()
{
    S s;
    <stmt_1>;
    <stmt_2>;
    ....
    fun(s);
    ....
    <stmt_n>;
}
```

The call to `fun` is the last access of `s` if and only if all the statements following it,
up to `<statement_n>` do not access `s` at all.

The Last Use of an EMO lvalue will be a move, otherwise it will be a copy.

```
{
  S s;
  func(s);  // not last use of s, copy
  func(s);  // last use of s, move
}
```

**Return statements**. If a function local variable or function parameter passed by value is
returned directly via `return x`, that is the last use of `x`. If the return argument is an
expression that is using `x` several times, the rightmost use of `x` will be considered the
last use. For example, in`return fun(x, y, z, x)`, the last use of `x` is when passing the
fourth parameter.

**Nested functions and lambdas**. Module level functions that contain nested functions or
lambda functions that access an outer local variable will not be subject to last use dataflow
analysis. The reason is that a pointer to the nested function or lambda could be escaped from
the containing function:

```
void gun();
void sun();
auto fun()
{
    S a;
    void nested() { gun(a); }
    sun(a);                 // last use of `a` in `fun`, but a pointer to `nested`
                            // is escaped and `nested` accesses `a`
    return &nested;
}
```

Local variables and by value parameters of nested functions are subject to the same last use
analysis as module level functions.

**Multiple last accesses**. A variable may have multiple last accesses. For example:

```
S foo(bool flag)
{
    S s;
    if(flag)
        return fun(s);
    else
        return gun(s);

    //return s; -> would invalidate previous last accesses, becoming the new last access of `s`
}
```

**Loop statements**. Local variable/Function parameter passed by value accesses inside
`while`/`for`/`do-while`/`foreach` bodies will be regarded as last accesses solely in
the following 2 situations: (1) the access is on an execution path that ends the loop
(return, break, goto outside of the loop body -with respect to the goto rules mentioned
below-) or (2) the variable lifetime does not exceed a loop iteration:

```
void gun(S s);
S foo()
{
    S s;
    while (cond)
    {
        if (cond2)
            return s;     // case (1) last use -> move
        else if (cond3)
            func(s);      // copy
        else
        {
            S s;
            gun(s);       // case(2) move
        }
    }
    return S();
}
```

**Gotos**. An lvalue access that is preceded (directly or not) by a label and succeeded by a `goto` to the aforementioned label, will not be considered a last access (even though the `goto` might not be executed in certain runtime paths).

```
void foo()
{
    S s1;
    int a;
l1:
    ++a;
    func(s1);     // not last access.
    if (a != 42)
       goto l1;

    S s2;
    int b = gun(s2);   // not last access, because of sun(s2); gotos to labels that
                       // do not preced the access of an lvalue do not affect the DFA
    if (b != 42)
        goto l2;
    sun(s2);
l2:
}
```

**Static conditions**. Compile time conditions do not affect the last access decision mechanism. The DFA will be run after all the static conditions have been evaluated:

```
void foo(T)()
{
    S s;
    func(s);                // this will be the last access of s when foo is
                            // instantiated with anything other than S
    static if(is(T == S))
        gun(s);
    else
        fun(a);
}
```

**AndAnd/OrOr expressions**. *e1 || e2* and *e1 && e2* expressions are treated the following way:

  * if `e1` accesses `x` and `e2` does not, then `e1` is the last access of `x`;
  * if `e2` accesses `x` and `e1` does not, then `e2` is the last access of `x`;
  * if both `e1` and `e2` access `x`, then `e2` is the last access of `x`;

**Partial move**. A variable of an aggregated type (struct or class) may contain an EMO field:

```
void fun(T t);
void gun(S s);
struct S
{
    T t;    // T is EMO
}
{
    S s;
    fun(s.t);
    gun(s);
}
```

Although the call to `fun` is the last time `s.t` is accessed, `s` is still used after that. To correctly
treat this situation, it is necessary, that `s.t` will make a copy, otherwise when `gun` is called `s` will
be in a partially invalid state (the move could potentially alter `s.t`). However, if `fun` would be the last
access of `s`, then it would be no problem to move `t`. Therefore, the generalized rule is that an access to
an EMO field of an aggregate will be moved only if that is the last access of the containing variable.

**Pointers**. Whenever the address of a variable `x` is taken, `x` will lose the possibility of last access optimization.
For example:

```
{
  S s;
  int* p = &s.i;
  func(s);  // not last use of s
  *p = 3;   // because s is still being written to
}
{
  ...
  S s;
  S* ps = &s;
  func(s);      // not last use
  int j = ps.i; // because s is still being read
}
{
  ...
  S s;
  S* ps = &s;
  func(s);   // ps still points to s, so it's not last use, even if ps is never used
}

struct T { int j; S s; ~this(); }

{
  T t;
  func(t.s);  // not last use because of T's destructor
}
```

An expression yielding an rvalue of an EMO is always the Last Use of that rvalue,
and a move is done.

```
void func(S);
...
func(S());  // S() is an rvalue, so always a move
```


### Destruction

Moving an EMO means that the responsiblity for destruction of that value
moves along with it.

```
S test(S s)
{
    return func(s); // destruction of s is now func's responsibility
}
```


For merging control paths where one path may have moved the lvalue:

```
{
    S s;
    if (cond)
        func(s); // copy or move?
    s.__dtor();  // but what if s was moved?
}
```
the implementation may choose to use a copy, or can use a move with a flag
that gates the destructor call:
```
{
    S s;
    bool flag = true;
    if (cond)
    {
        func(s); // copy or move?
        flag = false;
    }
    flag && s.__dtor();
}
```
If `func()` may throw an exception, `flag` must be set to false before
`func()` is called.

#### Assignment after Move

```
S s, t;
func(s); // A
s = t;   // B
```
may be compiled two ways:

1. A: `s` is copied, B: `s` is assigned
2. A: `s` is moved, B: `s` gets constructed, not assigned

at the implementation's discretion. Case 1 can be done for a quick build,
case 2 for an optimized build.

The reason for this is the non-default assignment operator will destruct the
original contents of the target, meaning it must still be live. But a move
operation would leave the contents in an undefined state. The move/construct
should be more efficient at runtime than the copy/assign.


### Example: The Swap Function

If `S` is an EMO, the swap function is:
```
void swap(ref S s, ref S t)
{
    S tmp = s;
    s = t;
    t = tmp;
}
```
Since there are no uses of rvalues, use of move semantics would rely on the
implementation determining that each read is the last use.


### Inefficiency


#### copy then move

```
struct S { ... declare EMO ... }
struct T { S s; }

void func(S u)
{
    T t;
    t.s = u;  // move
}

S g()
{
    S s;
    func(s);  // copy
    return s;
}
```

Note that first a copy of `s` is made, then a move of `u`. This isn't as
efficient as just a copy. If this turns out to be a problem, regular ref's
can be used:

```
struct S { ... declare EMO ... }
struct T { S s; }

void func(ref S u)
{
    T t;
    t.s = u;  // copy
}

S g()
{
    S s;
    func(s);  // pass by pointer
    return s;
}
```

and even both overloads can be provided:

```
void func(S);
void func(ref S);
```
and the overload rules will pick the `ref` version for lvalues, and the non-`ref`
for rvalues.



### Interfacing with C++

#### Rvalue Reference

A Move Ref is corresponds with a C++ rvalue ref. This means that to interface with
C++ rvalue ref parameters, the object on the D side has to be an EMO.

D:

```
struct S { ... declare EMO ... }
void func(S);
```
C++:
```
struct S { ... };
void func(S&&);
```

### State of Object After Move

When D moves an object, the memory region left behind is left in
an undefined state. The destructor won't be called on it.
When C++ moves an object, it expects the memory region left behind
to be valid and in a destructible state. Therefore, for objects
that are to be interoperable with C++, the Move Constructor and
Move Assignment Operator should also leave the moved from object
in a destructible state. The most pragmatic way to achieve that is
to set it to its default .init state.

### Value Parameters

While it appears that C++ best practice is to use rvalue references instead
of values for parameters, there remains plenty of legacy code that uses values.
In order to interface to C++ value parameters, a means is necessary to force
it for `extern (C++)` functions.

The storage class `@value` applied to an EMO would cause it to be a value parameter.
It would be ignored for non-EMO parameter types (to facilitate generic code).
`@value` is allowed in combination with `ref` or `out` storage classes.


## Breaking Changes and Deprecations

Code that relied on [this bug](https://issues.dlang.org/show_bug.cgi?id=20424)
will no longer work.


## Reference

[1] [Named Return Value Optimization](https://en.wikipedia.org/wiki/Copy_elision)


## Acknowledgements

This has been in development for a long time, and many people have made crucial contributions
of ideas, critique, and evaluation that resulted in this proposal:

Razvan Nitu, Andrei Alexandrescu, Sahmi Soulaimane, Martin Kinkelin, Manu Evans, Atila Neves,
Mike Parker, Ali Cehreli

## Copyright & License
Copyright (c) 2019, 2021 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)


## Reviews


