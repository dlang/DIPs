# Attributes

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | (number/id)                                                     |
| Review Count:   | 0
| Author:         | Nicholas Wilson                                                 |
| Implementation: | (links to implementation PR if any)                             |
| Status:         | Will be set by the DIP manager (e.g. "Approved" or "Rejected")  |

## Abstract

Addresses the desire for different sets of default attributes.

### Links

[Forum discussion](https://forum.dlang.org/thread/wnddmlmfinqqfccdlhqc@forum.dlang.org)

## Terminology

Groups of attributes that are mutually exclusive (such as `@safe`, `@system`, `@trusted`) and presence/absence attributes
(e.g. `pure`, `nothrow`) and their (currently) non-existant logical negations are called _attribute groups_.

## Rationale

Many users feel that the default attributes have the wrong defaults.
Attributes are not invertable, thus putting 
```
pure: nothrow: @nogc: @safe:
```
at the top of a file means that one can never "undo" those attributes.
This DIP proposes a solution to easily change the default values of the attributes while also allowing symbol specific 
overrides of individual attribute groups.

## Description

Move all (DMD) compiler recongnised attributes into `core.attribute`, making them symbols in their own right, 
grouping by attribute groups into `enum`s, each with
* a default value `inferred`. The compiler shall determine the value of the attribute. It is illegal to forward declare a function `inferred`.
* the attribute(s)
* (if applicable) the attributes' logical negation.

A module declaration may be tagged with zero or more attribute groups, to apply to all symbols (bar templates which remain inferred with explicit tagging) declared within the module acting as the default.
If any attribute groups are absent, then the value for that attribute group default to the corresponding value in `core.attribute.defaultAttributeSet`, which will have the values of the current defauls, but may be versioned in druntime as the end user wishes.
As all the attributes are now symbols we can group the in an `AliasSeq` like fashion to apply them én masse as is done in LDC for [`@fastmath`](https://github.com/ldc-developers/druntime/blob/ldc/src/ldc/attributes.d#L58).

It is illegl to explicitly provide more than one (mutually exclusive) attribute from any given attribute group. 
Attributes applied explicity override the module default attribute set.

### Breaking changes / deprecation process

Use of the current attributes that are not prefiex by an `@` such as `pure` and `nothrow`,
and optionally other modifiers that are attribute like such as `final` will be changed to refer to the `core.attribute` symbols,
and their use without the leading `@` will be deprecated.

No breaking changes are expected.

### Examples

`module foo;` 
will become implicitly 
`@core.attribute.defaultAttributeSet module foo;` 
with respect to attributes (`core.attribute` will be implicitly imported, by `object.d`), 
if no attributes from `core.attribute` are attached.

 Attribute groups may be selectivly added to the module declaration, so that:
 `@nocg module foo;` 
 means that all symbols in this module are implicity `@nogc` (with `nogc` referring to `core.attribute.GarbageCollectedness.nogc`),
 but otherwise has all the same defaults as the default attribute set.
 
 `@nogc @core.attribute.GarbageCollectedness.gc module foo;` 
 shall be an error because there are two explicit conflicting attribute.
 Likewise 
 ```
 module foo;
 @nogc @core.attribute.GarbageCollectedness.gc 
 void bar() { };
 ```
 shall be an error for the same reasons.
 
 ```
 @nogc module foo;
 
 // bar overrides the default @nogc'ness of the module and is @gc
 @core.attribute.GarbageCollectedness.gc void bar() {auto a = new int;} 
 
 // baz's gc'ness is determined by someOtherFunction
 @core.attribute.GarbageCollectedness.inferred void baz() { someOtherFunction(); }
 ```

## Copyright & License

Copyright (c) 2017 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## Review

Will contain comments / requests from language authors once review is complete,
filled out by the DIP manager - can be both inline and linking to external
document.
