# Mixin Template Intermediary Storage

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | (number/id -- assigned by DIP Manager)                          |
| Review Count:   | 0 (edited by DIP Manager)                                       |
| Author:         | Marcelo Silva Nascimento Mancini (msnmancini@hotmail.com)       |
| Implementation: | (links to implementation PR if any)                             |
| Status:         | Draft                                                           |

## Abstract

Use intermediary variables inside mixin template without making it get included in
the code generation.

## Contents
* [Rationale](#rationale)
* [Prior Work](#prior-work)
* [Description](#description)
* [Breaking Changes and Deprecations](#breaking-changes-and-deprecations)
* [Reference](#reference)
* [Copyright & License](#copyright--license)
* [Reviews](#reviews)

## Rationale

Using mixin template inside a class scope does not allow you to define intermediary data (as this intermediary data will be included in the class as members, which can cause unintended behavior). The common solution to that has been to generate a mixin template that executes a string mixin with a function, such as that:
```d
mixin template MyMixin(A)
{
   mixin(MyMixinImpl!A);
}

```
The problem with that approach is that it introduces a lot of mental friction from getting the syntax correctly inside a string, it makes compilation times slower as the possibility of using `format` or string append is really high. 

Another pattern that is also used for using variables inside `mixin template`, is creating a private template containg all variables necessary inside the mixin template:

```d
private template Vars(A, string name)
{
    alias myMember = __traits(getMember, A, name);
    enum _isConst = isConst!myMember;
    enum _isRef = isRef!myMember;
}

mixin template MyMixin(A)
{
    static foreach(mem; __traits(allMembers, A))
    {
        static if(Vars!(A, mem)._isConst && Vars!(A, mem)._isRef){}
        else static if(Vars!(A, mem)._isRef){}
        else static if(Vars!(A, mem)._isConst){}
    }
}
```

In summary, this is an attempt to make `mixin template` more capable. The following code errors out today with redefinition:

```d
mixin template MyMixin(A)
{
    static foreach(mem; __traits(allMembers, A))
    {
        alias myMember = __traits(getMember, A, mem);
        enum _isConst = isConst!(myMember);
        enum _isRef = isRef!(myMember);

        ///Now do what you need with those informations and combinations
        static if(_isConst && _isRef){}
        else static if(_isRef){}
        else static if(_isConst){}
    }
}
```
As this code is not being able to compile, to run that code without using the string mixin or template trick, one would need to:
```d
static if(isConst!(__traits(getMember, A, mem)) && isRef!(__traits(getMember, A, mem))){}
else static if(isRef!(__traits(getMember, A, mem))){}
else static if(isConst!(__traits(getMember, A, mem))){}
```

This makes the code fairly unreadable and a lot more verbose. With the proposed solution, one could even reduce templates usage by using the following code:
```d
//non template execution for isConst
enum funcAttributes = __traits(getFunctionAttributes, myMember);
enum _isConst2 = funcAttributes.has("const");
enum _isRef2 = funcAttributes.has("ref");
```

The proposed solution for this problem is then the keywords `mixin delete`:
```d
mixin template MyMixin(A)
{
    static foreach(mem; __traits(allMembers, A))
    {
        mixin delete {
            alias myMember = __traits(getMember, A, mem);
            enum funcAttributes = __traits(getFunctionAttributes, myMember);
            enum _isConst = funcAttributes.has("const");
            enum _isRef = funcAttributes.has("ref");
        }

        ///Now do what you need with those informations and combinations
        static if(_isConst && _isRef){}
        else static if(_isRef){}
        else static if(_isConst){}
    }
}
```

## Prior Work
No prior work has been done on that.

## Description

All code inside `mixin delete` will need to be evaluated on compilation time, and will be usable inside `mixin template`.

It must allow redefinition of variables or have other kind of mechanism for compatibility with `static foreach` (maybe generating an specific scope for mixin templates).




```
Declaration:
    FuncDeclaration
    VarDeclarations
    AliasDeclaration
    AliasAssign
    AggregateDeclaration
    EnumDeclaration
    ImportDeclaration
    ConditionalDeclaration
    StaticForeachDeclaration
    StaticAssert
+   MixinDeleteDeclaration
```

```
+MixinDeleteDeclaration:
+    mixin delete DeclarationBlock
```



## Breaking Changes and Deprecations
Breaking changes aren't anticipated as both `mixin` and `delete` keywords are reserved and the combination of them still doesn't exists.

## Copyright & License
Copyright (c) 2022 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## Reviews
The DIP Manager will supplement this section with a summary of each review stage
of the DIP process beyond the Draft Review.
