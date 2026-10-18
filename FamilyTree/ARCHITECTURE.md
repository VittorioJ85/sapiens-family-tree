# Family Tree maintenance guide

Maintained by Vittorio. User-facing text, comments, and documentation are English.

## Module responsibilities

| Module | Responsibility |
| --- | --- |
| `scripts/server/*` | Thin hooks around world setup, Sapien loading, recruitment, child creation, death, removal, and authorized renaming. Preserve vanilla behavior and event ordering. |
| `familyTree/service.lua` | World lifetime, typed Sapien observations, deduplicated work queue, and naming coordination. Four observations per server update. |
| `familyTree/requests.lua` | Network boundary: authenticated tribe lookup, input validation, access checks, and explicitly selected public fields. |
| `familyTree/archive.lua` | Versioned database, bounded read cache, paged indexes, family lookup, and lazy surname occupancy. No full-history startup scan. |
| `familyTree/nameSettings.lua` | Defaults, legacy migration, bounded validation, UTF-8 validation, and per-tribe settings retrieval. Shared by UI and server; the server always validates again. |
| `familyTree/nameCatalog.lua` | Stable culture identifiers, name pools, exclusion migrations, deterministic pool order, and sorted display copies. |
| `familyTree/surnames.lua` | Inheritance, unused-name selection, manual-rename protection, and shared-state persistence. The third return from `apply` signals a pending occupancy scan. |
| `familyTree/familyStats.lua` | On-demand lineage counts and oldest living member. Lineage IDs stay internal. |
| `familyTree/ui.lua` | Family navigation, bounded history, zoom, pagination, and asynchronous request handling. |
| `familyTree/settingsUI.lua` | One editor for both entry points; separate group, surname, and custom-list views. Shared validation and paging. |
| `scripts/mainThread/ui/inspect/*`, `scripts/hammerstone/*` | Integration adapters for vanilla Family and optional Hammerstone Mod Options. |

Custom UI modules must stay outside `mainThread/ui`. Hammerstone's patch rules assume files in that namespace exist in the base game. The no-op `setBackFunction` adapter is required by the vanilla collection and is intentionally retained.

## Data and lifetime

The world database is `familyTree_v1`, schema 1. Keys include `p:<id>`, paged `list:<index>:<page>`, `count:<index>`, `member:<index>:<id>`, and `nameSettings:<tribe>`. Pages contain 32 entries. Membership records make ordinary repeated observations idempotent. Reparenting can leave stale index candidates; readers verify current parent edges before displaying them.

The read cache contains at most 256 entries. Cache reads and writes copy nested data, so callers and database adapters cannot mutate cached settings by retaining a table reference. Persisted tables are internally constructed or normalized by the settings validator; arbitrary network tables must never be passed directly to `archive:put`.

`service:init` clears previous world references and queued IDs. The world adapter resets before vanilla initialization and preserves only events produced during that new bridge setup. Death timestamps are sticky: a later load/removal observation cannot resurrect a recorded person.

The native `babyBorn` notification records a server-authored `pendingBirth:<motherID>` timestamp. It preserves the original notification arguments and return values. Successful child creation transfers this timestamp to `birthTime` and clears the pending record; failed creation retains it. No baby person or surname is created. A later birth for the same mother replaces an unconsumed event. `birthObservedTime` remains the historical child-object creation event, never an inferred birth. Birth, child-observation and death timestamps are immutable once recorded. Public date strings use `getYearLength()` / `getDayLength()` and the absolute world clock, starting at Year 1, Day 1. Missing legacy events remain unknown; no archive-wide migration is performed.

Surname occupancy is transient and grows with known active members and occupied names. It rebuilds at most one archive page per naming attempt, then updates incrementally. A pending scan is retried through the normal queue. Current loaded members are checked before assigning a new family name. Inheritance, player edits, and existing duplicates are preserved; only new generated names require an unused entry while one remains available. Empty occupancy counts are discarded.

## Trust and access

Recruited nomad families use optional `surnameGroup` person metadata and `recruitGroup:<seed>:<tribe>` records. These are additive schema-1 records, written only from the server recruitment hook after checking actual destination membership, player ownership, and automatic naming. The seed is the smallest member ID for deterministic ordering. Group surnames are generated once, through the bounded occupancy scan, and then reused. The group ID is not an inferred biological parent and is excluded from public network responses. Counts follow a group only while the person's surname matches its recorded shared name; conflicting manual names retain ordinary lineage behavior. No new network action can create or edit groups.

