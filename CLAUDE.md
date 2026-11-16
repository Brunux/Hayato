# CLAUDE.md

@AGENTS.md

## Working in the Umbrella
- Read the owning submodule's `AGENTS.md` (`core/AGENTS.md`, `desktop/AGENTS.md`, or
  `devices/AGENTS.md`) instead of loading all repositories at once.
- On 8-core ARM64 targets (MT8192), pin Cargo compilation/tests with `taskset -c 4-7` and `-j 4`.
- Always create and push PRs/branches targeting the owning sub-repository cleanly; never push
  directly to remotes unless requested.
