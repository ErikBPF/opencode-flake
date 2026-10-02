# Nix MCP startup fix

## Human seed and scope

> cant we keep both v1 and v2 working on durable option?
>
> do fix, but just merge to main now. No need to deploy yes

The verified source fix preserves the shared V1-compatible configuration
that V2 normalizes. mcp-nixos 2.4.3 is now a locked flake input, and the
Home Manager module launches its built executable directly. Deployment
realizes the closure; server startup no longer resolves a flake with `nix run`.
Local merge only; no push, consumer update, or deployment.

## Evidence

The original command initialized in 65.601 seconds during an isolated probe
with Nix download/cache retries. OpenCode V2's default startup budget is
30 seconds. The subsequent tool catalog loaded in 0.005 seconds.

Baseline `nix flake check --offline --no-build --no-write-lock-file` passed.
RED: `just check` failed with the new regression assertion:
`nix MCP must launch a built executable without runtime flake resolution`.
Direct execution of the already-built 2.4.3 package initialized in 1.914
seconds and listed tools in 0.005 seconds without executing any tool.

GREEN: `just check-full` passed all checks, including rendered V1-schema
validation, executable existence, single store-path command, and disabled
MCP registration. Existing direct dependency pins are unchanged; Nix renamed
the root nixpkgs lock node to `nixpkgs_2` when adding upstream dependencies.

Isolated runtime checks connected V1 1.18.30 in 7.876 seconds and V2 2.0.21
in 4.676 seconds using the same legacy MCP entry. Only initialization and
catalog discovery ran; no MCP tools executed. Temporary processes were stopped.

The initial full-check attempt exceeded its 120-second budget while fetching
dependencies through an unreachable cache. A 600-second rerun passed. V2 probe
repairs addressed diagnostic setup, not source: a one-shot list saw pending
initialization; direct HTTP lacked authentication. The successful probe used
an isolated registered service and OpenCode's authenticated API client.

## Review, limits, and recovery

Independent review found no code blockers; its stale-progress-note finding
is corrected here. No extra timeout, wrapper, package implementation, or
configuration schema was introduced.

Deployment remains intentionally deferred. The active V2 configuration is an
independent copied snapshot and is unchanged; a future separately authorized
refresh must adopt the generated command. No live service was restarted.
Recovery is to revert the fix commit and redeploy through the owning consumer
only when separately authorized.

Feedback: "this machine does have git credentials". Confirmed: V2's isolated
`XDG_CONFIG_HOME` hid the host Git configuration, including its author identity.
Git delivery commands use the host XDG config path temporarily; no identity,
credential, or global Git configuration changes are needed.
