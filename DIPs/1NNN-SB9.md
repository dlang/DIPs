# Print stack backtrace only when required

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | (number/id -- assigned by DIP Manager)                          |
| Review Count:   | 0 (edited by DIP Manager)                                       |
| Author:         | strawberry9 hotdigedydog@gmail.com                              |
| Implementation: | (links to implementation PR if any)                             |
| Status:         | Draft (possibly this should be an enhancement request instead?? |

## Abstract

Currently a compiled program will print a stack backtrace by default, as part of an
error message. However, backtracing information is only relevant for debugging purposes.
To end-users it just represents confusing noise. This proposal seeks to add built-in
support for printing the backtrace output only 'when it is required', rather
than it being printed by default.


## Contents
* [Rationale](#rationale)
* [Prior Work](#prior-work)
* [Description](#description)
* [Breaking Changes and Deprecations](#breaking-changes-and-deprecations)
* [Reference](#reference)
* [Copyright & License](#copyright--license)
* [Reviews](#reviews)

## Rationale
As per the abstract: Currently a compiled program will print a stack backtrace by default,
as part of an error message. However, backtracing information is only relevant for
debugging purposes. To end-users it just represents confusing noise. This proposal seeks
to add built-in support for printing the backtrace output only 'when it is required',
rather than it being printed by default.

## Prior Work
No prior work is to be found.

## Description
The base class of all thrown objects is defined in druntime\src\object.d
class Throwable : Object { .. }

A 'toString' overload within this class is the responsible entity for printing the 
stack backtrace. The specific code is:

        if (info)
        {
            try
            {
                sink("\n----------------");
                foreach (t; info)
                {
                    sink("\n"); sink(t);
                }
            }
            catch (Throwable)
            {
                // ignore more errors
            }
        }
        
By replacing the code above, with the code below, the user can decide when the
backtrace is printed, by simply setting an environmental variable as such:

DLANG_BACKTRACE=1

The code below will determine from that variable whether or not to print the backtrace.

        /**
         * A new evironment variable (if set by a user) is used to determine when to print
         * the stack backtrace. If the variable exists, and it's value is set to 1, then the
         * backtrace is printed. If the variable 'does not' exist, or if it 'does exist' but
         * it's value is set to anything other than 1, then 'the default' is to not print the
         * backtrace itself, but instead print a message on how to view the backtrace.
         * NOTE: This changes previous behaviour of always printing the backtrace.
         */
        import core.stdc.stdlib : getenv;
        import core.stdc.string : strcmp;
        char *btOp = getenv("DLANG_BACKTRACE");
        if (btOp != null)
        {
            if(strcmp(btOp,"1") == 0)
            {
                if (info)
                {
                    try
                    {
                        sink("\n----------------");
                        foreach (t; info)
                        {
                            sink("\n"); sink(t);
                        }
                    }
                    catch (Throwable)
                    {
                        // ignore more errors
                    }
                }
            }
            else
            {
                sink("\n----------------\nTo see stack trace, set environment variable: DLANG_BACKTRACE=1\n");
            }
        }
        else
        {
            sink("\n----------------\nTo see stack trace, set environment variable: DLANG_BACKTRACE=1\n");
        }

## Breaking Changes and Deprecations
As noted in the comments within the code above, this could be considered a breaking
change, in that anyone currently relying on the backtrace to be output 'by default',
will now have to manually set the following environment variable: DLANG_BACKTRACE=1

However, those who actually use the stack backtrace output, are highly likely
to already have sufficient knowledge and expertise to easily adjust to this change.

It is not expected that this would be a breaking change to any code.

## Reference
This is similar to what Rust do, where they require that you set RUST_BACKTRACE=1
to get the stack backtrace.

https://rustc-dev-guide.rust-lang.org/compiler-debugging.html

## Copyright & License
Copyright (c) 2020 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## Reviews
The DIP Manager will supplement this section with a summary of each review stage
of the DIP process beyond the Draft Review.
