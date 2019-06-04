# DIP Author Guidelines
Writing a solid and informative DIP is very hard work. The amount of effort required is often underestimated. And even with a high investment of time and effort, there are no guarantees that the proposal will ultimately be approved. Applying the recommendations in this document will increase the quality of your DIP and make it less likely to be rejected on the grounds of poor quality.

For examples of accepted DIPs that are considered to be of good quality, see [DIP 1003](../DIPs/accepted/DIP1003.md) and [DIP 1010](../DIPs/accepted/DIP1010.md) (although the layout of those DIPs should be eschewed in favor of [the current DIP template](../Template.md)).

## General Advice
The first step on the long road to acceptance is getting past the gatekeeper (the DIP manager) and into the DIP repository. The specifics required to get there are largely dependent on the nature of the proposal. However, there are a few general guidelines that, if followed, make for a more solid proposal and improve its odds of getting out of the pull request queue.

1. Motivate, explain and demonstrate the value gained from implementing the proposed feature. Alternative solutions should be considered and compared.
2. Use real-world examples, taken from specific projects where possible.
3. Consider potential objections against the proposal, research them, and address them.
4. Stick to formal and technical language in general, avoid colloquialisms. A DIP should be formulated like a scientific or academic paper, as opposed to an op-ed article.
5. Provide sufficient technical details that can be used as a specification by D compiler developers.

Be prepared for a lot of work. There are countless ideas bandied about in the community forums, but few developers are committed to pursuing an idea to the final stages of evaluation. Many are unwilling to make the effort without a guarantee of acceptance. If such guarantees could be made, there would be no need for the DIP process.

The purpose of the process is to provide a coherent, formalized proposal for the language authors to evaluate. It is not impossible that a feature which they are inclined to reject may be approved in the end as the result of a convincing proposal. In short, DIP Authors should start with the expectation that rejection is the default outcome and, instead of being discouraged, use that as motivation to craft the best DIP possible.

## Proper Motivation
Any DIP must focus on "why" at least as much as "what". Language changes must be justified. Doubt about the necessity or value of a change will be a strong motivator for rejection.

It is vital to research any alternative approaches to solving the same problem and explain why the proposed choice is superior. If there are any relevant stories of success or failure in other programming languages, consider referring to them with an explanation of how they might apply to D.

Redundancy of existing features should not be used as precedent and/or justification for adding another redundant feature. Similarly, an existing language flaw should not be used as an excuse for adding new, similarly flawed, functionality.

It is important to evaluate the costs of adding, changing, or removing language features. Something that uses existing syntax and builds upon established semantics is considered much less expensive than a proposal requiring a completely new concept. More expensive proposals should add greater benefit.

Avoid speculation. For example, unless you are an expert on human behavior, claims that a feature will increase the language's popularity or adoption rate are meaningless. Testimony based on personal experience, or that of others, is acceptable as long as it is backed up with data or a solid reasoning.

## Demonstrative Examples
The Rationale section should showcase examples that currently are not possible or are complex or verbose in D, followed by an implementation demonstrating the expected usage of the proposed feature. At best, the example would be taken from existing code (e.g. found in DUB, Phobos, etc).

Keep in mind that without such examples to back it up, any reasoning in favor of a proposed feature may be completely disregarded. This is also why examples from existing code are preferred. D is a practical language and even a theoretically sound proposal is not important enough if it doesn't offer any substantial improvements to code that actually gets written.

To further strengthen the DIP, the presence of an accompanying implementation will allow reviewers to test the examples to determine if they function as predicted.

## Potential Objections
Foreseeing and countering potential objections before they are raised increases the strength of the proposal. If you can easily foresee potential objections but are unable to counter them, then the likelihood of the DIP surviving the process is much lower. Failing to address them at all significantly reduces the likelihood of acceptance, as such objections are sure to be raised by the language maintainers if not by the community reviewers.

No DIP author will have access to a crystal ball, but the author who takes the time to consider the proposal from all angles, to examine it from the perspective of opposition, will be more likely to leave Draft Review with a stronger DIP.

## Formal and Technical Language
A DIP serves as a specification for a language feature. Its target audience is a formal one. It is not intended to entertain, argue an opinion, or persuade an audience with impressive rhetoric. The language should be clear, concise, precise, and grounded in fact. Personal opinions regarding the proposed feature that cannot be supported with evidence should be excised. "Flowery language" should be avoided.

## Technical details
Anyone proposing a language change is expected to understand how existing language features will be affected by the proposal and how the change can be implemented at a level sufficient for crafting a formal proposal. Anyone not fully cognizant of these details should either research them or enlist the aid of someone more knowledgeable before submitting the proposal.

It is crucial for any proposed change to list all possible concerns regarding breakage of existing D code caused by the change. Even if the chance of breakage seems very low, it needs to be listed. If code breakage is likely to affect at least a few existing projects, the proposal must include a description of the intended deprecation process.

Submitted proposals should cover as many of these details as possible, but no DIP author is expected to be a qualified expert on language design or compiler technology. Any obvious technical details the author may have overlooked will hopefully be identified during the Draft Review process. The author is expected to make a best effort to comprehend and effectively address Draft Review feedback before a DIP is accepted into the repository.

Ultimately, to move beyond the Draft Review, the specification should be formal and detailed enough so that independent compiler authors can rely on it to implement the feature in a compliant way. There must be no room for interpretation. For example, any change that requires adjusting the language grammar must include a description of the change in the same format as the [existing grammar spec](https://dlang.org/spec/grammar.html).