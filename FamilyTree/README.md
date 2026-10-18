# Family Tree

Version 0.14.4 - by Vittorio

Tree cards show a small native portrait when the person is available in the current tribe's follower data. Portraits scale with the tree and use the space beside the person's details. Historical or unavailable people without appearance data show "No portrait"; older records cannot reconstruct their faces.

Get to know the families behind your tribe. Unfold generations in a family tree you can drag and zoom, find living relatives, and remember those who came before them. Give families a lasting name with optional surnames inherited from either parent, drawn from twelve cultures, or add your own. Nomad groups joining together share a family name. Automatic naming starts off until you choose your settings. New families receive unused names while your selection still has names available. Names you change yourself stay just as you chose them.

## Family view

Select a Sapien and open **Family**, beside **Roles** and **Inventory**. One expandable tree opens directly, showing the selected person, their parents, up to eight children, and those children's known co-parents. Repeated co-parents are shown once in the initial family. Further children and generations stay closed until requested. To explore siblings, open a parent's Children branch. There is no separate Overview / Explore tree mode.

- **Starting Sapien** returns to the person selected when the panel opened.

- **Back** restores the previous person, relationship view, and page.

- **Archive** lists recorded tribe members, including deceased members.

- The magnifying glass moves the camera to an available living person and opens their inspection view. It is disabled for deceased or unavailable people.

- Family totals distinguish living tribe members, deceased members, and absent or unconfirmed members. A star marks the oldest confirmed living member of the family in the tribe; the Oldest button focuses that person even when their card is outside the current view.

- **Refresh** updates the displayed information. Counts reflect the time of the request, rather than a continuous live total.

Family counts follow the recorded parent used for surname inheritance or an explicitly recorded recruited family group. Legacy records retain the previous paternal lineage with maternal fallback. Unrelated founders sharing a surname are kept separate. Missing ancestry may split a lineage. These counts do not include every biological relative across both parents' families.

## Navigating the tree

Open **Family → Explore tree**. The selected person is the focus, outlined in gold. The new view uses generation rows and connected person cards, inspired by a dynasty tree while keeping the game's interface style.

- **+ Parents** and **+ Children** are available on every known person's card, including descendants and side branches. You can open a child's other parent and that parent's family, or an ancestor's other children, without changing focus. Parents appear one generation above their child; children appear one generation below their parent. Branches that change direction use separate horizontal space to avoid overlaps; drag sideways to reach wide branches. Select a person's name to make them the focus.
- **- Parents / - Children** folds a branch, including its visible descendants. Reopening it reuses already loaded information. **More** loads the next page of children; each page contains at most eight candidates. Pages may contain fewer or no visible entries when records are private or a parent link was corrected.
- Drag empty canvas space with the left mouse button to move the tree. Use the mouse wheel or **- / +** to zoom from 20% to 130%. **Center** brings the focus back into view. **Fit** centers the explored tree and reduces its scale within this range; very large trees may still require panning.
- Mother connections are pink, father connections blue, and unspecified connections gold. Each link has its own attachment points; overlapping routes use separate tracks. Gaps at crossings distinguish a crossing from a junction. **Trace** on a card shows only that occurrence's visible direct connections; **All** restores every connection, without fetching more people.
- Children of the same known parent pair are grouped together. Child cards identify the parent they were opened from and the other recorded parent. Already visible co-parents also connect to their other visible, known children. Maternal and paternal relatives stay on their correct generation rows; sharing a row does not mean sharing parents. **Generation -1** is one step above the focus; **+1** is one below.
- Living tribe members show **Alive | age N**, matching the native Sapien list. Age is read when the person is loaded into the tree; use **Refresh** or reopen Family to update cached cards. Unavailable ages remain unknown. Deceased people retain their recorded age at death.
- **Born** and **Died** show the recorded world year and day, using the world's calendar lengths (year/day numbering starts at 1). These are not Sapien age years or the tribe's day counter. Actual births are recorded from this version onward and attached when the independent child appears. Missing older birth dates remain **Unknown**. For living people with only the older child-creation record, **Child since** labels that distinct event. Historical deaths already recorded by the mod can be dated; missing dates are never invented.
- The magnifier visits a currently available living Sapien. Deceased and unavailable people remain readable but cannot be visited. The star retains the oldest-living-member marker for the focus family; recorded family totals remain above the canvas.
- **Back** returns to the preceding focused person. **Starting Sapien** returns to the person originally selected. **Archive** opens the paged tribe records; choosing a person returns to their tree. **Names** opens the shared surname editor. Back from either returns to the preceding view.
- **Collapse all** clears expanded branches and recenters the focus, retaining a bounded response cache. **Refresh** discards cached tree data and reloads the current focus. Closing Family or selecting another Sapien releases the view. Expansion and camera state are temporary and are not written into the world save.

