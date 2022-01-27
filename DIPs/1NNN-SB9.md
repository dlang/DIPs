# Printing stack backtrace only when required

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | (number/id -- assigned by DIP Manager)                          |
| Review Count:   | 0 (edited by DIP Manager)                                       |
| Author:         | strawberry9 hotdigedydog@gmail.com                              |
| Implementation: | (links to implementation PR if any)                             |
| Status:         | Will be set by the DIP manager (e.g. "Approved" or "Rejected")  |

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
A toString overload within this class is the responsible entity for printing the 
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
backtrace is printed, by simply setting an enviromental variable as such:

DLANG_BACKTRACE=1

The code below will determine from that variable whether or not to print the backtrace.

        import core.stdc.stdlib : getenv;
        import core.stdc.string : strcmp;

        /**
         * A new user-defined evironment variable is used to decide whether to print
         * the stack backtrace. If the variable exists and set to 1 then the backtrace
         * is printed. If that environment variable does not exist, or if it does exist
         * but it's value is set to anything other than 1, then the default is to not
         * print the backtrace.
         * NOTE: This changes previous behaviour of always printing the stack trace.
         */
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
        }

## Breaking Changes and Deprecations
As noted in the comments within the code above, this is a breaking change,
in that the stack backtrace will no longer get printed by default, but would now
require the user to set the environment variable, as defined above.

It is not expected that this would be a breaking change to any user code.

Althought it is a breaking change, those tasked with the role of using the
stack backtrace output, are likely to have sufficient knowledge and expertise
to easily adjust to this change.

## Reference
This is similar to what Rust do, where they require that you set RUST_BACKTRACE=1
to get the stack trace.

https://rustc-dev-guide.rust-lang.org/compiler-debugging.html

## Copyright & License
Copyright (c) 2020 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## Reviews
The DIP Manager will supplement this section with a summary of each review stage
of the DIP process beyond the Draft Review.
