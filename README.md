# Family Tree

A Sapiens mod by **Vittorio**. Private repository owner: **VittorioJ85**.

The installable mod is in `FamilyTree/`. See its existing README and compatibility
notices. The internal folder name is preserved; packaged installation folder:
`FamilyTree`.

## Checks and packaging

Run `python tools/package.py` with Python 3.11+ for game-independent metadata,
JSON, and byte-for-byte ZIP verification. GitHub Actions runs it on pushes and
pull requests and retains ZIP/checksum artifacts for 14 days. Outputs go to
ignored `dist/`. No installation or public release happens automatically.

Run `python tools/check.py` on Windows for local Public and Unstable checks,
followed by packaging. Coverage: Family Tree regression and process-restart suites; requires locally installed Hammerstone.
Local paths are documented in AGENTS.md. In-engine behavior is not tested by CI.

## Working copy

This is a standalone, byte-verified snapshot; `import-manifest.json` records the
initial source hashes, not a continuously updated release manifest. Original
workspace files and install scripts are unchanged. There is no automatic sync.
Choose one working copy before editing; do not maintain divergent copies.

In GitHub Desktop: Add local repository, Fetch/Pull, create a feature branch,
edit, test, review, Commit, then Push. Check Actions before merging.

## Assets and licensing

Existing author credits and third-party notices are retained. No new blanket
license is assigned. Review redistribution rights before making this public.
Model files are imported unchanged. Structures Plus includes the shared model
finalization modules; authoring requires NumPy. Do not regenerate or consolidate
assets without immutable source snapshots and the documented geometry checks.
