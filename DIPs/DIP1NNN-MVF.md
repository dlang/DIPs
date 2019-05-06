# Transition D to a `@safe`-by-default Language

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | (number/id -- assigned by DIP Manager)                          |
| Review Count:   | 0 (edited by DIP Manager)                                       |
| Author:         | Michael V. Franklin (slavo5150@yahoo.com)                       |
| Implementation: | TBA                                                             |
| Status:         |                                                                 |

## Abstract

This DIP proposes a plan to transition D to a language that produces `@safe` code by default, no longer requiring the user to opt in to `@safe` code by decorating their code with attributes.  To provide as graceful of a transition as possible, the user will be able to opt out of the `@safe`-by-default behavior by utilizing the existing `@system` and `@trusted` attributes, or through the use of a new compiler flag, `-revert=safeByDefault`.  In addition, a new `version` identifier, `D_SystemByDefault`, will be introduced to allow users to detect whether or not the compiler was invoked with the aforementioned compiler flag and, utilizing D's existing design by introspection features, provide accomodation in their code for both the `@safe`-by-default behavior, the existing `@system`-by-default behavior, or even enforce that one or the other be used to compile their code.

The transition to `@safe`-by-default will take about 2 years, with an additional 2 years to fully deprecate and remove any transition features introduced in the process.  The exiting `@system`-by-default behavior will remain available through the use of a compiler flag indefinitely or until such time in the future that the community feels comfortable deprecating and removing it.  In other words, this is an addition-only change. The existing behavior is not being deprecated or removed, it's just being placed behind a compiler flag shifting the burden off of those wishing to have `@safe` code, and on to those opting out of `@safe` code, as it should be.

