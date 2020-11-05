# Token-based Mixins

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | *TBD by DIP Manager*                                            |
| Review Count:   | 0 (edited by DIP Manager)                                       |
| Author:         | Quirin F. Schroll (q.schroll@gmail.com)                         |
| Implementation: | *none*                                                          |
| Status:         | Draft                                                           |

## Abstract

The author suggests adding another way to express mixin statements and declarations based on
the way `q{}` string literals are handled.
The goal is to make meta-programming code more readabe by giving the programmers a way to write idiomatic `mixin` code
that is easier to write correctly, review and debug.

Notably, it enables using idiomatic pseudo code found in the D Language Specification to become actual code.

## Contents
* [Rationale](#rationale)
* [Prior Work](#prior-work)
* [Description](#description)
* [Breaking Changes and Deprecations](#breaking-changes-and-deprecations)
* [Reference](#reference)
* [Copyright & License](#copyright--license)
* [Reviews](#reviews)

## Rationale

In meta-programming, mixin declarations and statements are often used in conjunction with large literals containing code,
where dynamic code parts are inserted at specific points in string literals (code templates) using interruptions like
```D
mixin("...", identifier, "...");
```
or
```D
mixin("...%s...".format(..., identifier, ...));
```
That impairs readability greatly.
The language should allow for code that directly express what the programmer means.

In those cases, progrmmers mean: Insert the value of `identifier` and not literal `"identifier"` here.
Another observation is also that hardly anywhere, the value of `identifier` and the string  `"identifier"` are needed together.

In the interruption case, the `", identifer, "` potions interrupt the code with much noise.
It also reduces the potential of using `q{}` strings since inside them, braces need to be balanced,
therefore the `q{}` string cannot be interrupted at any place.

In the `format` case, holes mostly look like `%s` and there is no way to visually match them with their intended replacements.
Also, adding, reordering or removing holes necessitates an according change of the processing function's arguments.
To the author, there seems to be a split in coding practices for the case where more than one hole is to be filled with the same content,
whether to use `%1$s` specifiers in the template string or merely `%s` and repeat the argument.
This addition solves this issue without imposing a choice for which choice is the least bad one.

Syntax highlighting is ususually not available for string literals that are indended to be used as code.

## Prior Work
There are several proposals to add interpolated strings.

String interpolation solves one of the problems tackeld by this DIP, but not all of them.
The author believes that string interpolation is a great addition for generating string literals at runtime,
but this addition is superior for code generation.
Even when string interpolation is added to the language, this addition will be worth the efforts implementing and maintaining it.

## Description
The DIP suggests adding another way to write mixin statements and declarations, notably absent are mixin expressions.
Since readers may not be familiar with the distinction, a brief summary of the terms *mixin statements, declarations,* and *expressions* is given at the end of this section.

Currently, the `mixin` keyword can be followd by an opening parenthesis constituting a mixin statement, declaration, or expression,
depending on the context the keyword occurs in;
or be followed by an identifier constituting a mixin template instantiation.

The DIP suggests adding another case:
When the `mixin` keyword is followed by an opening bracket, it introduces a token-based mixin declaration or statement, depending on the context the keyword occurs in.
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
mixin("lhs.a ", op, "= rhs.a;");
mixin("lhs.b ", op, "= rhs.b;");
```
Here, `op` is marked not to be replaced by `"op"`.
Notice that when `op` happens to be `"+"` for example, the resulting `+=` constitutes a single D token.

Use case for the use case of the assignment:
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


The unbalanced braces in the semicolon-ended token-based mixin is demonstrated by this:
```D
auto opBinary(string op)(...)
{
    enum value = mixin[op] (ref v) { return v op 1; } (10 op 2);
    //                     ––––––––––––––––––––––––––––––––––––

    // Equivalent to:
    enum value = mixin("(ref v) { return v ", op, " 1; } (10 ", op, " 2);");
}
```
The tokens that are part of the mixed-in are the ones above dashes.
The semicolon after `1` does not end the token scan, since the opening brace before `return` is not closed yet.

### About Mixin Statements, Declarations, and Expressions

Mixin statements, declarations, and expressions are all introduced by the `mixin` keyword.
They deal with inserting code that is derived from compile-time known string expressions.
They have nothing to do with `mixin template` constructions that insert symbols.
The difference between mixin statements, declarations, and expressions is only where the `mixin` keyword is used:
* Mixin declarations happen when `mixin` is used in a scope that contains delarations, such as module scope or inside the `struct`, `union`, `class`, and `interface` definition blocks.
* Mixin statements and expressions happen when `mixin` is used inside function blocks.
    * Mixin statements generate whole statements so the code generated must include `;` at the end.
    * Mixin expressions generate parts of expressions and the code generated must not include `;` at the end.
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
+       mixin [ TokenMixinArguments ,opt ] { Tokens }
+       mixin [ TokenMixinArguments ,opt ] Tokens ;

    MixinDeclaration:
        mixin ( ArgumentList ) ;
+       mixin [ TokenMixinArguments ,opt ] { Tokens }
+       mixin [ TokenMixinArguments ,opt ] Tokens ;

    MixinExpression:
        mixin ( ArgumentList )

    MixinType:
        mixin ( ArgumentList )
```

The entries for `MixinExpression` and `MixinType` are unchanged and only mentioned to
anticipate confusion. Token mixins are always statements or declarations and never expressions.

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
