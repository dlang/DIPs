# Tagged Union

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | (number/id -- assigned by DIP Manager)                          |
| Review Count:   | 0 (edited by DIP Manager)                                       |
| Author:         | RUSShy                               |
| Implementation: | (links to implementation PR if any)                             |
| Status:         | Will be set by the DIP manager (e.g. "Approved" or "Rejected")  |

## Abstract

Self explanatory

```D
enum MyTag
{
    A, B, C
}


union Tagged : MyTag
{
    int A;
    float B;
    bool C;
}

// compiler check if all tags are present in Tagged

Tagged stuff =  { B: 2.5 };

switch(stuff)
{
    MyTag.A => (ref int myInt) {
    },
    
    
    MyTag.B => (ref float myFloat) {
    },
    
    
    MyTag.C => (ref bool myBool) {
    },
}

// in universe that doesn't suck

switch(stuff)
{
    .A => (ref int myInt) {
    },
    
    
    .B => (ref float myFloat) {
    },
    
    
    .C => (ref bool myBool) {
    },
}

```

boom

## Contents
* [Rationale](#rationale)
* [Prior Work](#prior-work)
* [Description](#description)
* [Breaking Changes and Deprecations](#breaking-changes-and-deprecations)
* [Reference](#reference)
* [Copyright & License](#copyright--license)
* [Reviews](#reviews)

## Rationale
Required.

No need a library, works out of the box, optimzed and well integrated to the language, no templates, no speciam !match syntax, works everywhere, including better-c where std is not available

Check other languages

## Prior Work

Check other languages

## Description

Check other languages

## Breaking Changes and Deprecations

std.sumtype is a mistake, now what we do about it? thanks std maintainers

Remove std.sumtype, since it won't be needed

## Reference

https://ziglang.org/documentation/master/#Tagged-union


## Copyright & License

Public Domain

## Reviews
The DIP Manager will supplement this section with a summary of each review stage
of the DIP process beyond the Draft Review.
