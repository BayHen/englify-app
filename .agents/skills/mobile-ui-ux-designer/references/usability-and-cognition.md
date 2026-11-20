# Usability and Cognition

Use this reference to reason about whether an interface is understandable, predictable, efficient, and recoverable.

## Build a usable conceptual model

People form an explanation of how a product works from visible structure, labels, prior experience, and feedback. Make that explanation coherent.

- Organize features around user concepts and goals rather than database entities or internal team structure.
- Keep the relationship between an action and its result obvious.
- Use the same concept, label, and interaction consistently across the app.
- Reveal system boundaries when they matter: local versus synced, draft versus published, pending versus completed, reversible versus final.
- Avoid controls whose visual appearance suggests a behavior they do not have.

## Affordances, signifiers, mapping, and constraints

- An affordance is what an object permits; a signifier communicates where and how to act. Ensure tappable items look tappable and noninteractive text does not imitate controls.
- Map controls near the content they affect unless a persistent global action is more appropriate.
- Constrain invalid actions early. Use appropriate input types, ranges, defaults, disabled states, and prerequisite explanations.
- Do not disable an action without helping the user understand what is required, especially when the requirement is not visible.
- Make irreversible or high-risk actions visually and spatially distinct from routine actions.

## Feedback and system status

Every meaningful action needs timely, proportional feedback.

- Immediate local feedback confirms the tap or gesture was recognized.
- Progress feedback communicates that work continues and, when useful, how much remains.
- Completion feedback states what changed and what happens next.
- Failure feedback preserves context and offers recovery.
- Long-running work should survive navigation or explain clearly when it cannot.
- Avoid optimistic success when the operation can still fail unless the app can reconcile or roll back safely.

## Recognition over recall

- Keep relevant choices, context, units, constraints, and recent values visible.
- Use labels with icons when the icon's meaning is not universally clear.
- Avoid asking people to remember information from previous screens when it can be carried forward.
- Use search, history, suggestions, and sensible defaults to reduce memory burden without creating privacy surprises.

## Decision load and progressive disclosure

- Reduce simultaneous choices when choices compete for attention, not merely to produce an emptier screen.
- Group related options and order them by task sequence or importance.
- Use progressive disclosure for advanced or infrequent decisions, but do not hide information required to make a safe choice.
- Break long workflows at meaningful conceptual boundaries. Avoid many tiny steps that make progress feel slow.
- Chunk content by meaning. Do not apply simplistic memory-number rules as universal limits.

## Familiarity and platform expectations

People bring expectations from other apps and from the operating system.

- Prefer familiar navigation, controls, icons, gestures, and terminology.
- Depart from convention only when the benefit outweighs learning cost and the new behavior can be made discoverable.
- Do not use a familiar visual pattern with a surprising meaning.
- Preserve expected back, cancel, save, undo, and selection behavior.

## Target acquisition and motor effort

- Make frequent and important actions easy to reach and large enough to activate.
- Increase target area without necessarily increasing visible icon size.
- Separate dangerous actions from common actions.
- Avoid placing small competing targets at screen edges or in moving content.
- Do not require speed, precision, multi-finger gestures, or dragging when an accessible alternative can accomplish the same task.

## Complexity belongs somewhere

A product cannot eliminate all inherent complexity; it can decide where that complexity is handled.

- Move repeated calculation, formatting, validation, and sequencing into the system.
- Do not automate decisions that require informed user judgment without transparency and control.
- Use defaults to absorb routine complexity, but make consequential defaults visible and reversible.
- Avoid exposing implementation complexity as unexplained codes, states, or steps.

## Error prevention and recovery

- Design the valid path so it is easier than the invalid path.
- Validate at the point where the user can fix the problem.
- Preserve entered data after errors.
- Use confirmations selectively for costly or irreversible actions; frequent confirmations train people to dismiss them.
- Prefer undo for common reversible actions.
- Explain whether partial work was saved, submitted, queued, or lost.
- Never blame users for predictable mistakes created by the interface.

## Scanability and self-evidence

A mobile screen should communicate its purpose and next action during a quick scan.

- Use a clear page title or contextual heading.
- Give the primary action a specific label.
- Make sections visually distinct through spacing and hierarchy.
- Remove words that add no meaning, but retain context needed for trust and safety.
- Put critical information where it is needed, not only in help text.
- Avoid multiple elements competing as the primary action.

## Perceived quality

A visually coherent interface can feel easier to use, but aesthetics cannot compensate for broken interaction.

- Use polish to increase confidence and comprehension.
- Do not let visual novelty hide weak contrast, unclear controls, or slow feedback.
- The beginning, moments of difficulty, and ending strongly shape memory. Make onboarding, recovery, and completion states especially clear and respectful.

## Review questions

1. Can a first-time user state what this screen is for?
2. Is the primary action obvious and accurately labeled?
3. Does each action produce visible and accessible feedback?
4. What must the user remember that the app could show or carry forward?
5. Which errors can be prevented rather than explained?
6. Are destructive and irreversible consequences clear before commitment?
7. Does back or cancel behave as the platform and the user's mental model predict?
8. Is the interface using familiar patterns without copying another platform's behavior?
9. Can someone recover after interruption, network failure, denial, or a mistaken action?
10. Is any visual polish reducing rather than improving clarity?
