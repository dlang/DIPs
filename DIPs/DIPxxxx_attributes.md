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
of the built-in attributes attributes by having module level defaults. It does not (yet) 
propose any mechanism to remove compiler attributes directly (e.g. `@!nogc`).

### Links

[Forum discussion](https://forum.dlang.org/thread/wnddmlmfinqqfccdlhqc@forum.dlang.org)

## Terminology

Groups of attributes that are mutually exclusive (such as `@safe`, `@system`, `@trusted`) and binary attributes
(e.g. `pure`, `nothrow`) and their (currently) non-existant logical negations are called _attribute groups_.

Attributes from `core.attribute` are called core attributes.

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
grouping by attribute groups into `enum`s, each with the following members:
* `inferred`. The compiler shall determine the value of the attribute. It is illegal for a function declaration without a body to be marked `inferred`. Does not apply to `final`/`virtual`.
* the attributes default value e.g. `@system` impure
* the default values' logical negation e.g `@safe` pure
* any remaining attributes, e.g. `@trusted`

It is suggested that 
* `inferred` have the value 0, and the compiler shall be required to determine the appropriate value and use that to replace enum 
core attributes which are set to the value `inferred`, i.e. no symbols in object files or in reflection shall have a core attribute
with the value `inferred`. 
* the attributes current default have the value 1.
* the negation of the default the value 2.
* any other values (e.g. `@trusted`) continue from the value 3.

As all the attributes are now symbols we can:
* group them in an `AliasSeq` like fashion to apply them en masse, as is done in LDC for [`@fastmath`](https://github.com/ldc-developers/druntime/blob/ldc/src/ldc/attributes.d#L58)
* mutate the `AliasSeq`s with compile time computations.

A module declaration may be tagged with zero or more attribute groups to apply to all symbols declared within the module acting as the default, with except of templates which remain inferred with explicit tagging.
Any attribute groups not provided will be inserted into the modules' attribute list from `core.attribute.defaultAttributeSet`, the master set of atributes. 

The values of `core.attribute.defaultAttributeSet` will be determined by version conditions under the control of compiler switches to provide maximum utility and flexibility, like so:

```
version (D_SafeD)
    alias __defaultSafetyAttribute = FunctionSafety.safe;
else
    alias __defaultSafetyAttribute = FunctionSafety.inferred;

version (D_BetterC)
{
    alias defaultAttributeSet = 
        AliasSeq!(nogc,
                  __defaultSafetyAttribute,
                  nothrow,
                  FunctionPurity.inferred);
}
else
{
    alias defaultAttributeSet = 
        AliasSeq!(FunctionGarbageCollectedness.inferred,
                  __defaultSafetyAttribute,
                  FunctionThrowness.inferred,
                  FunctionPurity.inferred);
}                                     
```
It is also possible for the end user to directly control `core.attribute.defaultAttributeSet` by editing druntime directly.

It is illegal to explicitly provide more than one attribute from any given attribute group as they are mutually exclusive. 
Attributes applied explicity to any symbol override the module default attribute set.

### Attributes & attribute like compiler behaviour encompassed in this DIP

Encompassed:

* pure
* @nothrow
* @nogc
* @safe/@system/@trusted

Optionally encompassed:

* final/virtual
* Type_Info / Module Info generation (other components of -betterC?)

Not encompassed:

* @disable
* @property

as they are not grouped and do not make sense as a default.

### Breaking changes / deprecation process

Use of the current attributes that are not prefiex by an `@` such as `pure` and `nothrow`,
and optionally other modifiers that are attribute like such as `final` will be changed to refer to the `core.attribute` symbols,
and thus their use without the leading `@` will be deprecated. 

No other breaking changes are intended, although the introduction of the new enum symbols to be implicitly imported by `object.d`
may break some code if the names chosen clash (unlikely).

### Examples

`module foo;` 

will become implicitly 

`@core.attribute.defaultAttributeSet module foo;` 

with respect to attributes (`core.attribute` will be implicitly imported, by `object.d`), 
if no attributes from `core.attribute` are attached.

 Attribute groups may be selectivly added to the module declaration, so that:
 
 `@nogc module foo;` 
 
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
 void quux();
 
 // Error: declarations may not have their attributes be explicity inferred
 @core.attribute.GarbageCollectedness.inferred blarg(); 
 ```

As the core attributes are now also regular attributes we can manipulte them as such:

```
version(SafeD) // hypothetically set by -safe on the command line
{
    alias __defaultSafetyAttribute = FunctionSafety.safe;
}
else
{
    alias __defaultSafetyAttribute = FunctionSafety.system; // or inferred
}
// Similarly for the other core attributes

alias defaultAttributeSet = AliasSeq!(__defaultSafetyAttribute, __defaultThrowAttribute, ...); // ... meaning and so on
```

A similar approach could be used to always have -betterC imply `@nothrow @nogc` (and Typeinfo emission if it were to come under the control of an attribute).

It is also possible to conveniently infer multiple attributes at once:

```
template infer(Attrs...)
{
    static if (Attrs.length == 0) alias infer = AliasSeq!();
    else static if (is(typeof(Attr[0] == cast(typeof(Attrs[0]))0))) // if e is a value of an enum
    {
        alias infer = AliasSeq!(typeof(Attr[0]).inferred,infer!(Attrs[1 .. $]));
    }
    else 
        alias infer = AliasSeq!(Attr[0].inferred,infer!(Attrs[1 .. $]));

}
```

and can be used like

```
@infer!(nogc,FunctionSafety) module foo;
```
to infer attributes by either the core attribute enum (`FunctionSafety` in the above example) or a value of that enum (`nogc` in the above example).

## Copyright & License

Copyright (c) 2017 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## Review

Will contain comments / requests from language authors once review is complete,
filled out by the DIP manager - can be both inline and linking to external
document.
