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

//
Required.

Short and concise description of the idea in a few lines.

## Contents
* [Rationale](#rationale)
* [Prior Work](#prior-work)
* [Description](#description)
* [Breaking Changes and Deprecations](#breaking-changes-and-deprecations)
* [Reference](#reference)
* [Copyright & License](#copyright--license)
* [Reviews](#reviews)

## Rationale
Writing the same enum type names over and over again (e.g. exhaustive enum switch-cases)
involves the unnecessary, often gratuitous repetition of the enum member's type name.

The solution used by many other modern language is simple: permit the omission
of the enum member's type name when it can be inferred from its context.
Dlang having this shortcut would be equally beneficial, with few drawbacks.

//
Required.

A short motivation about the importance and benefits of the proposed change.  An existing,
well-known issue or a use case for an existing projects can greatly increase the
chances of the DIP being understood and carefully evaluated.

## Prior Work
Implementation of this feature in other languages:
- [Swift](https://docs.swift.org/swift-book/LanguageGuide/Enumerations.html)
- [Ziglang](https://ziglang.org/documentation/master/#Enum-Literals)
- [Odin](https://odin-lang.org/docs/overview/#implicit-selector-expression)

Java allows omitting an enum type in switch-case statements: [https://docs.oracle.com/javase/tutorial/java/javaOO/enum.html](https://docs.oracle.com/javase/tutorial/java/javaOO/enum.html)
A suggestion for a similar feature in Rust, but with a different approach: [https://internals.rust-lang.org/t/enum-path-inference-with-variant-syntax/16851](https://internals.rust-lang.org/t/enum-path-inference-with-variant-syntax/16851)

//
Required.

If the proposed feature exists, or has been proposed, in other languages, this is the place
to provide the details of those implementations and proposals. Ditto for prior DIPs.

If there is no prior work to be found, it must be explicitly noted here.

## Description
I propose that ETI will work in the following contexts:

#### 1. Assignment statements.
Assigning to a variable with a known type should allow ETI.
```d
enum A{ a,b,c,d; }

struct B{ A one, two; }

void main(){
    A    myA1 = .b; //myA1 = A.b
    auto myA2 = .b; //error, unless a function "A b()" exists, we don't know the type of ".b"
    
    B myB;
    myB.one = .c; //myB.one = A.c
    myB.two = .d; //myB.two = A.d
}
```

#### 2. Return statements.
If a function has an explicit enum return type, its return statement(s)
should allow ETI.
```d
enum A{ a,b,c,d; }

A myFunc(){
    return .c; //returns A.c
}

auto myBrokenFunc(){
    return .c; //error, unless a function "T c()" exists, we don't know the type of ".c"
}
```

#### 3. Parameters.
Most parameters require explicit typing beforehand, and thus should
always allow ETI. The exception is alias template parameters, which
should disallow ETI altogether.
```d
enum A{ a,b,c,d; }

struct B{ A one, two; }

void myFunc(A param){}

void main(){
    B    myB1 = {one:.a, two:.b};
    auto myB2 = B(.a, .b);
    
    myFunc(.a);
}
```

#### 4. Switch-case statements.
Switch-case statements should always allow ETI.
```d
enum WordLetterOfTheDay{ a,b,c,d; }

void main(){
    WordLetterOfTheDay letterToday = .b;
    
    import std.stdio;
    switch(letterToday){
        case .a:
            writeln("Apple");
            break;
        case .b:
            writeln("Bicycle");
            break;
        case .c:
            writeln("Caterpillar");
            break;
        case .d:
            writeln("Didgeridoo");
            break;
    }
}
```

#### 5. Array literals.
When an array literal has a specified type, ETI should always be allowed(1).
When an array literal has an ambiguous type, I propose that any type explicitly
used for the first array item should be applied to the rest of the array with ETI(2).
```d
enum A{ a,b,c,d; }

A[4] x = [.a, .b, .c, .d];  //(1)
auto y = [A.a, .b, .c, .d]; //(2)
```

Any time where there is more than one valid enum candidate, ETI should not be allowed:
```d
enum A{ a,b,c,d; }
enum B{ a,b,c,d; }

void myFunc(A param){}
void myFunc(B param){}

void main(){
    myFunc(A.a);
    myFunc(.a); //error, we have two equally valid candidates!
}
```

//
Required.

Detailed technical description of the new semantics. Language grammar changes
(per https://dlang.org/spec/grammar.html) needed to support the new syntax
(or change) must be mentioned. Examples demonstrating the new semantics will
strengthen the proposal and should be considered mandatory.

## Breaking Changes and Deprecations
In order to maintain compatibility with existing codebases, attempting
to use ETI in ambiguous contexts should prioritise non-ETI syntax,
but emit a warning so that the user is made aware of the ambiguity:
```d
enum A{ a,b,c,d; }

A b(){ return A.d; }

A myBrokenFunc(){
    return .b;//warning, prioritising "A b()" in what appears to be attempted ETI syntax
    //returns A.d
}
```
The only exceptions should be
1. in switch-case statements, as they cannot contain function calls;
2. in array literals where the first item has an explicit type.

//
This section is not required if no breaking changes or deprecations are anticipated.

Provide a detailed analysis on how the proposed changes may affect existing
user code and a step-by-step explanation of the deprecation process which is
supposed to handle breakage in a non-intrusive manner. Changes that may break
user code and have no well-defined deprecation process have a minimal chance of
being approved.

## Reference
- [DIPX: Enum Literals / Implicit Selector Expression](https://forum.dlang.org/thread/yxxhemcpfkdwewvzulxf@forum.dlang.org)
- [Enum literals, good? bad? what do you think?](https://forum.dlang.org/thread/zvhelliyehokebybmttz@forum.dlang.org)
- [Implementing Parent Enum Inference in the language (.MyValue instead of MyEnum.MyValue) #88](https://github.com/dlang/projects/issues/88)

//
Optional links to reference material such as existing discussions, research papers
or any other supplementary materials.

## Copyright & License
Copyright (c) 2022 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## Reviews
The DIP Manager will supplement this section with a summary of each review stage
of the DIP process beyond the Draft Review.
