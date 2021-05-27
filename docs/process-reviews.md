# The DIP Review Process
This document describes the purpose of and procedure for each stage of the DIP review process. DIP authors should read the [DIP Author Guidelines](./guidelines-authors.md) for advice on how to write a DIP, and the [DIP Authoring Process](./process-authoring.md) for details on how to submit a DIP and on an author's responsibilities in each review stage. Community members who intend to provide feedback during the public review stages of the process should read the [DIP Reviewer Guidelines](guidelines-reviewers.md) for details on the what is expected from reviewers at each stage of the review process.

There are four review stages, three of which are public and open to all participants.

## Draft Review
The Draft Review officially begins as soon as the DIP manager causes a DIP submitted as a pull request to the [DIP Repository] to be set to the `Draft` status. Note that if the DIP manager determines that a DIP is still in development, he may close the pull request and ask the author to resubmit when the DIP has reached a draft state. DIP authors should read the [DIP Authoring Process document](./process-authoring.md) to understand the difference.

The purpose of the Draft Review is to find and fix any obvious flaws in the content of the DIP. Unaddressed technical issues, potential feature conflicts, potential deprecations, spelling, grammar, and so on, are all welcome targets of criticism and debate. Technical feedback is intended to come from community members, where a wide variety of expertise and experience is to be found, rather than the DIP manager. See the [DIP Reviewer Guidelines] for details of what is and is not acceptable feedback.

All discussion in the Draft Review takes place in pull request comments at the [DIP Repository]. The DIP manager will periodically invite community members to submit feedback in the discussion tread, but a DIP's Point of Contact (POC) may do the same at any time.

