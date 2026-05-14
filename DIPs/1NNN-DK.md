# `@default` attribute

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | (number/id -- assigned by DIP Manager)                          |
| Review Count:   | 0 (edited by DIP Manager)                                       |
| Author:         | Dennis Korpel (dkorpel@gmail.com)                               |
| Implementation: |                                                                 |
| Status:         | Will be set by the DIP manager (e.g. "Approved" or "Rejected")  |

## Abstract

Add a `@default` attribute, which removes the effect of lexically preceding attributes.

## Contents
* [Rationale](#rationale)
* [Prior Work](#prior-work)
* [Description](#description)
* [Breaking Changes and Deprecations](#breaking-changes-and-deprecations)
* [Reference](#reference)
* [Copyright & License](#copyright--license)
* [Reviews](#reviews)

## Rationale

D supports [many attributes](https://dlang.org/spec/attribute.html).
When a multitude of attributes needs to apply to a multitude of declarations, it can lead to visual noise from
repeating the attribute names, colloquially called 'attribute soup'.

```D
struct S
{
    private void f() const @nogc nothrow pure @safe
    {

    }

    private void g() const @nogc nothrow pure @safe
    {

    }

    // ...
}
```

One way to mitigate this is by using the `Attribute:` syntax, which will make the attribute apply to all following declarations until the end of the scope the attribute appears in.

```D
struct S
{
    @nogc nothrow pure @safe:
    private:
    const:

    void f()
    {

    }

    void g()
    {

    }

    // ...
}
// attributes' influence ends here
```

This reduces the repetition of attributes, but it becomes a problem when there are a few declarations that need an exception.
Sometimes this can be solved by annotating the exceptional declaration with an inverse attribute:

| Attribute                | Undone by           |
|--------------------------|---------------------|
| `private`                | `public`            |
| `@system`                | `@safe`             |
| `extern(C)`              | `extern(D)`         |
| `nothrow`                | `throw`             |
| `pragma(inline, true)`   | `pragma(inline)`    |

However, most attributes do not have an inverse that resets it to the default:

- `align()`
- `deprecated`
- `static`
- `extern`
- `abstract`
- `final`
- `override`
- `synchronized`
- `scope`
- `const`
- `immutable`
- `inout`
- `shared`
- `__gshared`
- `pure`
- `@disable`
- `@nogc`
- `@property`
- `@UserDefinedAttribute`

Moreover, because function attributes are inferred in template functions, forcing them back to the default is not always desirable either.
Consider:

```
struct S
{
    @nogc nothrow pure @safe:

    void f() { }

    void g() { }

    void toString(O)(ref O sink) if (isOutputRange!(O, char))
    {
    }
}
```

In this case, the `toString` method should not force the provided Output Range to have an implementation of `sink.put` with all function attributes, but
neither should `toString` be denied those attributes when it can infer them.
The only option here is to place all template methods above the `@nogc nothrow pure @safe:` line, or go back to 'attribute soup' by repeating all function attributes for individual members.

What is really desired is something to specify that attributes on `toString` should go back to the default state,
which this DIP proposes in the form of the `@default` attribute.

## Prior Work

- [DIP 1029 - Add throw as Function Attribute](http://dlang.org/dips/1029)
The `throw` attribute was added to address the lack of a way to invert the effect of `nothrow:`.
However, it has not been implemented yet, and can be superseded by this DIP.

- [DIP 1012 - Function Attributes](http://dlang.org/dips/1012)
Proposes to move function attributes to `core.attribute` enabling traditional methods of attribute manipulation (`AliasSeq`) and introspection.
This DIP has been abandoned.

## Alternatives

It has been proposed before that attributes could take a boolean parameter evaluated at CTFE (e.g. `@safe(x && y)`), or reset to the default by passing the `default` keyword as a parameter.
This allows more precision, but it is more complex and verbose:

```D
@nogc nothrow pure @safe:

// ...

void f(T)(T x) @nogc(default) @nothrow(default) pure(default) @safe(default)
{

}
```

Another option is to use `@default` to specify default function attributes for regular functions, but not functions with attribute inference.
```D
struct S
{
    @default @nogc nothrow pure @safe:

    void f() {}    // attributes apply here

    auto g(T)() {} // does not apply here
}
```
However, this does not provide a way to invert attributes that aren't inferred.
Neither does it provide a way to invert function attributes on functions without attribute inference.

```
struct S
{
@default @nogc const:

    void usesGc() {} // out of luck, not a template

    void mutates(T)() {} // out of luck, `const` is not inferred
}
```

### Syntax

The syntax `@default` is chosen because `default` is already a reserved keyword, but it may not be the clearest name.
A different name, such as `@reset`, could be considered, despite it potentially being used as a User Defined Attribute already.

The `@` could be omitted when using the `default` keyword, but it is suggested to keep it to make it clear it's related to attributes, and not types or the `default` statement.

## Description

The `@default` attribute is added as an `AtAttribute`.

```diff
AtAttribute:
+   @ default
    @ disable
    @ nogc
    @ live
    Property
    @ safe
    @ system
    @ trusted
    UserDefinedAttribute
```

The `@default` attribute is not attached to any declarations.
Instead, it prevents any lexically preceding attributes from applying to the declarations that would have the `@default` attribute applied to them.

```
@safe pure nothrow:
private:

// ...

@default @safe:

void normalFunc() // public, and only @safe
{

}

@default private void templateFunc(R)(R range) // private, all attributes inferred
{
    foreach(e; range) {}
}

private @safe pure @default void noAt(); // no attributes apply
```

## Breaking Changes and Deprecations

Since `default` is a keyword, existing User Defined Attributes cannot be called `@default`, so there is no breakage.

## Reference
- [Attributes in the specification](https://dlang.org/spec/attribute.html)

## Copyright & License
Copyright (c) 2022 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## Reviews
The DIP Manager will supplement this section with a summary of each review stage
of the DIP process beyond the Draft Review.
