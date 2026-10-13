# Behavior contract; runnable bindings and observed results are recorded separately.
Feature: Managed OpenCode V2 workspace backends
  Scenario: Independent native workspace backends
    Given the homelab and dataplatform workspaces have preserved V1 databases
    When the verified Endeavour user environment is activated
    Then both explicitly addressed workspace backends report the pinned V2 version
    And native ol and ow clients connect to their respective backends
    And each backend uses a separate V2 database and its intended provider route
    And neither original V1 database content or schema is modified by V2
    And the homelab legacy database receives only the approved owner-only permission change

  Scenario: Verified essential integrations
    Given the exact V2 package and pinned plugins are installed through the flake
    When a disposable model and shell roundtrip is performed
    Then provider-scoped session headers reach only their intended providers
    And RTK executes without weakening approval of the original shell command
    And configured MCP servers connect and web fetch returns source content

  Scenario: Enforceable guardrails
    Given native V2 permission prompts remain enabled
    When an agent requests secret files or unapproved shell operations
    Then protected direct reads are denied
    And shell commands outside narrow inspection allowances require approval
    And documented authorized deployment commands are not permanently denied

  Scenario: Optional context and quota experiments
    Given Context Fold and usage sidebar have immutable enable-time pins
    When the default managed environment starts
    Then neither optional plugin loads
    And no quota fallback is represented as custom gateway usage

  Scenario: Native session management
    Given the global V2 CLI configuration is managed declaratively
    When the operator manages multiple sessions
    Then native session and tab shortcuts remain available
    And terminal-specific delivery limitations are documented without claiming unobserved UI success
