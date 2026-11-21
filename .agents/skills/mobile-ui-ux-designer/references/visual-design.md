# Visual Design for Mobile Interfaces

Use visual design to communicate structure, priority, state, and brand. Do not begin with decoration.

## Start with hierarchy

Establish a grayscale structure before relying on color.

- Identify the screen title, primary action, key content, secondary actions, supporting metadata, and low-priority detail.
- Create contrast between levels through size, weight, position, whitespace, and grouping.
- De-emphasize secondary content instead of making every important item larger or brighter.
- Use one dominant emphasis strategy per region. Too many bold labels, badges, and colors cancel each other out.
- Keep primary actions stable across related screens when task logic permits.

## Spacing and layout

- Adopt a documented spacing scale, commonly built from a small base unit. Use larger multiples for section rhythm and smaller increments only when component anatomy requires them.
- Prefer relationships over isolated numbers: elements in a group sit closer together than separate groups.
- Align to meaningful edges and baselines. Avoid nearly aligned elements.
- Give dense content enough structure; do not force every item into a card.
- Set sensible maximum widths on large screens so text and controls do not stretch excessively.
- Account for safe areas, system bars, keyboards, foldable hinges, and transient overlays.
- Preserve useful content when space changes through reflow, reveal, or presentation changes rather than simple scaling.

## Typography

- Use the system typeface by default unless brand requirements justify a well-tested custom family.
- Use a small semantic type scale rather than many arbitrary sizes.
- Pair size with weight and spacing; size alone should not carry hierarchy.
- Keep body text comfortable and allow native text scaling.
- Avoid uppercase for long labels and content.
- Use tabular numerals for changing numeric columns when supported and useful.
- Do not truncate critical labels, amounts, units, errors, or consequences without another way to access the full content.
- Test localization expansion, multiline labels, right-to-left scripts, and the largest accessibility sizes.

## Color

Create semantic roles rather than scattering hex values:

- background and elevated surfaces;
- primary and secondary text;
- accent/action;
- border/divider;
- success, warning, error, and informational status;
- disabled and pressed states;
- focus and selection.

Rules:

- Maintain contrast in light, dark, and high-contrast appearances.
- Do not use reduced opacity as the only disabled treatment if it harms legibility.
- Never encode status solely by hue; add text, iconography, shape, or position.
- Reserve saturated color for elements that need attention.
- Avoid using semantic colors decoratively in ways that weaken their meaning.
- Prefer platform dynamic/system colors where they improve adaptation.

## Borders, surfaces, and depth

- Use whitespace, subtle background changes, or alignment before adding borders.
- Borders should clarify containment, focus, selection, or separation—not outline every object.
- Shadows and elevation must correspond to layering or interaction, not random decoration.
- Avoid nesting cards inside cards unless the hierarchy genuinely requires separate surfaces.
- Modal layers must make ownership and dismissal clear.
- Validate translucent materials over realistic content and accessibility appearances; do not sacrifice legibility for a glass effect.

## Components and consistency

- Similar function should look and behave similarly.
- Different priority or consequence should look different.
- Preserve component anatomy: label, icon, supporting text, validation, state, and target area.
- Do not make an entire complex card tappable when it contains multiple independent actions without clear semantics.
- Use icons from the platform or design system when available. Do not mix unrelated icon families.
- Pair unfamiliar icons with text and supply accessible names.

## Imagery and illustration

- Use imagery when it adds recognition, instruction, emotional context, or product value.
- Avoid generic decoration that pushes essential content below the fold.
- Crop intentionally and preserve focal points across device sizes.
- Provide meaningful descriptions for informative images; hide decorative images from assistive technologies.
- Do not place essential text inside raster images.

## Motion

Motion should explain:

- where an element came from or went;
- how a hierarchy changed;
- whether an action succeeded;
- whether content is loading;
- how a gesture maps to an outcome.

Rules:

- Keep motion brief and interruptible.
- Respect reduced-motion settings.
- Avoid motion that blocks input or creates repeated attention capture.
- Do not animate every list item or surface by default.
- Use continuity and shared elements only when they clarify relationships and remain performant.
- Provide non-motion cues for state changes.

## Practical refinement sequence

1. Remove unrelated visual noise.
2. Clarify title, primary action, and task state.
3. Group content by meaning.
4. Normalize spacing and alignment.
5. Simplify the type scale.
6. Establish semantic color roles and contrast.
7. Reduce unnecessary borders and containers.
8. Add states, icons, imagery, depth, and motion only where they improve comprehension.
9. Test at real device sizes, text scales, and appearances.

## Common AI-generated UI failures

Reject or revise designs that contain:

- gratuitous gradients or glassmorphism;
- a dashboard composed entirely of identical rounded cards;
- huge headings that crowd out the task;
- multiple floating action buttons or ambiguous icon-only controls;
- low-contrast gray text and thin borders;
- arbitrary corner radii, shadows, and spacing values;
- placeholder charts or metrics with no decision value;
- a "clean" empty screen that removed necessary context;
- desktop web patterns squeezed onto a phone;
- iOS-styled navigation on Android or Material controls on iOS without a deliberate reason;
- no loading, empty, error, offline, or accessibility states.
