Edge-FML: Run & Smoke Test

Quick run instructions (Windows cmd.exe):

- Run the minimal test (non-interactive):

```bat
matlab -batch "run('j:\\VSCodeAIDemos\\Edge-FML\\run_minimal_test.m')"
```

- Run the smoke test script (creates `tests/smoke_test_result.txt`):

```bat
matlab -batch "run('j:\\VSCodeAIDemos\\Edge-FML\\tests\\smoke_test.m')"
```

Notes and troubleshooting:
- Ensure MATLAB is on PATH and licensed. If using Parallel Toolbox, the code will attempt to start a pool automatically.
- If you see errors related to `parfor` or parallel pools, run without parallelism by setting the constructor flags in your runner scripts (e.g., pass `'Parallel', false`).
- If memory issues occur, the code now hints GC instead of calling `pack` to avoid blocking behavior.

If you want me to run the smoke test now, give me permission and I'll invoke MATLAB commands on your behalf (or guide you to run them locally).