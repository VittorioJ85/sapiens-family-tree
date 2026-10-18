# Changelog

## 0.14.4 - 2026-10-12

- Fix world initialization on releases without the `crouchLow` animation (reported on public 0.6.1.3). The bedside animation uses the available seated pose, or standing pose if seated is unavailable, preserving its twelve-second duration and action behavior.
- Add regression coverage for missing crouch and seated animations. Full gameplay on the exact reported 0.6.1.3 build remains unverified; local public-directory animation assets match the newer beta assets.

## 0.14.3 - 2026-10-10

- Add native Sapien portraits beside the details in family-tree cards. Scale them with zoom and keep text in its own clipped column.
- Create portraits only for visible cards, release them when panned offscreen or closed, and use existing client follower data without additional network requests or archive writes.
- Show "No portrait" for deceased, unknown or unavailable people whose appearance is not recorded. No guessed faces or historical data migration.

Automated UI checks cover identity, placement, zoom, text separation and view cleanup. Final native rendering still needs an in-game check.

## 0.14.2 - 2026-10-10

- Journal each person/index update before writing it. Replay interrupted updates before new archive access, including cases where the person will never load again. Preserve schema-1 records and settings without a full archive scan.
- Recover Family and surname-settings panels after ten seconds without a reply. Ignore late/duplicate replies; a timed-out save has an unknown outcome and requires reloading the server settings before further editing.
- Reuse an on-demand lineage index for family statistics. Subsequent openings inspect only the selected family's members; current ages and loaded membership remain live. Reject pagination across archive revisions rather than combine inconsistent counts.

Automated validation uses injected write interruptions, controlled panel callbacks and a separate three-process file-adapter test. Native database power-loss behavior, multiplayer transport and final in-world operation are not certified by these tests. This source release is not automatically installed or published.

## 0.14.1 — 2026-10-09

- Show living tribe members' ages on tree cards using the native age calculation and display offset. Refresh or reopen Family to update cached ages.
- Keep age at death unchanged; do not estimate missing ages from calendar dates or disclose current live data of former members in another tribe. No age field is written to the archive.

Automated tests pass against the installed native child/adult/elder age formatter, including refresh, parent/child payloads, card text, unavailable/foreign members, deceased records and invalid state. Final in-game appearance remains unverified.

## 0.14.0 — 2026-10-09

- Unify Family into one expandable tree. Remove the duplicate fixed overview and Overview / Explore tree switches.
- Open a bounded initial family: the focus, two parent slots, eight child candidates and their authorized co-parents. Share repeated co-parents in this initial snapshot; load further children eight candidates at a time and deeper generations only on demand.
- Keep Archive, Names, Back, Starting Sapien, visit controls, family statistics and dates directly accessible. Add an Oldest button that focuses the oldest confirmed living family member. Statistics responses preserve the current tree and camera.
- Retain existing family/person server actions for compatibility. Household requests enforce the same authenticated membership checks and never recursively load relatives or scan beyond their candidate page.

Automated tests cover native Family entry, unified navigation and settings, bounded snapshots, co-parent privacy/sharing, child pagination across storage boundaries, cache reuse, stale callbacks, existing tree controls, and archive/history restoration. In-game visual verification remains pending. Original world saves are not used by the tests.

## 0.13.0 — 2026-10-09

- Separate overlapping relationship routes and their card attachment points. Color mother/father connections, break crossings visibly, and add **Trace / All** for a person's direct links.
- Group children by their known co-parent, identify that parent on cards, and connect already visible co-parents to their other visible children. Pack side branches into nearby free space, retain true generation rows, and add generation labels and **Fit** with a 20% minimum zoom.
- Show recorded birth/death dates in the world's year/day calendar. Capture future native birth events until the child object exists; preserve historical child observations as a separate event and show unknown birth dates honestly. Event timestamps are immutable on replay.
- Preserve lazy loading, permissions, loop filtering and bounded caches. A child page reads at most one extra direct co-parent per returned child, after checking historical tribe membership.

