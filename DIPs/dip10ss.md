# Enum and Function Parameter Attributes

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | 10ss                                                            |
| Review Count:   | NA                                                              |
| Author(s):      | [skl131313](https://github.com/skl131313)                       |
| Status:         | NA                                                              |


## Abstract

Allow additional meta information (attributes) to be attached with enums and functions parameters, including built-in attributes such as `deprecated`.

### Links

[Preliminary discussion about Enum and Function Parameter Attributes on the NG](http://forum.dlang.org/thread/cltyrthdxkkfvuxqasqw@forum.dlang.org)

[Pull request implementing UDAs for function parameters](https://github.com/dlang/dmd/pull/4783/files)

## Rationale

It is currently not possible to attach attributes to both enums and function parameters. This excludes a few features that can be used with almost any other symbol in D.

Attributes and user-defined attributes (UDA) serve as a means to provide extra meta data for a symbol. What can be said for why attributes were included as a feature in D can also be said for why they should be extended to enums and function parameters. It is benefitial to provide extra meta data about a symbol that can be used at compile-time.

The concept known as "orthogonality of language features" applies here. Attributes can be applied to almost every symbol in D. A user would expect them to also be applicable to enums and function parameters.

## Description

Grammar changes for [Enum](https://dlang.org/spec/enum.html):

```
EnumMember:
    Identifier
    Identifier = AssignExpression

// becomes -------------------------------------------

EnumAttribute:
    DeprecatedAttribute
    UserDefinedAttribute

EnumAttributes:
    EnumAttribute
    EnumAttiribute EnumAttributes

EnumMember:
    Identifier
    Identifier = AssignExpression
    EnumAttributes Identifier
    EnumAttributes Identifier = AssignExpression
```

Grammar change for [Function](https://dlang.org/spec/function.html):

```
Parameter:
    InOut_opt BasicType Declarator
    InOut_opt BasicType Declarator ...
    InOut_opt BasicType Declarator = AssignExpression
    InOut_opt Type
    InOut_opt Type ...

// becomes -----------------------------

ParameterAttribute:
    UserDefinedAttribute

ParameterAttributes:
    ParameterAttribute
    ParameterAttribute ParameterAttributes

Parameter:
    InOut_opt BasicType Declarator
    InOut_opt BasicType Declarator ...
    InOut_opt BasicType Declarator = AssignExpression
    InOut_opt Type
    InOut_opt Type ...
    ParameterAttributes InOut_opt BasicType Declarator
    ParameterAttributes InOut_opt BasicType Declarator = AssignExpression
    ParameterAttributes InOut_opt Type
```

## Existing Solutions

A current solution for applying an UDA to an enum or parameter is to use an UDA on the parent symbol with some additional information for which child element it should be applied to. This allows the desired UDA to be used and associated with the desired symbol. It introduces some duplication and the information stored in the UDA is separated from the rest of the information of the symbol.

```D
@MyUda("feature0", "...")
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

A solution for applying the `deprecation` attribute to an enum member can be done by reimplementing an enum as a structure with static enums. This allows the attribute to be placed with the desired enum member. While still allowing for any existing code that simply used an enum before hand to still work accordingly, as if the struct was an enum.

```D
enum SomeEnumImpl
{
    none         = -1,
    actualValue2 = 2,
    actualValue3 = 3,
}

struct SomeEnum
{
    SomeEnumImpl x;
    alias this x;

    deprecated("reason for deprecation")
    static enum deprecatedValue0 = none;

    deprecated("reason for deprecation")
    static enum deprecatedValue1 = none;
}
```

### Examples

Allowing to deprecate enums which should not be used anymore as seen [here](https://github.com/vibe-d/vibe.d/pull/1947/files):

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
    static enum deprecatedValue0 = SomeEnumImpl.none;

    deprecated("reason for deprecation")
    static enum deprecatedValue1 = SomeEnumImpl.none;
}

// becomes

enum SomeEnum
{
    none = -1,
    deprecated("reason for deprecation")
    deprecatedValue0 = none,
    deprecated("reason for deprecation")
    deprecatedValue1 = none,
    actualValue2 = 2,
    actualValue3,
}
```

Providing extra attributes that can be used to take advantage of knowledge known about the function parameters:

```D
extern(C) void fetch(@NonNull int* ptr)
{
}
```

Examples of above from [vibe.d](https://github.com/vibe-d/vibe.d):

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

## Copyright & License

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)
