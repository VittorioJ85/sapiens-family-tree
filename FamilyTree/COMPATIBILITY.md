# Embedded compatibility support

Author and integration: Vittorio.

This mod includes its own compatibility support for Hammerstone Framework 1.8.4,
Vanilla Tweaks 1.2.0 and Creative Mode 1.3.0, including Creative Mode's server-side
interaction with Time Control Plus. The separate Sapiens Mod Compatibility
Hotfixes mod and the other Vittorio mods are not required for this support.

The adaptations cover Hammerstone menu source changes and dependency sorting,
Vanilla Tweaks server initialization, Creative Mode build-plan arguments and
server-only imports. Mod settings, time controls, and third-party files on disk
are preserved. Only enabled dependencies with recognized source contracts are
adapted. Unknown versions or edited files are skipped with a diagnostic message.
Native game source guards select the relevant adaptations rather than relying
on a beta/public version string. Existing corrected dependencies are left intact.

Every participating mod bundles the same versioned support modules and reference
assets. The game's module cache shares one support instance when multiple mods
are enabled. Initialization and DDAPI interception are idempotent. This is bundled
code, not a dependency on another mod; any one participating mod can provide it.

No network access, executable patch, save migration, or Workshop-file modification
is performed by this support. The native pathfinding crash workaround discussed
elsewhere in this project is unrelated and is not included.

Development source and packaging: `embedded-compatibility/build.py` in the project.
Compatibility tests exercise real game loaders and Hammerstone patches with mocked
engine services. In-game rendering, full simulation and multiplayer still require
runtime validation. See the development validation report for tested installations.

Third-party attribution is in COMPATIBILITY_NOTICES.md.