The initial family is limited to two parent slots, eight child candidates and their known co-parents (at most 19 cards). Grandparents, grandchildren, and additional children are requested only when their branch or More control is opened. Moving or zooming does not contact the server. Family totals use the existing separate paged calculation; they do not recursively expand the tree. The view is limited to 256 loaded card occurrences and 64 cached branch pages. If it fills up, focus a person or use **Collapse all** to continue. The same ancestor can appear on different lineage paths; a person already on the current path is omitted entirely, preventing cycles without adding duplicate cards or empty space. A branch with no additional visible people shows **No new people**; **More** remains available if another page exists. Unknown or inaccessible ancestors remain anonymous, and no missing genealogy is invented.

## Try for a Baby

Select an adult member of your tribe and choose **Try for a Baby** in the circular action menu. Choose the other partner in the window, review **Low / Medium / High** and the estimated percentage, then press **Try for a Baby**. Unavailable pairs show the reason and a disabled start button. The window updates automatically while a meeting is in progress and can be closed without interrupting it.

- Both partners must be at least 18, belong to your tribe, and meet health, hunger, and loyalty requirements. The pair must include one female and one male Sapien. The mother must be within the game's adult pregnancy age range, neither pregnant nor caring for a baby. The game's recorded close-family relationships exclude a pair; a shared surname alone does not.
- Two completed beds must be within 12 metres of each other and within the 60-metre search area around the initially selected Sapien. Beds occupied, reserved, or individually assigned to someone outside the pair are excluded. A campfire is not required.
- Each partner walks to one bed. When both arrive, they perform a synchronized, non-explicit twelve-second stand/crouch/sit animation beside the beds. This uses the native skeleton and poses. Ordinary work can be interrupted to attend; dangerous actions and other known special visits are not interrupted.
- The chance depends on age, existing relationship scores, happiness, stored food, and population pressure. These are game-balancing probabilities, not a hidden vanilla percentage. **Low** is below 35%, **Medium** is 35% to below 65%, and **High** is at least 65%. The maximum is 85%. Conditions are checked again at completion, so the final chance can change during travel.
- After three unsuccessful completed attempts, **that pair** is blocked until the mother's displayed age has advanced by five years. The failure count and cooldown survive save/reload and apply regardless of which partner opens the menu. Once the cooldown expires, the pair starts a fresh cycle. A successful attempt resets the count.
- Interrupted travel, unreachable or newly occupied beds, changed eligibility, and a naturally occurring pregnancy cancel the meeting without a failure. Travel times out after about five simulation minutes. Closing the window is not a cancellation.
- Natural pregnancies remain independent of pair attempts and cooldowns. A successful requested attempt starts the game's normal pregnancy with the selected father; subsequent pregnancy, birth, and surname inheritance follow the existing game and mod rules.

At least **five stored food items** are required, just as in the game's natural pregnancy gate. Fruit still growing on trees does not count. Population-growth restrictions and the population cap still apply. Disabling automatic surnames does not disable this manually requested action.

## Surnames and settings

Open **Mod Options â†’ Family Tree** when Hammerstone is installed, or **Family â†’ Names** with or without Hammerstone. Both editors use the same settings, saved per tribe in the world database. Hammerstone is optional.

- **Automatic names ON/OFF** controls new automatic assignments and inheritance. Existing names remain unchanged. Assignments begin with the independent child object; the preceding baby phase is not processed.

- In **Culture groups**, tick any combination of **Roman**, **Greek**, **Japanese**, **English**, **French**, **Russian**, **Sumerian**, **Aztec**, **Spanish**, **Arabic**, **German**, **Ancient Egyptian**, and **Custom list**. Open **Names** beside a group to tick individual surnames, with **Select all**, **Clear all**, and paged lists. The name view uses nine rows across as many columns as the panel width permits (typically 27 or 36 names per page). Each of the twelve built-in culture groups contains 128 distinct entries; custom lists retain their separate 128-name limit. A disabled group contributes no names even if its individual boxes are checked.