## Contents
* [Rationale](#rationale)
* [Description](#description)
* [Breaking Changes and Deprecations](#breaking-changes-and-deprecations)
* [Reference](#reference)
* [Copyright & License](#copyright--license)
* [Reviews](#reviews)

## Rationale

At a recent security conference, a Microsoft engineer revealed that approximately 70% of security vulnerabilities in Microsoft products are due to memory safety bugs[2].

As more and more devices become connected to the Internet and other networks, the severity of memory safety exploits increases significantly.  In October of 2016 malicious actors exploited seemingly innoculous devices from printers to baby monitors to perform a distributed denial of service attack on DNS provider Dyn[5].

At the "Trends in Systems Programming" panel at DConf 2017, Walter Bright had this to say[1]:

> I strongly feel that [memory safety] is a coming tsunami in programming languages and we better be ready for it. [...] It's a major issue and I want to be there when the tsunami falls on the beach. [...] It's me looking a couple years ahead, reading the tech news about the kinds of problems people are having and looking "how can we get ahead of this?" so that we're ready when people are going to demand it.  I firmly believe that memory safety will be an absolute requirement moving forward, very soon, for programming language selection. [...] I believe memory safety will kill C.  People are tired of those expensive disasters they have when they have memory corruption bugs,  and malware gets in, and wrecks their system and destroys their customer trust and their products, and they're just not going to put up with it anymore.

With such a strong statement advocating for memory-safety, and trends confirming Walter's prediction, it is alarming that **D is currently NOT memory-safe by default**.

The software development field has been aware of memory-safety issues for decades which has contributed to the rise of more modern general-purpose programming languages (e.g. Go, Rust, C#/VB.Net, Swift, Java) that are memory-safe out-of-the-box.  Those languages require users to employ special techniques to opt out of memory-safety; doing nothing is, efectively, opting in to memory safety.  D, on the other hand, is in the minority in this class of programming languages as **D is currently NOT memory-safe out-of-the-box** and requires users to opt into memory safety using the `@safe` attrbute; doing nothing is, effectively, opting out of memory safety.

As a consequence of the [Default Effect](https://en.wikipedia.org/wiki/Default_effect)[3], quoted below, users may perceive D as an unsafe language if `@safe` is not the default.

> Defaults might affect the meaning of choice options and thus agents' choices over them. For example, it has been shown that under an opt-in policy in organ donation choosing not to become an organ donor is perceived as a choice of little moral failing. Under an opt-out policy, in contrast, choosing not to be an organ donor is perceived as morally more deficient. These differences in evaluation might affect the rational choice over these options.

In the experience report below[4], the effect described above currently backfires on D.  Upon learning D is not `@safe`-by-default, potential D users, rather than questioning their own values as being deficient, perceive D as being deficient.

> At work I've recently changed to a position in which I have more leverage to influence which language certain key parts of our product are written in. Currently that's primarily Java, with a collection of small services written in Go. If I had my way, it'd all be rewritten in D, but I need to convince the other members of my team that it's feasible to use D (as an aside, GC was actually a big plus for them - I work in cybersecurity, so memory safety is a core requirement for most parts of our product. Memory safety *without* a GC would be even better, as there are security concerns around data lifetime with a GC, but baby steps).
>
> The first question I was asked was "is it memory safe by default?", to which the answer was painfully "no, only in code annotated with @safe". The inevitable follow-up is "so you have to mark every function with @safe?!"... not a great showing for D in that respect.
>
> It's not a deal-breaker, but it already puts D on an uneven footing in regards to Go and Rust, which both claim full memory safety by default.

Transitioning D to a `@safe`-by-default language will demonstrate that D is serious about memory-safety, and is making strides to encourage its proliferation.

### Advantages
  * D users wanting more robustness and reliability from their programming language will no longer be subject the inconvenience, no matter how small, of opting in to memory safety; D will be memory-safe out of the box.
  * D will be able to market itself honestly and confidently as a memory-safe language without requiring any addendums equivalent to "some assembly required".
  * D will be in a better position to compete with other languages that are memory-safe out of the box, and be better prepared for the future as trends turn toward demandng memory safety from software.
  * Users will have more of a reason to use D over other languages, both memory-safe and memory-unsafe, and more ammunition to advocate for its continued adoption.
  * The transition to `@safe`-by-default will provide multiple marketing opportunities to get the word out about D and the benefits of its memory safety features.

## Description

This DIP proposes a very simple path forward that will not introduce any breaking changes if users utilize the transition features being proposed.  Within 2 years, starting from the approval of this DIP, D will be `@safe`-by-default.  Existing users, with the flip of a compiler switch, will be able to maintain existing behavior and avoid any breaking changes.  Using the proposed new `version` identifier, `D_SystemByDefault`, users will be able to precisely manage the transition in their code with the full power of D's exceptional meta-programming facilities.

### Stage 1: Epoch minus 2 years: Raising Awareness
The approval announcement of this DIP will serve as the official announcement, and the beginning of the transition, marking **Epoch minus 2 years**.

Upon approval of this DIP, a new page will be created at [dlang.org](http://dlang.org) detailing the transition plan, schedule, milestones and any additional information to help users understand when the transition will occur, how it will affect them, and how they can transition with D.  It will be updated and maintained as the transition progresses.

The [dlang.org home page](http://dlang.org) and [dlang.org download page](https://dlang.org/download.html) will feature a prominent notice informing users of the transition, with a link to the aforementioned page describing the transition.  The [dlang.org calendar](https://dlang.org/calendar.html) will be updated with any important milestones, and will be updated and maintained as the transition progresses.

Additional announcements can also be made through [The D Blog](https://dlang.org/blog/), reddit, Hackker News, and potentially other social media to reach as broad an audience as possible.  This will also serve to raise greater interest in D.

This stage will help users understand what to expect and give them a full year to plan how they wish to transition with D, ask questions, and raise any potential issues before anything happens.

### Stage 2: Epoch minus 1 year: Introduction of Compiler Flags

DMD will be updated with 2 compiler flags, `-transition=safeByDefault` and `-revert=safeByDefault`.

  * Invoking the compiler with `-transition=safeByDefault` will cause the compiler to produce code that is `@safe`-by-default.
  * Invoking the compiler with `-revert=safeByDefault` will cause the compiler to produce code that is `@system`-by-default, maintaining the status quo.
  * Invoking the compiler with neither flag will cause the compiler to produce code that is `@system`-by-default while emitting a deprecation warning message informing users of the upcoming transition, where to find more information, and how to silence the warning message by invoking the compiler with either `-transition=safeByDefault` or `-revert=safeByDefault`.  Users are welcome to tolerate the warning message until **Epoch**, at which time the warning message will no longer appear.
  * If the compiler is invoked with both `-transtion=safeByDefault` and `-revert=safeByDefault`, the one specified latest on the command line with take precedence.  This is to allow users to specify a global preference, but then override it on a per-project or per-file basis.
  * Templates without an explicit `@safe`, `@trusted`, or `@system` attribute will remain agnostic, inferring their attributes from the site of their insantiation, regardless of whether the compiler was invoked with one of the aforementioned compiler flag or not, maintaining the status quo.

DMD will also be updated with a new `version` identifier `D_SystemByDefault` that will be set to `true` any time the compiler is invoked with `-revert=safeByDefault` or neither flag.  Utilizing D's fantastic design by introspection features, users will be able to use `D_SystemByDefault` in their code to futher manage the transition with greater detail and greater precision, as illustrated below.

```D
// Ensuring a module is only compilable with a `@safe`-by-default compiler
module myModule;

version (D_SystemByDefault)
{
    static assert(false, "This module should only be compiled with a `@safe`-by-default compiler.  Use `-transtion=safeByDefault`");
}

// Module implementation
```

```D
// Ensuring a module is only compilable with a `@system`-by-default compiler
module myModule;

version (D_SystemByDefault) { } else
{
    static assert(false, "This module should only be compiled with a `@system`-by-default compiler.  Use `-revert=safeByDefault`");
}

// Module implementation
```

A changelog entry detailing said features will accompany the release in which they appear.

### Stage 3: Epoc - D Becomes `@safe`-by-Default Programming Language

DMD will be updated to be a `@safe`-by-default compiler.
  * Invoking the compiler with neither the `-transition=safeByDefault` flag nor the `-revert=safeByDefault` flag will cause the compiler to produce code that is `@safe`-by-default.  The deprecation warning message added in Stage 2 will be removed.
  * Invoking the compiler with `-transtion=safeByDefault` have no effect on code, but will emit a deprecation warning stating that the `-trasition=safeByDefault` flag is no longer needed and should no longer be used.
  * Invoking the compiler with `-revert=safeByDefault` will cause the compiler to produce `@system` code by default, allowing the user to opt out of the new `@safe`-by-default behavior, and revert to the old behavior.
  * Templates without an explicit `@safe`, `@trusted`, or `@system` attribute will remain agnostic, inferring their attributes from the site of their insantiation, regardless of whether the compiler was invoked with a `-transition` or `-revert` flag or not, maintaining the status quo.

A changelog entry detailing these changes will accompany the release in which they appear.

### Stage 4: Epoc plus 1 year: Invalidate `-transition=safeByDefault` Flag

DMD will be updated to produce an error if the compiler is invoked with the `-transition=safeByDefault` flag stating that the flag is no longer needed and should not be used.  The `-revert=safeByDefault` flag will remain unchanged.

### Stage 5: Epoc plus 2 years: Remove Transition Features

The `-transition=safeByDefault` compiler flag will be removed.  The compiler will emit a standard unrecognized flag error any time it is used.  The `-revert=safeByDefault` flag will remain unchanged.

### (Optional) - Deprecate `@system`-by-Default Features

Any time after **Epoc** the compiler can be updated to deprecate and eventually remove the `-revert=safeByDefault` compiler flag, the `D_SystemByDefault` version identifier, and the `@system`-by-default behavior.  However, that is out of scope for this DIP.  They can be deprecated and removed quickly using D's normal deprecation process, maintained indefinitely, or anything in between at the discretion of the language authors.

### Scope

This DIP will only address the `@safe` attribute.  Unlike the other classes of attributes (e.g. purity, mutability, and throwability), D already has everything it needs to negate the `@safe` attribute or override the compiler's safety constraints through the user of the `@system` and `@trusted` attributes respectively.  Therefore, no new language features or modifications are being proposed.

## Breaking Changes and Deprecations

If users utilize the new compiler features proposed in this DIP, no breaking changes should occur.

## Reference

[1] - [Walter Bright on Memory Safety at DConf 2017](https://youtu.be/Lo6Q2vB9AAg?t=1414)
[2] - [Microsoft: 70 percent of all security bugs are memory safety issues](https://www.zdnet.com/article/microsoft-70-percent-of-all-security-bugs-are-memory-safety-issues/)
[3] - [The Default Effect](https://en.wikipedia.org/wiki/Default_effect)
[4] - [D User's Experience Report](https://forum.dlang.org/post/deuzkvsasxspxsnvgtrb@forum.dlang.org)
[5] - [2016 Dyn Cyberattach](https://en.wikipedia.org/wiki/2016_Dyn_cyberattack)

## Copyright & License

Copyright (c) 2018 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## Reviews

The DIP Manager will supplement this section with a summary of each review stage
of the DIP process beyond the Draft Review.