`familyTreeRequest` accepts nine explicit actions: `family`, `familyStats`, `familySummary`, `person`, `household`, `branch`, `list`, `getNameSettings`, and `setNameSettings`. Tribe IDs are derived from the authenticated game connection, never supplied by the client. Person IDs are bounded strings without archive delimiters, whitespace, or control characters. Page indexes must be finite integers from 0 to 1,000,000. Only `familySummary` accepts an optional finite nonnegative integer `revision`; it is a consistency token, never an authorization token.

Loaded objects must have the engine's Sapien type before observation. This prevents a forged family request from feeding a building into automatic naming. A person must currently belong to the requesting tribe or have recorded historical membership. Historical access is deliberate so dead and former members remain in the archive; it is not a snapshot system that freezes data when someone leaves.

Person responses use a field allowlist: identity, display name, tribe, status, death details, and relationship label. Private parent edges, surname ancestry, and raw lineage identifiers are not returned. An ancestor never recorded in the requesting tribe becomes an anonymous unknown node, and traversal stops at that boundary. Child pages filter unauthorized people; candidate counts can include hidden or stale slots.

Custom lists must be dense arrays of at most 128 strings, each at most 96 UTF-8 bytes. Controls, delimiters, and malformed UTF-8 are rejected. Culture selections are known boolean keys; exclusions are bounded to the catalog/migration/custom-list capacity. Unknown top-level settings fields are discarded rather than persisted. Client-side validation is convenience, not authorization.

The mod does not evaluate names as Lua, run shell commands, or construct filesystem paths from requests. This review covers the mod's Lua handlers, not Steam authentication, the engine's network deserializer, or other mods. Input bounds limit work per request after decoding; there is no separate mod-level request-rate limiter.

## UI lifecycle

Serial counters invalidate callbacks after Family navigation, closing the entire options window, reload, or replacement of the Family Tree controls. Saving temporarily locks the editor draft until a response or timeout; a timeout requires reloading the server settings because the save outcome is unknown. Hammerstone eagerly constructs every mod's controls, then switches tabs by hiding persistent views. Creating or showing another mod's panel must therefore leave the Family Tree editor and its pending response alive. Close the old editor only when replacing its own controls, such as Reset, or when closing the options window.

## Compatibility and changes

### Expandable tree (0.12.0)

Every known card exposes both directions, including descendants. The layout first places straight ancestor/descendant branches, then processes a growing work list of placed occurrences. Reversed branches are shifted into the closest free horizontal space, using forbidden shift intervals from cards on matching generation rows. Newly placed occurrences enter the same work list, so nested direction changes work within the existing 256-card limit. Children are ordered by their authorized co-parent identity; unknown co-parents are not treated as one family. Every occurrence is placed once, and every edge moves exactly one generation up or down.

Rendering derives additional edges to an already visible co-parent's other known children, without allocating people or fetching branches. Distinct attachment ports and non-overlapping horizontal routing tracks replace the shared midpoint bus. Disjoint spans may reuse a track; each generation gap grows only as much as its tracks need. Opaque line halos distinguish crossings from junctions. Mother/father roles determine color. Trace filters edges incident to one occurrence; camera, trace, and Fit remain client-only. The 256-card bound also limits supplemental edges (at most one per child), routing work, and rendered line quads.

`treeModel.lua` is an engine-independent occurrence tree; `treeView.lua` renders it using native clipped views and buttons. The family controller owns one tree renderer plus the archive list and settings editor. The old fixed overview renderer and treeMode state have been removed. Opening or refocusing requests `household`: one sanitized root, two parent slots, eight child candidates and their authorized co-parent records. It seeds the model and response cache, shares repeated co-parents in that initial family, and fits the camera once. Statistics updates retain expanded branches and camera state. `person` and `family` remain supported for existing callers and compatibility; the UI no longer uses them. `branch` accepts only `parents` (page zero, at most two anonymous/public entries) or `children` (eight candidates within an existing 32-entry archive page). A child row includes its other parent's name/ID only after a membership check, requiring at most one additional direct record read. Unknown/private co-parents expose neither name nor ID. Neither `household` nor `branch` calls `archive:family`, recursively fetches ancestors, or scans past a filtered page. The same authenticated tribe and historical-membership checks apply to both endpoints.

The initial tree contains at most 19 cards and loads no grandparents or grandchildren. Branch child pagination advances by eight candidates; archive storage and archive-list pages remain at 32 entries. Sparse or corrected pages retain their cursor without scanning ahead. A branch stores open state, loaded children, a candidate-page cursor, and pending/error state. Folding does not refetch or automatically walk deeper branches. A FIFO response cache retains at most 64 pages; occurrence state retains at most 256 cards. Four concurrent branch requests are allowed, with a ten-second UI timeout. Close/refocus creates a new model; Collapse all increments its revision, drops occurrences, and retains only bounded cached responses. Late callbacks cannot reopen or populate an obsolete model/revision. World data is not changed to store expansion/camera state.

