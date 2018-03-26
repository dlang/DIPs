# The Deprecation Process

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | 10XX                                                            |
| Review Count:   | 0                                                               |
| Author:         | Jack Stouffer <jack@jackstouffer.com>                           |
| Implementation: | N/A                                                             |
| Status:         |                                                                 |

## Abstract

In order to incrementally improve D or it's standard library, it's often necessary to
mark features or functions for future removal. This document proposes a standardized
process for language maintainers to remove public features. This process would be 
used across DMD, Druntime, and Phobos.

## Contents
* [Rationale](#rationale)
* [Description](#description)
    * [Public Functions, Types, and Modules](#public-functions-types-and-modules)
    * [Language Features](#language-features)
* [Copyright & License](#copyright--license)
* [Reviews](#reviews)

## Rationale

There is general disagreement on the best and/or accepted way to remove public
features. Each deprecation ends up being handled slightly differently depending on
who's writing the pull request. Standardizing the process makes sure that
deprecations are done very publicly and carefully, so as to minimize breakage and
to provide clear fixes for user code.

## Description

The following lays out the rules to follow to deprecate a part of D.

A symbol or feature must not be marked for removal on a specific date, but rather on a
specific release. This allows users to easily know if upgrading will break their
code or not.

Users must be given at least 10 non-patch releases before the deprecated features
are removed. More releases can be given if the removed code is commonly used.
There are two cases where the deprecation period is allowed to be shorter:

1. The code or feature is notably dangerous or unsafe, and users need to remove
it from their code as soon as possible.
2. The existence of the current code precludes its own fix or the fix of an equally
important issue.

Shortening the deprecation period should be done with caution to avoid giving D
an image of instability.

At the time of the pull request for deprecation, all code in Phobos, Druntime,
and DMD must be updated to remove use of the effected code. Any projects that
are tested on the Project Tester that are broken should also have their
maintainers notified.

Both at the time of deprecation and removal, a changelog entry must be made. This
changelog entry should have a short motivation for the deprecation (or removal)
and should describe which steps can be taken by the user to upgrade their codebase.

In order to facilitate on schedule deprecations, a comment of the format
`@@@DEPRECATED_[version]@@@` should be added to the top of the code to be removed/disabled.
This comment allows code to be easily searched before every release to
catch all planned deprecations.

### Public Functions, Types, and Modules

All removals (or changes that make the code `private`/`package`) of public functions,
types, and modules must be accompanied with a deprecation period.

The symbol(s) must be marked using the `deprecated` keyword with a message containing
the planned removal period. A pointer to more information should also be added. E.g.
"See the 2.080 changelog for more details" or "See the function documentation for more
details". The documentation of the symbol(s) must be updated noting the
deprecation and removal plan. The documentation should contain information to help
the users using the symbol(s) transition their code away from the symbol(s).

If the deprecation is occuring because the symbol(s) are being replaced by new
symbols, both the old and the new symbol(s) should be availible un-deprecated
in at least one release to allow users to build their code without issue on
both the `stable` and `master` branches.

On the first release in the deprecation period, the removed symbol(s) should
be removed from any module or package wide list of public functions/booktables/cheatsheets
to demphize its use. On the fifth release in the deprecation period, the documentation
for the symbol should be removed completely while keeping the code itself public until
complete removal.

If there is no equivalent for the functionality of the removed symbol in the
standard library or the runtime, the code should be moved to
[undeaD](https://github.com/dlang/undeaD) to allow users to keep their current
code if refactoring is not possible.

### Language Features

Unless the removed language feature is very unsafe or causes damage to real
world systems, all changes or removals must be accompanied with a deprecation
period. "Language features" includes bugs in the current behavior that existing
user code depends on, e.g. [Issue 10378](https://issues.dlang.org/show_bug.cgi?id=10378).
Fixing such issues should include a deprecation period for the current behavior,
and an introduction of the new behavior as the default only at the end of the
period.

Deprecations to language features must also update the [language deprecations
page](https://dlang.org/deprecate.html) on dlang.org simultaneously. The deprecation
message given by the compiler should contain the planned removal period and/or a
pointer to more information pertaining to the deprecation.

Warnings must NOT be used in the deprecation process. Warnings are set as errors
in many build systems (including DUB), and would therefore prematurely break many
user's code. The exception is when the deprecation is for a change which turns 
something into a warning. In this case the code which would trigger the warning must
also first go through a deprecation period.

## Copyright & License

Copyright (c) 2018 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## Reviews

The DIP Manager will supplement this section with a summary of each review stage
of the DIP process beyond the Draft Review.