Automated suites pass, including a multi-partner family, maternal grandparents, non-overlapping tracks/ports/cards, visible co-parent links, trace/fit callbacks, privacy, native notification forwarding, pending-birth reload/failure handling, immutable dates and calendar boundaries. A schematic generated from production layout geometry was inspected. Native in-game visual confirmation remains pending; original world saves were not used for tests.

## 0.12.3 — 2026-10-09

- Add **Parents** to descendant cards. Every known person now supports opening both parents and children without changing focus.
- Extend side-branch layout to handle repeated direction changes, including a child's other parent and that parent's family, while preserving generation heights and non-overlapping cards.
- Retain on-demand loading, cached reopening, bounded view size, and omission of return links already on the current path.

All automated tests pass, including descendant-parent button callbacks, nested direction changes, layout uniqueness, collapse/reopen, and loop filtering. In-game visual confirmation of the new branches remains pending.

## 0.12.2 — 2026-10-09

- Omit people previously shown as **Repeated on path** instead of creating terminal duplicate cards. They no longer consume layout space, connecting lines, or the card budget.
- Preserve internal loop prevention, lazy pagination, and legitimate appearances on separate lineage paths. Keep cached responses independent of the path using them.
- Show **No new people** when an opened branch contains no additional visible people.

Automated regression tests pass, including filtered-only pages, cache reuse across different paths, duplicate entries, card budgets, layout bounds, and ancestor-child UI behavior. The player confirmed 0.12.1 working; this display adjustment still needs in-game confirmation.

## 0.12.1 — 2026-10-09

- Add **Children** to ancestor cards, allowing siblings, uncles/aunts, and further descendants to be explored without changing focus.
- Place these collateral branches beside the main tree, retaining correct generation heights and preventing card overlaps.
- Keep branch loading, paging, caching, and view limits unchanged. Return links to people already on the current path remain terminal, preventing endless expansion.

Automated model and UI tests pass, including multiple simultaneous collateral branches, generation heights, collapse/reopen behavior, return links, and card hitboxes. The 0.12.0 tree was confirmed working in-game by the player; the new collateral layout still needs visual confirmation.

## 0.12.0 — 2026-10-09

- Add **Family → Explore tree**, with connected person cards and independently expandable ancestor and descendant branches.
- Support dragging, mouse-wheel/button zoom, centering, branch collapse, and focusing another person. Preserve the original overview, family totals, oldest-member marker, and visit-person action.
- Load only one direct generation or one 32-candidate child page per branch request. Reuse cached branches; moving and zooming are client-only.
- Bound each view to 256 card occurrences, 64 cached pages, and four concurrent branch requests. Stop ancestry cycles and keep unknown or inaccessible people anonymous.
- Add request timeouts, retry controls, and protection against responses arriving after closure, navigation, or collapse.

Automated LuaJIT tests cover server access, direct-generation reads, paging, cycles, layout, UI hitboxes, drag/zoom, cache reuse, and lifecycle handling. Rendering and input delivery are simulated; final appearance and mouse handling still need in-game confirmation.

## 0.11.0 — 2026-10-09

- Add **Try for a Baby** to the radial menu of adult tribe members, with explicit partner selection, estimated Low/Medium/High chances, and explanations for unavailable pairs.
- Require two suitable completed beds within 12 metres of each other. Both partners walk there before a synchronized twelve-second bedside animation.
- Persist failures per pair. Three completed unsuccessful attempts block that pair for five further age years; interruption does not count as a failure.
- Keep natural pregnancy independent, preserve a pregnancy that begins during travel, and use native pregnancy and father information on success.
- Validate ownership, eligibility, beds, and outcomes on the server. Reject attempts through the generic plan endpoint and restore or release saved meeting state on reload.
- Add polling, timeout recovery, and stale-response protection to the partner window.

Automated LuaJIT regression tests cover the lifecycle, cooldown, cancellation, authorization, native radial dispatch, and simulated UI. Visual animation, pathfinding, and a live multiplayer session still need in-game verification.

## 0.10.0 — 2026-10-05

