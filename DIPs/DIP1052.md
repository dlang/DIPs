# More built-in tuple support

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | 1xxx                                                            |
| Review Count:   | 0                                                               |
| Author:         | Timon Gehr (<timon.gehr@gmx.ch>)                                |
| Implementation: | N/A                                                             |
| Status:         | Will be set by the DIP manager (e.g. "Approved" or "Rejected")  |

## Abstract

This DIP proposes further built-in support for tuples.

## Links

- Walter's original post on tuple unpacking (2010):
  http://forum.dlang.org/post/i8jo6k$sba$1@digitalmars.com
  
  More posts on the topic can be found around October 07, 2010 (threading problems):
  http://forum.dlang.org/group/general?page=767

- DIP 32 (listing many alternative proposals): https://wiki.dlang.org/DIP32

- Some of the feature requests on the forums:
  - (2013) http://forum.dlang.org/post/gridjorxqlpoytuxwpsg@forum.dlang.org
  - (2017) https://forum.dlang.org/thread/glpsggkvxsiwxwfolwog@forum.dlang.org
    - Includes discussion with Steven Schveighoffer, which inspired proposal 2
  - (2017) http://forum.dlang.org/post/cktzfujipzzlloacthka@forum.dlang.org

- Killing the comma operator (2016): https://forum.dlang.org/thread/vcuinavnczqssdyewbjr@forum.dlang.org

## Rationale

The D programming language currently supports tuples with the library primitive `std.typecons.Tuple`, which has the following limitations:

- Tuples have to be unpacked manually:
  ```d
  Tuple!(int, string) foo();

  auto ab = foo(), a = ab[0], b = ab[1];

  int c;
  string d;
  c = ab[0];
  d = ab[1];
  ```

- Tuples have to be expanded manually:
  ```d
  auto a = [1, 2, 4, 7, 2];
  auto b = [3, 5, 3, 2, 4];
  
  int add(int a,int b)
  {
      return a + b;
  }
  auto c = zip(a, b).map!(t => add(t.expand));
  writeln(c); // "[4, 7, 7, 9, 6]\n"
  ```

- Tuple syntax is slightly verbose.


Treating multiple values as one tuple and unpacking a tuple back into multiple values is useful and should be supported with as little friction as possible. Built-in tuple syntax has previously been blocked by the comma operator. Using the result of a comma expression has recently been deprecated, which enables progress on built-in tuple support.

Goals of this DIP:
- Allow manipulating tuples at least as conveniently as in other modern languages with built-in tuple support.
- Maintain backwards-compatibility with std.typecons.Tuple while keeping a clean semantics.
- Minimal language improvements leading to the desired effects.


## Description

This DIP includes six proposals that add more built-in tuple support to D, some of them are independent.

### Proposal 1: Unpacking declarations

We add the following syntactic sugar to unpack AliasSeq's (including via `alias this`).

```d
auto (a, b) = tuple(1, "2");
(int a, string b) = tuple(1, "2");

foreach((x, y); [tuple(1, "2"), tuple(3, "4"), tuple(5, "6")]){
    writeln(x, " ", y); // "1 2\n3 4\n5 6"
}

foreach((int x, string y); [tuple(1, "2"), tuple(3, "4"), tuple(5, "6")]){
    writeln(x, " ", y);// "1 2\n3 4\n5 6"
}
```

The number of values has to match exactly.

Patterns can be nested:

```d
auto (a, (b, c)) = tuple(1, tuple("2", 3.0));
(int a, (string b, double c)) = tuple(1, tuple("2", 3.0));
```

In a pattern where at least one component specifies a type, each component needs to specify a type or at least one storage class:

```d
(int a, b) = tuple(1, "2"); // error
(int a, auto b) = tuple(1, "2"); // ok

(int a, (b, c)) = tuple(1, tuple("2", 3.0)); // error
(int a, auto (b, c)) = tuple(1, tuple("2", 3.0)); // ok
(int a, (auto b, auto c)) = tuple(1, tuple("2", 3.0)); // ok

auto (a, immutable b, c) = tuple(1, "2", 3.0); // ok (restriction does not apply to storage classes)
```

This proposal is independent of whether or not built-in tuple syntax is added.


### Proposal 2: Auto-expansion for `alias this`

When a function is matched against a single argument and matching fails, matching with an `alias this` rewrite is tried (resulting in at most a match with implicit conversion). In particular, if the `alias this` is to an AliasSeq, this allows calling a function with multiple parameters with a single tuple argument.

```d
auto a = [1, 2, 4, 7, 2];
auto b = [3, 5, 3, 2, 4];

auto c = zip(a, b).map!((x, y) => x + y);
```

