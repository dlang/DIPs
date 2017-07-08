# Attributes

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | (number/id)                                                     |
| Review Count:   | 0
| Author:         | Nicholas Wilson                                                 |
| Implementation: | (links to implementation PR if any)                             |
| Status:         | Will be set by the DIP manager (e.g. "Approved" or "Rejected")  |

## Abstract

Addresses the desire for different sets of default attributes and rectifies the non-invertibilty
of the special compiler recognised attributes by having module level defaults. It does not (yet) 
propose any mechanism to remove compiler attributes directly (e.g. `@!nogc`).

### Links

[Forum discussion](https://forum.dlang.org/thread/wnddmlmfinqqfccdlhqc@forum.dlang.org)

## Terminology

Groups of attributes that are mutually exclusive (such as `@safe`, `@system`, `@trusted`) and presence/absence attributes
(e.g. `pure`, `nothrow`) and their (currently) non-existant logical negations are called _attribute groups_.

## Rationale

Many users feel that the default attributes have the wrong defaults and given that attributes are not invertable,  putting 
```
pure: nothrow: @nogc: @safe:
```
at the top of a file means that one can never "undo" those attributes.
This DIP proposes a solution to easily change the default values of the attributes while also allowing symbol specific 
overrides of individual attribute groups.

## Description

Move all (DMD) compiler recognized attributes into `core.attribute`, making them symbols in their own right, 
grouping by attribute groups into `enum`s, each with
* a value `inferred`. The compiler shall determine the value of the attribute. It is illegal to have a function declaration `inferred`.
* the attribute(s)
* (if applicable) the attributes' logical negation.

A module declaration may be tagged with zero or more attribute groups, to apply to all symbols (bar templates which remain inferred with explicit tagging) declared within the module acting as the default.
If any attribute groups are absent, then the value for that attribute group default to the corresponding value in `core.attribute.defaultAttributeSet`, which will have the values of the current defauls, but may be versioned in druntime as the end user wishes, of with command line switches (e.g. `-safe` or if Type_Info / Module Info generation is added as an attribute `-betterC`).

As all the attributes are now symbols we can group the in an `AliasSeq` like fashion to apply them en masse as is done in LDC for [`@fastmath`](https://github.com/ldc-developers/druntime/blob/ldc/src/ldc/attributes.d#L58).

It is illegal to explicitly provide more than one attribute from any given attribute group as they are mutually exclusive. 
Attributes applied explicity to any symbol override the module default attribute set.

### Attributes & attribute like compiler behaviour encompassed in this DIP

Encompassed:

* pure
* @nothrow
* @nogc
* @safe/@system/@trusted

Optionally encompassed:

* final
* Type_Info / Module Info generation (other components of -betterC?)

Not encompassed:

* @disable

### Breaking changes / deprecation process

Use of the current attributes that are not prefiex by an `@` such as `pure` and `nothrow`,
and optionally other modifiers that are attribute like such as `final` will be changed to refer to the `core.attribute` symbols,
and thus their use without the leading `@` will be deprecated. 

No breaking changes are intended, although the introduction of the new enum symbols to be implicitly imported by `object.d`
may break some code if the names chosen clash (unlikely).

### Examples

`module foo;` 

will become implicitly 

`@core.attribute.defaultAttributeSet module foo;` 

with respect to attributes (`core.attribute` will be implicitly imported, by `object.d`), 
if no attributes from `core.attribute` are attached.

 Attribute groups may be selectivly added to the module declaration, so that:
 
 `@nocg module foo;` 
 
 means that all symbols in this module are implicity `@nogc` (with `nogc` referring to `core.attribute.GarbageCollectedness.nogc` via an alias in `core.attribute`),
 but otherwise has all the same defaults as the default attribute set.
 
 `@nogc @core.attribute.GarbageCollectedness.gc module foo;` 
 shall be an error because there are two explicit mutually exclusive attributes.
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
 
 // quux is implicily @nogc because foo is @nogc
 void quux() {} 
 ```

## Copyright & License

Copyright (c) 2017 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## Review

Will contain comments / requests from language authors once review is complete,
filled out by the DIP manager - can be both inline and linking to external
document.
