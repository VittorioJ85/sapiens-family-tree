# Project instructions

## Engineering approach

- Approach work throughout this project from the perspectives of an experienced senior software engineer, software architect, QA engineer, security reviewer, and debugger.
- Apply these perspectives to architecture, implementation, maintainability, quality assurance, security review, and systematic root-cause analysis as appropriate to the task.
- Clearly distinguish verified results from assumptions and unresolved issues, and report relevant testing and its limitations accurately.

## Game installations

- The user identifies `D:/Steam/steamapps/common/Sapiens_NICHT_BETA` as the public release of Sapiens, not the unstable beta.
- The user identifies `%APPDATA%/majicjungle/sapiens_NICHT_BETA` as the corresponding public-release user data directory. Use this directory for public-release saves, logs, and installed mods; keep its data separate from unstable-beta data.
- Use this installation when inspecting public-release game code or checking public-release compatibility. Keep findings for the public release separate from unstable-beta findings, and state which installation was inspected or tested.

## Mod author and language

- For every mod created for this project, set the developer/author to `Vittorio` in its metadata and author credits.
- Write all mod content and descriptions in English, including user-facing text, names, tooltips, documentation, and release descriptions.

## Mod code quality and security

- Whenever creating or updating a mod, review and adjust its code to keep it well structured, maintainable, and free of unnecessary duplication.
- Check the mod code for security vulnerabilities and address any issues found.
- Add clear English documentation and comments where they help explain behavior, non-obvious logic, assumptions, or maintenance requirements.
- Remove unnecessary, obsolete, or unused code, verifying that it is not required by game callbacks, mod registration, or other runtime entry points.

## Shared model assets (all mods and future building parts)

- Reuse a single GLB for identical geometry, UVs, helper nodes, collision and camera data; express material-only variants through explicit material mappings and stable model aliases.
- Before adding or regenerating models, check for structural duplicates. Keep genuinely different geometry and detail levels separate. Never merge by visual resemblance alone.
- Preserve existing model names and buildable/object identifiers, compose material mappings correctly, and verify LOD behavior and third-party material compatibility. Do not assume native chained remaps compose automatically.
- Keep consolidation reproducible in build tooling; validate alias targets, reject cycles/path traversal, and test both supported game editions. Report in-engine validation separately from offline checks.
- Finalize generated GLBs with the shared build tooling, including lossless vertex packing: merge only complete byte-identical attribute tuples within a primitive, preserve ordered triangle attributes and four-byte vertex alignment, and keep unsupported layouts unchanged. Update normalization hashes together with repacked files; retain a full source snapshot before overwriting buffers. Generators must honor indices, accessor offsets and strides.
- Evaluate further placement sharing per independent slot component and in both directions, including any extra files caused by splitting existing material aliases. Accept only positive net reductions and compose new authoring transforms with existing metadata; a whole-family result is not sufficient to reject every subset.
- Batch model generators must read all logical inputs from an immutable snapshot or buffer them before writing any shared canonical asset. Later alias reads must not observe a mixture of authoring and normalized runtime geometry.