This is in line with the design of `alias this`.

This proposal is independent of whether or not built-in tuple syntax is added.


### Proposal 3: Built-in tuple types and literals

`std.typecons.Tuple` and `std.typecons.tuple` are moved to object.d and renamed to `__Tuple` and `__tuple` respectively.
`std.typecons.Tuple` and `std.typecons.tuple` become aliases to `__Tuple` and `__tuple` respectively.

The following lowerings are added:

```d
(int, string, double)  ==> __Tuple!(int, string, double)
(1, "2", 3.0) ==> __tuple(1, "2", 3.0)
```

`()` is treated specially: it is the value `__tuple()` by default, but if used in a context where a type is expected, it is the type `__Tuple!()` instead.

Singleton tuples are specified with a trailing comma (the trailing comma is optional for non-singleton tuples):

```d
(int,) t = (1,);
```


### Proposal 4: Unpacking assignments

A tuple of lvalues can be used as an lvalue in an assignment:

```d
(int, string) t = (1, "2");
int a;
string b;
(a, b) = t;

int x = 1, y = 2, z = 3;
(x, y) = (y, x);
assert((x, y) == (2, 1));

((x, y), z) = ((z, x), y); // nesting allowed
assert((x, y, z) == (3, 2, 1));

```

This should only be added if built-in tuple literals are added.


### Proposal 5: Unpacking function arguments

```d
void foo((int x, int y), int z){
    writeln(x, " ", y, " ", z);
}

foo((1, 2), 3); // "1 2 3\n"

auto dg = ((x,y), z) => writeln(x," ",y," ",z);
dg((1, 2), 3); // "1 2 3\n"
```

This should only be added if unpacking declarations are added.


### Proposal 6: Placeholder name `_`

Symbols with the name `_` should not be inserted into the symbol table.

```d
auto (a, _) = t; // extract first element, ignore second element
foreach(_; 0 .. 10){} // repeat 10 times, without introducing a foreach loop variable
```

This is useful independently of the other proposals.

### Grammar changes

The following grammar additions will be sufficient.
(Note that many grammar rules are repeated due to (existing) distinct restrictions on what `StorageClasses` are allowed; this can make the proposed grammar changes look more profound than they are.)

#### Proposal 1 (Unpacking declarations)
(Note that ForeachTupleDeclarators2 is the same as TupleDeclarators2 except that the former allows all `StorageClasses`, while the latter allows only `ForeachTypeAttributes`.)

```diff
  VarDeclarations:
      ...
      AutoDeclaration
+     StorageClasses[opt] TupleDeclarators ;

+ TupleDeclarators:
+     TupleDeclarator
+     TupleDeclarator , TupleDeclarators

+ TupleDeclarator:
+     ( TupleDeclarators2 )
+     ( TupleDeclarators2 ) = Initializer

+ TupleDeclarators2:
+     TupleDeclarator2 ,
+     TupleDeclarator2 , TupleDeclarator2
+     TupleDeclarator2 , TupleDeclarators2

+ TupleDeclarator2:
+     StorageClasses[opt] Identifier
+     StorageClasses[opt] BasicType BasicType2[opt] Identifier
+     StorageClasses[opt] ( TupleDeclarators2 )


  ForeachType:
      ...
      ForeachTypeAttributes[opt] alias Identifier
+     ForeachTypeAttributes[opt] ( ForeachTupleDeclarators2 )

+ ForeachTupleDeclarators2:
+     ForeachTupleDeclarator2 ,
+     ForeachTupleDeclarator2 , ForeachTupleDeclarator2
+     ForeachTupleDeclarator2 , ForeachTupleDeclarators2

+ ForeachTupleDeclarator2:
+     ForeachTypeAttributes[opt] Identifier
+     ForeachTypeAttributes[opt] BasicType BasicType2[opt] Identifier
+     ForeachTypeAttributes[opt] ( ForeachTupleDeclarators2 )
```

#### Proposal 2 (Auto-expansion for alias this)
No grammar changes necessary.

#### Proposal 3 (Built-in tuple types and literals)
```diff
  BasicType
      ...
      TypeVector
+     TupleType

+ TupleType:
+     ( TupleTypes )

+ TupleTypes:
+     Type ,
+     Type , Type
+     Type , TupleTypes

  PrimaryExpression:
      ...
      StringLiterals
+     TupleLiteral
      ArrayLiteral
      ...

+ TupleLiteral:
+     ( TupleExpressions )

+ TupleExpressions
+     Expression ,
+     Expression , Expression
+     Expression , TupleExpressions
```

