# DIP Reviewer Guidelines
The first three stages of the DIP review process allow members of the D community to provide feedback on a DIP before it reached the Formal Assessment stage. A DIP that enters the review pipeline should emerge before the Formal Assessment as polished and solid as possible. It's helpful to all involved, but particularly the DIP author and the DIP manager, if the community reviewers remain on topic and keep their feedback on target. Adhering to the following guidelines will assist in achieving both goals.

## Unacceptable Feedback
Feedback discussions take place in GitHub Pull Request threads for the Draft Review state and in forum threads for the Community and Final Review stages. It is important that feedback stays on topic. Too often, feedback threads are filled with personal opinions that are not aimed at strengthening the DIP, or devolve into off-topic discussions. Such discussions increase the burden on the DIP author who must monitor the discussion for actionable feedback, for the DIP manager who must monitor the discussion (in Community and Final reviews) to extract a review summary, and for anyone trying to follow the discussion with a focus on the quality of the proposal. The DIP manager will strictly ensure that review threads remain on topic.

Posts that do nothing more than declare the commenter's opposition to the DIP, e.g. "I think this is a terrible idea and there's no way I'll support it", are off topic. No one is seeking your support for the DIP. What we want is actionable feedback. If you have concrete reasons for why the proposal is a bad idea or is severely flawed, list them. Then your comment will be on topic and the author will have some potentially valuable feedback to consider. The DIP manager will delete such posts that lack any valuable feedback and paste them in a new post in a separate DIP discussion thread.

Posts that wander off on the pros and cons of something completely unrelated to the quality of the DIP, such as the joys of string handling in C or the incompetence of computer science professors or some ridiculous issues with one OS or another, are very off topic. The DIP manager will delete such posts with both prejudice and pleasure.

In short, reviewers are asked to keep all of their comments focused on identifying weaknesses in and providing suggestions to improve the DIP, and to avoid corrupting such useful feedback with extended expositions that are off topic. The DIP manager and the DIP authors will thank you.

## General Guidelines
The Draft Review, Community Review, and Final Review stages of the DIP process all serve different purposes with their own set of guidelines, but a common set applies to both.

The DIP process is intended to be collaborative, not adversarial. The goal is to work together as a community to produce the best possible outcomes for the D language. The language maintainers are not your enemy, neither are the DIP author, the DIP manager, nor other members of the community. All involved want what is best for the language, though they will often disagree on how to get there. Remember that before posting and endeavor to keep your posts free of personal insults and ad hominem attacks.

The DIP process is neither a popularity contest nor a public vote. The ultimate goal of each review stage is to strengthen the proposal by improving the DIP's language and clarifying its technical issues. There are two broad questions on which each reviewer should focus their consideration and aim to provide detailed feedback.

### Is the proposal acceptable as a language change in principle?
Before considering the technical details of the proposal, the reviewer should consider its merit. This is a subjective question for which providing concrete guidelines is likely not possible. A sample of possible points to consider:

* does the proposal actually improve the language, i.e. it isn't simply bikeshedding or change for change's sake?
* does the perceived benefit of the proposal outweigh any complexity it may add?
* is the potential for code breakage acceptable?
* is there a possible alternative to implementing the proposed feature as a library rather than as a language change?

Consider a proposal to change the `immutable` keyword to `imm`. While some may consider such a change beneficial for the number of keystrokes the new keyword would save, there is a strong argument to be made that such a change is unacceptable on the grounds that it falls in the category of bikeshedding. On the other hand, [a proposal to replace](../DIPs/accepted/DIP1003.md) the `body` keyword with `do` brings an obvious benefit in reducing the number of keywords by one, ultimately presenting a minor reduction in the complexity of the language at no cost.

If, as a reviewer, you find yourself with any doubts as to the acceptability of a DIP, please make a note of your concerns in the Draft or Community review stage. Such feedback is less useful in the Final Review stage.

### Is the proposal workable in practice?
This is the question that delves into the technical details. Not all reviewers will have the requisite background to answer the question outright, but it can be broken down into more specific components that reviewers of varying skill levels can attempt to evaluate.

* _is the proposed feature specified in sufficient detail?_ A DIP should provide enough detail that a programmer with the requisite skill set to implement the proposed feature, and should provide examples demonstrating each unique aspect of the feature in action. It's conceivable, even likely, that a DIP author has not considered every possible angle in drafting the proposal. In the worst case, the detail may be insufficient to the degree that a top to bottom read of the DIP leaves the reviewer uncertain as to what is being proposed. More realistically, reviewers may notice gaps in the proposal for which they can make suggestions to provide clarity.
* _are edge cases, flaws, and risks identified and addressed?_ Beyond the specification of the proposed feature, the DIP author must also consider and attempt to detail the potential side effects of its behavior. No DIP author possesses a crystal ball and, no matter their level of knowledge and experience, cannot be expected to foresee all possible side effects. Reviewers should draw on their own experience to uncover any issues the author may not have addressed. It's particularly important to consider if the proposed feature opens any security holes in the language or conflicts with existing language features.
* _are there any platform or architecture pitfalls to be aware of?_ While this plausibly falls under the previous category, it is worth emphasizing. LDC and GDC support a broader range of architectures than DMD, and this should not be forgotten by the DIP author. Reviewers should consider any potential for platform- or architecture-specific issues that the author may have overlooked.
* _is there an implementation that proves the proposed feature works in practice?_ A DIP is not required to be accompanied by an implementation in order to leave the Draft Review stage, but the presence of an implementation will strengthen the DIP. Not all DIP authors will have the means to implement their proposals, but an attempt should be made to find someone who can. If there is no implementation, why not? Was the feature too difficult to implement or was there simply no one available with the time and means to implement it? Reviewers with the time and means might consider volunteering to provide an implementation in that case. If there is an implementation, reviewers are encouraged to test the examples provided in the DIP and push further by experimenting.
* _does the DIP consider prior work from other languages?_ Rare are the language features that exist in a vacuum. The DIP author should identify other languages including the same (or similar) feature, provide a comprehensive review of the pros and cons of the implementation(s), and a comparison of each instance with the current proposal. As a reviewer, you should draw on your own experience with other languages and identify any prior work you find missing from the proposal.
* _if the proposed feature is a breaking change, is there a well-defined migration path?_ Breaking changes can be controversial, but debates on their merit or value are not on topic in a DIP review. However, examination of the DIP's Breaking Changes and Deprecations section is on topic. Reviewers should consider if the author has identified all potential breakage and clearly outlined a migration path that accounts for each.

Any other weaknesses or potential improvements a reviewer identifies in the proposal are fair game for feedback.

## Draft and Community Review Guidelines
Both of the first two stages of the review process are aimed at improving the DIP's language (see [the author guidelines](./guidelines-authors.md) for hints), its technical strength, and its overall quality. Personal opinions on the merit of the proposed feature are welcome in both stages as long as they are accompanied by concrete reasons that identify flaws with the proposal.

The goal of these review stages is to _strengthen the proposal_, not to shoot it down or discourage the author. Discussions about specific aspects of the DIP are welcome as long as they are focused and do not devolve into endless arguments. By the time a DIP has gone through its final Community Review round, it should be in or extremely near to a final draft.

## Final Review
Feedback in this stage is intended to uncover any flaws that were missed in the previous review rounds. Ideally, a DIP in Final Review will require no revisions. This *is not the place* for personal opinions, with or without concrete reasons. Nor is it the place for suggesting fundamental changes to the DIP unless they are motivated by the discovery of a fundamental flaw.

In short, if you are unable to identify any problems with the DIP, then please do not comment in the Final Review thread.