# Shortened Method Syntax

| Field           | Value                                                          |
|-----------------|----------------------------------------------------------------|
| DIP:            | (number/id -- assigned by DIP Manager)                         |
| Review Count:   | 0 (edited by DIP Manager)                                      |
| Author:         | Max Haughton, Adam D. Ruppe                                       |
| Implementation: | https://github.com/dlang/dmd/pull/11833                        |
| Status:         | Draft                                                          |

## Abstract

This DIP proposes a shortened syntax for function definitions.
The following syntax is proposed:

```D
int add(int x, int y) pure => x + y;
```

The feature is already implemented in the D programming language as a preview.

## Contents
* [Rationale](#rationale)
* [Prior Work](#prior-work)
* [Description](#description)
* [Reference](#reference)
* [Copyright & License](#copyright--license)
* [Reviews](#reviews)

## Rationale
A shortened syntax for function literals is already supported in the D programming language. For example:

```D
const succ = (int x) => x + 1;
```

is equivalent to

```D
const succ = function(int x) { return x + 1; };
```

Via a trivial change to the language, a similar syntax can be implemented for function definitions.
This will bring more consistency to the syntax of function literals and definitions and save the programmer a few keystrokes.

For example, consider a simple range producing a range excluding one end (`[from, to)`):
```d
struct LongerExclusiveRange(T)
{
	T from, to;
   invariant(from <= to);
   bool empty() {
      return from == to;
   }
   void popFront() {
      ++from;
   }
   T front() {
      return from;
   }
}
```
The implementation in D without this DIP is 14 lines.
```d
struct ExclusiveRange(T)
{
	T from, to;
   invariant(from <= to);
   bool empty() => from == to;
   auto popFront() => ++from;
   T front() => from;
}
```
An implementation utilizing this DIP is only 8 lines (about 40% less typing).

The syntax enabled by this DIP can also make writing compositions of functions (ranges or otherwise), more direct: If there is nothing to
require use of braces then they can be elided. For example, take this arbitrary composition of ranges:
```d
auto doesWork()
    => iota(1, 100)
        .map!(x => x + 1)
        .filter!(x => x > 4)
        .each!writeln;
```
With the shortened methods syntax, this function terminates syntactically in the same place it does semantically.
The call to `each` is where the function's work ends, this DIP allows the programmer to end the function's syntax there too.
This saves the author some keystrokes, and saves the reader from having to process unnecessarily visual noise.

## Prior Work
This DIP has the potential to result in a post-facto blessing of
a preview feature already supported by the compiler. [The existing implementation](https://github.com/dlang/dmd/pull/11833)
was written by Adam D. Ruppe.

The proposed feature is present in the C# programming language, where instances of its use are referred to as
[Expression-bodied members](https://docs.microsoft.com/en-us/dotnet/csharp/programming-guide/statements-expressions-operators/expression-bodied-members).

The C# documentation demonstrates an idiomatic example of the proposed feature, reproduced here:

```c#
public class Location
{
   private string locationName;

   public Location(string name)
   {
      locationName = name;
   }

   public string Name => locationName;
}
```

Note that the `Name` function is a simple one-liner that returns the `locationName` member. Such one-liners are common in C#,
where programmers are encouraged to provide access to member variables via member functions.

## Description
### Semantics
The proposed semantics are a simple example of what is referred to in the theory of programming language implementation as lowering:

```d
FunctionDeclarator => AssignExpression;
```

shall be rewritten to

```d
FunctionDeclarator
{
	return AssignExpression;
}
```

Given that constructors and destructors cannot have return values, the implementation should reject any attempt to implement
a constructor or destructor using the shortened method syntax and provide a meaningful error message.
### Grammar
The proposed feature requires the following grammar changes:
```diff
FunctionBody:
     SpecifiedFunctionBody
     MissingFunctionBody
+    ShortenedFunctionBody
...

+ShortenedFunctionBody:
+    => AssignExpression ;
```


## Reference
Recently, [it has been noted](https://github.com/dlang/dlang.org/pull/3059) that the current implementation allows the use of
function contracts with this syntax. Function contracts are not possible with function literals, so this DIP does not address
the issue. It is mentioned here both for future reference and in case review determines the proposal should be enhanced to
explicitly address function contracts in the presence of shortened method syntax.

### Trivia

* [The syntax was mentioned on the D Bugzilla in 2011](https://issues.dlang.org/show_bug.cgi?id=7176). The dialectics in this thread
  can be considered a pre-review.
* [Shortened Methods are documented in the specification](https://github.com/dlang/dlang.org/pull/2956)
* [A dmd changelog entry was added](https://github.com/dlang/dmd/pull/12241)

## Copyright & License
Copyright (c) 2021 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## Reviews
The DIP Manager will supplement this section with a summary of each review stage
of the DIP process beyond the Draft Review.