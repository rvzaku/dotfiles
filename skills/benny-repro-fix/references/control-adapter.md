# Control-adapter contract

The skill does not assume how a particular application is launched or driven. Use an existing user-designated control skill or adapter and a completed user-facing feature map for the target app. Do not invent a new automation or control plane as part of this task.

If either the adapter or feature map is missing, ambiguous, or incomplete for the reported path, stop before driving the app and report the missing capability.

## Required capabilities

### Launch the target

Start the requested revision in the intended test environment. Confirm the application, workspace, account, data set, and feature state using stable app markers. Return the revision and environment details used for the run.

### Drive the real UI

Use user-visible actions such as clicking, typing, key presses, scrolling, dragging, resizing, or navigation. Prefer accessible roles, labels, and stable selectors. Use coordinates only after a fresh screenshot.

Do not set internal app state, call hidden app methods, write directly to storage, or inject DOM changes to create the reported symptom. Arrange only documented preconditions such as fixtures, permissions, or feature flags. The defect itself must still appear through real interaction.

### Exercise mapped states

Read the relevant feature-map section before driving. Use its paths and stable markers; avoid generated class names, dynamic hashes, child indexes, or brittle DOM positions. Reset enough state to perform an independent second repro attempt.

### Inspect read-only state

Use the least invasive available state read to confirm what the UI shows, such as an accessibility tree, view hierarchy, process state, local log, network status, or app-exposed debug state. If a query changes state, do not use it as a cross-check.

### Capture evidence

Capture screenshots and a recording of the complete repro path, including the discriminating final state. Record artifact paths, times, and app identity. Keep artifacts outside source control and follow the repository's retention rules.

### Clean up

Stop only processes and sessions created by this run. Remove only disposable profiles, workspaces, fixtures, and captures created for the task. Do not delete user work.

## Adapter readiness

Before relying on an unfamiliar adapter, do a harmless check in the test environment: launch the target, confirm its identity, drive one documented feature-map state, inspect state, capture an image and short clip, then clean up. Report missing capabilities before starting repro. Never touch production unless the task explicitly identifies a safe, authorized test action.
