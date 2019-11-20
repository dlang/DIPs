# Deprecate context-sensitive string literals

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | (number/id -- assigned by DIP Manager)                          |
| Review Count:   | 0 (edited by DIP Manager)                                       |
| Author:         | Dennis Korpel dkorpel@gmail.com                                 |
| Implementation: | (links to implementation PR if any)                             |
| Status:         | Draft                                                           |

## Abstract
D unofficially boasts that it has a context-free grammar allowing for easy lexing and parsing for text editors or syntax highlighters.
This is currently not true however, because delimited strings are context-sensitive.
Since they are rarely used, it is proposed that delimited strings therefore become deprecated and later removed from the language.

## Contents
* [Rationale](#rationale)
* [Prior Work](#prior-work)
* [Description](#description)
* [Breaking Changes and Deprecations](#breaking-changes-and-deprecations)
* [Reference](#reference)
* [Copyright & License](#copyright--license)
* [Reviews](#reviews)

## Definitions

This DIP talks about string literals starting with a q, of which there are multiple variants in D.
They will be referred to by the following names:
```D
// "identifier-delimited strings"
q"EOS
text
EOS";

// "bracket-delimited strings"
q"(text)";
q"<text>";
q"[text]";
q"{text}";

// "character-delimited strings"
q"/text/";

// "delimited strings" refer to any of the above

// "token strings"
q{if () else {}};
```

In the reference compiler's error messages, identifier-delimited strings are referred to has 'heredocs'.
In this DIP, [Here documents](https://en.wikipedia.org/wiki/Here_document)[0] refer to the usage of string literals for including large bodies of text directly into source code, not to a specific type of string literal.

## Rationale

Walter Bright [has stated](https://www.digitalmars.com/articles/b90.html) [1] with regards to language design:

"Things that are true gods:

Context free grammars. What this really means is the code should be parseable without having to look things up in a symbol table. C++ is famously not a context free grammar. A context free grammar, besides making things a lot simpler, means that IDEs can do syntax highlighting without integrating in most of a compiler front end, i.e. third party tools become much more likely to exist."

D has claimed to be [able to be parsed by a context-free grammar](https://www.digitalmars.com/d/2.0/template-comparison.html) [2],
but some users have expressed [doubts](https://forum.dlang.org/post/iks2f2$mlm$1@digitalmars.com) [3] about that because certain things (like static / associative arrays) cannot be distinguished by a context-free language.
Responses mention how the parser only decides the basic structure of code, and certain type-related things are distinguished during semantic analysis.
However, as first [pointed out by a Stack Overflow user](https://stackoverflow.com/a/7083615) [4], there is one construct that, without a doubt, proves that D's grammar is not actually context free:
```
DelimitedString:
    q" Delimiter WysiwygCharacters MatchingDelimiter "
```

Considering a delimiter can be an identifier, this is almost a textbook example of a context sensitive construct.
It is not so bad that it requires keeping a symbol table, but `Delimiter` and `MatchingDelimiter` stand out as informal terms in an otherwise formal context-free grammar.
Consequently, in the [D language grammar example from Pegged](https://github.com/PhilippeSigaud/Pegged/blob/dc2a85b9c026878920c3bbbe5ced68c0fa5f07a2/pegged/examples/dgrammar.d#L999) [5] where every rule _has_ to be formally defined, delimited strings are assumed to not exist.

Luckily, delimited strings are not very commonly used in D code.
To quantify the usage, a scan of string literal usage was performed using libdparse. The search is limited to:
- a snapshot from July 2019 of all packages registered on dub
- repositories that could be cloned with git (no private/deleted/mercurial repositories)
- files with a `.d` extension
- string literals directly in source code, not inside a string mixin or build artifact

With these limitations it does not give the full picture, but it still gives a reasonable impression.
The following observations were made:
- There are 714 identifier-delimited or character-delimited strings, 509 of which are in the package 'DStep'
- There are 152 bracket-delimited strings using brackets (`q"( like this )"`)
- Identifier-delimited strings are used at least once in 28/1586 packages
- Bracket-delimited strings are used at least once in 32/1586 packages
- Identifier-delimited strings make up 0.06% of all string literals (0.02% without DStep)
A spreadsheet with the full breakdown can be found [here](https://gist.github.com/dkorpel/10cc13d0740c50a8aab30588f392950f)[6].

Possible reasons for their rare usage include:
- Here documents are not needed as often as short strings to begin with
- String literals (even regular "" ones) can span multiple lines in D
- `q{}` strings cover D code and DSL's with similar lexical syntax, such as JSON or GLSL.
- Wysiwyg strings like \`text\` cover many other cases: Pegged grammars, SQL, regex, English text.
- If a \` is needed, it can be concatenated using the `~` operator or a `r""` string can be used.
- The `import("file.txt")` statement completely eliminates the need for any escaping, and even allows binary data. It also encourages separation between code and data.
- even if the programmer is looking for delimited strings, chances are [they won't easily find it](https://forum.dlang.org/post/xabbngzetiapvdayurpw@forum.dlang.org).

Removing identifier-delimited strings would mean context free parser generators can be used for D, with no asterisks.
It also reduces language complexity and makes the specification more formal.
The downside is that it breaks some code without a direct replacement.
However, as shown above, in practice there are not many of these string literals and they often can be easily replaced with other string literals.

# Prior Work

Hexstring literals [have been deprecated](https://dlang.org/deprecate.html#Hexstring%20literals) since version 2.079 (March 1 2018), with rationale:
"Hexstrings are used so seldom that they don't warrant a language feature.".
As of July 2019, there are still 1035 hex string literals spread across 15 registered dub packages.

The deprecation of context-sensitive string literals is considered similar to the deprecation of hexstring literals, with a few differences:
- Deprecation warnings for hexstring literals have a trivial fix (use `std.conv: hexstring` instead), while there is no trivial fix for all identifier-delimited string literal deprecation warnings.
In practice identifier-delimited strings are often easily replacable with bracket-delimited strings or wysiwyg-strings however.
- Hexstring literals are context-free, so identifier-delimited strings add much more language complexity since they are not context-free. 
Therefore removing the latter from the language is more beneficial than removing hexstring literals with regards to simplifying the D language.

## Other languages
Rosetta code has a comparison of [Here documents in different languages](https://rosettacode.org/wiki/Here_document) [7].
D mentions its q-strings there, but the syntax highlighting in the code snippet is all messed up, nicely illustrating the problem with it.
Notable languages having identifier-delimited string literals are C++, Perl and PHP.
Other languages such as Java, JavaScript, Python, C#, and Rust feature only context-free string literals.

# Description

The use of identifier-delimited strings becomes deprecated following the [usual deprecation cycle](https://github.com/dlang/DIPs/blob/master/DIPs/accepted/DIP1013.md#language-features), just like hex-strings.
Character-delimited strings also become deprecated.
Even though using a single character as delimiter is still context-free, it requires adding a parser state for every possible character, of which there are many.
Token strings (`q{}`) and strings with brackets as delimiters (`q"{}" q"()" q"<>" q"[]"`) are unaffected and can be suggested as a replacement.

## Grammar Changes

The current rule for delimited strings is removed and rules are added for specifically allowed delimiters.

```diff
DelimitedString:
- q" Delimiter WysiwygCharacters MatchingDelimiter "
+ q"( WysiwygCharacters )"
+ q"{ WysiwygCharacters }"
+ q"[ WysiwygCharacters ]"
+ q"< WysiwygCharacters >"
```

## Breaking Changes and Deprecations

Any code that formerly uses delimited strings needs to be changed to use a different string literal or an import statement.
Below is a list of dub-packages that use at least one of these literals and thus need to be updated:
```
dstep
pgator
orange
tsv-utils
dentist
jwtd-es
jwtd
ae
dtools
button
msgpack-rpc
dmd
arsd-official
ddmd-experimental
dini
gpgme-d
phobos
dalicious
dlangide
remarkify
dcaptcha
ddata
doveralls
dtest
easing
flod
libdparse
nwn-lib-d
```

## Reference

[0] ["Here document" on Wikipedia](https://en.wikipedia.org/wiki/Here_document)

[1] [Walter Bright on context-free grammars](https://www.digitalmars.com/articles/b90.html)

[2] [Context-free grammar: yes](https://www.digitalmars.com/d/2.0/template-comparison.html)

[3] ["is the advertising as "context-free grammar" wrong?"](https://forum.dlang.org/post/iks2f2$mlm$1@digitalmars.com)

[4] [Stack Overflow post describing the issue](https://stackoverflow.com/a/7083615)

[5] [D language grammar example from Pegged](https://github.com/PhilippeSigaud/Pegged/blob/dc2a85b9c026878920c3bbbe5ced68c0fa5f07a2/pegged/examples/dgrammar.d#L999)

[6] [String literal usage breakdown per dub project](https://gist.github.com/dkorpel/10cc13d0740c50a8aab30588f392950f)

[7] [Here documents in different languages](https://rosettacode.org/wiki/Here_document)

## Copyright & License

Copyright (c) 2019 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## Reviews

The DIP Manager will supplement this section with a summary of each review stage
of the DIP process beyond the Draft Review.
