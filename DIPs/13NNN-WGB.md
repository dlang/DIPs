# Copying, Moving, and Forwarding

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | (number/id -- assigned by DIP Manager)                          |
| Review Count:   | 0 (edited by DIP Manager)                                       |
| Author:         | Walter Bright walter@digitalmars.com                            |
| Implementation: | (links to implementation PR if any)                             |
| Status:         | Will be set by the DIP manager (e.g. "Approved" or "Rejected")  |

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
In particular, when an object is an rvalue, it is more efficient to move it to the called
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

A variable is initialized by copying a value into it (copy construction)
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

Consider a function g:

```
ref S g(return ref S s) { return s; }
```
which can be used to forward its argument like so:

```
S s;
f(g(s));  // copy
f(g(s));  // copy
f(g(s));  // move
f(g(S()); // move
```
no extra copies are made as a side effect of this forwarding
process.

An alternative view of this issue:

```
void h(ref S s) { f(s); }
...
S s;
h(s);   // copy
h(s);   // copy
h(s);   // move
h(S()); // move
```

I.e. again no extra copies of are made.


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

Rust types are annotated as "moveable" or "copyable", rather than the function parameter.

An rvalue cannot be moved.

A moveable type can be copied at the call site with an explicit copy (like D's .dup property).

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

If a Move Constructor is not defined for a struct that has a Move Constructor in
one or more of its fields, a default one is defined, and fields without a Move Constructor
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

### Elaborate Move Object (EMO)

An EMO is a struct that has both a Move Constructor and a Move Assignment Operator.
An EMO defaults to exhibiting move behavior when passed and returned from functions
rather than the copy behavior of non-EMO objects.


### Overloading EMO

EMO objects follow the same overloading rules as non-EMO objects.


### Move Ref

A *Move Ref* is a parameter or a return value that is a reference to an EMO. (The `ref`
is not used.)

```
S func(S s) // parameter is passed by Move Ref, and returned by Move Ref
{
    return s;
}

ref S func(ref S s) // parameter is passed and returned by reference
{
    return s;
}
```
It is not possible to pass or return an EMO by value. It is not possible to pass
or return a non-EMO object by Move Ref.


### Calling by Move Ref

```
struct S { ... declare EMO ... }

...
func(S()); // S() creates an rvalue, and a reference
           // to that rvalue is passed to func()

void func(S s)
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


### Returning by Move Ref

```
S func()
{
    S s;
    return s;
}
```

The function `func()` does not destruct `s`, that obligation is transferred to
the caller. In this way functions can be "pipelined" together, with the EMO being
moved from one to the next by merely passing along the pointer.

The implementation is very similar to that of non-EMO objects in that a hidden pointer is passed
to `func()` that points to an uninitialized memory region in the caller's stack
frame, `s` is moved to that region, and the hidden pointer is returned.

For:
```
S func(S s)
{
    return s;
}
```
The hidden pointer is still passed to the invocation of `func()`, but the pointer
returned is the reference to the parameter `s`. In this way it differs from non-EMO
objects in that the caller may not rely on the uninitialized memory region holding
the returned object.

The hidden pointer is passed even when it is not needed, as the caller only knows
the signature of the function, not its implementation.


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


### Last Use

The determination of the *Last Use* of an lvalue is crucial in determining
if the use will be a move or a copy. The Last Use is equivalent to being the
end of the *Live Range* of an lvalue.

An expression yielding an rvalue of an EMO is always the Last Use of that rvalue,
and a move is done.

```
void func(S);
...
func(S());  // S() is an rvalue, so always a move
```

Determining if `func(s)` is the last use of lvalue `s` requires *Data Flow Analysis*
in the general case, but simple cases such as:
```
S test(S s)
{
    return func(s);
}
```
should be implementable without DFA.

In general,

```
{
  S s;
  func(s);  // copy
  func(s);  // copy
  func(s);  // move because it's the Last Use
}
```
where the first two calls make copies and the third transfers ownership (and the
responsibility of destruction) of `s`
to `func()` using a move is desirable.

Cases like:
```
struct S { int i; ... declare EMO ... }

...
S s;
int* p = &s.i;
func(s);  // must be copy
*p = 3;   // because p is a live reference to s
```
and:
```
struct S { int i; ... declare EMO ... }

...
S s;
S* ps = &s;
func(s);    // must be copy
ps.i = 3;   // because p is a live reference to s
```
must be detected.

Calls in loops:

```
S s;
while (cond)
    func(s);
```
should always copy.

### Destruction

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

#### hidden pointer

The hidden pointer for EMO return values is still required even when it is
not needed. However, if the function is inlined, the pointer will be recognized
as a dead variable and will be elided by the optimizer.

For:
```
struct S { ... declare EMO ... }
S mars();
S venus()
{
    return mars();
}
```
both `mars()` and `venus()` require a hidden pointer to uninitialized memory
large enough to hold an instance of `S`. But the call to `mars()` can reuse
the hidden pointer passed to `venus()`. But if there are more instances needing
a hidden pointer in one expression, only one can reuse the caller's hidden pointer:

```
struct S { ... declare EMO ... }
S mars(S);
S pluto(S);

S venus(S s)
{
    return mars(pluto(s)); // one of these calls can reuse venus' hidden pointer
}
```

Also, the caller's hidden pointer can be reused if the reuse object size is the
same or smaller size of the caller's hidden pointer's memory area.


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

A Move Ref is corresponds with a C++ rvalue ref.

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

## Breaking Changes and Deprecations

None known.

## Reference

[1] [Named Return Value Optimization](https://en.wikipedia.org/wiki/Copy_elision)


## Acknowledgements

This has been in development for a long time, and many people have made crucial contributions
of ideas, critique, and evaluation that resulted in this proposal:

Razvan Nitu, Andrei Alexandrescu, Sahmi Soulaimane, Martin Kinkelin, Manu Evans, Atila Neves,
Mike Parker, Ali Cehreli

## Copyright & License
Copyright (c) 2019 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)


## Reviews


