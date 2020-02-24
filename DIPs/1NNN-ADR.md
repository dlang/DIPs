
# String Interpolation

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | 1027 v2                                                         |
| Review Count:   | 0                                                               |
| Author:         | D community team effort based on Walter's original DIP          |
| Implementation: |                                                                 |
| Status:         | Initial formalization                                           |

## Abstract

Instead of requiring a format string followed by an argument list, string interpolation enables
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

While the conventional format string followed by the argument list is fine for
short strings and a small number of arguments, it tends to break down with longer strings
that have many arguments. Omitted arguments, extra arguments, and mismatches
between format specifiers and their corresponding arguments are common errors. Embedding arguments
in the format strings can eliminate these errors. Readability is improved and the code is visually
easier to review for correctness.

## Prior Work

* Interpolated strings have been implemented and well-received in many languages.
For many such examples, see [String Interpolation](https://en.wikipedia.org/wiki/String_interpolation).
* Previous version of this DIP and its associated discussions
* [C#'s implementation](https://docs.microsoft.com/en-us/dotnet/csharp/language-reference/tokens/interpolated#compilation-of-interpolated-strings)
* [Javascript's implementation](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Template_literals)

## Description

```
writefln(i"I ate $apples and ${%d}bananas totalling $(apples + bananas) fruit.");
```
gets rewritten as:
```
writefln(_d_interpolated_string!("I ate ", _d_interpolated_format_spec(null), " and ", _d_interpolated_format_spec("%d"), " totalling ", _d_interpolated_format_spec(null), " fruit.")(), apples, bananas, apples + bananas);
```

where `_d_interpolated_string` and `_d_interpolated_format_spec` are defined exclusively inside druntime.

This will also work with `printf`:

```
printf(i"I ate ${%d}apples and ${%d}bananas totalling ${%d}(apples + bananas) fruit.\n");
```
becomes:
```
printf(_d_interpolated_string!("I ate ", _d_interpolated_format_spec("%d"), " and ", _d_interpolated_format_spec("%d"), " totalling ", _d_interpolated_format_spec("%d"), " fruit.\n")(), apples, bananas, apples + bananas);
```

The `{%d}` syntax is for circumstances when the format specifier needs to be given by the user.
What goes between the `{` `}` is not specified, so this capability can be used by any function
in the present, past, or future without needing to update the core language or runtime library.
Interpolated strings agnostic about what the format specifications are.


The interpolated string starts as a special string token, `InterpolatedString`, which is the same as a
`DoubleQuotedString` but with an `i` prefix and no `StringPostFix`.

```
InterpolatedString:
   i" DoubleQuotedCharacters "
```

The `InterpolatedString` appears in the parser grammar
as an `InterpolatedExpression`, which is under `PrimaryExpression`.

```
InterpolatedExpression:
   InterpolatedString
   InterpolatedString StringLiterals

StringLiterals:
   StringLiteral
   StringLiteral StringLiterals
```

`InterpolatedExpresssion`s undergo semantic analysis similar to `MixinExpression`.
The contents of the `InterpolatedExpression` must conform to the following grammar:

```
Elements:
    Element
    Element Elements

Element:
    Character
    '$$'
    '$' Argument
    '$' FormatString Argument

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

The `InterpolatedExpression` is converted to a tuple expression, where the first tuple element
is the lowered druntime template instantiation and the `Argument`s form the remainder of the tuple elements.

The druntime `object._d_interpolated_string` struct constructor or function is called with no runtime arguments and a compile time argument list constructed as follows:

If the `Element` is:

* `Character`, it is written to the output string.
* `'$$'`, a '$' is written to the output string.

If a `'$'` occurs without a following `'$'`, it terminates the current output string (if any), appends it to the template argument list, and appends a new argument to the template instantiation as follows:

* `'$' Argument`, then `_d_interpolated_format_spec(null)` is appended to the argument list.
* `'$' '{' FormatString '}' Argument`, then `_d_interpolated_format_spec(FormatString)` is appended to the argument list. Note that `FormatString` may be the empty string, which is passed as `""` instead of as `null`. For example `i"${}foo"` is passed as `_d_interpolated_string!(_d_interpolated_format_spec(""))()`.

If characters remain, it continues the processing loop with a fresh template argument to `_d_interpolated_string`.

The result of this `_d_interpolated_string` function call becomes the first element of the tuple.

If the `Argument` is an `Identifier`, it is appended to the tuple as an `IdentifierExpression`.
If the `Argument` is an `Expression`, it is lexed and parsed (including the surrounding parentheses)
(similar to `MixinExpressions`; you could think of the compiler as putting `mixin(...)` around the extracted string) and appended to the tuple as an `Expression`.

Compile-time errors will be generated if the `Elements` do not fit the grammar.

### Diagnostics

An `i""` string is likely not be compatible with existing D `string` functions and variables. The compiler SHOULD provide helpful hints in the error messages to point new users in the right direction to understand how to use the new feature. This message MAY link to a web page to educate the user on which solution is appropriate for them.

```
void foo(string s) {}

foo(i"test $(4)"); // a CT error due to type mismatch. The compiler should suggest functions (see below) to remedy the user's problem.
```

### Concatenations

In order to facilitate convenient formatting of long strings, if a `StringLiteral` follows an `InterpolatedString`,
it is appended to the `InterpolatedString` in the parsing pass. (Not the lexer pass.)
A `StringPostfix` may not appear on any of them.
Such concatenations enable the various string literal types to be used as `InterpolatedStrings`,
such as:

```
i""q{apples and $("bananas")}
```
yielding a tuple expression:
```
_d_interpolated_string!("apples and ", _d_interpolated_format_spec(null))(), ("bananas")
```

### Library additions

While the compiler only lowers to library calls and thus does not need to know about any of this, user functionality relies on a small library implementation.

One suggested implementation would be:

```
struct _d_interpolated_string(Parts...) {
        static:

        private bool hasAllSpecs() {
            foreach(part; Parts)
               static if(is(typeof(part) == _d_interpolated_format_spec))
                  if(part.spec is null)
                       return false;
            return true;
        }

        private string toFormatStringImpl(string defaultSpec) {
           if(__ctfe) {
                string ret;
                foreach(part; Parts)
                        static if(is(typeof(part) == _d_interpolated_format_spec)) {
                                if(part.spec is null)
                                        ret ~= defaultSpec;
                                else
                                        ret ~= part.spec;
                        } else static if(is(typeof(part) : const(char)[]))
                                ret ~= part;
                        else static assert(0);
                return ret;
           } else assert(0);
        }

        private immutable(char*) toFormatStringzImpl() {
                return toFormatString!(null).ptr;
        }

	// we may also add a lambda for escaping chars to this
        public template toFormatString(string defaultSpec) {
                enum toFormatString = toFormatStringImpl(defaultSpec);
        }

        static if(hasAllSpecs()) {
                // alias this to a string, even a string literal, loses
                // the implicit conversion to const(char)* needed by
                // printf. so gotta use a wrapper that explicitly returns
                // that :(
		//
		// A future compiler enhancement could allow alias this to
		// a string literal to also implicitly cast to const(char)*,
		// just like the string literal itself, further enhancing
		// this experience
                alias toFormatStringzImpl this;
        }
}

immutable struct _d_interpolated_format_spec {
        string spec;
}
```

If the library functions are not present in `object.d`, use of interpolated strings MUST result in a compile-time error. The compiler SHOULD issue a user-friendly diagnostic, for example "string interpolation support not found in druntime" instead of leaking implementation details in error messages.

As an addition for user-friendliness, I also suggest we add an `idup` overload to `object.d` specialized for arguments starting with an instantiation of `_d_interpolated_string`, and overloads for existing Phobos format string functions that forward to the *compile time* overloads.

In object.d
```
string idup(I, T...)(I fmt, T args) if(is(I == _d_interpolated_string!Args, Args...)) {
        import std.format;
        return format!(I.toFormatString!"%s")(args);
}
```

Since `idup` is already a symbol and since this new overload is constrained to just the new type, this has no effect on existing code and does not contribute to namespace pollution. Moreover, since `"string".idup` is already an accepted convention for converting `const` strings to the immutable-based `string` type, it is also a natural extension of existing user skills for string assignment. Lastly, it is already known that `.idup` invokes the GC and associated allocator, so it should come to no surprise that `i"".idup` does as well. However, normal string `idup` does not import Phobos while this does, that is a hidden implementation detail that can be improved upon in the future and strikes the best current balance between usability and elegance of implementation.

In Phobos
```
auto writefln(Fmt, Args...)(Fmt fmt, Args args) if(is(Fmt == _d_interpolated_string!Ignored, Ignored...)) {
        import std.stdio; // of course this should be IN std.stdio, making this import unnecessary
        return std.stdio.writefln!(fmt.toFormatString!"%s", Args)(args);
}
// ditto for formattedWrite, format, and any other uses.
```

These ensure that interpolated strings just work for their most likely target functions while also providing a new benefit: the format string, including user additions via `${}`, will be checked at compile time, even when passed as a runtime argument.

```
string name;
writefln(i"Hello, ${%d}name"); // causes a compile error for invalid format specification
```

Note that this comes despite the compiler itself knowing absolutely nothing about format specifiers - it is entirely implemented in library code, and third parties may provide their own formats and checks.

We may also provide user-friendly aliases for `_d_interpolated_string` and `_d_interpolated_format_spec`, but the color of the bikeshed is not important to this DIP author.

### Justifications

The library wrapper may seem superfluous, however it serves three key roles:

1. It divorces the compiler entirely from details of generated format strings.
2. It provides necessary error checking capabilities.
3. It provides an additional API for user functions to introspect the string, building on D's existing compile-time capabilities.

The previous version of this DIP proposed a simple string literal instead of the result of `_d_interpolated_string` as the first argument passed. This is problematic because it introduces potentially subtle errors in likely usage.

#### Wrong-use in unrelated function

Consider a function in D today:

```
/++
	Creates a window with the given title, width, and height. If
	width or height are set to zero (the default), your window will
	be automatically sized.
+/
Window createWindow(string title, int width = 0, int height = 0);
```

A user has some code that calls it like so:

```
import std.conv;
auto window = createWindow("Process debugger " ~ to!string(pid));
```

A new version of the compiler is released and the user, eager to try D's new string interpolation feature, rewrites that code as would be common in many other languages:

```
// look at this clean new code :D
auto window = createWindow(i"Process debugger $pid");
```

It compiles without error. In bliss, the happy user thinks: "d rox". Then... the program is run and the window width is extraordinary. But the documentation says it will be automatically sized by default. The confused user wonders: why did this change? They run the program again and get another random width. Is the library incompatible with the new dmd version?

After some time, they notice the window title has changed to "Process debugger %" before being cut off by the taskbar width. "This new dmd version must be super buggy," they think, "it corrupted my string!"

Exasperated, they go online to ask the D gurus if anyone else has experienced this bizarre behavior. After an hour of wasted time, they finally mention having experimented with D's new string interpolation feature earlier in the day.

The helpful people in the D forum point them at the spec: "I know it looks like a string," the Master explains, "but it is actually lowered to an auto-expanding tuple whose first element is a string. That's causing your problem. I'd love to fix it in the library, but it is literally impossible to differentiate this case from legitimate usage :("

"D is weird," the user replies, deflated and defeated, "I think I'm just going to use Python. Have you see its f-strings?"

***

On the other hand, with `_d_interpolated_string`, it IS possible to tell those uses apart! In fact, the library author doesn't have to do anything - the user will see a helpful error message from the compiler and perhaps try `i"Process debugger $pid".idup` instead, or another suitable alternative.

If the library author does choose to adapt to the interpolated string, she can do so while keeping it separate from its existing default arguments by way of overloading the first argument on the new type yielded by `_d_interpolated_string`.

#### On implicit conversions

To avoid these unintentional bugs in libraries that don't anticipate interpolated strings, this DIP does NOT recommend implicit conversion of the `_d_interpolated_string` structure to `string`, excepting special circumstances. In the example druntime implementation code above, I included `static if(hasAllSpecs)` as a condition for `alias this`.

The logic here is if the user takes the additional effort to explicitly write format specifiers for all interpolated values, they've demonstrated significant understanding of how the feature works both in general and for their specific use case. In that case, we can allow implicit conversion so the interpolated string can be used by existing functions.

```
// the user knew enough to write %x for each item, let's trust
// that they understand the caveats of printf and allow this to happen.
printf("${%d}count ${%s}(name.toStringz)(s) available.");
```

This gives maximum compatibility with existing functions balanced against safety of accidentally calling existing functions inappropriately.

Whereas most existing functions that can use this are C functions and `alias this` suffers a current limitation of allowing `string` or `const(char*)`, but not both, I chose in the example code to use the C compatible version instead of the D compatible one. If `alias this` were enhanced in the future, perhaps we'd allow that implicit conversion too given the same use effort of spelling out specifiers. Also, when using D functions, you can generally call `.idup` on the interpolated string, or if avoiding garbage collected memory, you'd want to call another function to prepare the string into an alternate buffer anyway. Since Phobos functions can (and should) be overloaded on the new type, the user is unlikely to require additional implicit conversions anyway.

#### Interpolation to different formats

Consider an existing D library for interacting with databases. It includes a function:

```
/++
	Performs a query against the database. The `sql` string
	should consist of the SQL commands with `?n` placeholders
	to represent the given argument.

	Note that SQL placeholders are 1-based, meaning `?1` refers
	to the first argument given, aka `args[0]` in D.

	WARNING:
	Do NOT attempt to use string concatenation to inject data into
	the sql string - doing so puts you at risk of injection attacks.
	Always use the `args` facility with `?n` placeholders.
+/
Result query(T...)(string sql, T args) {}
```

It may even offer a version with `sql` as a compile-time string argument, so it can more effectively cache and reuse query handles and possible offer compile-time checks in D, analogous to `writefln(x, args)` vs `writefln!x(args)`.

A user with some understanding of D's new string interpolation feature may attempt to use it here:

```
query(i"Select name from people where age > $min_age");
```

With a plain string, that will compile successfully, but throw a sql syntax error. Oh, the user realizes, I need to add the specifier:

```
query(i"Select name from people where age > ${?1}min_age");
```

Yay, it worked! But it is a little awkward: suppose I change the condition:

```
query(i"Select name from people where name like ${?1}pattern and age > ${?2}min_age");
```

How annoying, I had to fix up all the subsequent placeholder numbers. Can't this be done automatically?

With `_d_interpolated_string`, it can! The database library can add an overload for it that iterates the arguments and generates the correct sql string for its database target, transparently to the user, without risking any code breakage on the existing `query` functions. Everyone wins!

However, a word of warning. Suppose the user tried `query(i"Select name from people where age > $min_age");` and the library did NOT overload for it. The compiler may suggest "did you try .idup?" in its error message, trying to be helpful and point the user toward coercing it into a traditional `string` argument.

The documentation warns against *concatenation*, not *interpolation*.... yet the `.idup` would give the same result. The library cannot catch this user error after-the-fact.

That said, this is no worse than the user writing `"age > " ~ max_age` (except in that it is more convenient), but I recommend the compiler diagnostic output a web link with more detail than just writing "try idup".

#### Conversion to string

```
string s = i"";
```

will give a type mismatch error. With my recommended `idup` overload in `object.d`, using this is no harder than using a `const char[]` assignment to `string` without requiring an additional import from the user.

Other functions should also be available and explained on a web site for users to learn, including, but not limited to, a solution for `@nogc` users. `snprintf` may play that role if the user gives specifiers, as detailed above in the implicit conversion segment.

### Limitations

#### All format specifiers must be known at compile time

It is impossible to provide a format specifier `i"${this_part}foo` at run time. However, you could call a formatting function inside the expression, like `i"$(some_formatter(foo))"`.

#### Mixing Conventional Format Arguments With Interpolated Strings in legacy functions

Interpolated string formats cannot be mixed with conventional elements unless the receiving function overloads on `_d_interpolated_string`:

```
const char* tool = "hammer";
printf(i"hammering %s with ${%s}tool", "nails");
```
will produce:
```
const char* tool = "hammer";
printf("hammering %s with %s", tool, "nails");
```
as the interpolated arguments will always come first, and out of order with the conventional
arguments. This error is not detected by the compiler, but since the user must proactively write
a format specifier, it ought not happen frequently by accident.

With D functions like `writefln` providing an overload specifically on `_d_interpolated_string`,
this can be detected and treated as a compile-time error (which the sample library implementation
would do), corrected to `%%s`, or even interleaved correctly by library code.

#### W and D Interpolated Strings

`wchar` and `dchar` interpolated strings are not allowed at this time.

## Breaking Changes and Deprecations

Since the interpolated string is a new token, no existing code is broken.

## Reference

* [DIP 1027---String Interpolation---Community Review Round 1]
(https://digitalmars.com/d/archives/digitalmars/D/DIP_1027---String_Interpolation---Community_Review_Round_1_333503.html)

## Copyright & License
Copyright (c) 2019 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## Reviews

### Community Review Round 1

[Reviewed Version](https://github.com/dlang/DIPs/blob/148001a963f5d6e090bb6beef5caf9854372d0bc/DIPs/DIP1027.md)

[Discussion](https://forum.dlang.org/post/abhpqwxqgiyzgqxmjaky@forum.dlang.org)

The review generated a tremendous volume of feedback and discussion. Key points that were raised include:

* the choice of `%` instead of something more familiar from other language, like `$`. Related, the lowering of `%%` to `%` was raised multiple times as being problematic. The DIP author modified the proposal to use `$` instead.
* the requirement of the `i` prefix. The DIP author explained that an interpolated string has to be a separate token.
* what about concatenating multiple strings to the interpolated string with `~`? The DIP author explained that this presents a problem during semantic analysis. He said it can be solved by allowing automatic concatenation of any strings following an interpolated string. Although such behavior is deprecated for string literals, and interpolated string is not treated as a string literal.
* the choice of lowering an interpolated string to a tuple of format string + arguments as opposed to a tuple of strings and arguments. The DIP author responded that he didn't see the point.
* why not lower to a function call? The DIP author responded that functions currently can't return tuples and it wouldn't work with `printf`.
* why not a library solution? The DIP author said he tried, but it requires an awkward syntax.
* why no assignment to string? The DIP author presented several reasons why this was undesirable, including: requires GC allocation, worse performance due to intermediate buffer, will not work with BetterC, and more.
* the lowering of `%{FormatString}` only works with `printf` and `writef`. The DIP author decided to change it to simply `{FormatString}`, e.g., `{%d}` instead of `%{d}`, and treating everything in the braces as a whole string rather than as a suffix to `%`.

Much of the discussion revolved around the syntax and the choice of lowering to a tuple of format string and arguments, and questions about interaction with other language features (e.g., templates, token strings). The DIP author's position, established over several comments, was essentially:

* tuples can easily be manipulated to suit the user's needs
* the implementation must be compatible with BetterC, meaning `printf` and similar C functions
* the implementation must not trigger GC allocations
* the implementation must not depend on Phobos
* the implementation must be performant