- Enabled groups are merged into one pool of distinct names. Unchecking a name excludes that spelling across all groups. Automatic assignment requires at least one available name; an empty selection can be saved while automatic names are off. Existing single-choice settings migrate to the corresponding checked groups, preserving any previously saved selection.

- Built-in names use Latin-script spellings and invariant fictional house-name forms. The Russian list does not change surname endings by gender. Sumerian and Aztec entries include personal/ruler names and invented single-word names inspired by cultural sounds, used as fictional hereditary house names for gameplay. They are not a list of 128 historically attested surnames, and these names do not claim historical or linguistic accuracy.

- Select **Paternal (father)** or **Maternal (mother)** using the mutually exclusive checkboxes. Children inherit the selected parent's recorded surname, including from a deceased parent. If that parent is unknown, the other parent is used as fallback. Without an inherited surname, a name is selected deterministically from the chosen pool.

- Changing the pool does not rename existing families. Names remain stable after leaving and rejoining a tribe or discovering additional ancestry.

- When automatic naming is ON, a nomad group recruited together receives one shared surname and is counted as a family. Group membership comes from the game's shared nomad tribe, not physical proximity. Only members that actually joined the player's tribe participate. A player-edited surname is preferred as the shared name; otherwise an existing automatic surname is reused, or a new unused name is selected from the enabled pool. Conflicting player edits and deliberate surname removal remain unchanged. Automatic surnames may be unified when the group joins. Biological parent relationships are never invented. Individual recruits from settled tribes retain the normal naming rules. This applies to future recruitment events, not previously recruited groups. Recruitment while automatic naming is OFF does not create a naming group.

- New surname assignments prefer names not currently held by another member of the tribe. Repeats are allowed only once every enabled name in the combined pool is occupied (128 names if all Ancient Egyptian names alone are enabled). Inheritance deliberately shares the parent's name. Existing duplicates and player edits remain unchanged. Known deceased or removed members do not reserve names; unavailable members last recorded alive still do. Current manual names also count, using ASCII case-insensitive comparison.

- **Ancient Egyptian** includes 128 single-word, Latin-script names, with four or five entries for every initial A–Z. To provide this balanced alphabet, the pool mixes historical personal-name spellings with invented Egyptian-inspired house names; it is not a collection of 128 historically attested surnames.

- To create a custom list, open **Custom list editor**, enter names separated by semicolons and click **Add**. **Remove** deletes a list entry without renaming anyone. Up to 128 unique names are supported, with a limit of 96 UTF-8 bytes per name. Spaces within names are allowed. An empty **Custom list** contributes no names; other enabled groups remain available.

- **Save** applies the settings. **Reload** discards unsaved changes. **Defaults** and Hammerstone's **Reset to default** prepare defaults that must also be saved. Defaults are automatic assignment OFF, no culture groups selected, paternal inheritance, and an empty custom list. To enable naming, choose the desired culture groups or custom list, switch Automatic names to ON, and click Save.

Player-edited full names are preserved exactly, including deliberate surname removal. The first whitespace-separated part is treated as the given name and the remainder as the inheritable surname. A single-part name receives no appended surname; future children without an inherited surname can receive one from the selected pool. Already named children are not renamed retroactively.

Changes made under an older version can be protected if they still differ from the stored automatic name. Names already overwritten by an older version cannot be reconstructed.

When automatic assignment is enabled, existing unnamed members are processed during normal observation, such as loading the world or opening their family. New recruits, recruited groups, and newly created child objects are recorded automatically.

## Installation and updates

Close Sapiens before updating. Copy the `FamilyTree` folder into the game's user-data `sapiens/mods` directory, keeping `modInfo.lua` directly inside that folder. Restart the game and enable **Family Tree** as a world mod when creating a world. Keep the mod folder name unchanged.

The supplied `family-tree-tests/update_installed.ps1` updater backs up installed Family Tree copies, updates their files, removes superseded files, and verifies file hashes. When updating manually from 0.1.x, remove `scripts/mainThread/ui/manageUI/familyTreeUI.lua` and `scripts/mainThread/ui/manageUI/tribeCollection.lua`. Custom UI modules now use `scripts/familyTree` for Hammerstone compatibility. Replace the former German `README-DE.md` with this English README.

