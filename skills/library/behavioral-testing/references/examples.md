# Independent tests at public seams

For a CLI contract `double INTEGER`: input `21` must exit 0 and print `42\n`;
input `oops` must exit 2, not an uncaught traceback or a successful empty result.
Use literal expected results from that contract. Run the CLI as a subprocess.

- A broken implementation returning 0 for invalid input must fail the exit assertion.
- Moving parsing into a private helper must not affect either test.
- If the contract promises exactly one notification, assert the external receiver's
  observed count and payload. A count on an internal parsing helper proves little.
- A test of 'no charge on empty cart' needs a nonempty control demonstrating that
  the test can actually observe a charge. Otherwise a disconnected mock passes both.

The deterministic fixture in `tests/skills.test.py` demonstrates this criterion;
it does not demonstrate that any model follows the prose better than a baseline.
