# First class functions

| Section        | Value                                  |
|----------------|----------------------------------------|
| DIP:           | 27                                     |
| Author:        | Amaury SÉCHET                          |
| Status:        |                                        |

## Abstract

This DIP is the first of 3. It intends to define what is a function in D. The DIP proposes to radically simplify functions' behavior first class functions. The DIP proposes ways to mitigate breakage involved and allow optional parenthesis when no confusion is possible.

## Description

D currently has first class function, and what I'll call second class function. They are defined as follow :

```d
ReturnType secondClass(Parameters) {
  // Function body.
}
```

First class and second class function both have their own behavior. In this DIP, I propose to define second class function such as :
 * Taking the address of a second class function return a first class function.
 * A second class function implicitely convert to a first class function.

The behavior of a first class function is altered such as it is possible to use optional parentheses. See the optional parentheses section below for the details of the behavior.

The function keyword in is expression now match function type instead of second class function. See the is expression section below for detail behavior.

### Rationale

D is a very complex language. It promotes several paradigms while being a system language. If this is a force of D, this is also a source of trouble. In fact every feature can combine itself why many other features, some of them from different paradigms - other way of thinking - and every single special case, cause a combinatorial explosion of special cases when other features are involved.

This problem is experienced by many D users who try to use advanced features together in non trivial projects. Combined together, special cases lead to surprising behaviors, unnecessary blockades, and sometime compiler bugs.

If it is impairing users, it is also impairing polishing the language, as many corner cases have to be considered, and cause difficulties for compiler implementers and libraries creators that uses generic techniques.

To solve, or at least reduce that problem, D specification needs to promote simplicity (as opposed to complexity, not difficulty). To move toward this goal, this DIP reduce all function to a single entity : the D first class function. It rid of functions like defined in C or C++, as they are useless and essentially accidental complexity.

### Optional parentheses

Redundant parenthesis can be a burden for argument-less functions (or single argument function calls used as UFCS). An implicit function call is performed in the following cases :

1. When .identifier lookup fails on the function :

```d
uint foo() {
  return 0;
}

void bar(uint function() a) { writeln("function bar"); }
void bar(uint a) { writeln("uint bar"); }

foo.bar(); // function bar
foo().bar(); // uint bar

void buzz(uint a) {}
foo.buzz(); // OK: Implicit call to foo is added as lookup failed on the function.
```

2. When used in a foreach :

```d
import std.algorithm;
 
void main() {
  foreach(i; iota(5).map!(n => n * n)) {
    import std.stdio;
    writeln(i); // Prints 0 then 1, 4, 9 and 16.
  }
}
```

3. When used as an expression statement that has no effect :

```d
uint foo() {
  return 0;
}

auto bar = foo;

foo; // Will call foo.
bar; // Will call foo as well.
```

You must note that this is a regular first class function behavior, so optional parentheses apply regardless how the function is defined :

```d
auto foo = function uint() {
  writeln("foo called !");
  return 42;
}

void bar(uint function() a) { writeln("function bar"); }
void bar(uint a) { writeln("uint bar"); }

foo.bar(); // function bar

void buzz(uint a) {}
foo.buzz(); // foo called !
```

This effectively will allow the use of optional parenthesis on first class functions, which obviate the need to keep second class function to be able to benefit from optional parenthesis.

### Is Expression

The function type specialization used in is expression is modified such as it matches first class function, and alias parameters as defined on https://dlang.org/spec/expression.html#IsExpression .

```d
void foo() {}
auto bar = foo;

static assert(is(typeof(foo) == function)); // OK
static assert(is(typeof(bar) == function)); // OK
static assert(is(void function() == function)); // OK
```

Matching parameters using an identifier is also affected to work with all first class functions.

```d
static assert(is(typeof(foo) P == function)); // OK, P is an empty sequence.
static assert(is(void function(uint) P == function)); // OK, P is an a sequence of one element : uint.
```

### Breaking changes / deprecation process

The first area where this DIP breaks code is when it comes to optionnal parentheses. The specifications is such as most current uses of optional parenthesis will keep the same semantic. The current semantic is essentially accidental and a great source of confusion.

Breakage will occur when a function's result is passed as argument to another function using optional parenthesis. The case is uncommon enough and even proved itself to be a confusing enough to be justification to introduce breaking changes in phobos, for instance, disabling argumentless text calls.

The compiler should warn about this for a while before actually changing the behavior, but, considering this has waranted change in phobos API to work around, the breakage is justified and in fact, desirable.

The second area of breakage is the use of is expression to differenciate first and second class function. This can be replaces by testing, for instance, if the function is an rvalue. This was a source of bugs in phobos in the past (notably in std.getopt) as people expect the is expression to match first and second class function. This is has also been a source of problems in phobos - made and reviewed by experienced D users, it is unrealistic to expect regular user to get it right. Therefore, this breakage is also a welcome simplification of the language.

## Copyright & License

Copyright (c) 2016 by Amaury SÉCHET

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)
