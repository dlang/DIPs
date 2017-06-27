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

## Rationale

State a short motivation about the importance and benefits of the proposed
change.  An existing, well-known issue or a use case for an existing projects
can greatly increase the chances of the DIP being understood and carefully
evaluated.

Many users feel that the default attributes have thr wrong defaults.
Attributes are not invertable.

## Description

Move all (DMD) compiler recongnised attributes into `core.attribute`, making them symbols in their own right.

Group mutually exclusive attributes together (making them different members of the same `enum`) with an additional value of infered,
e.g. `@system`,`@trusted`,`@safe` would all refer to the same enum, with inferred being the default. This is called an _attribute group_.
This also make attributes that do not begin with an `@` such as `nothrow` `pure` now start with an `@`, deprecate the form without the `@`.

Allow tagging a module declaration with these attributes, to apply to all symbols.
As all the attributes are now symbols we can group the in an `AliasSeq` to apply them én masse as is done in LDC for [`@fastmath`](https://github.com/ldc-developers/druntime/blob/ldc/src/ldc/attributes.d#L58).

Have an `AliasSeq` of the default values of the current attributes be applied when a sepcific attribute group is absent,
taking on the current default set of attributes if none are specified.

It is illegl to provide more than one mutually exclusive attribute from any given attribute group. 
Attributes applied explicity override the module default attribute set.

The attributes of templates shall conform to the attributes of the point of instansiation (with the defaults of being inferred shall be no change).

### Breaking changes / deprecation process

Use of the current attributes that are not prefiex by an `@` such as `pure` and `nothrow`,
and optionally other modifiers that are attribute like such as `final` will be changed to refer to the `core.attribute` symbols,
and their use without the leading `@` will be deprecated.

No breaking changes are expected.

### Examples

`module foo;` will become synonymous with `@core.attribute.defaultAttributeSet module foo;` 
(`core.attribute` will be implictly imported, by `object.d`)

 attribute groups may be selectivly added 
 `@nocg module foo;` - all symbols in this module are implicity `@nogc` with `nogc` reffering to `core.attribute.GarbageCollectedness.nogc`,
 but otherwise has all the same defaults as the default attribute set.
 
 `@nogc @core.attribute.GarbageCollectedness.gc module foo;` shall be an error because there are two explicit conflicting attribute.
 likewise 
 ```
 module foo;
 @nogc @core.attribute.GarbageCollectedness.gc module foo;
 ```
 shall be an error for the same reasons.
 ```
 @nogc module foo;
 @core.attribute.GarbageCollectedness.gc void bar() {new int;} // bar overrides the default @nogc'ness of the module and is @gc
 @core.attribute.GarbageCollectedness.inferred void baz() { someOtherFunction(); } // baz's gc'ness is determined by someOtherFunction
 ```

## Copyright & License

Copyright (c) 2017 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## Review

Will contain comments / requests from language authors once review is complete,
filled out by the DIP manager - can be both inline and linking to external
document.
