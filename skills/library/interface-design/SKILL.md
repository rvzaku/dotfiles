---
name: interface-design
description: Design or critique a distinctive usable interface and its copy, with responsive, keyboard, accessibility and real-browser verification.
license: Apache-2.0
compatibility: Project UI stack; authorized fresh-profile browser through the native browser tool
---

# Intentional interface design

Modified and condensed from Anthropic frontend-design at the pinned source in
`NOTICE.md`. Added explicit evidence, browser permissions and accessibility checks.
No proprietary UI tool, browser profile copying or designer endorsement implied.

Inputs: audience, primary job, real content, constraints and existing design system.
Output: a compact design plan, implemented journey, browser evidence and limitations.

1. Ground the direction in the actual subject and audience. Propose the missing
   brief explicitly rather than pretending it is user research. Compare two small
   layout concepts; select the one that makes the primary action clearest.
2. Define a compact palette, type scale/roles, spacing and layout. Follow an
   existing brand before inventing one. Spend visual boldness in one useful place;
   typography, imagery and composition must serve the subject, not a generic kit.
3. Write plain user-facing copy: concrete action names consistent across button,
   confirmation and error. Empty and failed states explain the next safe action.
   Never invent testimonials, customers, outcome metrics or unlicensed imagery.
4. Implement a complete small journey, including loading/error/empty/success states.
   Preserve semantic controls, labels, keyboard focus/order, contrast, touch targets,
   responsive reflow and reduced motion. Decoration is not a substitute for hierarchy.
5. Drive the actual journey in an authorized fresh browser profile with
   chrome-devtools-axi (or the task's existing browser tool). Check narrow and wide
   widths, keyboard navigation and visible focus, error recovery and persistence.
   Capture action and result, not just a screenshot of a final screen. Automated
   accessibility checks complement manual interaction; do not claim WCAG compliance
   from a scan alone. If browser access is unavailable, label visual QA not tested.

Never connect a personal profile, read cookies, publish assets or change production
without explicit task authority. Critique against the brief and remove distractions.
