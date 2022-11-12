# Enum Type Inference

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            |                                                                 |
| Review Count:   | 0                                                               |
| Author:         | Aya Partridge (zxinsworld@gmail.com)                            |
| Implementation: |                                                                 |
| Status:         | Draft                                                           |

## Abstract

Enum Type Inference (henceforth ETI) is a shortcut to allow the omission of an enum member's
type name when it can be contextually inferred. Its presence in other languages has proven its convenience and popularity.

## Contents
* [Rationale](#rationale)
* [Prior Work](#prior-work)
* [Description](#description)
* [Grammatical Changes](#grammatical-changes)
* [Reference](#reference)
* [Copyright & License](#copyright--license)
* [Reviews](#reviews)

## Rationale
Writing the same enum type names over and over again can be tedious. The solution offered by several other modern languages is simple: permit the omission
of the enum member's type name when it can be inferred from its context.
Having this shortcut in D would be equally beneficial, with few drawbacks.

## Prior Work
Implementation of this feature in other languages:
- [Swift](https://docs.swift.org/swift-book/LanguageGuide/Enumerations.html)
- [Ziglang](https://ziglang.org/documentation/master/#Enum-Literals)
- [Odin](https://odin-lang.org/docs/overview/#implicit-selector-expression)

Java allows omitting the enum type in switch-case statements: https://docs.oracle.com/javase/tutorial/java/javaOO/enum.html

A suggestion for a similar feature in Rust, but with a different approach: https://internals.rust-lang.org/t/enum-path-inference-with-variant-syntax/16851

## Description
This DIP proposes that ETI in D should use the syntax `$enumMember`. This syntax was chosen because the dot operator without an enum name as used in other languages (`.enumMember`) would have the same syntax as D's [module scope operator](https://dlang.org/spec/module.html#module_scope_operators). Suggestions for an alternative syntax may be raised,
but the proposed syntax should already represent the best compromise between convenience and compatibility.

In principle, ETI should be allowed anywhere that an enum type is known unambiguously at compile-time.
The following is a (non-exhaustive) list of circumstances in which ETI will be permitted.

### 1. Initializers and assignments
ETI is allowed when initializing or assigning to a variable that has a known enum type.
```d
enum A{ a,b,c,d }

struct S{ A one, two; }

void main(){
    A    myA1 = $b;      // myA1 = A.b
    A    myA2 = $b | $c; // myA2 = A.c
    auto myA3 = $b;      // error, we don't know the type of "$b"!

    S myS;
    myS.one = $c; // myB.one = A.c
    myS.two = $d; // myB.two = A.d
}
```

### 2. Return statements
ETI is allowed in return statements when a function has an explicit enum return type.
```d
enum A{ a,b,c,d }

A myFn(){
    return $c; //returns A.c
}

auto myBrokenFn(){
    return $c; // error, we don't know the type of "$c"!
}
```

### 3. Argument lists
ETI is allowed in the argument lists of function calls and template instantiations when they can bind to explicitly typed enum parameters.
```d
enum A{ a,b,c,d }

struct S{ A one, two; }

void myFn(A param){}
void myDefaultFn(A param=$d){}
void myTempFn(T)(T param){}

void main(){
    S    myS1 = {one:$a, two:$b};
    auto myS2 = S($a, $b);

    myFn($a);
    myFn($a + $a); // passes A.b

    myDefaultFn();
    myDefaultFn($c);

    myTempFn!A($a);
    myTempFn($a); // error, can't infer a type to instantiate the template with from "$a"
}
```

### 4. Case statements
ETI is allowed in the case statements of a switch.
```d
import std.stdio: writeln;

enum WordLetterOfTheDay{ a,b,c,d/*...*/ }

void main(){
    auto letterToday = WordLetterOfTheDay.b;
    
    import std.stdio;
    switch(letterToday){
        case $a:
            writeln("Apple");
            break;
        case $b:
            writeln("Bicycle");
            break;
        case $c:
            writeln("Caterpillar");
            break;
        case $d:
            writeln("Didgeridoo");
            break;
        /*...*/
    }
}
```

### 5. Array literals
A) ETI is allowed in array literals in initializations and assignments as determined by item 1 (Initializations and assignments) above.

B) ETI is also allowed in array literals for which an explicit enum type can be inferred.
```d
enum A{ a,b,c,d }

// (A)
A[4] x = [$a, $b, $c, $d];
// (B)
auto y = [A.a, $b, $c, $d]; // typeof(y) = A[]
auto z = [A.c, 64, $b, $b]; // typeof(z) = int[]
```

### Other considerations
When the resolution of ETI is ambiguous due to multiple candidate enums, ETI is prohibited.
```d
enum A{ a,b,c,d,e }
enum B{ a,b,c,d }

void myFn(A param){}
void myFn(B param){}

void main(){
    myFn(A.a);
    myFn($a); // error, we have two equally valid candidates!
    myFn($e); // OK, the only candidate is "myFn(A.e)", since B does not have "$e"
}
```

### ETI vs `with` statements
For some use-cases, an argument could be made against the need for ETI. For instance, `final switch` statements combined with `with` statements:
```d
enum A{ a, b, c }

void main(){
    auto myA = A.b;
    final switch(myA) with(typeof(myA)){
        case a:
            // ...
            break;
        case b:
            // ...
            break;
        case c:
            // ...
            break;
    }
}
```
In the above case, ETI is not necessary.

However, there are many everyday cases where using `with` statements would prove insufficient, or outright silly.
For example, given the following delcarations:
```d
enum Size{ small, medium, large }
enum Shape{ square, round, triangular }
enum State{ on, off, undefined }

struct Obj{
    Size  size;
    Shape shape;
    State state;
    
    void myFn(Size size, Shape shape, State state){};
}
```
Let's create a `main` that doesn't use ETI or `with` statements:
```d
void main(){
    Obj myObj = {
        size:  Size.large,
        shape: Shape.round,
        state: State.on,
    };
    myObj.myFn(Size.medium, Shape.square, State.undefined);
}
```
Next, here's a version using ETI:
```d
void main(){
    Obj myObj = {
        size:  $large,
        shape: $round,
        state: $on,
    };
    myObj.myFn($medium, $square, $undefined);
}
```
And finally, here's a version rewritten to use `with` statements:
```d
void main(){
    Obj myObj;
    with(myObj) with(Size) with(Shape) with(State){
        size  = large;
        shape = round;
        state = on;
        
        myFn(medium, square, undefined);
    }
}
```
The version using ETI is shorter than the version without it, but without losing any readability.
The same can't be said for `with` statements, which produces a much less readable result.

## Grammatical Changes
```diff
PrimaryExpression:
+   $ Identifier
```

## Reference
- [DIPX: Enum Literals / Implicit Selector Expression](https://forum.dlang.org/thread/yxxhemcpfkdwewvzulxf@forum.dlang.org)
- [Enum literals, good? bad? what do you think?](https://forum.dlang.org/thread/zvhelliyehokebybmttz@forum.dlang.org)
- [Implementing Parent Enum Inference in the language (.MyValue instead of MyEnum.MyValue) #88](https://github.com/dlang/projects/issues/88)

## Copyright & License
Copyright © 2022 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## Reviews
The DIP Manager will supplement this section with a summary of each review stage
of the DIP process beyond the Draft Review.
