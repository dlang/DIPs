# String Interpolation

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | (number/id -- assigned by DIP Manager)                          |
| Review Count:   | 0 (edited by DIP Manager)                                       |
| Author:         | Walter Bright walter@digitalmars.com                            |
| Implementation: | (links to implementation PR if any)                             |
| Status:         | Will be set by the DIP manager (e.g. "Approved" or "Rejected")  |

## Abstract

Instead of a format string followed by an argument list, string interpolation enables
embedding the arguments in the string itself.


## Contents
* [Rationale](#rationale)
* [Prior Work](#prior-work)
* [Description](#description)
* [Breaking Changes and Deprecations](#breaking-changes-and-deprecations)
* [Reference](#reference)
* [Copyright & License](#copyright--license)
* [Reviews](#reviews)

## Rationale

While the conventional format string followed by the argument list is perfectly fine for
short strings and a small number of arguments, it tends to break down with longer strings
with many arguments. Omitting an argument, having an extra argument, and having a mismatch
between a format specifier and its corresponding argument are common errors. By
embedding the argument in the format string tends to eliminate these errors. It's easier
to read and visually easier to review for correctness.

## Prior Work

* Interpolated strings have been implemented and well-received in many languages.
For many such examples, see [String Interpolation](https://en.wikipedia.org/wiki/String_interpolation).
* Jason Helson has submitted a DIP [String Syntax for Compile-Time Sequences](https://github.com/dlang/DIPs/pull/140).
* [Adam's string interpolation proposal](http://dpldocs.info/this-week-in-d/Blog.Posted_2019_05_13.html)

## Description

```
writefln(i"I ate %apples and %{d}bananas totalling %(apples + bananas) fruit.");
```
gets rewritten as:
```
writefln("I ate %s and %d totalling %s fruit.", apples, bananas, apples + bananas);
```
It will also work with printf:

```
printf(i"I ate %{d}apples and %{d}bananas totalling %{d}(apples + bananas) fruit.\n");
```
becomes:
```
printf("I ate %s and %d totalling %s fruit.\n", apples, bananas, apples + bananas);
```

The `{d}` syntax is for when the format specifier needs to be anything other that `s`,
which is the default. What goes between the `{` `}` is not specified so this capability
can work with foreseeable format specification improvements without needing to update
the core language. It also makes interpolated strings agnostic about what the format
specifications are, as long as they start with `%`.


The interpolated string starts as a special string, `InterpolatedString`, which is the same as a
`DoubleQuotedString` but with an `i` prefix and no `StringPostFix`. This appears in the grammar
as an `InterpolatedExpression` which is under `PrimaryExpression`.

`InterpolatedExpresssion`s undergo semantic analysis similar to `MixinExpression`.
The string scanned from left to right, according to the following grammar:

```
Elements:
    Element
    Element Elements

Element:
    Character
    '%%'
    '%' Argument
    '%' FormatString Argument

FormatString:
    '{' FormatString '}'
    CharacterNoBraces

CharacterNoBraces:
    CharacterNoBrace
    CharacterNoBrace CharacterNoBraces

CharacterNoBrace:
    characters excluding '{' and '}'


Argument:
    Identifier
    Expression

Expression:
    '(' Expression ')'
    CharacterNoParens

CharacterNoParens:
    CharacterNoParen
    CharacterNoParen CharacterNoParens

CharacterNoParen:
    characters excluding '(' and ')'
```

The `InterpolatedExpression` is converted to a tuple expression, where the first element
is the transformed string literal, and the `Argument`s form the rest of the elements.

The transformed string literal is constructed as follows:

If the `Element` is:

* `Character`, it is written to the output string.
* `'%%'`, a '%' is written to the output string.
* `'%' Argument` then '%s' is written to the output string.
* `'%' '{' FormatString '}' Argument` then '%' `FormatString` is written to the output string.

If the `Argument` is an `Identifier` it is inserted in the tuple as an `IdentifierExpression`.
If the `Argument` is an `Expression` it is lexed and parsed (including the surrounding parentheses)
like `MixinExpressions` and inserted in the tuple as an `Expression`.

Compile time errors will be generated if the `Elements` do not fit the grammar.

### Limitations

Interpolated string formats cannot be mixed with conventional elements:

```
writefln(i"making %bread using %d ingredients", 6); // error, %d is not a valid element
```

Interpolated strings won't work with `*` format specifications that require extra arguments.
This will produce a runtime error with `writefln` and undefined behavior with
`printf`, because the arguments won't line up with the formats. The compiler does not check
the formats for validity.

No attempt is made to check that the format specification is compatible with the argument type.
Making such checks would require that detailed knowledge of `printf` and `writef` be hardwired
into the core language, as well as knowledge of which formatting function is being called.


## Breaking Changes and Deprecations

Since the interpolated string is a new token, no existing code is broken.

## Reference

## Copyright & License
Copyright (c) 2019 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## Reviews
