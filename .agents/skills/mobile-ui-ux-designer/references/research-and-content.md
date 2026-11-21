# Product Research and UX Content

Use this reference when the design depends on uncertain user behavior, terminology, task sequence, or comprehension.

## Research starts with uncertainty

Define what decision the research must improve.

Create an assumptions register with:

- assumption;
- evidence currently available;
- consequence if wrong;
- confidence;
- cheapest ethical method that could increase confidence;
- owner and decision date.

Prioritize assumptions that combine high uncertainty with high consequence. Do not research questions that cannot change a decision.

## Choose evidence that matches the question

- **Generative interviews:** understand behavior, context, workarounds, motivations, and language.
- **Contextual observation:** reveal environmental constraints and actions people forget to report.
- **Usability testing:** find where a proposed or implemented flow breaks down.
- **Diary or longitudinal methods:** study behavior that unfolds over time.
- **Analytics:** identify where and how often behavior occurs, not necessarily why.
- **Support and review analysis:** surface repeated pain points and terminology, while accounting for selection bias.
- **Prototype or assumption tests:** cheaply test demand, comprehension, workflow, or feasibility before full implementation.

Triangulate when the decision is important. A single method rarely explains the whole problem.

## Interviewing users

- Recruit people whose recent behavior matches the decision, not only people who say they are interested.
- Ask about a specific recent event: what happened, in what order, with what tools, constraints, and consequences.
- Avoid pitching, teaching, or asking respondents to design the product for you.
- Ask neutral follow-ups such as "What happened next?" and "How did you decide?"
- Separate observed behavior, direct statements, interpretation, and design implications.
- Protect privacy and collect only necessary information.
- Stop treating a repeated quote as truth until the underlying behavior and context are understood.

## Continuous discovery

- Connect discovery to a desired user or business outcome.
- Map user opportunities before choosing solutions.
- Compare multiple solutions instead of becoming attached to the first plausible idea.
- Identify the riskiest assumption in each solution and test that assumption directly.
- Keep discovery close enough to delivery that evidence changes implementation.
- Record decisions and discarded alternatives so teams do not repeat old debates without new evidence.

## Usability testing

Test realistic tasks, not opinions about visual taste.

- State a goal and context without telling the participant which control to use.
- Observe first; help only after the breakdown is understood.
- Record success, critical error, hesitation, backtracking, misinterpretation, and recovery.
- Distinguish a one-person preference from a repeated structural problem.
- Fix severe problems and retest. A single test round is not validation forever.
- Include assistive-technology and large-text testing when the feature is core.

## Synthesis

For each finding, document:

- evidence and source;
- frequency or confidence without pretending small samples are statistical estimates;
- user impact;
- underlying need or opportunity;
- design implication;
- unresolved question.

Avoid turning every observation into a persona trait. Use artifacts only when they improve decisions.

## UX writing principles

Interface copy is part of the interaction design.

### Labels

- Use specific, familiar terms from the user's domain.
- Prefer action verbs for buttons.
- Name the outcome when possible: "Save address," "Send invite," or "Delete draft" is clearer than "Continue" or "Submit."
- Keep the same concept named the same way throughout the flow.
- Avoid jargon, internal status codes, and playful language in risky or stressful moments.

### Instructions

- Put instructions where they are needed.
- Explain constraints before the user violates them.
- Use examples for formats that are hard to infer.
- Do not write long introductory paragraphs when progressive, contextual guidance works better.

### Errors

A useful error communicates:

1. what happened;
2. what is still safe or saved when relevant;
3. how to fix it or what will happen next.

Rules:

- associate field errors with the field;
- preserve input;
- avoid blaming language;
- do not expose stack traces, raw server messages, or internal codes as the primary message;
- provide retry only when retry can help;
- distinguish offline, timeout, validation, permission, conflict, and server failure when the recovery differs.

### Empty states

- State why the area is empty when ambiguity exists.
- Explain the value or next step without turning every empty state into marketing.
- Provide a primary action only when an action is genuinely available.
- Distinguish first use, no results, cleared filters, no permission, and failed loading.

### Permissions and privacy

- Ask just in time, close to the action that benefits.
- Explain the user benefit and scope in plain language before the system prompt when useful.
- Do not shame or block unnecessarily after denial.
- Provide a path to settings when the user intentionally retries a feature requiring the permission.
- Explain data use, retention, and visibility when those facts affect the decision.

### Confirmations

- Confirm routine reversible actions through immediate feedback rather than modal interruption.
- Use a confirmation for irreversible, costly, externally visible, or security-sensitive actions.
- Name the object and consequence.
- Make the destructive action specific; avoid generic "Yes."
- Offer undo when it is safer and less disruptive.

## Content review checklist

1. Are labels specific enough to predict the outcome?
2. Does the copy use the user's language consistently?
3. Are constraints visible before failure?
4. Can errors be acted on without losing work?
5. Is the tone calm and proportional to the situation?
6. Is permission copy truthful and just in time?
7. Does localization have enough space and context?
8. Can assistive technology understand dynamic status updates?
