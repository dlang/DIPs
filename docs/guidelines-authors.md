# DIP Author Guidelines

Thank you for deciding to write a D Improvement Proposal (DIP). Your time and effort in enhancing the D programming language are greatly appreciated. This document aims to guide you through the process of creating a clear, concise, and understandable proposal.

## General Advice

When drafting your initial DIP, allow your thoughts to flow freely. You can refine the language, add examples, and fill in gaps through subsequent revisions.

Before submission, the DIP manager will ensure your proposal adheres to these guidelines:

1. Clearly motivate the proposal, explaining its value and comparing it with alternative solutions.
2. Incorporate real-world examples, preferably from specific projects.
3. Anticipate and address potential objections with thorough research.
4. Use formal and technical language, avoiding colloquialisms. A DIP is a technical document, not an opinion piece or blog post.
5. Provide detailed technical information for D compiler developers to use as a specification.

## Proper Motivation

A DIP must justify its existence by focusing on the "why" as much as the "what". Unnecessary or valueless language changes are likely to be rejected.

Research alternative solutions, explaining why your proposal is superior. Refer to successes or failures in other languages and how they relate to D.

Avoid using redundancy in existing features or language flaws as justification for similar additions.

Consider the cost of adding, changing, or removing features. Changes that build on existing syntax and semantics are less costly than those requiring new concepts. Costlier proposals should offer significant benefits.

Steer clear of speculation. Unless you are an expert, avoid claims about increased popularity or adoption. Personal or anecdotal evidence should be supported by data or solid reasoning.

## Demonstrative Examples

Include examples in the Rationale section showing situations that are currently impossible, overly complex, or verbose in D. Preferably use real code examples (e.g., from DUB, Phobos).

Without such examples, a theoretically sound proposal might be disregarded. Practical improvements to real-world code are essential.

An accompanying implementation allows reviewers to test the examples, verifying their functionality.

## Potential Objections

Addressing potential objections strengthens your proposal. If you foresee objections but cannot counter them, or you ignore them completely, the chance of acceptance is decreased.

Consider your proposal from all angles and perspectives, including those of potential opposition.

## Formal and Technical Language

A DIP is a formal specification for language features, intended for a technical audience.

During development, it is acceptable to prioritize clarity and factual accuracy over formality:

1. Aim for clear, concise, precise, and factual text.
2. Remove unsupported personal opinions about the proposed feature.
3. Avoid ornate or flowery language.

The DIP manager will assist in formalizing the text before submission. The more effort you put into the language initially, the less revision will be needed.

## Technical Details

DIP authors should understand how the proposal affects existing features and how it can be implemented. If you lack certain knowledge, research or seek expert help before submission.

List all potential issues, including any possible disruption to existing D code. Describe the intended deprecation process if significant code breakage is likely.

Cover as many details as possible in your proposal. While not expected to be experts in language design or compiler technology, authors should address community feedback comprehensively.

The final draft should be detailed enough for independent compiler authors to implement the feature without ambiguity. For example, changes to the language grammar must include a detailed description,  formatted as in the [existing grammar spec](https://dlang.org/spec/grammar.html).
