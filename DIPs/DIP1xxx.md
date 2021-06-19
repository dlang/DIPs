# Enum Literals

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


MyTag tag = .A;


void what(MyTag tag)
{}

what(.B);

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

When using a lot of enums, typing their name become a chore, let save some typing for later more important code

Check other languages

## Prior Work

Check other languages

## Description

Check other languages

## Breaking Changes and Deprecations

none

## Reference

https://ziglang.org/documentation/master/#Enum-Literals


## Copyright & License

Public Domain

## Reviews
The DIP Manager will supplement this section with a summary of each review stage
of the DIP process beyond the Draft Review.