There is no set time limit on how long a DIP may remain in Draft Review. Periodically, the DIP manager will peruse the DIPs currently under Draft Review and select one to prepare for [Community Review](#community-review). Both the frequency of this occurrence and the selection criteria are wholly at the DIP manager's discretion. Once a DIP has been selected, the DIP manager will work with the POC to ensure that unique criticisms raised throughout the Draft Review period are reasonably addressed.

## Community Review
When the DIP manager is satisfied that a DIP is ready to proceed beyond the [Draft Review](#draft-review) stage, the DIP manager will assign the DIP a number, set its status to `Community Review Round 1`, and announce the review in the [D forums]. The purpose of the Community Review is to expose the DIP to a wider audience in order to find flaws that were not uncovered in the [Draft Review](#draft-review), further improve the language and scope of the DIP, and generally revise the DIP until it is meets the standards set forth in the Guidelines document. Reviewers should familiarize themselves with the [DIP Reviewer Guidelines] before providing feedback.

The DIP manager will announce the review in the [D Forums] and open a thread where community members can discuss the DIP and provide feedback. Everyone is welcome to participate in this review stage. The DIP's POC is expected to respond to each unique feedback point raised. If the POC determines a criticism is actionable, an acknowledgement should be made that the DIP will be revised accordingly. If the POC determines a criticism is not actionable or applicable, a rationale is welcome but not required. Unactionable feedback should still be acknowledged even if no rationale is provided. The DIP manager may refuse to advance a DIP to the next stage until all unique feedback points have been addressed by the POC.

At the end of the Community Review, the DIP manager will work with the DIP's POC to ensure all feedback has been addressed, revise the DIP as necessary, and include a summary of the review round in the Reviews section of the DIP. If the feedback leads to extensive revision, as judged by the DIP manager in consultation with the POC, the DIP manager may call for another review round. In that case, the status of the revised DIP will be set to `Community Review Round N`, where `N` is the sequential number of the new round. DIPs requiring further Community Review rounds will take precedence over DIPs in Draft Review. When any review round is completed, the status of the DIP will be set to `Post-Community Round N`.

Round 1 reviews will generally begin within the first seven days of the month unless a delay is in order (e.g. the DIP manager and author engage in a long revision process). Ideally, only one DIP will be in Community Review Round N at any given time, but circumstances may warrant initiating multiple Round N reviews simultaneously at the DIP manager's discretion (e.g. a DIP is given high priority, the Draft Review queue is long, etc). If multiple Community Reviews are initiated in a given month, the additional reviews may begin at any time. Each round of a Community Review will continue for a period of 15 days from the date of the announcement unless terminated earlier by the DIP manager. The DIP manager will include the terminal date in the first post of the review thread. For example, a review beginning on Monday the 1st will end on Monday the 15th at a time specified by the DIP manager.


## Final Review
A DIP may remain in the `Post-Community Round N` status for a maximum of 180 days. Periodically, the DIP manager will determine if any post-community DIP is ready to move forward to the Final Review stage. Only one DIP will be in this stage at any given time unless the DIP manager determines an exception is required.

Extraneous circumstances may cause progress to be delayed. If a given DIP has not been moved out of the Post-Community state after 180 days, the DIP manager is required either to move it forward or to append its status with the `Abandoned` or `Postponed` label after consultation with the POC or, if the POC is unavailable, the language maintainers.

When a DIP enters the Final Review stage, the DIP manager will set its status to `Final Review`, announce the review in the [D Forums], and create a discussion thread where everyone is welcome to leave feedback. Final reviews will always begin in the third week of the month and will last for a period of 15 days unless the DIP manager terminates the review early. The DIP manager will include the termination date in the first post of the discussion thread.

The purpose of the Final Review is to provide one final opportunity to examine the revisions made in response to the [Community Review](#community-review) rounds and further refine the DIP as necessary. Reviewers should familiarize themselves with the [DIP Reviewer Guidelines] to understand what is and is not acceptable in the Final Review.

The DIP is not expected to undergo significant revision as a result of the Final Review. The exception to this rule is in the case that any major flaws are discovered which may have been overlooked in previous review rounds or introduced as a result of revision. In such a scenario, the DIP manager will consult with the DIP's POC and/or the language maintainers to determine how to proceed. Most likely, this will require moving the DIP to one more round of Community Review, in which case it will have priority over DIPs in Draft Review.

If no major flaws are discovered as a result of the Final Review, the DIP manager will set the status of the DIP to `Post-Final`, add a summary of the Final Review to the Reviews section of the DIP, and consult with the POC to determine if any revision is necessary. As soon as any required revisions are complete and any preceding DIP under Formal Assessment have been decided upon or otherwise removed from active consideration, the DIP manager will move the DIP to the next stage.

## Formal Assessment
The DIP manager is required to submit a DIP to the language maintainers for Formal Assessment as soon as possible following the [Final Review](#final-review).

The language maintainers will try to render judgement within 30 days of the start of the Formal Assessment. This is, however, an unpredictable process. It is not unusual for the language maintainers to require input from the DIP's POC, or to ask for revisions. Generally, the DIP manager will act as the intermediary for all interactions between the language maintainers and the POC via email. In some cases, circumstances may require direct discussion between the language maintainers and the POC via email or another medium.

If the language maintainers determine that revisions to the DIP are required, the DIP will remain in the Formal Assessment state but will no longer be under active consideration. This will allow another DIP to be moved into active consideration. The DIP manager will notify the POC and will await notification that the revisions are complete, periodically checking in with the POC as necessary. When revisions have been completed, the revised DIP will return to active consideration at the first opportunity, taking precedence over any DIP currently in the `Post-Final` state.

After the language maintainers determine a final disposition for the DIP, the DIP manager will mark it as `Accepted` or `Rejected`. If they decide more time is needed, the `Extended` label may be appended to the DIP status. The DIP manager will periodically consult with the language maintainers to determine if the DIP is ready for a final disposition. At the end of 90 days, if the language maintainers are still not ready for a finial decision, the DIP manager may append the `Postponed` label.

## Postponed and Abandoned DIPs
At any point in the review process, the DIP's POC may request that the DIP manager mark the DIP status with the `Postponed` label. If contact with the POC is lost, the DIP manager may mark a DIP as Abandoned. DIPs marked as either are frozen at the current stage of the DIP process.

Postponed DIPs may be revived by the POC (or DIP Author(s)) at any time within 180 days from the day the label was added. If no request to revive the DIP is made after 180 days, the DIP manager will change the label from `Postponed` to `Abandoned` unless consultation with the POC warrants extension of the postponement.

Abandoned DIPs may be revived by anyone at any time. DIPs in the `Post-Final` state will not be marked as `Abandoned` and will instead be moved into the Formal Assessment stage, in which case a volunteer may be sought to apply any revisions requested by the language maintainers.

When a postponed or abandoned DIP is revived, the DIP manager will consult with the new POC to determine if the DIP may continue the DIP process from the stage at which the label was applied, if it should move to an earlier stage, or if it should be completely rewritten and resubmitted as a new DIP.

## Withdrawn and Superseded DIPs

A DIP's author may choose to withdraw the DIP from the review process at any time. If the DIP is the subject of an ongoing round of review, the DIP manager will announce the termination of the review round and add to the DIP a summary of the review to date. The DIP manager will mark the DIP as Withdrawn and no further action will be taken. Withdrawn DIPs are _not_ frozen at the current stage of the DIP process. The process is completely terminated.

Unlike Abandoned DIPs, a Withdrawn DIP cannot be revived without the DIP manager's approval. A DIP author will have a specific reason for withdrawing from the process, and that reason might preclude further consideration of the DIP. For example, a DIP that was withdrawn because it received an overwhelmingly negative response should be rewritten and submitted as a new proposal rather than revived in its original form. If the DIP manager does allow a Withdrawn DIP to be revived, it must begin the review process anew from the first round of Community Review.

A DIP's status may be set to `Superseded` at any stage in the DIP process to indicate that the proposal was made obsolete, e.g. by the acceptance of an alternative proposal, the implementation of a feature similar to that proposed by the DIP, etc. Superseded DIPs may not be revived without the consent of the language maintainers.

## The Ideal Process
The following steps outline the process for the best-case scenario after a DIP is selected to leave Draft Review, in which the DIP does not require significant revision and no extra Community Review rounds are required.

* the DIP enters Community Review in the first week of Month A.
* after Community Review, the DIP author will have four weeks to complete any required revisions.
* in the third week of Month B, the Final Review begins.
* after Final Review, no revisions are required and no other DIP is under active consideration, so the DIP may immediately move into Formal Assessment.
* the language maintainers have enough information to render a verdict on the DIP within 30 days.

So in the best-case scenario, a DIP will require two to three months to go from Community Review to acceptance or rejection. The DIP manager will strive to keep the process as short as possible, but it should be expected that the best-case scenario will be rare and a period of four or five months will be more common.

[DIP Repository]: https://github.com/dlang/DIPs
[D Forums]: https://forum.dlang.org/
[DIP Reviewer Guidelines]: ./guidelines-reviewers
