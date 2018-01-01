# Enum and Function Parameter Attributes

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | 10ss                                                            |
| Review Count:   | NA                                                              |
| Author(s):      | @skl131313                                                      |
| Status:         | NA                                                              |


## Abstract

Allow additional meta information (attributes) to be attached with enums and functions parameters, including built-in attributes such as `deprecated`.

### Links

[Does it require a DIP?](http://forum.dlang.org/thread/cltyrthdxkkfvuxqasqw@forum.dlang.org)

## Rationale

It is currently not possible to attach attributes to both enums and function parameters. This excludes a few features that can be used with almost any other symbol in D. Attributes and User Defined Attributes serve as a means to provide extra meta data for a symbol. What can be said for why attributes were included as a feature in D can also be said for why they should be extended to enums and function parameters. It is benefitial to provide extra meta data about a symbol that can be used at compile-time.

## Description

TBD

## Existing Solutions

Existing solutions exist only for UDAs, for an attribute such a `deprecated`, there is no existing solution to receive the desired effect.

Apply UDA through parent symbol with additional information for which child it should be applied to:

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

This allows the desired UDA to be used and associated with the desired symbol. It introduces some duplication and the information stored in the UDA is separated from the rest of the information of the symbol.


### Examples

Allowing to deprecate enums which should not be used anymore:

```D
enum SomeEnum
{
    feature0,
    feature1,

    deprecated("use feature0 or feature1 instead")
    feature2,
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

// scripting language can now know that the index is of a specific type
// the scripting language not being aware that it is just an index
void someFunction(string name, @ScriptType.vehicle int vehicleIndex)
{
    // ...
}
```

Providing extra attributes that can be used to take advantage of knowledge known about the function parameters:

```D

extern(C) void fetch(@NonNull int* ptr)
{
    // ...
}
```

## Copyright & License

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)



