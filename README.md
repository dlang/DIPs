# D Improvement Proposals (DIPs)

[List of submitted DIPs](https://github.com/dlang/DIPs/blob/master/DIPs/README.md)

[List of old DIPs approved before this repo existed](https://github.com/dlang/DIPs/blob/master/DIPs/archive/README.md)

## Purpose

This repository stores and manages improvement proposals for the D programming
language. Common examples include the change of existing language semantics,
addition of new major features to compiler or enforcement of new process as a
standard. In general, any controversial change must be managed as a DIP and
thus requires approval by the language authors and feedback from the D
community.

## Procedure

### Submitting new D Improvement proposal

1. Write a document for new improvement proposal based on
   [the template](https://github.com/dlang/DIPs/blob/master/Template.md).
   All sections mentioned in the template are important - for example, a change
   implying breaking changes has almost no chance to be accepted if it
   doesn't describe a migration path to mitigate breakage in great details.
   Please put great care in drafting the proposal - the proposal needs to
   convince the language authors and D community of the added value through the change.

2. Create a new pull request against this repository by adding a new document to
   the `DIPs` folder picking up the next spare ID (>= 1000). The DIP manager will
   provide feedback about what information needs to be added for DIP to be of expected
   quality. The DIP document must be named "DIP<id>.md".

3. After initial feedback has been addressed, the DIP manager will announce the new DIP
   in the official [D newsgroup](http://forum.dlang.org/group/announce) for community feedback.
   This will allow to evaluate strong and weak points of the proposal before it gets to
   the language author's attention.

3. Once a proposal has all necessary details and the DIP manager considers it
   to be ready for evaluation by language authors, the pull request gets merged
   with the DIP status being `Draft`. A DIP pull request should not be merged
   faster than one month from newsgroup announcement to ensure everyone had a
   chance to comment on it.

### Getting DIP approved

1. Once in a few months the DIP manager has to pick one DIP from those
   that are currently in `Draft` status. Proposals with more detailed
   descriptions and/or proof of concept implementation should have a higher
   priority.
2. The DIP is brought to the language authors for review. The DIP manager's
   responsibility is to gather and provide information about the proposal
   at their request. After each round of review the DIP manager must publish
   its short summary and outcome to the mailing list.
3. Review should result in the DIP either being moved to `Approved` status or
   modified with a list of issues that need to be worked on before a final
   decision can be made. In case the DIP topic seems important but language
   authors decide it needs more research, a new topic on the
   [Dlang-study](http://lists.puremagic.com/cgi-bin/mailman/listinfo/dlang-study)
   mailing list may be initiated.

### Collaborating on DIPs

1. Anyone can submit new pull requests with updates to merged DIP document as
   long as original author gets notified about it.

2. Discussion regarding the DIP's text is welcome in pull requests - everyone
   is welcome to participate in the review.

3. If there are many uncertainties about the proposal, consider first publishing
   document somewhere else and discussing it via the [NG](http://forum.dlang.org/group/general)
   or e-mails. That will greatly reduce amount of back-and-forth changes in the
   DIP pull request later.

## Advices for writing great DIPs

Writing good informative DIP with solid chances to get approved is very
hard work - it is often underestimated how much effort is expected to be put
into writing one.

1. Focus on answering "why" question as much as explain "what". At this stage
   of language development a change has to bring a great value and any doubt
   will be likely be treated in favor of rejecting.

2. Be very pedantic and formal in describing required language/compiler
   changes. For example, make separate sections for grammar changes, semantic
   changes, expected compiler error messages and so on. DIP should provide
   a detailed design documentation for compile developer willing to implement
   it.

3. Research any alternative approaches to solving same problem and explain
   your choice. If there are any relevant success or failure stories in
   other programming languages, consider referring to them with explanation
   of how it applies to D.

4. Showing example of real-world project that could benefit from the
   improvement can greatly improve its chances to be accepted. D is intended
   to be a practical language and one of recurring questions when new
   changes are considered is "does it really make real projects better?". If
   that is not possible, try designing code examples with intention to answer
   the very same question.

5. Be prepared for a lot of work. There are always many ideas proposed but
   much less developers commited to pursuing the idea to final stages of
   evaluation. DIP system is _not_ for submitting ideas but for formal approval
   of language changes.

## DIPs by the D language authors

Language changes initiated by language authors are also supposed to go through
the DIP queue. By their very nature formal approval is not needed.
Hence they are processed slightly different and an
increased focus is put into bringing community attention and feedback.

At the time of writing this document only Walter Bright and Andrei Alexandrescu
are meant as a language authors here.

## The DIP manager responsibilities

The idea behind the role of the DIP manager is to have a person who will do
minimal initial research and quality control saving time for language authors
to focus on actual decision.  That implies gathering information, maintaining
this repository and communicating to involved parties so that process keeps
moving forward. Essentially the DIP manager is supposed to act as proxy between
D users and the language authors to allow handling the growing scale of DIP
information reliably.
