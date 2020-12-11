# Token-based Mixins

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | *TBD by DIP Manager*                                            |
| Review Count:   | 0 (edited by DIP Manager)                                       |
| Author:         | Quirin F. Schroll (q.schroll@gmail.com)                         |
| Implementation: | *none*                                                          |
| Status:         | Draft                                                           |

## Abstract

In meta-programming, mixins are the ultimate answer of kings:
Almost anything that can be thought of can be achieved using them.
However, programmers abstain from mixins because non-trivial mixin code is harder to maintain.
One pays the price of kings, so to speak.
This DIP tries to lower that price.

The author suggests adding another way to express mixin statements and mixin declarations
for the case where the code consists of a large pattern with a few open spots.
It token-based mostly the same way `q{}` string literals are token-based.
The goal is to make meta-programming code more readabe by giving the programmers a way to write idiomatic `mixin` code
that is easier to write correctly and so easier to review and debug.

Notably, it enables using idiomatic pseudo-code found in the D Language Specification to become actual code.

## Contents
* [Rationale](#rationale)
* [Prior Work / Alternatives](#prior-work--alternatives)
* [Description](#description)
* [Breaking Changes and Deprecations](#breaking-changes-and-deprecations)
* [Reference](#reference)
* [Copyright & License](#copyright--license)
* [Reviews](#reviews)

## Rationale

Mixin declarations and statements are often used in conjunction with large string literals containing code,
where a few code parts need to vary and are inserted at specific points between string literals.
One common way is interrupting the literal using commas:
```D
mixin("...pattern...", hole, "...pattern...");
```
This will be referred to as the _interruption pattern_ in this DIP.

Another is Phobos' `format` function like this:
```D
mixin("...pattern...%s...pattern...".format(holes...));
```
This will be referred to as the _replacement pattern_ in this DIP.

In both cases, progrmmers usually mean to insert the value of some `identifier` and not literal `"identifier"` in a large block of code.
The DIP proposes a solution such that `identifier` can used where its value is supposed to go without any noise or aberration.
The case where the value of `identifier` and the string  `"identifier"` are needed together is also covered by this DIP using replacement assignments.
Sometimes it is a syntactically short function call instead of an identifer.
If the result of such a function call can be given a comprehensive name, which is usually the case, it is also covered by replacement assignments.

In the author's view, both patterns impair code comprehension greatly:
* In the interruption pattern, the `", identifer, "` potions interrupt the code with much noise compared to what is achieved.
Using `q{}` strings most syntax highlighter keep code visually appealing. Because braces need to be balanced inside them,
a `q{}` string cannot be interrupted at any place, which greatly limits their applicability for generating
function blocks, aggregate types like structs and classes or control structurs like `if`s or loops using interruptions.

* In the replacement pattern, holes mostly look like `%s` and there is no way to visually match them with their intended replacements.
While writing such code is not too hard (in the opinion of the DIP author), understanding and maintaining it is:
Adding, reordering or removing holes necessitates an according change of the processing function's arguments.
To the author, there seems to be a split in coding practices for the case where more than one hole is to be filled with the same content,
whether to use `%1$s` specifiers or merely `%s` and repeat the argument.

Syntax highlighting is ususually not available for string literals that are indended to be used as code.
The only exception being `q{}` strings that, as has been argued, are not an option in many important use cases.

## Prior Work / Alternatives
There are several proposals to add interpolated strings.
String interpolation can be thought of as an alternative,
since it solves the problems tackeld by this DIP partially.

With interpolation, code is still in string literals.

The author believes that string interpolation is a great addition for generating string literals at runtime,
but this addition is superior for code generation.
Even when string interpolation is added to the language, this addition will be worth the efforts implementing and maintaining it.

## Description
The DIP suggests adding another way to write mixin statements and declarations, notably absent are mixin expressions.
Since readers may not be familiar with the distinction, a brief summary of the terms
*mixin statements, declarations,* and *expressions* is given at the end of this section.

Currently, the `mixin` keyword can be followd by an opening parenthesis, constituting a mixin statement, declaration, or expression,
depending on the context the keyword occurs in;
or it can be followed by an identifier, constituting a mixin template instantiation.

The DIP suggests adding another case, the token-based mixin:
When the `mixin` keyword is followed by an opening (square) bracket, it constitutes a token-based mixin declaration or statement,
depending on the context the keyword occurs in.
Between brackets, a comma-separated list of possibly assigned identifiers follows.
Between braces, any tokens can be entered with special treatment of brace tokens that nest the same way they nest in `q{}` literals.
If no opening brace follows, any tokens can be entered with special treatment of brace tokens that nest the same way they nest in `q{}` literals,
but tokens are considered up to the next semicolon not nested in braces.
This is so that token-based mixins can be used to define lambda expressions with the brace syntax.

Every token and all white space between the braces is being replaced by a string literal containing the token or white space,
except for identifier tokens that coincide with one of the identifiers listed between the braces;
in that case, the idientifer token remains unchanged.
These string literal and identifer expressions are being concatenated and the result of the concatenation mixed in.

As an easy to follow example, consider
```D
mixin[op] lhs op= rhs;
```
or
```D
mixin[op]
{
    lhs.a op= rhs.a;
    lhs.b op= rhs.b;
}
```
as part of an `opOpAssign` implementation.
It is equivalent to
```D
mixin("lhs ", op, "= rhs;");
```
or
```D
mixin("lhs.a ", op, "= rhs.a;
       lhs.b ", op, "= rhs.b;");
```
In both examples, `op` is marked not to be replaced by the string `"op"`, but the value of `op`.
Notice that when `op` happens to be `"+"` for example, the resulting `+=` constitutes a single D token.

The usage of the assignment is demonstated here:
```D
auto opUnary(string op)() const
if (op == "++" || op == "--")
{
    mixin[o = op[0]]
        this o= 1;
}
```

Another use case that shows how idiomatic that usage is:
```D
struct TrivialProperty(T)
{
    template opDispatch(string name)
    {
        mixin template opDispatch(X = T)
        {
            mixin[name, _name = '_' ~ name]
            {
                private X _name;
                public X name() { return _name; }
                public void name(X value) { _name = value; }
            }
        }
    }
}

unittest
{
    struct Point
    {
        mixin TrivialProperty!int.x;
        mixin TrivialProperty!int.y;
    }
    // Point has _x and _y as private backing fields,
    // as well as getters and setters for x and y.
}
```
(Notice that `X = T` is not a feature.
Leaving it out and replacing `X` by `T` lead to compiler errors at the time of the writing of this DIP.)

The _semicolons in unbalanced braces rule_ is necessary to handle otherwise surprising cases correctly.
```D
auto opBinary(string op)(...)
{
    enum value = mixin[op] (ref v) { return v op 1; } (10 op 2);
    //                     ––––––––––––––––––––––––––––––––––––

    // Equivalent to:
    enum value = mixin("(ref v) { return v ", op, " 1; } (10 ", op, " 2);");
}
```
The tokens that are part of the mixin expressions are the ones above dashes.
The semicolon after `1` does not end the mixin expression, since the opening brace before `return` is not closed yet.

### About Mixin Statements, Declarations, and Expressions

Mixin statements, declarations, and expressions are all introduced by the `mixin` keyword.
They deal with inserting code that is derived from compile-time known string expressions.
They have nothing to do with `mixin template` constructions that insert symbols.
The difference between mixin statements, declarations, and expressions is only where the `mixin` keyword is used:
* Mixin declarations happen when `mixin` is used in a scope that contains delarations, such as module scope or inside the `struct`, `union`, `class`, and `interface` definition blocks.
* Mixin statements and expressions happen when `mixin` is used inside function blocks.
    * Mixin statements are whole statements so the mixed-in string must include `;` at the end.
    * Mixin expressions are expressions and the the mixed-in string must not include `;` at the end.
To many programmers, the distinction of mixin definitions and statements is practically irrelevant.
The distinction of mixin statements and expressions is relevant insofar as a trailing semicolon has to be accounted for:
for example, `return mixin("result");` is a statement containing a mixin expression, but `mixin("return result;");` is a mixin statement.

### Grammar changes

In the following, `Tokens` means slightliy differnt things.
In `{ Tokens }`, braces must be balanced, similar to `q{}` strings.
In `Tokens ;` Tokens may include `;` only in unbalanced braces. The first semicolon encountered after balanced braces or before any braces is not part of `Tokens`.

```diff
+   TokenMixinArguments:
+       TokenMixinArgument
+       TokenMixinArgument , TokenMixinArguments

+   TokenMixinArgument:
+       Identifier
+       Identifier = AssignExpression

    MixinStatement:
        mixin ( ArgumentList ) ;
+       mixin [ TokenMixinArguments , ] { Tokens }
+       mixin [ TokenMixinArguments   ] { Tokens }
+       mixin [ TokenMixinArguments , ] Tokens ;
+       mixin [ TokenMixinArguments   ] Tokens ;

    MixinDeclaration:
        mixin ( ArgumentList ) ;
+       mixin [ TokenMixinArguments , ] { Tokens }
+       mixin [ TokenMixinArguments   ] { Tokens }
+       mixin [ TokenMixinArguments , ] Tokens ;
+       mixin [ TokenMixinArguments   ] Tokens ;

    MixinExpression:
        mixin ( ArgumentList )

    MixinType:
        mixin ( ArgumentList )
```

The entries for `MixinExpression` and `MixinType` are unchanged and only mentioned to
show that they are intetionally unchanged.
Token-based mixins are always statements or declarations and never expressions.

## Breaking Changes and Deprecations
Since the additions of this change are a syntactic addition, code breakage is impossible.

## Reference
[Forum post suggesting this DIP](https://forum.dlang.org/post/vmcgpbjqimzpiiqsyyfk@forum.dlang.org)

## Copyright & License
Copyright © 2020 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## Reviews
The DIP Manager will supplement this section with a summary of each review stage
of the DIP process beyond the Draft Review.
