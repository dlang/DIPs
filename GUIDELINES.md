# DIP writing guidelines

## Expected content

Writing a good informative DIP with solid chances to get approved is very
hard work - it is often underestimated how much effort is required. Good
improvement proposals should:

1. Motivate, explain and demonstrate the value gained from implementing
   the change. Alternative solutions must be considered and compared.
2. Use real-world examples, either taken from existing projects, or looking
   like ones.
3. Consider possible objections against the proposal and research them
   as part of DIP document.
4. Stick to formal and technical language in general, avoid colloquialisms. A
   DIP should be formulated like a scientific paper, as opposed to an op-ed
   article.
5. Provide sufficient technical details that can be used as a specification
   by D compiler developers.

Be prepared for a lot of work. There are always many ideas proposed but
far fewer developers committed to pursuing the idea to the final stages of
evaluation. The DIP system is _not_ for submitting undeveloped ideas, it is
a process for formal approval of language changes.

The remainder of this document provides more detailed explanation of requirements.

## Motivation

Any DIP must focus on "why" at least as much as "what" and often even more.
At this stage of the D language development changes need to justify their
existence with great value. Doubt about the necessity or value of a
change will be a strong motivator for rejection.

It is important to research any alternative approaches to solving the same
problem and explain why the proposed choice is superior. If there are any
relevant success or failure stories in other programming languages,
consider referring to them with explanation of how they might apply to D.

Redundancy of existing features should not be used as precedent and
justification for adding another redundant feature. In a similar way, an
existing language flaw cannot be used as an excuse for adding more
functionality with a similar flaw.

It is important to evaluate costs of adding something the language. Something
that uses existing syntax and builds upon established semantics is considered
of much less weight than a proposal requiring completely new syntax or
concept.

## Examples

The motivation section should showcase examples that currently are not
possible or are contorted in D, followed by their alternative implementation
using the proposed feature. At best, the example would be taken from existing
code (e.g. found in dub, Phobos, etc). Next best is code that defines a
plausible artifact.

Keep in mind that without such examples to back it, any reasoning in favor of
proposed feature may be completely discarded. This is also why examples from
existing code are preferred - D is a practical language and even a theoretically
sound proposal is not important enough if it doesn't offer any substantial
improvements to code that actually gets written.

When possible, provide same example snippet implemented with both the current
definition of the D language and using proposed functionality to show the
improvement in a most obvious way.

## Technical details

Anyone attempting to propose a language change is expected to be sufficiently
knowledgeable in existing semantics that are affected by the proposal, as
well as compiler technology, to provide formal explanation of required changes.

That doesn't mean that a DIP author has to submit actual compiler patches. But
specification should be formal and detailed enough so that independent compiler
authors can rely on it to implement the feature in compliant way - it must not
leave any room for the interpretation.

For example, any change that requires adjusting language grammar must include
description of the change in the same format as [existing grammar
spec](https://dlang.org/spec/grammar.html).

## Breaking changes

It is crucial for any proposed change to list all possible concerns regarding
breakage of existing D code caused by the change. Even if chance of breakage
seems very low, it needs to be listed anyway.

If code breakage is likely to affect at least a few existing projects, the
proposal must include description of intended deprecation process for solving
the problem. No language
no transitional step.

DIP authors must not judge quality of existing project code and dismiss
potential breakage issues based on such opinion.
