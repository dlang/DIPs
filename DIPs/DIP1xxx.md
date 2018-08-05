# Multiple template constraints

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | (number/id -- assigned by DIP Manager)                          |
| Review Count:   | 0                                                               |
| Author:         | Nicholas Wilson                                                 |
| Implementation: |                                                                 |
| Status:         | Will be set by the DIP manager (e.g. "Approved" or "Rejected")  |

## Abstract

Allow multiple `if` template constraints with an optional message to be printed in the 
event that overload resolution fails (similar to `static assert`). The template is 
considered a valid overload iff each of the constraints is satified.

```D
template all(alias pred)
{
    bool all(Range)(Range range)
    if (isInputRange!Range)
    if (is(typeof(unaryFun!pred(range.front))),
        "`" ~ pred.stringof[1..$-1] ~ "` isn't a unary predicate function for range.front"))
    {
    }
}
```

### Reference

Optional links to reference material such as existing discussions, research papers
or any other supplementary materials.

## Contents
* [Rationale](#rationale)
* [Description](#description)
* [Breaking Changes and Deprecations](#breaking-changes-and-deprecations)
* [Copyright & License](#copyright--license)
* [Reviews](#reviews)

## Rationale

It is well known that compilation error messages due to template contraint overload resolution 
are particularly difficult to decipher. This is not helped by the number of overloads and very 
precice (and thus complex) constraints placed on the overloads. When overload resolution fails
the compiler will print out all the in scope overloads and their constraints, without indication
of which constraints have failed.

While it is not possible in the general case to provide useful information as to what constraints
have failed and why, because a constraint may have an arbitrary combination of logic. However the vast 
majority of constraints are expressed in Conjuntive Normal Form (CNF). In this case it is definitely 
possible to provide better daignostics as to which clauses have failed. However the current grammer
provides no way to translate particularly verbose constraints to a user not intimately familiar with 
the constraint e.g. `is(typeof(unaryFun!pred(range.front))` (TODO: more examples).

This DIP therefore proposes to formalise the use of CNF constraints by allowing multiple `if` constraints,
each with an optional message, such that the compiler is much better placed to provide better diagnostics,
such as:

* indicating if a clause is satisfied, 
* indicating if a clause is the same as another overload (e.g. range functions and `isRange!Range`)

## Description

Template constraints are changed to allow multiple multiple `if` template constraints with an optional message.
Each constraint must be satisfied to be a viable overload candiate. That is 
```D
template foo(T) 
if (constraint1!T) 
if (constraint2!T)
if (constraint3!T) { ... }
```
is semantically equivalent to 
```D
template foo(T) 
if (constraint1!T &&
    constraint2!T &&
    constraint3!T)
```

The optional constraint message can be used to provide a more easily uderstood description of why a 
constraint has not been met.

```D
template foo(T) 
if (constraint1!T, " Constraint1 not met for " ~ T.stringof) 
```

###Template Grammar changes

All references to `Constraint` in the spec now reference `Constraints`.

`Constraint` is changed from 
```
Constraint:
  if ( Expression )
```
to 
```
Constraint:
  if ( Expression )
  if ( Expression , Expression )
```

and `Constraints` is defined as 
```
Constraints:
  Constraint
  Constraint Constraints
```

## Breaking Changes and Deprecations

N/A. This DIP is purely additive. However in order to make use of this DIP, library writers will need 
to update the constraints from CNF to one clause per `if` constraint which is a backwards incompatible change.
This is not a problem for Phobos, since it is released in sync with the compiler.


## Copyright & License

Copyright (c) 2018 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## Reviews

The DIP Manager will supplement this section with a summary of each review stage
of the DIP process beyond the Draft Review.