IDs already on the occurrence's parent chain are filtered before card allocation and the capacity check, so return links create no extra cards or layout space. This includes valid links back to the focus and inconsistent ancestry loops. Filtering is per occurrence: shared cached response rows stay unchanged, legitimate appearances on different paths remain possible, and the server's next-page cursor is preserved even for an entirely filtered page. Selecting a name starts a new focus with both directions available. Unknown cards remain non-expandable. Maternal and paternal relatives retain the same generation when appropriate; relationship labels and routes distinguish their families.

The viewport uses the game's `setClipChildren(true)` and `mouseDown`/`mouseDragged`/`mouseUp`/`mouseWheel` callbacks. Camera changes are client-only. Cards create native controls when entering the visible area; offscreen cards are removed to release portrait render targets, while the bounded model retains their genealogy. Lines are native clipped quads. Text labels scale separately because standard-button font sizes are fixed. The existing family-statistics calculation remains separate and can read tribe archive pages even when genealogy branches are closed.

### Requested conception (0.11.0)

`familyTree/conceptionRules.lua` contains pure balancing and age/cooldown rules. `conception.lua` owns server validation, bed selection, the rendezvous, and the outcome. `conceptionUI.lua` only presents server results and sends the selected IDs. Small adapters register the native radial plan, order, action sequence, animation, and world update hook. No vanilla fertility update is wrapped or replaced.

The separate `familyTreeConception` endpoint accepts only `list`, `inspect`, and `start`, with bounded IDs and integer pages. It derives the tribe from the authenticated client and resolves live tribe members. It never accepts a supplied probability, father record, cooldown, bed, or outcome. The cosmetic radial plan is rejected by `planManager:addPlans`; only the validated pair endpoint creates the order. The UI lists eight partners per page, checks response generations, polls only while a visible meeting is active, and recovers after a ten-second response timeout.

Records are additive schema-1 keys: `conception:pair:<lowerID>:<higherID>` and a `conception:active` index. One record exists only for an explicitly attempted pair, with a failure count, mother's age deadline, serial, and latest event/result. There is no all-pairs precomputation or history scan. The server checks at most 32 simultaneous events, once per simulation second. Bed searches use the native spatial set, a 60-metre radius, and at most 64 suitable candidates. Partner listing sorts currently loaded tribe members on demand.

The event advances from `travelling` to `meeting` to `finished`. Each order carries the canonical pair key and serial; replacements and stale jobs cannot complete a new event. Both partners must be within three metres of their respective beds and reach the waiting action before they advance together. Each server tick rechecks eligibility and the exact beds. `ftPair` marks mod reservations; it does not replace native bed ownership. If a native sleeper takes a bed, the meeting cancels. Cleanup cancels only this event's matching orders and removes its markers. Object loads and on-demand reads reconcile markers left on unloaded objects after cancellation. Startup allows a short grace period for participants to load.

Cooldown uses `sapienConstants:getAgeValue(mother.sharedState) + 5`, matching the displayed age, rather than calendar `yearLength`. Changing an aging-speed mod therefore changes real elapsed time, not the required five age years. Success is resolved once with the server RNG and the game's normal pregnancy flags, father genetics, notification, and ability/proximity updates. An already pregnant mother cancels the event before the roll. Natural reproduction never consults pair records.

The probability is `clamp((.15 + .30*M + .10*F + .15*B + .10*H + .10*S) * P, 0, .85)`, where all factors are clamped to 0–1: `M=(50-motherAge)/25`, `F=(80-fatherAge)/40`, `B=average(shortBond+shortMood)/2`, `H=average(happiness)/5`, and `S=storedFood/(population+1)`. `P` is the remaining fraction after the native tribe/global soft-cap pressure calculation. It is a design formula for manual attempts; the native timer and random father selection remain separate.

Custom stationary actions are registered with the server AI and cannot auto-complete. The client animation VM maps only their animation-selection actions to native `idle` to avoid the engine's unknown-action branch; replicated sequence and progress IDs stay custom. A client animation adapter selects the new pose sequence only during the meeting. No tools, audio, or particle triggers are copied into the animation. Automated tests simulate rendering and movement, so they cannot confirm real terrain routing or final visual appearance.

