---
name: behavioral-testing
description: Build features or fix bugs test-first through public interfaces; evaluate whether tests catch broken behavior and survive internal refactoring.
license: MIT
compatibility: Project test runner and scoped shell access
---

# Behavioral testing

Modified portable synthesis of Matt Pocock's TDD and Lauren Tan's Pstack behavior
principle at the pins in `NOTICE.md`. This is the single testing discipline; do
not stack the originals. No native Skill tool, Cursor plugin or user interview is
required where the task already authorizes the interface.

Inputs: task acceptance contract, existing public interfaces and test runner.
Output: a regression test, observed red/green evidence, implementation, and limits.

1. Identify the highest useful public seam and what it catches/misses. Use the
   agreed task contract; escalate ambiguous product behavior rather than invent it.
2. Write one concrete test with expected values independently derived from the
   requirement. Run it and observe failure for the intended reason, not setup error.
3. Implement the smallest behavior change. Run the test, then relevant neighbors.
   Repeat one vertical slice at a time, not all imagined tests then all code.
4. Break behavior deliberately in a disposable fixture: wrong return, missing or
   duplicate effect. The test must fail. Then change internal structure without
   altering the interface: the test should still pass. Never mutate a shared app.
5. Refactor only while behavioral checks stay green. Record the commands, outputs,
   revision, and cases not covered. A mock of an external boundary is legitimate;
   assertions on private helper call order usually are not.

Read `references/examples.md` for seam and mutation examples. Tests must not derive
expected output by calling the implementation. No permission to deploy, publish,
install dependencies globally, or read secrets is implied.