- Treat a nomad group recruited together as one named family when automatic naming is enabled.
- Persist the recruitment group before queued naming; shared names survive deferred occupancy scans and save/reload.
- Prefer a protected player surname, then an existing automatic surname, otherwise select an unused name. Preserve conflicting manual names and surname removal.
- Include the assumed group in family counts without adding fictional parent edges. Descendants inherit through the existing paternal/maternal setting.
- Limit the change to actual arrivals in player tribes; exclude individual settled recruitment and automatic naming OFF.

Automated regression tests pass. In-game verification of group recruitment remains pending.

## 0.9.2 — 2026-10-02

- Fix "Loading name settings..." remaining visible when another mod, such as Precise Rotation, also offers Hammerstone options.
- Preserve the Family Tree editor during Hammerstone's eager creation of other mod panels. Cancel callbacks only when replacing Family Tree controls or closing the options window.
- Add regression coverage using the installed Hammerstone options module's actual multi-mod initialization, tab switching, reopening, and reset behavior.

This corrects a regression introduced in 0.9.1. Existing settings, names, and archive records are unchanged. Automated tests pass; in-game confirmation remains pending.

## 0.9.1 — 2026-10-02

- Split request validation and public responses from event observation and naming.
- Reject invalid actions, object types, IDs, pages, and malformed or oversized settings; validate custom-name UTF-8.
- Hide all internal ancestry fields from network responses and stop traversal at unknown ancestors.
- Deep-copy archive cache data, including nested settings.
- Reset world references and queues between worlds while retaining new bridge-load events.
- Return explicit pending-name status instead of coupling the service to index internals.
- Separate settings views, share paging/history logic, and remove unused UI arguments, the empty update method, and the unused revision counter.
- Lock drafts during saves and invalidate pending callbacks when switching mod panels.
- Document active migrations, security boundaries, performance limits, and regression tests.
- Derive package and backup versions from modInfo.lua. Keep historical diagnostic reports out of release packages.

The archive schema and existing family names are unchanged. Host and clients should use the same mod version because the private UI response shape changed. Automated checks pass; in-game validation remains pending.

## Earlier releases

Version 0.7.1 replaces paired Sumerian and Aztec catalog entries with single-word names without hyphens or spaces, retaining 128 distinct entries in each group. Saved exclusions follow the corresponding replacement entries. Existing people, inherited names, and player-edited names are not renamed.

Version 0.7.3 displays all cultural surname lists and custom names alphabetically (case-insensitive A–Z). Read each column from top to bottom, then continue with the next column. Display sorting leaves the assignment pool order, existing names, and saved exclusions unchanged.

Version 0.7.3 adds a tree preview icon to the mod selection list and detail panel. The bundled preview.png is referenced by modInfo.lua. Restart Sapiens after updating to refresh the preview.

Version 0.7.4 resizes the existing tree preview to 512 x 512 pixels (329,907 bytes), below the Steam Workshop preview limit of 1 MB. The artwork and gameplay are unchanged.

Version 0.7.5 refreshes the short mod description with more natural wording. Gameplay is unchanged.

Version 0.8.0 adds mutually exclusive Paternal and Maternal inheritance checkboxes in both settings entry points. Click Save to apply the choice per tribe. Paternal is the default for existing settings. Changing the mode affects future assignments only; existing names and player edits remain intact. Automatic names OFF still disables new assignments. New archive records remember the selected parent so family counts stay consistent even after the setting changes.

Version 0.8.1 starts automatic surname assignment disabled for tribes with no saved name settings. No cultures, including Greek or Roman, are preselected. Existing saved preferences remain unchanged. The family archive stays active; newly observed children and recruits keep their names until the player enables naming and saves a selection. Defaults and Reset to default prepare the same disabled state for saving.

Version 0.9.0 adds the Ancient Egyptian group, initially unselected, and avoids occupied surnames for new families until the enabled pool is exhausted. The culture grid fits all twelve groups plus the custom list. Automated checks cover 128 unique assignments before repetition, balanced initials, exclusions, manual edits, inheritance, unloaded members, deaths, lazy reload, and disabling naming during a pending scan. In-game validation of this update remains pending.
