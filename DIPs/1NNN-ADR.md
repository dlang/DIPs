
# Formatted string tuple literals

| Field           | Value                                                                                                |
|-----------------|------------------------------------------------------------------------------------------------------|
| DIP:            | 1NNN                                                                                                 |
| Review Count:   | 0                                                                                                    |
| Author:         | Adam D. Ruppe + Steven Schveighoffer (+ D community team effort based on Walter's original DIP 1027) |
| Implementation: |                                                                                                      |
| Status:         | Initial formalization                                                                                |

## Abstract

*NOTE: This DIP is based heavily on DIP 1027, and as such has much of the same contents, rationale, description, etc.*

Instead of requiring a format string followed by an argument list, string interpolation via formatted string tuple literals enables
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
* [DIP1027](https://github.com/dlang/DIPs/blob/master/DIPs/rejected/DIP1027.md)
* [C#'s implementation](https://docs.microsoft.com/en-us/dotnet/csharp/language-reference/tokens/interpolated#compilation-of-interpolated-strings) which returns a formattable object that user functions can use
* [Javascript's implementation](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Template_literals) which passes `string[], args...` to a builder function very similarly to this proposal
* Jason Helson submitted a DIP [String Syntax for Compile-Time Sequences](https://github.com/dlang/DIPs/pull/140).
* [Jonathan Marler's Interpolated Strings](http://github.com/dlang/dmd/pull/7988)

## Description

```
writefln(i"I ate $apples and ${%d}bananas totalling $(apples + bananas) fruit.");
```
gets rewritten as:
```
writefln(<interpolationSpec>, apples, bananas, apples + bananas);
```

The `interpolationSpec` parameter will have a type defined by druntime. The exact type name is unnamed for this spec. It is used by accepting a template parameter for the function being called. Each of the `$` tokens in the string is considered an interpolation parameter.

The `{%d}` syntax is for circumstances when the format specifier needs to be given by the user for that parameter.
What goes between the `{` `}` is not specified, so this capability can be used by any function
in the present, past, or future without needing to update the core language or runtime library. It also makes interpolated strings agnostic about what the format specifications are.

The spec can be used as follows:

`spec.toFormatString!(defaultSpec)` produces a compile-time format string with all the interpolated strings replaced as defined after the grammar below, but summarized as follows:
1. If the prefix `{...}` is put between the `$` and the parameter, whatever is inside the `{` `}` is used.
2. Otherwise, `defaultSpec` is used.

`spec.hasAllSpecs` is a compile-time boolean which indicates whether all interpolation parameters had specs defined with a `{}` prefix.

`spec` will automatically convert to a compile-time Null-terminated C string if `spec.hasAllSpecs` is true. This allows one to use it for already-defined C functions such as `printf`.

Example:

```D
void foo(T, Args...)(T spec, Args)
if (isInterpolationSpec!T) // used for overloading with other functions
{
    import std.stdio;
    string fmt = spec.toFormatString!"%s"; // also can be called at compile-time.
    writeln(`D format spec: "`, fmt, `"`);
    static if (spec.hasAllSpecs) // if all specs are specified
    {
        immutable char *zFormat = spec; // automatically converts to a C null-terminated string.
        writeln(`C format spec: "`, zFormat[0 .. strlen(zFormat)], `"`);
    }
}

void main()
{
    int apples = 5;
    int bananas = 6;

    foo(i"I ate $apples and ${%d}bananas totalling $(apples + bananas) fruit.");
    // output:
    // D format spec: "I ate %s and %d totalling %s fruit."

    foo(i"I ate ${%d}apples and ${%d}bananas totalling ${%d}(apples + bananas) fruit.");
    // output:
    // D format spec: "I ate %d and %d totalling %d fruit."
    // C format spec: "I ate %d and %d totalling %d fruit."
}
```
Example of `printf` usage:

```
printf(i"I ate ${%d}apples and ${%d}bananas totalling ${%d}(apples + bananas) fruit.\n");
```
becomes (after converting the spec to a Null-terinated C string):
```
printf("I ate %d and %d totalling %d fruit.", bananas, apples + bananas);
```
Any other usage of the interpolation spec parameter is not defined by the D specification, and subject to change at any time.

In particular you should not depend on the name of the spec type, or how it is implemented.


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
is the druntime interpolation spec, and the `Argument`s form the remainder of the tuple elements.

The compiler implements the following rules before passing the appropriate data to the runtime for each element:

If the `Element` is:

* `Character`, it is used as part of the format string.
* `'$$'`, a '$' is used as part of the format string.

If a `'$'` occurs without a following `'$'`, this will denote an interpolation parameter.

If the Element sequence is:
* `'$' Argument`, then the runtime is instructed to place the default format specifier into the format string. The default format specifier is defined by user code as a template parameter to `spec.toFormatString`.
* `'$' '{' FormatString '}' Argument`, then the runtime is instructed to put `FormatString` into the format string.

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

If the druntime implementation symbols are not present in `object.d`, use of interpolated strings MUST result in a compile-time error. The compiler SHOULD issue a user-friendly diagnostic, for example "string interpolation support not found in druntime" instead of leaking implementation details in error messages.

### Concatenations

In order to facilitate convenient formatting of long strings, if a `StringLiteral` follows an `InterpolatedString`,
it is appended to the `InterpolatedString` in the parsing pass. (Not the lexer pass.)
A `StringPostfix` may not appear on any of them.
Such concatenations enable the various string literal types to be used as `InterpolatedStrings`,
such as:

```
i""q{apples and $("bananas")}
```
would be identical to:
```
i"apples and $(\"bananas\")"
```
### Example Implementation

This implementation is provided for reference, but is not necessarily how the compiler and druntime will interact when processing interpolated strings. Therefore, while it is useful for discussion, this implementation will NOT be part of the D specification, and the actual implementation may vary.

In this implementation, the compiler uses lowering to provide all the information to the runtime. For example:
```
i"I ate $apples and ${%d}bananas totalling $(apples + bananas) fruit."
```

Would be lowered by the compiler to the list:
```D
.object._d_interpolated_string!("I ate ", .object._d_interpolated_format_spec(null),
                        " and ", .object._d_interpolated_format_spec("%d"),
                        " totalling ", .object._d_interpolated_format_spec(null),
                        " fruit."),
    apples, bananas, (apples + bananas)
```
The following new code would be added to object.d:

```D
struct _d_interpolated_string(Parts...) {
        static:

        private bool _hasAllSpecs() {
            assert(__ctfe);
            foreach(part; Parts)
               static if(is(typeof(part) == _d_interpolated_format_spec))
                  if(part.spec is null)
                       return false;
            return true;
        }

        public enum hasAllSpecs = _hasAllSpecs();

        private string toFormatStringImpl(string defaultSpec) {
            assert(__ctfe);
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
        }

        private immutable(char*) toFormatStringzImpl() {
                return toFormatString!(null).ptr;
        }

        public template toFormatString(string defaultSpec) {
                enum toFormatString = toFormatStringImpl(defaultSpec);
        }

        static if(hasAllSpecs) {
                alias toFormatStringzImpl this;
        }
}

immutable struct _d_interpolated_format_spec {
        string spec;
}

enum isInterpolationSpec(T) = is(T == _d_interpolated_string!P, P...);
```

### Optional `idup` mechanism

As an addition for user-friendliness, we also suggest to add an `idup` overload to `object.d` specialized for a tuple that is recognized as starting with an interpolation spec.

In object.d
```
string idup(I, T...)(I fmt, T args) if (isInterpolationSpec!I) {
        import std.format;
        return format!(I.toFormatString!"%s")(args);
}
```

Since `idup` is already a symbol and since this new overload is constrained to just the new type, this has no effect on existing code and does not contribute to namespace pollution. Moreover, since `"string".idup` is already an accepted convention for converting `const` strings to the immutable-based `string` type, it is also a natural extension of existing user skills for string assignment. Lastly, it is already known that `.idup` invokes the GC and its associated allocation, so it should come to no surprise that `i"".idup` does as well. However, normal string `idup` does not import Phobos while this does, that is a hidden implementation detail that can be improved upon in the future and strikes the best current balance between usability and elegance of implementation.

### Usage in existing string-accepting functions

No doubt there are many functions that accept a format string followed by the parameters for the format string. Such overloads can use the `isInterpolationSpec` test to ensure they do not clash with the normal string overload.

For example, `std.stdio.writefln` can be amended with the following overload:

```D
auto writefln(Fmt, Args...)(Fmt fmt, Args args) if (isInterpolationSpec!Fmt)
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

### Justifications

The complexity of the format spec may seem superfluous, however it serves three key roles:

1. It divorces the compiler entirely from details of generated format strings. For example, different functions that accept format strings might use different default format specifiers.
2. It allows overloading existing string-accepting functions to prevent accidental usage that happen to fit the parameter list (see example below).
2. It provides necessary error checking capabilities.
3. It provides an additional API for user functions to introspect the string, building on D's existing compile-time capabilities.

The previous version of this DIP proposed a simple string literal as the first argument passed. This is problematic because it introduces potentially subtle errors in likely usage.

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

This would compile without error, but would not do what the user intended. D would pass the variable `pid` as the second argument to the function, which would interpret it as window width. Without a way to detect this misuse, which is likely to be a common mistake made by programmers more familiar with string interpolation in other languages, users will be unpleasantly surprised with buggy code.

The `isInterpolationSpec` check provides such a way to detect misues. In fact, the library author doesn't have to do anything - the user will see a helpful error message from the compiler and perhaps try `i"Process debugger $pid".idup` instead, or another suitable alternative.

As an added benefit, if the library author does choose to adapt to the interpolated string, she can do so while keeping it separate from its existing default arguments by way of overloading the first argument on the new type.

Other alternatives discussed in the community included a compiler-recognized attribute on the parameter to indicate it takes a format string, but once we define rules for all the edge cases for ABI, mangling, overloading, etc., such a thing would have simply reinvented a struct type in a more awkward fashion. It is better to lean on rules the language and its users already understand than invent special rules for this one case.

#### On implicit conversions

To avoid these unintentional bugs in libraries that don't anticipate interpolated strings, this DIP does NOT recommend implicit conversion of the interpolation spec structure to `string`, excepting special circumstances. In the example druntime implementation code above, we included `static if(hasAllSpecs)` as a condition for `alias this`.

The logic here is if the user takes the additional effort to explicitly write format specifiers for all interpolated values, they've demonstrated significant understanding of how the feature works both in general and for their specific use case. In that case, we can allow implicit conversion so the interpolated string can be used by existing functions.

```
// the user knew enough to write %x for each item, let's trust
// that they understand the caveats of printf and allow this to happen.
printf("${%d}count ${%s}(name.toStringz)(s) available.");
```

This gives maximum compatibility with existing functions balanced against safety of accidentally calling existing functions inappropriately.

Whereas most existing functions that can use this are C functions and `alias this` suffers a current limitation of allowing `string` or `const(char*)`, but not both, I chose in the example code to use the C compatible version instead of the D compatible one. If `alias this` were enhanced in the future, perhaps we'd allow that implicit conversion too given the same use effort of spelling out specifiers.

Also, when using D functions, you can generally call `.idup` on the interpolated string, or if avoiding garbage collected memory, you'd want to call another function to prepare the string into an alternate buffer anyway. Since Phobos functions can (and should) be overloaded on the new type, the user is unlikely to require additional implicit conversions anyway.

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

If the spec were a plain string, that will compile successfully, but throw a sql syntax error. Oh, the user realizes, I need to add the specifier:

```
query(i"Select name from people where age > ${?1}min_age");
```

Yay, it worked! But it is a little awkward: suppose I change the condition:

```
query(i"Select name from people where name like ${?1}pattern and age > ${?2}min_age");
```

How annoying, I had to fix up all the subsequent placeholder numbers. Can't this be done automatically?

With this DIP, it can! The database library can add an overload for it that provides a searchable default, and at compile-time, replaces the generated string with one that has the correct numbered sequence of placeholders, transparently to the user, without risking any code breakage on the existing `query` functions. A possible improvement in the future might allow more sophisticated format string generation, allowing for the database library to do this directly using the format spec.

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

Interpolated string formats cannot be mixed with conventional elements unless the receiving function overloads on the interpolation spec type.

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

With D functions like `writefln` providing an overload specifically for interpolated strings,
this can be detected and treated as a compile-time error (which the sample library implementation
would do), corrected to `%%s`, or even interleaved correctly by library code.

Making these work implicitly would mean sacrificing the type safety identified in the `createWindow` case mentioned previously or baking knowledge of format strings into the language (and someone defining a rule so user-defined functions can utilize it), and this comes back to awkwardly reinventing a type.

Note that with a small improvement to provide the count of the interpolation parameters, subsequent interpolation strings could be used inside `writefln`.

#### W and D Interpolated Strings

`wchar` and `dchar` interpolated strings are not allowed at this time. If they were to be added, however, `i"..."w` would work the same way, except the interpolation spec would be configured to return `wstring` when calling `spec.toFormatString`.

## Breaking Changes and Deprecations

Since the interpolated string is a new token, no existing code is broken.

## Reference

## Copyright & License
Copyright (c) 2019 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## Reviews
