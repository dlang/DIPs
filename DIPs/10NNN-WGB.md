# Implicit Conversion of Expressions to Delegates

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | (number/id -- assigned by DIP Manager)                          |
| Review Count:   | 0 (edited by DIP Manager)                                       |
| Author:         | (your name and contact data)                                    |
| Implementation: | (links to implementation PR if any)                             |
| Status:         | Will be set by the DIP manager (e.g. "Approved" or "Rejected")  |

## Abstract

Allow implicit conversion of expressions to delegates. This happens already for
arguments to lazy parameters. This proposal extends it more generally and
lays the foundation for removing `lazy` as a special case delegate.


## Contents
* [Rationale](#rationale)
* [Prior Work](#prior-work)
* [Description](#description)
* [Breaking Changes and Deprecations](#breaking-changes-and-deprecations)
* [Reference](#reference)
* [Copyright & License](#copyright--license)
* [Reviews](#reviews)

## Rationale

The current form of this is the automatic conversion of arguments to `lazy`
parameters to delegates. The troubles with `lazy` are:

1. it stands out as an oddity
2. being an oddity means it is hard to reason about, especially with the
proliferation of parameter attributes
3. it is underdocumented
4. special case code for it is sprinkled throughout the compiler
5. it is rarely used, so likely has many undetected problems
6. it has largely gone unrecognized that it works like a delegate

`lazy` has found a home, however, in functions like this one in `std.path`:
```
pure @safe string absolutePath(string path, lazy string base = getcwd());
```
where it is undesirable to compute base argument unless it is actually needed.
With this change, it could be rewritten as:

```
pure @safe string absolutePath(string path, string delegate() base = getcwd());
```
and called the same way.

There's more than supplanting `lazy`. It makes delegates in general easier to write,
and experience suggests that the easier they are to write, the more uses people
find for them:

```
int delegate() dg = () { return 3; };
```
or:
```
int delegate() dg = () => 3;
```
become simply:
```
int delegate() dg = 3;
```


## Prior Work

None known.


## Description

Allow the implicit conversion of an `Expression` of type `T` to a delegate lambda function that
returns a type `T`. The body of the delegate lambda will be the `Expression` which
will be returned from the lambda.

I.e.:

Given expression `E` of type `T`, it is converted to:

```
T delegate() { return E; }
```

Attribute inference is done on the function, just as it is for all lambda functions.

The [match level](http://dlang.org/spec/function.html#function-overloading)
will be "2. match with implicit conversions".
If generated delegate lambda is not implicitly convertible to the delegate type
in the funciton declaration, there is no match.


### Grammar Changes

None.


### Function Overloading

```
void biff(int);            // A
void biff(int delegate()); // B

void test(int i)
{
    biff(i);
}
```

`i` is of type `int` which is an exact match for `A`. A match with `B` would be
via a conversion to a delegate lambda, so `A` is better and is selected.

```
void biff(long);            // A
void biff(long delegate()); // B

void test(int i)
{
    biff(i);
}
```
Both A and B are matched equally at the "conversion" level. Then, partial ordering is
applied. A variable of type `long` can be converted to `long delegate()` lambda, but a
`long delegate()` cannot be converted to `long`. Therefore, `A` is the better match.
This makes sense as the intuitive result.


### `null`

```
void biff(T delegate());

void test()
{
    biff(null);
}
```
`null` implicitly converts directly to any delegate, but is not of type `T`, so it will
not be turned into a lambda. Again, this is what is expected and is consistent
with existing code.


### Function Pointers

Implicit conversion of expressions to function lambdas is not done. There doesn't seem
much point to it, as there will be no arguments to the function lambda, meaning the expression
can only consist of globals.


### Deprecation of `lazy`

Although this DIP renders `lazy` redundant and unnecessary, it does not propose actually
removing `lazy`. That will be deferred for a future DIP.


## Breaking Changes and Deprecations

The only potential difficulty is if delegates are overloaded with other types. But the combination
of matching rules by conversion level and partial ordering appear to resolve this in the direction
of not breaking existing code.

## Reference

None.

## Copyright & License
Copyright (c) 2019-2020 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## Reviews
The DIP Manager will supplement this section with a summary of each review stage
of the DIP process beyond the Draft Review.