- Do not reorder assignment pools merely to change display order. `sortedNames` sorts a copy.
- Keep legacy single-culture settings and `renamedNames` migrations; old saves still depend on them.
- Keep the three obsolete-file names in the updater; they remove incompatible old UI modules and the superseded German README after backup.
- Defaults remain automatic naming OFF with no selected culture. Update settings validation and tests when adding groups.
- Keep schema 1 unless storage semantics actually require migration. Multiplayer host and clients should run the same release.
- The updater refuses a running game, checks destination paths for junctions, backs up all installed FamilyTree targets, and verifies copied file hashes. It does not edit world database contents or delete unrelated mod files.

## Review and validation: 0.9.1

The review confirmed and fixed non-Sapien request side effects, incomplete ancestor redaction, mutable nested cache data, and insufficient settings shape/size validation. A regression test reproduced the building-request failure before the fix. Tests cover these boundaries, malformed UTF-8, rejected saves preserving prior settings, world reset, and events emitted during bridge initialization.

The 0.9.1 editor-lifecycle change incorrectly treated another mod's control construction as a close event. With Family Tree followed by Precise Rotation, it discarded the pending settings response and left the loading text visible. Version 0.9.2 corrects that regression. The expanded test executes the installed Hammerstone options module with two mod configurations, reproduces the old failure, and verifies settings rendering, tab switching, hide/reopen, and reset replacement after the fix. View rendering remains simulated.

Remaining limits: native database atomic-key ordering and power-loss durability are not proven by Lua adapter tests. Pre-journal orphan records cannot be discovered without a separate inspection/repair operation and are not silently reset or migrated. Cold statistics indexing may still walk up to 256 ancestors per candidate; large histories take time. Tests use the installed game's LuaJIT with simulated UI/databases, not a running multiplayer world. Actual loading times in 100+ year worlds remain separate validation tasks.

### Audit fixes (0.14.2)

An observation first plans the person and up to three index updates (at most ten key/value writes). `pendingWrite` persists this complete intent before applying it. Replay writes the same values, then clears the journal with `false`; it finishes before a new operation or a read. Startup reads only schema and journal. The archive has a single server-VM writer; this is an ordered single-key-write recovery protocol, not a cross-store transaction with native Sapien state. Existing schema-1 keys remain compatible. Recovery failures propagate and retain the intent. Do not downgrade to a version that ignores a pending journal. Ordinary unchanged observations still cause no writes. Successful observations retain incremental surname occupancy; interrupted recovery discards it so it rebuilds safely.

`requestScope.lua` owns one panel RPC and its ten-second timer. Completion/cancellation is one-shot, removes the timer, and invalidates delayed or duplicate callbacks. Family navigation, initialization, settings close and hide cancel the panel's pending request. The existing branch/conception mechanisms retain their own independent request budgets. A save timeout does not establish failure: the editor discards the editable draft, explains that the outcome is unknown, and requires a server reload. Initial loading/statistics timeouts render an error and keep recovery navigation available.

The new `familySummary` endpoint builds a transient per-tribe lineage index in 32-candidate chunks. `pending` responses keep page zero until the index is complete. It then pages only the requested family's member IDs. No private lineage IDs/maps leave the server. At most four tribe indexes are retained, each proportional to its recorded members. Archive observations/index changes and recruitment-group writes advance an in-memory revision; changed revisions invalidate cached classification and reject in-flight mixed-revision pagination. UI totals use the returned revision on subsequent requests. Counts, oldest selection and ages are never cached: each family page inspects current objects. The legacy `familyStats` endpoint retains its original behavior for existing callers. Both endpoints share the same member-counting implementation. The cold index still scans historical candidates; warm refocus avoids scanning unrelated families.

### Card portraits (0.14.3)

`treeView.lua` uses the installed game's `uiGameObjectView:create` / `setObject` API with `backgroundCircle`, using only `playerSapiens:getInfo` for a known, non-deceased card. No appearance fields are sent through the family RPC or added to the archive. Missing appearances use a text placeholder. The 64-unit portrait sits at x=206, y=49, above the branch buttons. A clipped 190-unit details column prevents text from overlapping it. Portraits follow card zoom. Panning removes offscreen cards and their native render targets; returning recreates them locally. Closing clears the card content. No network requests or database writes are added by portraits. Automated tests simulate drawing; actual appearance uses the native renderer.

### Living age display

Public person rows receive an ephemeral `age` only for a loaded, typed Sapien currently in the authenticated tribe, with valid native age state and no archived death. It uses `floor(sapienConstants:getAgeValue(sharedState)) + 5`, matching the game's `getAgeDescription`. Dates and age years are distinct. This adds only bounded object lookups for requested rows, without archive writes, recursive loading or polling. Cached tree pages retain the snapshot until refreshed. Unknown/unavailable ages are never extrapolated; deceased records keep `ageAtDeath`.
