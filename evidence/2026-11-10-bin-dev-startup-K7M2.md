# Development startup verification

- Revision: `43db4906742db2fb13b238c9ccde378e4e1583b4`.
- The worktree contained extensive uncommitted changes before verification; these affected the runtime. Existing changes were preserved. No application or startup-script changes were necessary.
- Initial sandbox execution of `bin/dev` failed because debugger socket binding was prohibited. Verification was repeated outside the sandbox.
- `bin/dev` completed database preparation, then failed because an existing development stack occupied ports 3000 and 3036.
- Sent SIGTERM to the existing Foreman (PID 124), then to its remaining Puma master (PID 463). Restarted with `bin/dev > tmp/bin-dev-verification.log 2>&1`.
- The replacement Foreman (PID 2999) started Rails, Vite and Solid Queue. Puma listened on port 3000; Vite reported ready on port 3036; Solid Queue had a dispatcher, scheduler and workers for default, retention and recurring queues.
- HTTP GET `/` on port 3000 with `Host: base.app.localhost` returned 302. HTTP GET `/vite-dev/@vite/client` on port 3036 returned 200. The initially probed `/@vite/client` returned 404 because Vite uses the configured `/vite-dev/` base path.
- Left the replacement development stack running. Startup still emits MessagePack initialization and debugger messages; no claim is made about unrelated application workflows or the full test suite.
