# D Improvement Proposals (DIPs)

[List of submitted DIPs](https://github.com/dlang/DIPs/blob/master/DIPs/README.md)

[List of old DIPs approved before this repo existed](https://github.com/dlang/DIPs/blob/master/DIPs/archive/README.md)

## Purpose

This repository stores and manages improvement proposals for the D programming
language. Common examples include a change to existing language semantics,
the addition of a new major features to the compiler or enforcement of new process as a
standard. In general, any controversial change must be managed as a DIP and
thus requires approval by the language authors and feedback from the D
community.

## Procedure

### Submitting a new D Improvement proposal

1. Write a document for the new improvement proposal based on
   [the template](https://github.com/dlang/DIPs/blob/master/Template.md).
   All sections mentioned in the template are important - for example, a change
   implying breaking changes has almost no chance to be accepted if it
   doesn't describe a migration path to mitigate breakage.

2. Create a new pull request against this repository by adding a new document to
   the `DIPs` folder, using any spare ID (>= 1000). The DIP manager will
   provide feedback about what information needs to be added for the DIP to reach
   the required quality for further consideration.

   The DIP document must be named "DIP\<id\>.md". The exact DIP ID used at pull
   request stage is not important because during merging the DIP manager will
   replace it with the next currently available ID among the merged proposals,
   which will become the "real" ID for the DIP in future.

   The pull request title should match the DIP title.

3. After any initial feedback has been addressed, the DIP manager will announce the new DIP
   in the official [D newsgroup](http://forum.dlang.org/group/announce) for community feedback.
   This will help evaluate stronger and weaker points of the proposal before it gets to
   the language author's attention.

3. Once a proposal includes all necessary details and the DIP manager considers it
   to be ready for evaluation by the language authors, the pull request gets merged
   with the DIP status being `Draft`. A DIP pull request should not be scheduled for
   formal review earlier than one month after the newsgroup announcement to ensure
   everyone has a chance to comment on it.

### Migrating an old DIP

Many [DIPs][old-repo] were created before this repo existed.
If you are interested in adopting such a drafted DIP, [`dwikiquery`][dwikiquery]
can help with the conversion from the [DWiki][old-dips].

[dwikiquery]: https://github.com/dlang/DIPs/tree/master/tools/dwikiquery
[old-dips]: https://wiki.dlang.org/DIPs

### Getting a DIP approved

1. Once every few months the DIP manager has to pick one DIP from those
   that currently have `Draft` status. Proposals with more detailed
   descriptions and/or proof of concept implementations should have a higher
   priority.
2. The DIP is brought to the language authors for review. The DIP manager's
   responsibility is to gather and provide information about the proposal
   at their request. After each round of review the DIP manager must publish
   to the mailing list the outcome of the review along with a small summary.
3. Review should result in the DIP either being moved to `Approved` status or
   modified with a list of issues that need to be worked on before a final
   decision can be made. In the latter case such DIP may be marked with
   "Information Requested" status for ease of sorting. In case the DIP topic
   seems important but language authors decide it needs more research, a new topic on the
   [Dlang-study](http://lists.puremagic.com/cgi-bin/mailman/listinfo/dlang-study)
   mailing list may be initiated.
4. Distinction between `Approved` and `Pending Implementation` status is that
   for former just the concept itself got approval while the latter means DIP
   document can act as a final specification for implementing it upstream.
   Usually DIP that is only `Approved` will have remarks regarding what needs
   to be cleaned up in spec before it can be finalized.
5. If DIP was rejected during the formal review, it can't be ressurrected
   again. New DIP on similar topic may be submitted but it must be feature
   different solution.

### Collaborating on DIPs

1. Anyone can submit new pull requests with updates to merged DIP document as
   long as the original author is notified.

2. Discussion regarding the DIP's content is welcome in pull requests - everyone
   is welcome to participate in the review.

3. If there are many uncertainties about the proposal, consider first publishing
   document somewhere else and discussing it via the [NG](http://forum.dlang.org/group/general)
   or e-mails. That will greatly reduce the number of back-and-forth changes in the
   DIP pull request later.

## Advice for writing great DIPs

There is a dedicated
[document](https://github.com/dlang/DIPs/blob/master/GUIDELINES.md) with
explanations of expected DIP content and overall writing advices. Ignoring it
makes chance of DIP approval very low.

## DIPs by the D language authors

Language changes initiated by language authors are also supposed to go through
the DIP queue. By their very nature formal approval is not needed.
Hence they are processed slightly different and an
increased focus is put into bringing community attention and feedback.

At the time of writing this document only Walter Bright and Andrei Alexandrescu
are meant as a language authors here.

## The DIP manager responsibilities

The idea behind the role of the DIP manager is to have a person who will do some
minimal initial research and quality control, saving time for language authors
to focus on the actual decision. That implies gathering information, maintaining
this repository and communicating to involved parties so that the process keeps
moving forward. Essentially the DIP manager is supposed to act as a proxy between
D users and the language authors to help handling the growing scale of DIP
information reliably and effectively.
