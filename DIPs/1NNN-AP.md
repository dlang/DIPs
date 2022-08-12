# Enum Type Inference

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            |                                                                 |
| Review Count:   | 0                                                               |
| Author:         | Aya Partridge (zxinsworld@gmail.com)                            |
| Implementation: |                                                                 |
| Status:         | Draft                                                           |

## Abstract

Enum Type Inference (ETI) is a shortcut to allow the omission of an enum member's
type name when it can be contextually inferred.

While D's pre-existing syntax makes ETI a more complex feature to implement than in brand
new languages, its presence in many new languages has proven its convenience and popularity.

## Contents
* [Rationale](#rationale)
* [Prior Work](#prior-work)
* [Description](#description)
* [Reference](#reference)
* [Copyright & License](#copyright--license)
* [Reviews](#reviews)

## Rationale
Writing the same enum type names over and over again (e.g. exhaustive enum switch-cases)
involves the unnecessary, often gratuitous repetition of the enum member's type name.

The solution used by many other modern languages is simple: permit the omission
of the enum member's type name when it can be inferred from its context.
Dlang having this shortcut would be equally beneficial, with few drawbacks.

## Prior Work
Implementation of this feature in other languages:
- [Swift](https://docs.swift.org/swift-book/LanguageGuide/Enumerations.html)
- [Ziglang](https://ziglang.org/documentation/master/#Enum-Literals)
- [Odin](https://odin-lang.org/docs/overview/#implicit-selector-expression)

Java allows omitting an enum type in switch-case statements: [https://docs.oracle.com/javase/tutorial/java/javaOO/enum.html](https://docs.oracle.com/javase/tutorial/java/javaOO/enum.html)

A suggestion for a similar feature in Rust, but with a different approach: [https://internals.rust-lang.org/t/enum-path-inference-with-variant-syntax/16851](https://internals.rust-lang.org/t/enum-path-inference-with-variant-syntax/16851)

## Description
Due to `.enumMember` being the same syntax as the [module scope operator](https://dlang.org/spec/module.html#module_scope_operators),
I propose that ETI should use the syntax `$enumMember`. I'm open to discussing alternatives,
but I believe that my proposed syntax represents the best compromise between convenience and compatibility.

#### 1. Assignment statements.
Assigning to a variable with a known type should allow ETI.
```d
enum A{ a,b,c,d; }

struct B{ A one, two; }

void main(){
    A    myA1 = $b; //myA1 = A.b
    auto myA2 = $b; //error, we don't know the type of "$b"!
    
    B myB;
    myB.one = $c; //myB.one = A.c
    myB.two = $d; //myB.two = A.d
}
```

#### 2. Return statements.
If a function has an explicit enum return type, its return statement(s)
should allow ETI.
```d
enum A{ a,b,c,d; }

A myFunc(){
    return $c; //returns A.c
}

auto myBrokenFunc(){
    return $c; //error, we don't know the type of "$c"!
}
```

#### 3. Parameters.
Most parameters require explicit typing beforehand, and thus should
always allow ETI. The exception is `alias` template parameters, which
cannot use ETI.
```d
enum A{ a,b,c,d; }

struct B{ A one, two; }

void myFunc(A param){}
void myTempFunc(T)(T param){}

void main(){
    B    myB1 = {one:$a, two:$b};
    auto myB2 = B($a, $b);
    
    myFunc($a);
    myTempFunc!A($a);
    myTempFunc($a); //error, can't infer a type to instantiate template with from "$a"
}
```

#### 4. Switch-case statements.
Switch-case statements should have a special syntax that works the same way as `switch(myVar) with(typeof(myVar))`.
```d
enum WordLetterOfTheDay{ a,b,c,d/*...*/; }

void main(){
    auto letterToday = WordLetterOfTheDay.b;
    
    import std.stdio;
    switch(letterToday){
        case a:
            writeln("Apple");
            break;
        case b:
            writeln("Bicycle");
            break;
        case c:
            writeln("Caterpillar");
            break;
        case d:
            writeln("Didgeridoo");
            break;
        /*...*/
    }
}
```

#### 5. Array literals.
When an array literal has a specified type, ETI should always be allowed(1).



When an array literal has an ambiguous type, I propose that if an enum type is explicitly
used for the first array item, ETI should be allowed in the remainder of the array.
```d
enum A{ a,b,c,d; }

A[4] x = [$a, $b, $c, $d];  //(1)
auto y = [A.a, $b, $c, $d]; //(2)
```

#### Other considerations
Any time where there is more than one valid candidate for the type of a member, ETI should not be allowed.
```d
enum A{ a,b,c,d,e; }
enum B{ a,b,c,d; }

void myFunc(A param){}
void myFunc(B param){}

void main(){
    myFunc(A.a);
    myFunc($a); //error, we have two equally valid candidates!
    myFunc($e); //OK, the only candidate is "myFunc(A.e)", since B does not have "$e"
}
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
