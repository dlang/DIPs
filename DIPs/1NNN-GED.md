# Disallow Comments in Special Token Sequences

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | (number/id -- assigned by DIP Manager)                          |
| Review Count:   | 0 (edited by DIP Manager)                                       |
| Author:         | Garrett D'Amore garrett@damore.org                              |
| Implementation: | (links to implementation PR if any)                             |
| Status:         | Draft                                                           |

## Abstract

Required.

We propose to disallow comments of any form within the special token sequences.
(These are typically sequences like `#line 1234 "file.d"`)


## Contents
* [Rationale](#rationale)
* [Prior Work](#prior-work)
* [Description](#description)
* [Breaking Changes and Deprecations](#breaking-changes-and-deprecations)
* [Reference](#reference)
* [Copyright & License](#copyright--license)
* [Reviews](#reviews)

## Rationale

The grammar for special tokens sequences is somewhat confusing when it comes to
the presence of comments within them.  As this is processed during lexical analysis,
the allowance for comments within them adds a complication in creating tools, while
offering very little (arguably no) real-world benefit.

The current D implementation does not match the C11 standard behavior on one hand,
and on the other the requirement to support block comments adds additional complexity
when lexing the code for D.

For example, the following is legal in D:

```d
#line //
  123
int c = 4;
```

While the following is *not* legal in C:

```
#line //
  123
int c = 4;
```

Bizarrely C11 does permit block comments to span multiple lines within such a directive:

```
#line /* one
      two
      three */ 123
```

This turns out to be rather problematic because in some instances (such as when
assessing comments for syntax highlighting) we would like to pass a comment as a
token to the parser (which will treat it as whitespace semantically in most situations),
and we would also like to be able to pass the special directive as a complete token
(which should obtain the same behavior).  This flies in the face of the specification
which indicates that these are processed during lexical scanning.

As another point, the special token sequence is one of only a couple of special
sequences that are sensitive to newlines.  The other ones are the handling for
line comments "//", heredoc strings, and shebangs.  All of these are best handled
at the lexical state, so that the parser need not have any special awareness of newlines.

Note that these special directives are generally not coded by humans (with some
special exception for compiler test suites, which is the only time the author
has seen them manually created), but are intended rather to faciliate
generating relevant diagnostic messages from generated code. (So that the diagnostic
message can refer to the true source, rather than some generated file.  This is less
common with D code, but such use cases involving LEX and YACC grammars are common in the
C world.)  Such tools never emit comments on these lines.

If a human needs a comment, it is trivial to add a comment to the line above or below.

## Prior Work

DMD issue [#22825](https://issues.dlang.org/show_bug.cgi?id=22825) introduced a fix
that attempted to resolve a discrepancy between the C11 handling for `#line` directives
and that used in D.

Unfortunately, the implementation in D still does not match the standard C11 behavior.

While the official DMD parser and scanner support block comments in
D code, the author's Tree-Sitter grammar does *not* (see https://github.com/gdamore/tree-sitter-d).

## Description

In order to simplify all this, and to facilitate grammars, we would
propose to make the use of comments within these special token sequences
illegal.  We would propose to treat these as a "peer" (lexically) to
comments and shebang sequences.

The grammar for this should be made clear, with the additional of the following
statement added to 2.16 (Special Token Sequences):

(insert betweeen items 2 & 3):

"3. Special token sequences may be processed in a manner similar to comments, and
    comments within them are not permitted."


Detailed technical description of the new semantics. Language grammar changes
(per https://dlang.org/spec/grammar.html) needed to support the new syntax
(or change) must be mentioned. Examples demonstrating the new semantics will
strengthen the proposal and should be considered mandatory.

## Breaking Changes and Deprecations

Technically this is a breaking change.

However, it's exceedingly unlikely that this breaking change will affect any
actual user source code.  For that reason we are not proposing to have
a deprecation period.

If any code is broken by this, it would be trivial to fix by moving the
comment to a line above or below the directive, or deleting it.

## Reference

https://issues.dlang.org/show_bug.cgi?id=22825

ISO/IEC 9899:211 Section 6.4.9 Comments

## Copyright & License
Copyright (c) 2022 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## Reviews
The DIP Manager will supplement this section with a summary of each review stage
of the DIP process beyond the Draft Review.
