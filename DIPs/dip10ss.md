# Enum and Function Parameter Attributes

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | (number/id -- assigned by DIP Manager)                          |
| Review Count:   | 0 (edited by DIP Manager)                                       |
| Author:         | [@skl131313](https://github.com/skl131313)                      |
| Implementation: | [Function UDAs](https://github.com/dlang/dmd/pull/7576) / [Enum UDAs](https://github.com/dlang/dmd/pull/6161) |
| Status:         | Will be set by the DIP manager (e.g. "Approved" or "Rejected")  |

## Abstract

In D, attributes provide a means of attaching compile-time information to a symbol. Built-in attributes provide information to the compiler, User-Defined Attributes (UDAs) provide information to the programmer or tooling, and both are accessible through compile-time reflection.

D currently prohibits the use of attributes on some types of symbols, specifically enums and function parameters. This document describes a proposal to allow UDAs and built-in attributes to be attached to enums and function parameters.

### Reference

[Preliminary discussion about Enum and Function Parameter Attributes on the NG](http://forum.dlang.org/thread/cltyrthdxkkfvuxqasqw@forum.dlang.org)

[(New) Pull request implementing UDAs for function parameters](https://github.com/dlang/dmd/pull/7576)

[(Old) Pull request implementing UDAs for function parameters](https://github.com/dlang/dmd/pull/4783/files)

[Pull request implement UDAs for enums](https://github.com/dlang/dmd/pull/6161)

## Contents
* [Rationale](#rationale)
* [Description](#description)
* [Existing Solutions](#existing-solutions)
* [Examples](#examples)
* [Breaking Changes and Deprecations](#breaking-changes-and-deprecations)
* [Reviews](#reviews)

## Rationale

Allowing attributes to be attached to function parameters and enums would enable current implementations to be simplified and result in cleaner, more easily readable code. Current workarounds involve attaching the attributes to the parent symbol instead, as such additional identifying information needs to be added to the attribute indicating which child the attribute belongs to. This makes it difficult to read as information pertaining to a symbol isn't located with it, instead you would need to look through the parent's attributes.

The concept known as "orthogonality of language features" can be said to apply to this proposal. Attributes can be applied to almost every symbol in D, a user would expect them to also be applicable to enums and function parameters.

## Description

The changes made to D would be relatively minor. Most of the framework for attributes already exists, and it would just be a matter of extending that to the respective symbols for enums and function parameters.

The following syntaxes are being proposed to be accepted:

```D
enum SomeEnum
{
    // attributes declared infront of enum value
    @(90) @MyUda deprecated("reason") someEnumValue0,
    @(91) @MyUda deprecated("reason") someEnumValue1 = 1,
}

// attributes for enum values can be retrieved with __traits(getAttributes, ...)
static assert(__traits(getAttributes, SomeEnum.someEnumValue0)[0] == 90);
static assert(__traits(getAttributes, SomeEnum.someEnumValue1)[0] == 91);

// for functions, attributes are allowed infront of function parameters
void someFunction(@(93) @MyUda int someParameter)
{
    // can use __traits(getAttributes, ...) with the paramter from inside of function
    static assert(__traits(getAttributes, someParamter)[0] == 93);
}

void someExternalFunction()
{
    // attributes can be accessed for paramters by another function
    // through existing functionality of __parameters
    static if(is(typeof(someFunction) PT == __parameters))
    {
        static assert(__traits(getAttributes, PT[0 .. 1])[0] == 93);
    }
}
```

Grammar changes for [Enum](https://dlang.org/spec/enum.html):

```diff
+ EnumAttribute:
+     DeprecatedAttribute
+     UserDefinedAttribute

+ EnumAttributes:
+     EnumAttribute
+     EnumAttiribute EnumAttributes

EnumMember:
    Identifier
    Identifier = AssignExpression
+   EnumAttributes Identifier
+   EnumAttributes Identifier = AssignExpression
```

Grammar change for [Function](https://dlang.org/spec/function.html):

```diff
+ ParameterAttribute:
+     UserDefinedAttribute

+ ParameterAttributes:
+     ParameterAttribute
+     ParameterAttribute ParameterAttributes

Parameter:
    InOut_opt BasicType Declarator
    InOut_opt BasicType Declarator ...
    InOut_opt BasicType Declarator = AssignExpression
    InOut_opt Type
    InOut_opt Type ...
+   ParameterAttributes InOut_opt BasicType Declarator
+   ParameterAttributes InOut_opt BasicType Declarator = AssignExpression
+   ParameterAttributes InOut_opt Type
```

## Existing Solutions

A current solution for applying a UDA to an enum or parameter is to use an UDA on the parent symbol with some additional information for which child element it should be applied to. This allows the desired UDA to be used and associated with the desired symbol. It introduces some duplication and the information stored in the UDA is separated from the rest of the information of the symbol.

```D
@MyUda("feature0", "...")
@MyUda("feature1", "...")
@MyUda("feature2", "...")
enum SomeEnum
{
    feature0,
    feature1,
    feature2,
}

@MyUda("param0", "...")
void foo(int param0)
{
}
```

A solution for applying the `deprecation` attribute to an enum member can be done by reimplementing an enum as a structure with static enums. This allows the attribute to be placed with the desired enum member. While still allowing for any existing code that simply used an enum beforehand to still work accordingly, as if the struct was an enum. An example of this workaround can be seen in the [Examples](#examples) section, with the corresponding solution if this proposal was implemented.

### Examples

Deprecating individual enums value which should not be used anymore as seen [here](https://github.com/vibe-d/vibe.d/pull/1947/files):

```D
enum SomeEnumImpl
{
    none         = -1,
    actualValue2 = 2,
    actualValue3 = 3,
}

public struct SomeEnum
{
    SomeEnumImpl x;
    alias this x;

    deprecated("reason for deprecation")
    enum deprecatedValue0 = SomeEnumImpl.none;

    deprecated("reason for deprecation")
    enum deprecatedValue1 = SomeEnumImpl.none;
}

// becomes

enum SomeEnum
{
    none = -1,
    actualValue2 = 2,
    actualValue3,

    deprecated("reason for deprecation") deprecatedValue0 = none,
    deprecated("reason for deprecation") deprecatedValue1 = none,
}
```

Providing extra attributes that can be used to take advantage of knowledge known about the function parameters. An example of this is `NonNull` as could be implemented in LDC2 through LLVM. More details [here](https://clang.llvm.org/docs/AttributeReference.html#nonnull).

```D
extern(C) void fetch(@NonNull int* ptr)
{
}
```

More examples of parameter attributes from [vibe.d](https://github.com/vibe-d/vibe.d):

```D
@body("user")
@errorDisplay
auto postUsers(User _user, string  _error)
{
}

// becomes

auto postUser(@body User user, @errors Errors errors)
{
}

// Another example:

@path("/users/:id")
@queryParam("page")
@before!authenticate("user")
auto getUsers(string _id, int page, User user)
{
}

// becomes

@path("/users/:id")
auto getUser(@urlParam string id, @queryParam int page, @auth User user)
{
}
```

Provide information on function parameters for use with scripting languages or other type evaluation:

```D
enum ScriptType
{
    vehicle,
    character,
    scenery,
}

struct ScriptParameter
{
    string name;
    ScriptType type;
}

@ScriptParameter("vehicleIndex", ScriptType.vehicle)
void someFunction(string name, int vehicleIndex)
{
}

// becomes

enum ScriptType
{
    vehicle,
    character,
    scenery,
}

void someFunction(string name, @ScriptType.vehicle int vehicleIndex)
{
}
```

## Breaking Changes and Deprecations

No breaking changes are to occur from including these features.


## Copyright & License

Copyright (c) 2017 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## Reviews

The DIP Manager will supplement this section with a summary of each review stage
of the DIP process beyond the Draft Review.
