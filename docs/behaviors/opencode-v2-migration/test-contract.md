# OpenCode V2 migration: reconciled test contract

**Status:** final traceability draft, 2026-10-13; reconciles accepted planning with delivered checks, not retrospective planning.

**Basis:** [human seed](behavior.md), [accepted scenarios](migration.feature), [delivery evidence](stage-one-pager.md). Gherkin has no executable step bindings; checks cover specific assertions, not whole-scenario completion.

Commands run from the indicated repository. `$V2` identifies the realized leaf 2.0.27 executable; `$PONYTAIL` identifies the realized managed Ponytail package directory.

## Scenario bindings

### Independent native workspace backends

Desktop:

```sh
python3 -m unittest discover -s tests/local-workspace-sessions -p 'test_*.py'
"$V2" --version
python3 tests/opencode-project/smoke_auth.py "$V2" 2.0.27
```

Reported 27 tests cover evaluated units, isolated database/XDG paths, routing, launcher forwarding, PATH and synthetic chmod fixtures. Fixtures preserve inode/size/mtime and work-database metadata; they do not establish production V1 byte/schema preservation.

Disposable auth smoke establishes exact version/PID, explicit native API addressing, authenticated `/api/info` and unauthenticated 401. Neither check activates production backends.

### Verified essential integrations

Leaf:

```sh
bash tests/opencode-v2-contract.sh
nix build .#opencode-v2 --no-link
```

Recorded GREEN covers updater isolation, malformed metadata, required CI wiring and exact package build; CI execution remains separate evidence.

Desktop:

```sh
node tests/opencode-profiles/test_headers.mjs
node tests/opencode-profiles/test_plugins.mjs "$PONYTAIL"
OPENCODE_TEST_BINARY="$V2" python3 tests/opencode-profiles/test_header_integration.py
OPENCODE_TEST_BINARY="$V2" python3 tests/opencode-profiles/test_runtime_v2.py
OPENCODE_TEST_BINARY="$V2" python3 -m unittest discover -s tests/local-workspace-sessions -p test_tool_roundtrip.py
```

Hook checks cover provider filters, original RTK permission input and Ponytail transforms. The exact-version synthetic tool roundtrip passed with real RTK execution and model continuation. Loopback header test deliberately returns HTTP 400, but its Ponytail-injection assertion currently fails. Runtime API checks plugin activation and permission decisions; these currently fail. Latest results belong in the delivery record.

### Enforceable guardrails

```sh
python3 tests/opencode-profiles/test_settings.py
python3 tests/opencode-project/test_configuration.py
```

Settings/project checks inspect rules. Runtime checks exercise native read denial despite agent override, shell approval, narrow inspection allowances and destructive denial. Shell approval is not sandboxing.

### Optional context and quota experiments

Settings/project checks verify default absence, immutable fragments, Fold debug disabled and sidebar `default: none`. Optional runtime trials were cancelled; compatibility, quota retrieval and savings remain unverified.

### Native session management

Settings checks verify global CLI, prompt permissions, native tabs and unchanged default bindings. Desktop's `docs/guides/opencode-v2-sessions.md` documents shortcuts. Actual keyboard delivery remains manual/unobserved.

## Delivery boundaries

Q1–Q5 persist: native isolation; optional plugins off; Endeavour activation after GREEN; reviewed green commit/push/PR authorized, merges not; existing homelab V1 chmod-only 0600 exception. Run owner lint/fmt/docs/dry gates. Obtain separately authorized leaf merge/publication and immutable consumer pin before activation. Never substitute sibling source for production.

Real-provider completion, MCP connectivity/source return and two live endpoint acceptance remain required deployment evidence, not established by static or loopback checks. Consumer's leaf remains 2.0.21 until publication. Full flake checks belong in CI.
