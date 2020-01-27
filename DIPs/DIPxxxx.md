# Enhanced Attribute Defaults

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | (number/id -- assigned by DIP Manager)                          |
| Review Count:   | 0 (edited by DIP Manager)                                       |
| Author:         | anass-O                                                         |
| Implementation: | (links to implementation PR if any)                             |
| Status:         | Draft                                                           |

## Abstract

This DIP proposes the following two changes:

* Introducing new attributes `throw`, `impure`, and `@gc` as inverses of `nothrow`, `pure`, and `@nogc`.

* Allowing attributes (`@safe`, `@trusted`, `@system`, `throw/nothrow`, `pure/impure`, `@gc/@nogc`) that mutate function behavior to be set at the module level.


## Contents
* [Rationale](#rationale)
* [Prior Work](#prior-work)
* [Description](#description)
* [Breaking Changes and Deprecations](#breaking-changes-and-deprecations)
* [Reference](#reference)
* [Copyright & License](#copyright--license)
* [Reviews](#reviews)

## Rationale

Currently there is no easy way to set a default for function attributes. This includes the attributes for determining memory safety (`@safe`, `@trusted`, and `@system`) as well as the attributes `nothrow`, `pure`, and `@nogc`; which have various effects.

The easiest way to try to get behavior that changes the default attributes is to use the feature `@attribute:` that applies an `attribute` to everything after the `:`. This currently is the optimal solution as it reduces the amount of attribute bloat on every function, as opposed to labeling every function explicitly with the required attribute. There are still quite a few problems that are faced here.

```D
module someModule;

// attempt to change attributes to the desired defaults for this module
@safe nothrow pure @nogc:

struct SomeStruct {
    void someFunction() {
        // this function inherits `@safe` but doesn't inherit
        // `nothrow`, `pure`, nor `@nogc`

        throw new Exception(); // not `nothrow` or `@nogc`
        __gshared int a;       // not `pure`
    }
}

void someTemplateFunction(T...)(T args) {
    // loses auto inference
    // this function now is *required* to be `@safe nothrow pure @nogc`
    // even though it could auto infer these attributes
    // this usually isn't the desired behavior to have for a template
}

struct SomeBestPracticeStruct {
// these are *required* in each and every new aggregate scope
// for these attributes to be continued as the "default"
nothrow pure @nogc:

    void someFunction() {
        // now we have the desired effect, SomeBestPracticeStruct.someFunction
        // is `@safe nothrow pure @nogc` in comparison to SomeStruct.someFunction
        // that is only `@safe`
    }
}

struct SomeOtherBEsstPractiseStruct {
pure:

    void oneOrTwofunctionThatThrows() {
        // now we need just one or two functions that might need to throw
        // there are no inverses to `nothrow` nor `@nogc` so we would
        // need to shuffle this to the top

        throw new Exception();
    }

// now the intention isn't as obvious as this is separate from `pure:`
// and does not appear at the start of the aggregate scope
nothrow @nogc:

    // ...

}

```

To outline the problems with attempting to apply different default attributes:
* Not all attributes flow through aggregates, only `@safe`, `@trusted`, and `@system` do so. This means `@attribute:` is a no solution for every attribute. Changing this behavior would also cause significant breaking changes.
* Templates lose auto inference. As the attributes are applied to *everything* in the scope. This means they are also applied to templates and those templates are thus required to follow the rules of those attributes. Since templates can auto infer these attributes, the desired effect would be to simply have the template continue to be auto inferred. The function calling the template would then enforce any rules that would need to be applied.
* Attribute bloat at the aggregate scope. Since some attributes don't propagate through all scopes they must be reapplied for each new aggregate scope. This can become tedious and add extra bloat where it shouldn't be necessary.
* Lack of inverse effects for function attributes leads to odd reordering instead of maintaining the logical order of function definitions affecting readability. The `@attribute:` then appears somewhere in the middle of a large amount of code making it less visible and apparent of what the intention is.

## Prior Work

[DIP1029: Add throw as a function attribute.](https://github.com/dlang/DIPs/blob/master/DIPs/DIP1029.md)

[DIP10XX: Make nothrow the default.](https://github.com/dlang/DIPs/blob/master/DIPs/DIP1029.md)

[DIP1028: Make @safe the default.](https://github.com/dlang/DIPs/blob/master/DIPs/DIP1028.md)


## Description

The first part that is required is adding inverses to attributes which do not have one currently. This means introducing new attributes `throw`, `impure`, and `@gc` which correspond to have the inverse effect of the following respectively `nothrow`, `pure`, and `@nogc`. If the default of a module is set to `@nogc`, without the attribute `@gc` that entire module wouldn't be capable of using the GC, even if there may be one or two outlying functions that require it.

```D
nothrow {
    throw void foo() {
        throw new Exception(); // ok is throw
    }
}

pure {
    impure void foo() {
        __gshared int a; // ok is impure
    }
}

@nogc {
    @gc void foo() {
        int[] a = new int[10]; // ok is @gc
    }
}
```

Should an attribute and it's inverse appear explicitly declared on the same symbol, it shall be an error.

```D
throw nothrow void foo(); // error conflicting attributes
pure impure   void foo(); // "
@gc @nogc     void foo(); // "

throw:
    nothrow foo(); // ok, is nothrow

impure:
    pure void foo(); // ok, is pure

@gc:
    @nogc void foo(); // ok, is @nogc
```

The next part is to allow the default to be set at the module level. This would be done by adding the attribute in front of the `module` declaration at the beginning of the source file. The attributes that would be considered are as follows: `@safe`, `@trusted`, `@system`, `nothrow`, `throw`, `pure`, `impure`, `@nogc`, and `@gc`.

The attribute applied to the module would then be used as the default. It will not be applied to templates, as `@attribute:` did, templates will remain auto inferred.

```D
@safe nothrow pure @nogc module someModule;

struct SomeStruct {
    void someFunction() {
        // has the desired attributes `@safe nothrow pure @nogc`
    }
}

void someTemplateFunction(T...)(T args) {
    // auto inferred
    // defaults at the module level do not affect template auto inferring
    // in contrast to how `@attribute:` does
}

struct SomeOtherStruct {
    // @nogc functions...

    @gc void someOtherFunction() {
        // functions can stay in their logical order
        // should a function require something other than the default
        // set at the module level, they can declare so with the
        // new attribute with the inverse effect

        int[] a = new[10]; // ok
    }

    // @nogc functions...
}
```

Only function attributes are being considered for this DIP as these attributes tend to be applied on a larger scale. You may want an entire library to be `@nogc`, but making an entire library comprised of `immutable` variables isn't very useful. Attributes such as `immutable` also do not suffer the problem related to template auto inferring, which is a main factor in why `@attribute:` is insufficient for function attributes.

Changing the language defaults doesn't address the larger problem that a user can't easily set the defaults they require for a module. As described in [DIP1028](#Prior&#32;Work) and [DIP10XX](#Prior&#32;Work), which intend to change the language defaults without any easy upgrade path to make old `@system` and `throw` code compilable again. Why `@system:` and (the proposed) `throw:` aren't sufficient solutions has already been outlined in the [rationale](#Rationale) regarding the problems with `@attribute:` and defaults. Should `@safe` and `nothrow` become the default, this DIP resolves the problem with letting the user easily choose which defaults they desire for a module. Which before the burden was simply being shifted onto `@system` and `throw` users. With this proposal a user can simply add `@system`, `throw`, `@safe`, or `nothrow` before `module` in each source file. Resolving the issue of defaults irregardless of what attributes are actually the default. The default can be easily set to whatever meets a user's requirements for their module and/or project.

Ultimately `@attribute:` is more of an antipattern than a feature that should be promoted. When it appears in the middle of a large amount of code it can be difficult to see what the intention is and what behavior is being changed. With this proposal, the default can be set at the module level and the outlying functions can be explicitly marked with clear intention. Otherwise when a function isn't explicitly marked, what attributes a function inherits can be easily found at the very first line of the source file. Ideally `@attribute:` would be deprecated at the module level, but this is not the intention of this proposal nor is it a requirement for any future proposal. This proposal does not serve to dictate the best practices of a user, should they desire to continue to use `@attribute:`, it is their option to.

Part of the rationale for why attributes aren't passed through scopes and aggregates is it would promote declaring attributes at each new scope [\[1\]](#Reference). As described this problem already exists today. If the defaults do not match what you desire, you are **required** to declare attributes at each new aggregate/scope. This is not a pattern you simply can not follow, if it were simply a best practice. But it is practice you are forced to follow as you are unable to change the defaults and the defaults are reset at each new aggregate/scope.

### Grammar Changes

```diff
ModuleAttribute:
    DeprecatedAttribute
    UserDefinedAttribute
+   @safe
+   @system
+   @trusted
+   throw
+   nothrow
+   pure
+   impure
+   @gc
+   @nogc

FunctionAttribute:
+   throw
    nothrow
    pure
+   impure
    Property

AtAttribute:
    @ disable
+   @ gc
    @ nogc
    Property
    @ safe
    @ system
    @ trusted
    UserDefinedAttribute
```

## Breaking Changes and Deprecations

Any use of `impure` would need to be substituted for `_impure` or otherwise a different name. This is not a common word to be used and breakage is expected to be minimal. The keyword can be a situational keyword for a limited time to ease the transition.

Any attributes using the `@gc` name would also need to be changed. This is not a common attribute name used and breakage is expected to be minimal.

## Reference

\[1\] [Walter Bright: Attribute Best Practices](https://forum.dlang.org/post/qvmf7m$qte$1@digitalmars.com)

## Copyright & License
Copyright (c) 2020 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## Reviews
The DIP Manager will supplement this section with a summary of each review stage
of the DIP process beyond the Draft Review.