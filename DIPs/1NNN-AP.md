# Contextual Enum Type Omission

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            |                                                                 |
| Review Count:   | 0                                                               |
| Author:         | Aya Partridge (zxinsworld@gmail.com)                            |
| Implementation: |                                                                 |
| Status:         | Draft                                                           |

## Abstract

Contextual Enum Type Omission (ETO) is a shortcut to allow the omission of an enum member's
type name when it can be contextually inferred.
This feature's presence in other languages has made enums in them far more usable.

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
involves the unnecessary repetition of the enum member's type name.

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

According to [this issue](https://github.com/dlang/projects/issues/88#issue-1288877431),
the languages Jail and Styx also have this functionality. However, I was unable find
enough evidence to verify this claim.

//
Required.

If the proposed feature exists, or has been proposed, in other languages, this is the place
to provide the details of those implementations and proposals. Ditto for prior DIPs.

If there is no prior work to be found, it must be explicitly noted here.

## Description
I propose that ETO will work in the following contexts:

#### 1. Assignment statements.
Assigning to a variable with a known type should allow ETO.
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
should allow ETO.
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
always allow ETO. The exception is alias template parameters, which
should disallow ETO altogether.
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
Switch-case statements should always allow ETO.
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
When an array literal has a specified type, ETO should always be allowed(1).
When an array literal has an ambiguous type, I propose that any type explicitly
used for the first array index should be applied to the rest of the array with ETO(2).
```d
enum A{ a,b,c,d; }

A[4] x = [.a, .b, .c, .d];  //(1)
auto y = [A.a, .b, .c, .d]; //(2)
```

//
Required.

Detailed technical description of the new semantics. Language grammar changes
(per https://dlang.org/spec/grammar.html) needed to support the new syntax
(or change) must be mentioned. Examples demonstrating the new semantics will
strengthen the proposal and should be considered mandatory.

## Breaking Changes and Deprecations
In order to maintain compatibility with existing codebases, attempting
to use ETO in ambiguous contexts should prioritise non-ETO syntax,
but emit a warning so that the user is made aware of the ambiguity:
```d
enum A{ a,b,c,d; }

A b(){ return A.d; }

A myBrokenFunc(){
    return .b;//warning, prioritising "A b()" in what appears to be attempted ETO syntax
    //returns A.d
}
```
The exception should be in switch-case statements, as they cannot have function calls as cases.

//
This section is not required if no breaking changes or deprecations are anticipated.

Provide a detailed analysis on how the proposed changes may affect existing
user code and a step-by-step explanation of the deprecation process which is
supposed to handle breakage in a non-intrusive manner. Changes that may break
user code and have no well-defined deprecation process have a minimal chance of
being approved.

## Reference
[DIPX: Enum Literals / Implicit Selector Expression](https://forum.dlang.org/thread/yxxhemcpfkdwewvzulxf@forum.dlang.org)

[Implementing Parent Enum Inference in the language (.MyValue instead of MyEnum.MyValue) #88](https://github.com/dlang/projects/issues/88)

//
Optional links to reference material such as existing discussions, research papers
or any other supplementary materials.

## Copyright & License
Copyright (c) 2022 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## Reviews
The DIP Manager will supplement this section with a summary of each review stage
of the DIP process beyond the Draft Review.
