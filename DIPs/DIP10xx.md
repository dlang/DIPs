# Add unary operator `...`

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | 10xx                                                            |
| Review Count:   | 0                                                               |
| Author:         | Manu Evans turkeyman@gmail.com                                  |
| Co-Author:      | Stefan Koch uplink.coder@gmail.com                              |
| Implementation: | https://github.com/TurkeyMan/dmd/tree/dotdotdot                 |
| Status:         | Draft                                                           |

## Abstract
Add `...` expression to perform explicit tuple unpacking.

## Contents
* [Rationale](#rationale)
* [Prior Work](#prior-work)
* [Precedent in D](#precedent-in-d)
* [Description](#description)
* [Compilation Performance](#compilation-performance)
* [Breaking Changes and Deprecations](#breaking-changes-and-deprecations)
* [Reference](#reference)
* [Copyright & License](#copyright--license)

## Rationale
Static map is a common and very useful operation, but the mechanisms to implement a static map in D are awkward, and have a huge cost in compile time.

Specifcally the auto expansion of tuples leads to the need of using wrapper templates which inhibit the expansion. (In the order of N^2 instantiated templates per tuple length of N)

It is proposed that the language implement an expression to perform static map efficiently and concisely which will eliminate the necessity to use template expansion tricks to implement these patterns in programs, and avoid the compile time costs associated.

This DIP proposes a unary `...` syntax which explores an expression for tuples, and expands to a tuple of expressions's with tuples replaced by their respective tuple elements.

For example:
```d
(Tup*10)...  -->  ( Tup[0]*10, Tup[1]*10, ... , Tup[$-1]*10 )
```

## Prior Work
C++11 implemented template parameter pack expansion with similar semantics, and it has been a great success in the language.

Applied together with D's superior metaprogramming feature set, we can gain even greater value from this novel feature.

## Precedent in D
Under the current semantic `.offsetof` applied to a field tuple (`.tupleof`) does create a new tuple consisting of `offsetof` applied to each field. 

## Description
Add a unary operator `...` with precedence below other unary operations, and above binary operations.

It would take the form `expr...` where the result is a tuple of expressions.

The implementation will explore `expr` for any tuples present in the expression tree, and duplicate `expr` with each tuple being substitute for the respective tuple element.

```d
alias Tup = AliasSeq!(1, 2, 3);
int[] myArr;
assert([ myArr[Tup + 1]... ] == [ myArr[Tup[0] + 1], myArr[Tup[1] + 1], myArr[Tup[2] + 1] ]);
```

This is an effective and terse implementation of a static map applying a sequence of values to a common expression.

If multiple tuples are discovered beneath `expr`, they are expanded in parallel, and they must have equal length.

```d
alias Values = AliasSeq!(1, 2, 3);
alias Types = AliasSeq!(int, short, float);
pragma(msg, cast(Types)Values...);

> 1, short(2), 3.0f

alias OnlyTwo = AliasSeq!(10, 20);
pragma(msg, (Values + OnlyTwo)...);

> error: tuples beneath `...` expression have mismatching length
```

Notably, existing code can take immediate advantage of the improvements in compile time by upgrading the implementation of `staticMap`, and consequently, many parts of phobos:
```d
alias staticMap(alias F, T...) = F!T...;
```

The effect on user code will be increased readibility, a reduction in program logic indirections via 'utility' template definitions, and a dramatic improvement in compile time for sensitive applications.

Sensitive applications tend to include programs that perform systematic reflection, compile-time parsing, implementation of call-shim's (ie; foreign language binding), or any compile-time pre-processing that can't be strictly performed with CTFE.

### Grammar Changes
```diff
PostfixExpression:
    PrimaryExpression
    PostfixExpression . Identifier
    PostfixExpression . TemplateInstance
    PostfixExpression . NewExpression
    PostfixExpression ++
    PostfixExpression --
+   PostfixExpression ...
    PostfixExpression ( ArgumentListopt )
    TypeCtorsopt BasicType ( ArgumentListopt )
    IndexExpression
    SliceExpression
```

## Compilation Performance
Many D projects experience very slow compilation caused by explosive template expansion. Leading causes of template explosion tend to involve recursive expansion, and this most often looks like some form of static map (including `staticMap`).

Existing solutions where `...` may be applied are implemented using recursive template instantiation. Each template instantiation populates the symbol table, and it is common that the arguments to such templates generate very long mangled names.

By contrast, operator `...` generates no junk symbols at all and so avoids associated cost in compile time.

Experimental implementation has shown compile time improvement by orders of magnitude in sensitive programs.

Cost to compile-time of operator `...` is negligible and strictly linear with the length of source tuples, whereas recursive template instantion has quadratic cost in compile time due to growing symbol names and mangling costs with each iteration.

In practise, this quadratic cost applies effective upper-limits on the length of lists that can be handled at compile time. We can lift these practical limits using operator `...`

## Breaking Changes and Deprecations
None

## Reference
[C++11 parameter pack expansion reference](https://en.cppreference.com/w/cpp/language/parameter_pack)

## Copyright & License
Copyright (c) 2019 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)
