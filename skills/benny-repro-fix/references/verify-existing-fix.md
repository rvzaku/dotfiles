# Verify an existing fix

Use this procedure when an open pull request or merged commit plausibly addresses the report. The existing artifact owns the fix: verify it, do not edit it, author a competing patch, or open another PR.

## Qualify the artifact

Require a concrete code artifact: an open PR, merged PR, or merged commit with matching intent. A discussion, issue status, branch name, or cause hypothesis is not enough. Prefer an artifact linked from the Firstmate brief or supplied issue; otherwise select the closest code match and state why.

## Protect the working tree

Use an isolated checkout or the repository's safe worktree workflow when available. Preserve existing user changes. Record the baseline revision, patched revision, artifact URL, and shared build/environment inputs.

## Measure the baseline

For an open PR, use its base revision. For a merged fix, use the last suitable revision before the fix. Through the configured control adapter:

1. Launch the baseline app and confirm the environment.
2. Perform the reported path through real UI actions.
3. Observe the discriminating symptom.
4. Reset and repeat the path independently.
5. Capture screenshots, a recording, and the read-only state cross-check.

If the symptom does not appear twice on the baseline, there is no valid baseline. Do not claim the candidate fixed it.

## Measure the patched build

Build and run the PR or fix revision with the same inputs. Repeat the same user path twice, confirm the broken state is gone and the expected state appears, then capture the after evidence and same state check.

## Outcomes

- **Confirmed:** baseline reproduces twice and patched build resolves it twice. Report the artifact URL and before/after evidence. Open no PR.
- **Insufficient fix:** symptom remains on the patched build. Report that result; open no competing PR.
- **Inconclusive:** baseline, patched app, or evidence cannot be measured reliably. State which part failed and do not claim success.

Stop both builds and remove only temporary data created for verification. Preserve user changes.