Existing worlds without Family Tree require a separately verified migration procedure. See the [official mod creation guide](https://github.com/Majic-Jungle/sapiens-mod-creation/wiki/Getting-Started) for world-mod setup. Restoring older mod files does not undo names already saved in a world.

## Records and performance

The world archive stores compact person records and paged child/tribe indexes. Deceased members remain recorded. Missing details are not invented. `[d.]` denotes a deceased person; a last observation alive does not confirm the current state of an unavailable person.

Lists use 32 entries per page and the read cache holds up to 256 database entries, including index pages and missing-record lookups. Unchanged observations do not produce additional writes. The archive grows with recorded people and relationships, without comparing every possible pair.

Initialization reads the archive schema and one recovery journal, then processes up to four queued people per server update. This is a person-count limit, not a fixed millisecond budget. Child creation and death are recorded immediately. Family relationships and counts are calculated on request, with ancestry walks limited to 256 steps and cycle checks. The first count builds a transient lineage index one archive page at a time. Reopening or focusing another person reuses it until records change and reads only that family's members. Live presence, age and oldest-member selection are recalculated. At most four tribe indexes are retained; their memory grows linearly with recorded members. Derived results are not permanently stored.

The surname occupancy index is built only when a new family needs a name, reading at most 32 archive records per attempt. Assignment waits in the normal observation queue until the index is ready. Subsequent observations update this in-memory index incrementally. Each new generated name also checks loaded tribe members for recent joins and manual edits. This avoids repeated history scans, but work still scales with the current tribe population. The index is rebuilt lazily after reloading a world; it is not persisted.

## Limitations and validation

- People deleted before the mod recorded them may only survive as incomplete references.

- Recorded child creation is an observed event, not a guaranteed biological birth timestamp. Babies are not separate archive members.

- Cousin labels and general kinship degrees are not implemented. The expandable view explores selected ancestor/descendant branches rather than drawing every family in the world at once.

- Sibling pages filter duplicates and the selected person, so some pages may contain fewer entries.

- Requests are restricted to historically recorded members of the player's tribe. Unknown or outside-tribe ancestors cannot be explored further.

- Mods replacing the same `inspectSapienRelationshipsView` content may conflict. Universal compatibility has not been established.

- Person and index updates use a bounded recovery journal. An interrupted journaled operation is replayed before further reads or writes. This assumes atomic, ordered single-key writes by the native database; power-loss durability is not guaranteed. Old inconsistencies created before this version have no journal and are not silently migrated or reset. Back up the world before updating and do not downgrade while recovery is pending.

Automated tests use the installed game's LuaJIT and cover archive records, genealogy, pagination, caching, network validation, tribe access, naming, manual rename protection, settings persistence, optional Hammerstone integration, and UI behavior with simulated views. Version 0.9.2 also tests the installed Hammerstone options module's real multi-mod initialization, tab switching, reopening, and reset behavior. It fixes the settings panel remaining on "Loading name settings..." when other mods offer options. In-game validation of this hotfix remains pending.

Synthetic tests with 5,000 and 50,000 records use an in-memory database and do not measure real world-loading times. Performance in worlds aged 100+ years still requires repeated measurements of load time, memory, and frame time under comparable conditions. Longer-term validation should also cover deaths, save/reload cycles, emigration, multiplayer tribe isolation, UI scaling, and long names.

## Cultural name references

The Sumerian-inspired pool includes names attested in museum records, such as [Ur-Ningirsu and Gudea](https://www.metmuseum.org/art/collection/search/329069). The Aztec-inspired pool uses personal and ruler names; see the [list of rulers of Tenochtitlan](https://en.wikipedia.org/wiki/List_of_tlatoque_of_Tenochtitlan). These sources provide name context, while hereditary use is a gameplay adaptation.

New catalog entries start enabled within an enabled culture group. Previously excluded names remain excluded by spelling; newly added culture groups start disabled. Already assigned and player-edited names remain unchanged.


## Maintenance

See [ARCHITECTURE.md](ARCHITECTURE.md) for module responsibilities, data boundaries, compatibility rules, and the security review. Release history is in [CHANGELOG.md](CHANGELOG.md). Test setup and commands are in `family-tree-tests/README.md` in the source package.
