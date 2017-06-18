# D Improvement Proposals (DIPs)

Questions about this document or the DIP process should be directed to the current DIP manager, Mike Parker (aldacron@gmail.com).

[List of submitted DIPs](https://github.com/dlang/DIPs/blob/master/DIPs/README.md)

[List of old DIPs approved before this repo existed](https://github.com/dlang/DIPs/blob/master/DIPs/archive/README.md)

## Purpose

This repository is for the storage and management of improvement proposals for the D programming language. A D Improvement Proposal (DIP) is a formal document that details a potential feature or enhancement to the language, or the official tooling, and the rationale behind it. 

Each DIP is steered through a process of review by the DIP manager. Each stage of the process is intended to prepare the DIP for its ultimate evaluation by the language authors (Walter Bright and Andrei Alexandrescu). Each stage of the process, from DIP submission to the final evaluation, is described in the following section.

## Procedure

### DIP Submission

DIP submission is open to one and all. Each submission should adhere to a few guidelines intended to make the process reasonably efficient for the DIP manager and the language authors. There are two steps a DIP author must take to initiate the review process.

1.  Write a document that outlines the proposal in the format specified by [the template](https://github.com/dlang/DIPs/blob/master/Template.md) provided in this repository. Not every section listed in the template may apply to a given DIP, but it is important that every applicable section is included. For example, a proposal implying breaking changes has almost no chance to be accepted if it fails to describe a migration path to mitigate breakage, but a proposal that carries no breaking changes can dispense with that section. The author may further subdivide the document as desired.

2.  Create a new pull request against this repository that adds a new document to the `DIPs` folder. The document must be named "DIP1xxx-(Author Initials).md". The "xxx" is a placeholder for a future ID that will be assigned by the DIP manager if and when the PR is merged into the repository. The pull request title should match the DIP title.

#### Advice for writing great DIPs

The document '[GUIDLINES.md](https://github.com/dlang/DIPs/blob/master/GUIDELINES.md)' provides advice on how to write a proper DIP. Ignoring it reduces the chance of a DIP being accepted into the repository.

#### Migrating an old DIP

Many [DIPs][old-dips] were created before this repository existed. If you are interested in resurrecting one of them, then [`dwikiquery`][dwikiquery] can help with the conversion from the [DWiki][old-dips] to the new format.

[dwikiquery]: https://github.com/dlang/DIPs/tree/master/tools/dwikiquery
[old-dips]: https://wiki.dlang.org/DIPs


### Review Process

The overarching goal of the entire review process is to ensure the language authors have all the information they need to properly evaluate a DIP once it is in their hands. Ideally, the language authors should be able to discuss and evaluate the merits of a DIP without the need to ask for further clarification from the DIP author.

The first stage of the review process begins as soon as a DIP author opens a pull request submitting the DIP to this repository. Subsequent stages are opened and closed at the discretion of the DIP manager. The stages of the review process are as follows.

1.  **Draft Review** 
    While a DIP is in the PR queue, it will be open to feedback from the community and the DIP manager. At this stage, the review is carried out in PR comments. Reviewers should aim to fill any obvious holes in the DIP and request more detail where it is warranted. This is not the place for debates or detailed discussions about the DIP or its merits. Comments should be restricted solely to improving the proposal's coverage. Editorial suggestions are also welcome. 
    
    The overarching goal of this stage is for the DIP to achieve a state that minimizes the number of review rounds in the next stage.
    
    There is no time limit on the Draft Review, no guarantees on the amount of time that may elapse between the submission of a DIP and its acceptance into the repository. Upon determining a DIP is not suitable for acceptance into the repository, the DIP manager is required to inform the author of the changes that must be made to make it acceptable. If the author does not apply the recommendations within a *reasonable* amount of time, the DIP manager may close the PR until the author, or someone else, decides to reopen it and work to move the DIP forward.

    At the end of this stage, the DIP will be pushed be merged into the repostitory and given the `Draft` status.

2. **Preliminary Review**   
   The overarching goal of the Preliminary Review is to prepare the DIP for the Formal Review. This stage may consist of multiple rounds. Multiple DIPs may be under preliminary review simultaneously.

   To launch a Preliminary Review, the DIP manager will mark the DIP with the `Preliminary Review Round N` state (where `N` is the current Preliminary Review round), announce the review in the Announce forum, and open a discussion thread in the General forum. All review-related discussion should take place in this thread. Reviewers at this stage should do their best to look deeper into the proposal to discover any flaws that were not caught in the Draft Review. The DIP author is expected to address all primary criticisms (not every comment a criticism inspires) with comments in the thread.

   It is appropriate at this stage to debate the merits of the DIP, to suggest alternatives, and to discuss any aspect of the DIP that warrants discussion. However, it is desirable keep the thread focused on the DIP itself. Any peripheral discussions should be carried out in a separate thread.

   The period of review will last approximately 15 days, or until the DIP manager declares the review period to be complete, whichever comes first. Under special circumstances, the review period may be extended by the DIP manager. Comments added to the thread after the close of the review period may be ignored. 
   
   When the review period has ended, the DIP manager will change the state of the DIP to `Post-Preliminary N` and will work with the DIP author to update the DIP to incorporate feedback received, where appropriate. The DIP author is the final arbiter of what is and is not appropriate. If the modifications are extensive, the DIP manager may schedule another Preliminary Review round. In extreme cases, the DIP may be closed and a new version submitted as a new DIP.

   Once the DIP manager and the author are satisfied that the DIP is reasonably complete, the DIP manager will update the state of the DIP to `Pre-Formal`.

3. **Formal Review**
    This is the stage where the DIP is presented to the language authors for evaluation and a final decision on its disposition. Only one DIP may be under Formal Review at a time. This stage consists of two steps.

    The Formal Review is initiated when the DIP manager changes the state of a DIP to `Formal Review`, announces the review in the Announce forum, and opens a discussion thread in the General forum. 
    
    The discussion thread is the first step. It is an opportunity for the community to provide any last minute feedback on the DIP. The feedback period will last for approximately 15 days. Participants should avoid debate on the merits of the DIP at in this thread, though it is acceptable to make their express their opinions known for the benefit of the language authors. The primary focus should be on finding flaws that were overlooked in the previous stages. 
    
    The DIP author is not required to address any feedback at this stage, nor is the author required to incorporate any feedback into the DIP at the end of the period. However, the DIP manager may decide to halt the Formal Review if any of the feedback is deemed critical enough (e.g. a serious issue is raised in how a proposed feature interacts with existing features) and take the appropriate actoin (such as asking the author to update the DIP or, in extreme cases, reverting to a new Preliminary Review round).
    
    At the end of the feedback period, the DIP will be closed to all furhter updates and the second step initiated. The DIP manager will submit the DIP to the language authors and await their decision. Once the decision is reached, the DIP will be marked `Accepted`, `Rejected`, or `Postponed`. The language authors may ask for the DIP to be revised or rewritten. In the latter case, the process will begin again from the Draft Review stage when the DIP author submits the rewritten version. The DIP manager will add a summary of the decision at the bottom of the document.

    When a DIP is `Accepted` by the language authors, the DIP manager will ask the DIP author to remove any aspects of the DIP that were rejected (e.g. if the DIP presents multiple options, only the accepted option will remain). This penultimate version of the DIP is intended represent the feature as it is to be implemented. The DIP manager will include a note about the rejected aspects in the summary at the bottom of the document.

    A `Rejected` DIP cannot be resurrected. A DIP that is similar may be submitted, but must be clearly distinct from the rejected DIP. The DIP manager is the final arbiter and may refuse to merge such a DIP if the distinction is not clear.

    A DIP marked `Postponed` will remain as such indefinitely. The language authors will determine when to revisit the DIP and render a final judgement.

#### Exceptions to the Rules

Any DIP submitted by a language author is not subject to the second step of a Formal Review. However, the 15-day feedback period will still be opened in the General forum. The primary focus of every review period in this case should be more oriented to the merits of the propsed feature, rather than the quality of the DIP itself.

#### The Review Count

At the end of the Draft Review, the DIP is assigned a Review Count of `0` by the DIP manager. At the end of each subsequent round of reviews, the Review Count is incremented and is amended with a direct link to the version of the document that was reviewed in that round. The DIP manager will add a summary of the final decision, including the rationale, at the bottom of the document. 

## Responsibilities of the DIP manager

The DIP manager serves as Gatekeeper, Guide, and Coordinator throughout the DIP process. The role is intended to ease the burden on the language authors by ensuring that any DIPs they evaluate are well-written and reasonably complete. 

It should be *difficult* to get a DIP approved. The days when new features could be added to the language through a casual discussion in the community forums are in the past. If a feature is worth adding to the language, than it must be worth the time investment required to craft a complete proposal and shepherd it through the review process. 

* Gatekeeper -- The first step in the process is getting through the gate from the PR queue into the repository. The DIP manager has the authority to determine if a DIP meets the nebulous criteria for `Draft` status (determined on a case-by-case basis) and, if not, to refuse to accept the DIP into the repository until such requirements are met. This is not the same as rejecting a DIP outright, a privilege resting solely in the purview of the language authors. If a DIP author decides to abandon an unmerged DIP, anyone may take it over and modify it to meet the DIP manager's requirements. 

* Guide -- The DIP manager is responsible for keeping the DIP's status up-to-date, making sure the direct links to previously reviewed versions are accurate, and keeping the DIP author informed of what needs to be done to progress to the next stage. The DIP manager also must determine, based on nebulous criteria, when a DIP is ready to move out of the Preliminary Review stage to await formal review.

* Coordinator -- The DIP manager is required to announce and moderate DIP reviews, ensure that the DIP author addresses primary criticisms, facilitate any necessary communication between the language authors and the DIP author, and take steps to mitigate any potential confusion (e.g. including DIP titles in forum announcements).

Disagreements between a DIP author, or other community member, and the DIP manager are bound to arise (e.g. disagreement over the DIP manager's refusal to merge a DIP under Draft Review). If such conflicts can not be settled satisfactorily through private communication, the DIP manager may encourage the complainant to open a thread in the General forum for community mediation or may ask the language authors to render judgement, depending on the nature of the dispute.