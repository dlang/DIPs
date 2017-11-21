# Binary assignment operators for properties

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | 1xxx-mvf                                                        |
| Review Count:   | 0                                                               |
| Author:         | Michael V. Franklin (slavo5150@yahoo.com)                       |
| Implementation: | [PR 7079](https://github.com/dlang/dmd/pull/7079) (WIP)         |
| Status:         |                                                                 |

## Abstract

This document is a proposal to fill some holes in D's property design and implementation by addressing binary assignment operators (`x += v`, `x -= v`, `x ~= v`, etc...).  All other issues and problems in the design and implementation of properties are out of scope.

This proposal does not address unary assignment operators (e.g. `x++`, `++x`, etc...) as they are orthogonal to binary assignment operators, may require special considerations not present in this proposal, and would only complicate this DIP's review and approval process.  However, if and when this proposal is accepted and implemented, a followup DIP addressing unary assignment operators would be a logical progression, and is already planned for by the author of this DIP.

### Links

Historical DIPs and Discussions
  - [Prowiki Property](http://www.prowiki.org/wiki4d/wiki.cgi?DocComments/Property) - An old, but rather thorough examination of properties in the D language, [originally authored in August, 2007](http://forum.dlang.org/post/h5g94a$lc5$1@digitalmars.com).
  - [DIP4](https://wiki.dlang.org/DIP4) - First known DIP to address properties.  Superseded by DIP6
  - [DIP5](https://wiki.dlang.org/DIP5) - A variant of DIP4.  Superseded by DIP6.
  - [DIP6](https://wiki.dlang.org/DIP6) - Apparently the approved DIP that introduced the `@property` attribute.
  - [DIP21](https://wiki.dlang.org/DIP21) - A very brief proposal to "fix @property", specifically ambiguities in UFCS and optional parentheses.
  - [DIP23](https://wiki.dlang.org/DIP23) - A thorough proposal by Walter and Andrei to "Fix properties"
    - [Forum Discussion](http://forum.dlang.org/post/kel6c8$1h5d$1@digitalmars.com)
  - [DIP24](https://wiki.dlang.org/DIP24) - A Counter-proposal to DIP23
    - [Forum Discussion](http://forum.dlang.org/post/kes8or$nfj$1@digitalmars.com)
  - [DIP26](https://wiki.dlang.org/DIP26) - An attempt to establish a concrete definition of properties.  Essentially a counter-proposal to DIP23 and DIP24
    - [Forum Discussion 1](http://forum.dlang.org/post/mailman.1134.1360367620.22503.digitalmars-d@puremagic.com)
    - [Forum Discussion 2](http://forum.dlang.org/post/kf69m9$be2$1@digitalmars.com)
  - [DIP28](https://wiki.dlang.org/DIP28) - Another attempt at defining properties
    - [Forum Discussion](http://forum.dlang.org/post/fhjdrakntvahnmcwkvlv@forum.dlang.org)

Bugzilla Issues
  - [Issue 8006](https://issues.dlang.org/show_bug.cgi?id=8006) - Bugzilla issue specifically noting the absence of binary and unary assignment operators for properties.
  - [Issue 16187](https://issues.dlang.org/show_bug.cgi?id=16187) - Bugzilla issue specifically noting the absence of binary and assignment operators for `std.bitmanip.bitfields`.

Other
  - [Mutator methods](https://en.wikipedia.org/wiki/Mutator_method) - Wikipedia article documenting the implementation of property getters and setters.
  - [Property (programming)](https://en.wikipedia.org/wiki/Property_(programming)) - Wikipedia article documentating the the property abstraction.
  - [Comment in the implementation's pull request](https://github.com/dlang/dmd/pull/7079#issuecomment-327924953) that ultimately led to this DIP's current design and implementation.
  - [The D Programming Language by Walter Bright](https://youtu.be/WKRRgcEk0wg?t=64) - A talk presenting some of the pillars of the D programming language.

## Rationale

Properties in D have become quite the controversy and there has been no shortage of DIPs to try to remedy the situation.  Reviewing the previous DIPs and their forum discussions has revealed that the controversy is not with regard to binary assignment operators for properties, but rather with the ambiguities introduced by the interplay of properties, UFCS, optional parentheses, and other features of the language.

This DIP attempts to remove the non-controversial binary assignment operators feature from the larger property issue in an effort to not only move the design of properties forward, but also reduce the scope of and simplify the larger issue.

This DIP assumes that, since D has already opted into the properties feature, binary assignment operators for properties has always been a goal.  However, due to the aforementioned controversies, and the subtle gotchas lurking in the implementation details, the feature had become a difficult challenge, and therefore avoided.

That being said, this DIP still provides the following motivations.

### D's property implementation fails the Duck Test

After learning that D supports the property abstraction, users may approach the feature with [abductive reasoning](https://en.wikipedia.org/wiki/Duck_test) only to discover that, while simple assignment works as expected, binary assignment doesn't.

```D
struct S
{
    int field;

    int Property()          @property { return field; }
    int Property(int value) @property { return field = value; }
}

void main()
{
    S s;
    int value = s.Property;   // OK: Looks like a duck
    s.Property = value;       // OK: Swims like a duck
    s.Property += value;      // Error: s.Property() is not an lvalue: (i.e. Doesn't quack like a duck)
}
```

It is not apparent why D does not support binary assignment operators for properties.  We are left to assume that the design and implementation or properties in D is simply [unfinished business](http://forum.dlang.org/post/mgja40$2dhp$1@digitalmars.com), as no one has taken the initiative to work out the design and do the implementation.

### Modeling Power & Modern Convenience: Two pillars of D

Properties in D provide support for two of its fundamental pillars: Modeling Power and Modern Convenience.  However, the implementation is incomplete without binary assignment operators, so users are not able to completely encapsulate their implementation behind the property abstraction, nor provide the full convenience of that abstraction to their users.

When a language provides the property abstraction, users expect to be able to write expressions as one would with fields (e.g `a.prop += 1` instead of `a.prop(a.prop() + 1)`).  Granted, there are techniques in D that one can employ to achieve the former, but those techniques violate encapsulation and do not scale to all use cases, as further explained in the sections to follow.

### Lack of binary assignment operators for properties proliferates anti-patterns

[Issue 8006](https://issues.dlang.org/show_bug.cgi?id=8006) documents the lack of binary assignment operators for properties in D, and the desire by some users to have them.  Due to this issue, D programmers desiring the property abstraction are choosing to return fields by reference when, arguably, they should be returning fields by value.

```D
struct S
{
    int field;

    // Preferred pattern
    int prop()          @property { return field; }
    int prop(int value) @property { return field = value; }

    // Anti-pattern, leaking the abstraction
    ref int refProp()   @property { return field; }
}

void main()
{
    S s;

    // Preferred pattern, doesn't compile under existing implementation
    s.prop    += 1;    // Existing Implementation: Error: s.Property() is not an lvalue

    // Anti-pattern is used to "workaround" the lack of binary assignment operators for properties
    s.refProp += 1;    // Existing Implementation: OK: Operator is applied to return value
}
```
Unfortunately, [this anti-pattern has proliferated](https://github.com/dlang/phobos/search?utf8=%E2%9C%93&q=%22property%20ref%22).

If a setter were added to an lvalue property, it would never be called.

```D
struct S
{
    int field;
    int setterCount;

    ref int refProp() @property
    {
        return field;
    }

    // This setter is never called.  Cannot add additional logic to the setting
    // of the property.
    ref int refProp(int value) @property
    {
        setterCount++;
        return field = value;
    }
}

void main()
{
    S s;

    s.refProp += 1;
    assert(s.setterCount == 0);  // Existing Implementation: Setter is never called
}
```

Since D doesn't support binary assignments on rvalue properties and setters are bypassed for lvalue properties, it is currently not possible to add additional logic to the binary assignment of properties, diminishing the appeal of employing the property abstraction.

First-class binary assignment operators for properties would allow users to use rvalue properties, properly encapsulating their implementation without resorting to questionable techniques and leaky abstractions.

### Returning an lvalue is not always possible

[Issue 16187](https://issues.dlang.org/show_bug.cgi?id=16187) demonstrates a unique niche where properties are an attractive abstraction, but, due to the fact that bitfields are not individually addressable, it is not possible to work around the issue by returning an lvalue.

```D
struct S
{
    int field;

    ref int prop() @property
    {
        return field & 0b11;  // Existing Implementation: Error: `this.field & 3` is not an lvalue
    }
}

void main()
{
    S s;

    s.prop += 1;
}
```

First-class binary assignment operators for properties would provide a holistic solution that will scale well to all use cases where properties are an attractive abstraction.

### Precedence in other programming languages

The following popular programming languages [all support some sort of property syntax](https://en.wikipedia.org/wiki/Property_%28programming%29) and *also* all support binary assignment operators on said properties.

- C#/VB.Net
- Python
- Javascript
- Objective-C
- Swift

It is logical to assume that users familiar with those languages and their features will come to D with the expectation that D's properties should behave in a similar manner.

### A casual cost/benefit observation

[The implementation of this proposal](https://github.com/dlang/dmd/pull/7079) turned out to be quite simple, cohesive, and localized within the compiler's source code; it is a single additional function within the compiler's frontend.  It seems a relatively small cost compared to the modeling power, modern convenience, and potential reach that it adds to D's existing property abstraction features.

## Description

This DIP proposes the following design:

Consider the binary assignment expression `e1.prop @= e2` where `prop` is a getter or getter/setter pair of `@property` functions and `@=` is one of D's existing binary assignment operators.

**Requirements**
- **Requirement 1** - The operation must be performed according the existing specification of the binary assignment operator, `@=`.
- **Requirement 2** - `e1` must only be evaluated once.
- **Requirement 3** - `e1` must never be copied.
- **Requirement 4** - getter and setter each must be called exactly once.

In the general case, to meet these requirements, the binary assignment expression is lowered to the lambda expression `((auto ref _e1) => _e1.prop(_e1.prop() @ e2))(e1)` except under the following conditions:

- **Special Case 1** - If either the getter or setter function is not attributed with `@property` the binary assignment expression will not be lowered.
- **Special Case 2** - If the getter returns an lvalue, the binary assignment expression will not be lowered.
- **Special Case 3** - If `e1` is a type (e.g. `prop` is a `static` property or module-level property), the binary assignment expression will be lowered to `e1.prop(e1.prop() @ e2)`.  Special Cases 1 and 2 still apply.

The following subsections elaborate on each of these items.

### The general case

In the general case, the lowering to the lambda expression, ensures that `e1` is only ever evaluated once, and never copied.  For example, with the binary assignment expression `arr[i++].prop += 1`, `i` should only be incremented once.  The lambda expression also avoids the copying side effects of `e1` (e.g. a call to a copy constructor if `e1` were to be copied to a temporary variable).

The following example will compile and run under the existing compiler implementation demonstrating the proposed lowering.

```D
struct S
{
    int field;
    int copyCount;
    int getterCount;
    int setterCount;

    this(this)
    {
        copyCount++;
    }

    int prop() @property
    {
        getterCount++;
        return field;
    }

    int prop(int value) @property
    {
        setterCount++;
        return field = value;
    }
}

S s;
int getCount;

S* e1()
{
    getCount++;                  // introduce side effect for `e1`
    return &s;
}

void main()
{
    // The lowering of `s.prop += 1` as proposed in this DIP.
    // Compiles and produces the expected result in the existing implementation
    ((auto ref _e1) => _e1.prop(_e1.prop() + 1))(e1);

    assert(s.field == 1);        // Requirement 1: Confirm desired result
    assert(getCount == 1);       // Requirement 2: Confirm `e1` was only evaluated once
    assert(s.copyCount == 0);    // Requirement 3: Confirm `e1` was not copied
    assert(s.getterCount == 1);  // Requirement 4: Confirm getter was called exactly once
    assert(s.setterCount == 1);  // Requirement 4: Confirm setter was called exactly once
}
```

#### Free properties with a context argument

Free properties with a context argument can be called with UFCS.  Binary assignment expressions with such properties are lowered to the lambda expression just as they would be if they were members of the context argument.  [Special case 1](#Special%20case%201) and [special case 2](#Special%20case%202) still apply.

```D
struct S
{
    int field;
}

int prop(S* context) @property { return context.field; }
int prop(S* context, int value) @property { return context.field = value; }

void main()
{
    S s;

    // The lowering of `s.prop += 1` as proposed in this DIP.
    // Existing Implementation:  Compiles and produces the expected result.
    ((auto ref _e1) => _e1.prop(_e1.prop() + 1))(&s);

    assert(s.field == 1);
}
```

### Special case 1

Special case 1 places some restrictions on which functions can participate in the lowering.  Given that `@property` function and ordinary function overloads cannot coexist, it's somewhat of a moot point, but stated regardless for completeness.

If binary assignment operators for functions with optional parentheses that return rvalues is desired, it should be argued for in a separate DIP.

```D
struct S
{
    int field;

    // Getter `@property` function that returns an rvalue.
    // Accompanying setter `@property` function.
    //--------------------------------------------------------------
    int prop1() @property
    {
        return field;
    }

    int prop1(int value) @property
    {
        return field = value;
    }

    // `@property` on getter, but not setter.
    //--------------------------------------------------------------
    int prop2() @property
    {
        return field;
    }

    int prop2(int value)         // NOTE: no `@property` attribute
    {
        return field = value;
    }

    // `@property` on setter, but not getter.
    //--------------------------------------------------------------
    int prop3()                 // NOTE: no `@property` attribute
    {
        return field;
    }

    int prop3(int value) @property
    {
        return field = value;
    }

    // Ordinary function that returns an rvalue.
    // Accompanying ordinary setter function.
    //--------------------------------------------------------------
    int prop4()                 // NOTE: no `@property` attribute
    {
        return field;
    }

    int prop4(int value)        // NOTE: no `@property` attribute
    {
        return field;
    }
}

void main()
{
    S s;

    s.prop1 += 1;               // Existing Implementation:
                                // Compiler error: The operator cannot be applied to rvalues.
                                //-------------------------------------------------------------------
                                // Proposed Implementation:
                                // OK: The General Case: The expression is, therefore, lowered to the
                                // lambda expression and executed.  The getter and setter are both
                                // called exactly once.

    s.prop2 += 1;               // Existing Implementation:
                                // Compiler error: `@property` and ordinary functions overloads
                                // cannot coexist.
                                //-------------------------------------------------------------------
                                // Proposed Implementation:
                                // Compiler error: Special Case 1: Due to absence of the
                                // `@property` attribute on the setter, the expression is not
                                // lowered resulting in the existing implementation, maintaining
                                // the status quo.

    s.prop3 += 1;               // Existing Implementation:
                                // Compiler error: The operator cannot be applied to rvalues.
                                //-------------------------------------------------------------------
                                // Proposed Implementation:
                                // Compiler error: Special Case 1: Due to absence of the
                                // `@property` attribute on the getter, the expression is not
                                // lowered resulting in the existing implementation, maintaining
                                // the status quo.

    s.prop4 += 1;               // Existing Implementation:
                                // Compiler error: The operator cannot be applied to rvalues.
                                //-------------------------------------------------------------------
                                // Proposed Implementation:
                                // Compiler error:  Special Case 1: Due to the absence of the
                                // `@property` attribute, the expression is not lowered resulting
                                // in the existing impelementation, maintaining the status quo.
}
```

### Special case 2

If a getter returns an lvalue, the binary assignment expression is not lowered, resulting in the binary assignment operator being applied to the return value of the getter.

```D
struct S
{
    int field;

    // Getter `@property` function that returns an lvalue.
    // No setter.
    //--------------------------------------------------------------
    ref int prop1() @property
    {
        return field;
    }

    // Getter `@property` function that returns an lvalue.
    // Accompanying setter `@property` function.
    //--------------------------------------------------------------
    ref int prop2() @property
    {
        return field;
    }

    ref int prop2(int value) @property
    {
        return field = value;
    }

    // Ordinary function that returns an lvalue.
    // No accompanying setter
    //--------------------------------------------------------------
    ref int prop3()             // NOTE: no `@property` attribute
    {
        return field;
    }
}

void main()
{
    S s;

    s.prop1 += 1;               // Existing Implementation:
                                // OK: Operator is applied to the return value.
                                //-------------------------------------------------------------------
                                // OK: Special Case 2: Due to the fact the getter returns an lvalue,
                                // the expression is not lowered, resulting in the existing
                                // implementation's behavior, maintaining the status quo.

    s.prop2 += 1;               // Existing Implementation:
                                // OK: Operator is applied to the return value.  Setter is
                                // never called.
                                //-------------------------------------------------------------------
                                // Proposed Implementation:
                                // OK: Special Case 2: Due to the fact the getter returns an lvalue,
                                // the expression is not lowered, resulting in the existing
                                // implementation's behavior, maintaining the status quo.

    s.prop3 += 1;               // Existing Implementation:
                                // OK: Due to existing optional parentheses feature, operator
                                // is applied to the return value.
                                //-------------------------------------------------------------------
                                // Proposed Implementation:
                                // OK: Special Cases 1 and 2: Due to the absence of the `@property`
                                // attribute and the fact that the getter returns an lvalue, the
                                // expression is not lowered, resulting in the existing
                                // implementation's behavior, maintaining the status quo.
}
```

Despite the unfortunate inconsistency of this proposal treating rvalue properties and lvalue properties differently, it is necessary to prevent breakage and maintain the status quo.

Without this special case the following Phobos implementations would break.

- [`std.typecons.Nullable`](https://github.com/dlang/phobos/blob/feab9a2f5225d7f3a5179f24ae3699e64455807c/std/typecons.d#L2562-L2573)
- [`std.json.JSONValue`](https://github.com/dlang/phobos/blob/feab9a2f5225d7f3a5179f24ae3699e64455807c/std/json.d#L276-L287)

There would likely be other breakages in the D ecosystem.

### Special case 3

If `e1` is a type, and `prop` is a `static` property of that type, the semantics of `e1` are quite different (i.e. *Requirement 2* and *Requirement 3* are irrelevant). Therefore, it is handled differently.  [Special case 1](#Special%20case%201) and [special case 2](#Special%20case%202) still apply.

```D
struct S
{
    static int field;

    static int prop() @property { return field; }
    static int prop(int value) @property { return field = value; }
}

void main()
{
    // The lowering of `s.prop += 1` as proposed in this DIP.
    // Existing Implementation: Compiles and produces the expected result.
    S.prop(S.prop() + 1);
    assert(S.field == 1);
}
```

#### Module-level properties without a context argument

Module-level properties without a context argument are similar to `static` properties of an aggregate, so they are lowered in a similar manner.   [Special case 1](#Special%20case%201) and [special case 2](#Special%20case%202) still apply.

```D
int field;

int prop() @property { return field; }
int prop(int value) @property { return field = value; }

void main()
{
    // The lowering of `prop += 1` as proposed in this DIP.
    // Existing Implementation: Compiles and produces the expected result.
    prop(prop() + 1);
    assert(field == 1);
}
```

### Free, nested property functions

Nested functions cannot be overloaded, so it is currently not possible to create a getter/setter pair of nested `@property` functions.  Therefore, this implementation will have no effect on nested `@property` functions, maintaining the status quo.

```D
void main()
{
    int mP;
    int p() @property { return mP; }
    void p(int v) @property { mP = v; }  // Existing Implementation: Error: declaration p is already defined
}
```

### Alternatives

#### Prowiki article

[The Prowiki article](http://www.prowiki.org/wiki4d/wiki.cgi?DocComments/Property#Semanticrewritingofproperties) gave a thorough discussion and many examples, but did not provide any generalization and was too difficult for the author of this DIP to derive an appropriate algorithm from.  However, the article did provide insight that was incorporated into this DIP.

#### DIP4

[DIP4 proposes](https://wiki.dlang.org/DIP4#Usage)...

> `f.width += 5; // Calls getter, saves it in a temp, does += on temp, calls setter with temp`

That translates to:

```D
auto temp = f.width;
temp += 5;
f.width = temp;
```

That proposal violates Requirements 2.

#### DIP23

[DIP23 proposes](https://wiki.dlang.org/DIP23#Applying_operators)...

> If `a.prop` is a member variable, the expression `a.prop op= x` has the usual meaning. Otherwise, `a.prop op= x` gets rewritten twice. First rewrite is `(a.prop) op= x`, i.e. apply `op=` to the result of the property. Second rewrite is `a.prop = a.prop op x`. If only one of the two rewrite compiles, use it. If both compile, fail with ambiguity error.

That proposal violates Requirement 2, and it could potentially break existing code by emitting the ambiguity error.  Also, the rewrite `a.prop = a.prop op x` is ambiguous as to whether the assignment is applied to the return value of `a.prop` or passed to the setter.

#### DIP28

[DIP28 proposes](https://wiki.dlang.org/DIP28#Operator_overloading)...

```D
a.prop += 42;
// Become :
a.prop = a.prop + 42;
a.prop(a.prop() + 42); // Equivalent code if @property wasn't used.
```

That proposal violates Requirement 2.

### Breaking changes

Due to [special case 2](#Special%20case%202), the proposed implementation will introduce no breaking changes.

## Copyright & License

Copyright (c) 2017 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

