# OpenCode V2 migration: planning and delivery

**Status:** leaf package reviewed and locally GREEN; CI/publication and consumer integration remain. No activation.
**Stage / revision:** RV / 5, 2026-10-13.
**Basis:** [verbatim human seed](behavior.md), [behavior contract](migration.feature).

## Outcome and why

Both existing Endeavour workspace backends will use native V2 clients with isolated V2 databases. Old V1 database contents and schema remain untouched; history import is separate. Current Desktop origin/main already includes V2 packaging selection and safe RTK/gateway hooks. Earlier inspection of an older canonical branch must not be used as implementation baseline.

## Decisions and boundaries

- Q-1 accepted: native V2 backends and ol/ow launchers; no Rust/V1 client pairing.
- Q-2 accepted: Context Fold and usage sidebar remain opt-in and absent from default plugin lists.
- Q-3 accepted: Endeavour activation through the documented recipe after green checks.
- Q-4 accepted: publish reviewed green commits/task branches and leaf-first PRs in both repositories. Merging remains separately authorized. Consumer deployment waits for a published updated leaf.
- Q-5 accepted: restrict existing homelab V1 database from mode 0644 to 0600 through declarative activation. This explicit permission-only exception does not authorize reading or migrating its contents.
- Apply all six improvements: managed package, essential plugins, global CLI/compaction, V2 checks, permissions, pinned MCP/context cleanup.
- Only OpenCode-related dependencies are in scope. No fleet-wide upgrade, history import or additional orchestration framework.

## Delivery slices and verification

1. Leaf package: update official Linux-x64 V2 binary/hash; extend updater and required CI coverage. First observe assertion-failing tests for missing V2 coverage, then run those tests and build the exact V2 package. Preserve the V1 package lane.
2. Workspace routing: restore two explicit loopback V2 units with new database paths and native explicit-server launchers. Extend evaluated configuration tests first; then verify units, ports, provider routing, argument forwarding and preserved PATH behavior.
3. Settings and integrations: manage one global cli.json, supported compaction, update compatible pinned plugins and Donsetch, enforce secret-read/shell guardrails, remove redundant MCP overrides and duplicated startup guidance. Use existing header/credential tests and smallest necessary negative/positive checks.
4. Runtime: disposable exact-package header/tool/MCP smoke checks, then independent review and owner lint, format and dry-build gates. After a published immutable leaf pin exists, activate only Endeavour and query both explicit endpoints; do not use auto-discovery as evidence.

Success requires zero exit plus actual assertions. Infrastructure errors are not RED; static evaluation is not E2E. Desktop project checks observed assertion failures for unpinned MCP and unrestricted shell before changes; all five current checks pass, including rejection of compound commands and secret-reading Git arguments. The opt-in fragment check is metadata validation, not plugin runtime. Each failure hypothesis gets at most three repair attempts.

Leaf RED observed missing V2 updater/check/required-CI coverage, then additional malformed-metadata and exact-version failures. `bash tests/opencode-v2-contract.sh` passes with `PASS: V2 updater isolation, metadata validation, checks and required CI coverage`. Targeted updater checks and the exact V2 package build pass; `--version` reports `opencode v2.0.27`. The first remote build failed on missing acl-2.4.0; local retry succeeded. V1 remains 1.19.0 and full flake checks are reserved for CI.

Desktop backend configuration/wrapper tests pass 27 cases, including approved permission-only legacy DB fixtures. A disposable exact-2.0.27 API smoke confirms its own PID, native explicit-server client attachment, authenticated health and unauthenticated 401. One test harness repair handled the CLI version prefix; another closed the negative-control HTTP response. No production backend was changed. Essential plugin/tool and final owner gates are still outstanding.

Fresh leaf review reproduced one P2 finding: an unquoted Just recipe version could execute shell syntax and mask the updater failure. The added recipe-level regression failed before the fix, then passed with `quote(VERSION)`. Both targeted Nix lint and sandboxed updater checks pass after the fix. Review confirmed unchanged V1 behavior, sequential required CI coverage for both packages and exact registry integrity. The first-draft patch receipt is retained outside the repository; no acceptance or RED evidence was backdated.

On 2026-10-13, exact 2.0.27 also completed a synthetic model → native RTK shell → model continuation. Desktop settings/project checks and all four touched-host dry-builds pass. Native plugin/permission checks and Ponytail request injection fail, so consumer deployment is blocked despite static success. The bounded repair loop stopped without weakening assertions. Optional runtime trials were cancelled and remain unverified. See the [reconciled test contract](test-contract.md) for per-scenario evidence boundaries.

## Risks and recovery

The independent grill identified publication, database namespaces, server-side routing, approval order and controlling-session continuity as mandatory boundaries. Keep original V1 databases and a reachable matching recovery generation. Do not change live configuration manually, use an unpublished sibling tree for production, or restart the controlling trial session. Restore only task-owned experiments.

Separate clean task worktrees preserve unrelated work. Pending tmux PATH and isolated-trial MCP work must be reconciled before activation; their original worktrees stay unchanged. Global XDG variables from this harness point at trial roots, so documented HM activation needs explicit normal-user XDG roots.

## Continuing work

Reviewed green PR publication is authorized; leaf merge still needs approval. Publication is a real dependency for deploying the updated leaf, not a new activation approval gate. The leaf first-draft review is reconciled; consumer review and exact integration gates continue. Runtime results and unresolved gates remain explicit until observed. The Gherkin contract is traceability, not a claim that a feature runner executed.