#### Proposal 4 (Unpacking assignments)
The grammar additions for tuple literals suffice. For an unpacking assignment, the tuple literal is interpreted as an lvalue during semantic.

#### Proposal 5 (Unpacking function arguments)

(Note that ParameterTupleDeclarator is the same as TupleDeclarator except that the former allows all `StorageClasses`, while the latter allows only `InOut`.)
```diff
+ ParameterTupleDeclarator:
+     ( ParameterTupleDeclarators2 )
+     ( ParameterTupleDeclarators2 ) = Initializer

+ ParameterTupleDeclarators2:
+     ParameterTupleDeclarator2 ,
+     ParameterTupleDeclarator2 , ParameterTupleDeclarator2
+     ParameterTupleDeclarator2 , ParameterTupleDeclarators2

+ ParameterTupleDeclarator2:
+     InOut[opt] Identifier
+     InOut[opt] BasicType BasicType2[opt] Identifier
+     InOut[opt] ( ParameterTupleDeclarators2 )

  Parameter:
      ...
      InOut[opt] Type ...
+     InOut[opt] ParameterTupleDeclarator

TODO: FUNCTION LITERALS
```

#### Proposal 6 (Placeholder name `_`)
No grammar change is required.

### Breaking changes / deprecation process

#### Proposal 1 (Unpacking declarations)
Syntax addition, not a breaking change.

#### Proposal 2 (auto-expansion for `alias this`)
This change can break code in the following corner case:
```d
module a;

void foo(int x, int y);
```

```d
module b;

void foo(Tuple!(int, int) t);
```

```d
module c;
import a,b;
void main(){
    foo(tuple(1,2));
    // currently: would call b.foo
    // new: anti-hijacking error
}
```

If this is situation is considered sufficiently likely, we could turn the anti-hijacking error into a deprecation warning in the case where one of the matches was obtained using the new `alias this` rewrite.

Note that calls to functions whose overloads reside in the same module cannot be broken by this change (currently it is impossible to call a function with parameter type `Tuple!(double, double)` with a `Tuple!(int, int)` argument, so there is no way for the new matching mechanism to conflict with the old one).

#### Proposal 3 (Built-in tuple types and literals)
This change could break code that relies on the particular formatting that Phobos currently uses for tuples. The DIP author cannot see an obvious mitigation other than keeping `std.typecons.Tuple` and `core.object.__Tuple` separate instead of aliasing them.

#### Proposal 4 (Unpacking assignments)
Syntax addition, not a breaking change.

#### Proposal 5 (Unpacking function arguments)
Syntax addition, not a breaking change.

#### Proposal 6 (Placeholder name `_`)
This can be implemented using a non-disruptive two-stage process:

- *Stage 1*: Symbols with the name `_` are inserted into the symbol table but don't generate multiple definition errors unless they are subsequently accessed. Accessing symbols with the name `_` should be deprecated.
- *Stage 2*: Symbols with the name `_` are no longer inserted into the symbol table.



### Examples

Example from DIP 32, originally by bearophile:

```d
import std.stdio, std.algorithm, std.container, std.array;

auto encode(T)(Group!("a == b", T[]) sf) {
    auto heap = sf.map!((c, f) => (f, [(c, "")])).array.heapify!q{b < a};

    while (heap.length > 1) {
        auto (lof, loa) = heap.front;  heap.removeFront;
        auto (hif, hia) = heap.front;  heap.removeFront;
        foreach ((_, ref e); loa) e = '0' ~ e;
        foreach ((_, ref e); hia) e = '1' ~ e;
        heap.insert((lof + hif, loa ~ hia));
    }
    return heap.front[1].schwartzSort!((c, e) => (e.length, c));
}

void main() {
    auto s = "this is an example for huffman encoding"d;
    foreach ((c, e); s.dup.sort().release.group.encode)
        writefln("'%s'  %s", c, e);
}
```

### Limitations

Currently, slices of `std.typecons.Tuple`s auto-expand. Ideally, slicing a tuple would produce another tuple (instead of an AliasSeq).
As this DIP is based on rewriting to the current implementation of `std.typecons.Tuple`, this situation is unfortunately not addressed:

```d
void foo((int, double) t){}

foo((1, 2.0, "3")[0..2]); // error

foo(((1, 2.0, "3")[0..2],)); // ok
```

This illustrates another limitation: while proposal 2 makes it possible to call a function that takes multiple arguments with a single tuple, it is still not possible to call a function that takes a single tuple with multiple arguments.

## Acknowledgements

Proposal 2 was inspired by a helpful discussion with Steven Schveighoffer.

## Copyright & License

Copyright (c) 2017 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)
