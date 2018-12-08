# String Syntax for Compile-Time Sequences

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | (number/id -- assigned by DIP Manager)                          |
| Review Count:   | 0 (edited by DIP Manager)                                       |
| Author:         | Jason Hansen                                                    |
| Implementation: | https://git.io/fpSUA                                            |
| Status:         | Will be set by the DIP manager (e.g. "Approved" or "Rejected")  |

## Abstract

This DIP proposes adding a "string sequence literal" to D, primarily inspired
by string interpolation, but also applicable to a wide variety of use cases.

In a nutshell, this literal:

````
i"Hello, ${name}! You have logged on ${count} times."
````

is translated to the [compile-time sequence](https://dlang.org/articles/ctarguments.html):

````D
"Hello, ", name, "! You have logged on ", count, " times."
````
Note that the compiler does not perform any string interpolation; it merely
segments the literal into a sequence of strings and expressions.  The intent is for
further processing to be done in library code (see [rationale](#rationale) for a more detailed
description of possible applications).

### Reference

- Exploration: https://github.com/marler8997/interpolated_strings
- Example Library Solution: https://github.com/dlang/phobos/pull/6339/files
- Implementation: https://github.com/dlang/dmd/pull/7988
- https://forum.dlang.org/thread/khcmbtzhoouszkheqaob@forum.dlang.org
- https://forum.dlang.org/thread/c2q7dt$67t$1@digitaldaemon.com
- https://forum.dlang.org/thread/qpuxtedsiowayrhgyell@forum.dlang.org
- https://forum.dlang.org/thread/ncwpezwlgeajdrigegee@forum.dlang.org
- https://dlang.typeform.com/report/H1GTak/PY9NhHkcBFG0t6ig (#3 in "What language features do you miss?")

## Contents
* [Rationale](#rationale)
* [Description](#description)
* [Language vs Library Feature](#language-feature-vs-library-feature)
* [Breaking Changes and Deprecations](#breaking-changes-and-deprecations)
* [Copyright & License](#copyright--license)
* [Reviews](#reviews)

## Rationale

Sequence literals apply to a wide range of use cases. A few of these use cases are outlined below.

#### String Interpolation
One notable use for sequence literals is in string interpolation, which allows for more concise, readable, and maintanable code. For example:


src/build.d:556:<br>
`auto hostDMDURL = "http://downloads.dlang.org/releases/2.x/"~hostDMDVer~"/dmd."~hostDMDBase;`<br>
Becomes:<br>
`auto hostDMDURL = i"http://downloads.dlang.org/releases/2.x/$hostDMDVer/dmd.$hostDMDBase".text;`<br>
And, with syntax highlighing:<br>
![https://i.imgur.com/tXm6rBU.png](https://i.imgur.com/tXm6rBU.png)


src/dmd/json.d:1058:<br>
``s ~= prefix ~ "`" ~ enumName ~ "`";``<br>
Becomes:<br>
``s ~= i"prefix`$enumName`".text;``<br>
With syntax highlighting:<br>
![https://i.imgur.com/KTcOS0F.png](https://i.imgur.com/KTcOS0F.png)



#### Database Queries
NOTE: Add a couple sentences about why this use case is beneficial

`db.exec("UPDATE Foo SET a = ?, b = ?, c = ?, d = ? WHERE id = ?", aval, bval, cval, dval, id);`<br>
Becomes:<br>
`db.exec(i"UPDATE Foo SET a = $(aval), b = $(bval), c = $(cval), d = $(dval) WHERE id = $(id)");`



NOTE:(also, add other use cases)


## Description

Lexer Change:

Current:

```
Token:
   ...
   StringLiteral
   ...
```
New:

```
Token:
   ...
   StringLiteral
   i StringLiteral
   ...
```

No change to grammar. Implementation consists of a small change to `lex.d` to detect when string literals are prefixed with the `i` character.  It adds a boolean flag to string literals to keep track of which ones are "interpolated".  Then in the parse stage, if a string literal is marked as "interpolated", it lowers it to a sequence of strings and expressions.

Implementation and tests can be found here: https://github.com/dlang/dmd/pull/7988/files

#### Expressions

Expressions are not bindable to aliases, unless the expression is evaluatable at compile-time. For the purposes of simplicity, this proposal does not require any new mechanism, but any such mechanism to bind expressions to aliases would benefit this proposal.

Because of this, arbitrary expressions based on runtime data are allowed only when used in a runtime argument list.

Example:
```D
int a = 5;
writeln(i"a + 1 is ${a+1}"); // OK, prints "a + 1 is 6"
alias seq = AliasSeq!(i"a + 1 is ${a+1})"; // Error, cannot read `a` at compile time
```

See [Possible Improvements](#possible-improvements) for possible solutions.

## Language Feature vs Library Feature

It has been brought up that this could be done as a library. Here is a breakdown of the pros and cons of a library implementation as opposed to a language implementation:

:white_check_mark: Library Pros:
- Requires no language changes

:x: Library Cons:
- Awkward syntax
- Bad performance
- Depends on a library for a trivial feature
- Cannot be used with betterC


:white_check_mark: Language Pros:
- High performance
- Nice syntax
- Better integration (IDEs, syntax highlighting, autocompletion)

:x: Language Cons:

NOTE:(Should we have pros/cons for both, or only one?)
<br>
NOTE:(We should explain why the listed pros/cons make language feature a better choice)

## Possible Improvements

Because string sequence literals do not actually lower to individual strings, a call to `std.conv.text` (or similar) is required. It may be worth adding a simple function to druntime for concatenating *only* strings to avoid needing `text`.

## Breaking Changes and Deprecations
None :smile:

## Copyright & License

Copyright (c) 2018 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## Reviews

The DIP Manager will supplement this section with a summary of each review stage
of the DIP process beyond the Draft Review.
