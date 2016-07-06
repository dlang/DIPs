# D Improvement Proposals (DIPs)

[List of submitted DIPs](https://github.com/dlang/DIPs/blob/master/DIPs/README.md)

[List of old DIPs approved before this repo existed](https://github.com/dlang/DIPs/blob/master/DIPs/archive/README.md)

## Purpose

This repository exists for storing and managing proposals that may affect
D programming language greatly. Common examples would be changing existing
language semantics, adding new major features to compiler, enforcing new
process as a standard. In general, any controversial change that must be
approved by language authors and community feedback must be managed as a DIP.

## Procedure

### Submitting new D Improvement proposal

1. Write a document for new improvement proposal based on
   [the template](https://github.com/dlang/DIPs/blob/master/Template.md). All
   sections mentiond in the template are important - for example, change
   implying breaking changes has almost no chance to be accepted if it doesn't
   describe in great details migration path to mitigate it.

2. Create new pull request against this repository adding new document to
   `DIPs` folder picking up next spare ID (>= 1000). DIP manager will provide
   feedback about what information needs to be added for DIP to be of expected
   quality. DIP document must be named "DIP<id>.md".

3. Announce creation of new DIP in official
   [D newsgroup](https://forum.dlang.org) for community feedback. This will
   allow to evaluate proposal strong and weak points before it gets to language
   author attention.

3. Once DIP manager considers proposal has all necessary details and is ready
   for evaluation by language authors, pull request gets merged with DIP
   being in `Draft` status. DIP pull request should not be merged faster than
   one month from newsgrouo announcement to ensure everyone had a chance to
   comment on it.

### Getting DIP approved

1. Once in a few months DIP manager has to pick one DIP from those
   that are currently in `Draft` status. Proposal with more detailed
   descriptions and/or proof of concept implementation should have more
   priority.
2. The DIP is brought to the language authors for review. DIP manager
   responsibility is to gather and provide any information about the proposal
   at their request. After each round of review DIP manager must publish
   its short summary and outcome in the mail list.
3. Review should result in DIP either being moved to `Approved` status or
   modified with list of issues that need to be worked on before final
   decision can be made. In case DIP topic seems important but language
   authors decide it needs more research, new topic in dlang-study@puremagic.com
   mail list may be initiated.

### Collaborating on DIPs

1. Anyone can submit new pull requests with updates to merged DIP document as
   long as original author gets notified about it.

2. On point discussion regarding DIP text is welcome in pul requests - everyone
   is welcome to participate in the review.

3. If there are many uncertainities about the proposal, consider first publishing
   document somewhere else and dicussing it via forum or e-mails. That will
   greatly reduce amount of back-and-forth changes in DIP pull request later.

## DIPs by language authors

Languages changes initiated by language authors are also supposed to go thorugh
DIP queue but those are processed slightly differently and with a different
purpose. By their very nature formal approval is not needed and instead
increased focus is put into bringing community attention and feedback.

## Role of DIP manager

Idea behind the role of DIP manager is to have a person who will do minimal
initial research and quality control saving time for language authors to
focus on actual decision.  That implies gathering information, maintaining
this repository and communicating to involved parties so that process keeps
moving forward. Essentially DIP manager is supposed to act as proxy between
D users and language authors to allow handling the growing scale of DIP information
reliably.
