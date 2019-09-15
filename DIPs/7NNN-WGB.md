# Named Arguments

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | (number/id -- assigned by DIP Manager)                          |
| Review Count:   | 0 (edited by DIP Manager)                                       |
| Author:         | Walter Bright walter@digitalmars.com                            |
| Implementation: | (links to implementation PR if any)                             |
| Status:         | Will be set by the DIP manager (e.g. "Approved" or "Rejected")  |

## Abstract

Required.

Short and concise description of the idea in a few lines.


## Contents
* [Rationale](#rationale)
* [Prior Work](#prior-work)
* [Description](#description)
* [Breaking Changes and Deprecations](#breaking-changes-and-deprecations)
* [Reference](#reference)
* [Copyright & License](#copyright--license)
* [Reviews](#reviews)

## Rationale

1. Although this supports reordering, the real reason for naming is so one can
have
a function with a longish list of parameters, each with a reasonable default,
and the user need only supply the arguments that matter for his use case. This
is much more flexible than the current method of putting all the defaults at
the
end of the parameter list, and defaulting one means all the rest get defaulted.
2. For a longish list of parameters, when the user
finds himself counting parameters to ensure they line up, then named parameters
can be most helpful.
3. A step towards making it possible to replace the brace struct initialization syntax with
a function-call-like construct. I.e. the initialization of structs is unified with
struct literals and struct constructors.
4. Allow replaceing [`std.typecons.Flag`](https://dlang.org/phobos/std_typecons.html#Flag)
which is a bit syntactically awkward.
5. For situations when code clarity at the caller site is of paramount importance
(i.e. for some critical code), to make it unquestionably clear which values go where,
even for short argument lists.

## Prior Work

* DIP 88
* DIP 1019
* DIP 1020

Both DIP 1019 and DIP 1020 detail prior work in other languages, which will not be
repeated here.


## Description

This is based on the recognition that D already has
named parameters for [struct initializers](https://dlang.org/spec/struct.html#static_struct_init).
Closely related are [array initializers](https://dlang.org/spec/arrays.html#static-init-static)
and [associative array literals](https://dlang.org/spec/hash-map.html#static_initialization).

The addition to the syntax is replacing the definition of `ArgumentList` for function call
arguments with:

```
ArgumentList:
   NamedArgument
   NamedArgument ,
   NamedArgument , ArgumentList

NamedArgument:
   Identifier : AssignExpression
   AssignExpression
```

Assignment of arguments to parameters would work the same way as
[assignments to fields](https://dlang.org/spec/struct.html#static_struct_init).

Matching of the `NamedArgument`s to a function's, function pointer's, or delegate's type
proceeds in lexical order.
For each `NamedArgument`:

1. If an `Identifier` is present, it matches to the `Parameter` with the corresponding
`Identifier`. If it does not match any named `Parameter`, then it is an error.
2. If an `Identifier` is not present, the `Parameter` matched is the one following
the previous matched `Parameter`, or the first `Parameter` if none have been matched yet.
3. Matching a `Parameter` more than once is an error.
4. After the `NamedArgumentList` is exhausted, any unmatched `Parameter`s receive the
corresponding default value specified for that `Parameter`. If there is no default value,
it is an error.
5. If there are more `NamedArgument`s than `Parameter`s, the remainder match the trailing
`...` of variadic parameter lists, and `Identifier`s are not allowed.


The set of matched functions becomes the overload set, to which the usual overload resolution
is applied to select the best match.

I.e. function resolution is done by constructing an argument list separately
for
each function before testing it for matching. Of course, if the parameter
name(s) don't match, the function doesn't match. If a parameter has no
corresponding argument, and no default value, then the function doesn't match.

```
void snoopy(T t, int i, S s);     // A
void snoopy(S s, int i = 0, T t); // B

S s; T t; int i;
snoopy(t, i, s); // A
snoopy(s, i, t); // B
snoopy(s, t); // error, neither A nor B match
snoopy(t, s); // error, neither A nor B match
snoopy(s:s, t:t, i:i); // error, ambiguous
snoopy(s:s, t:t); // B
snoopy(t:t, s:s); // B
snoopy(t:t, i, s:s); // A
snoopy(s:s, t:t, i); // A
```

The `AssignExpression`s are evaluated in the lexical order they appear in the
`NamedArgumentList`.

### Explicit Template Instantiation

The same is applied to
[Explicit Template Instantiation](https://dlang.org/spec/template.html#explicit_tmp_instantiation).

The `TemplateArgumentList` is replaced with:

```
TemplateNamedArgumentList:
    TemplateNamedArgument
    TemplateNamedArgument ,
    TemplateNamedArgument , TemplateNamedArgumentList

TemplateNamedArgument:
    Identifier : TemplateArgument
    TemplateArgument
```

The matching rules are the same as described for functions.

Since template arguments are evaluated at compile time, there is no order of evaluation consideration.


## Breaking Changes and Deprecations

None


## Reference

* [DIP 1020 Named Parameters](https://github.com/dlang/DIPs/blob/c723d8f4e3ac2d5bcaf8cdff87e1507f09669ca6/DIPs/DIP1020.md)
** [Review Round 1](https://digitalmars.com/d/archives/digitalmars/D/DIP_1020--Named_Parameters--Community_Review_Round_1_325299.html)
** [Review Round 2](https://digitalmars.com/d/archives/digitalmars/D/DIP_1020--Named_Parameters--Community_Review_Round_2_330582.html)
* [DIP 1019 Named Arguments Lite](https://github.com/dlang/DIPs/blob/3bc3469a841b87517a610f696689c8771e74d9e5/DIPs/DIP1019.md)
** [Review Round 1](https://digitalmars.com/d/archives/digitalmars/D/DIP_1019--Named_Arguments_Lite--Community_Review_Round_1_324110.html)
** [Review Round 2](https://digitalmars.com/d/archives/digitalmars/D/DIP_1019--Named_Arguments_Lite--Community_Review_Round_2_327714.html)
** [Final Review](https://digitalmars.com/d/archives/digitalmars/D/DIP_1019--Named_Arguments_Lite--Final_Review_330067.html)
* [DIP 88 Named Arguments](https://wiki.dlang.org/DIP88)
** [Review Thread Jan 23 2016](https://digitalmars.com/d/archives/digitalmars/D/DIP_88_Simple_form_of_named_parameters_279191.html)
** [Any News on DIP88?](https://digitalmars.com/d/archives/digitalmars/D/Any_news_on_DIP88_298814.html)

## Copyright & License
Copyright (c) 2019 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## Reviews
The DIP Manager will supplement this section with a summary of each review stage
of the DIP process beyond the Draft Review.
