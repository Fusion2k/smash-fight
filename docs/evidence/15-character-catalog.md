# Character catalog evidence (#15)

Implemented source: the commit containing this report, based on `a56e7d6d3fcdb28bb04a53c63761220df6cd847a`. The issue resolution records the final commit and post-commit run. Date: 2026-11-15. Host: Windows, Windows PowerShell 5.1, Standard Godot `4.7.2.stable.official.ed1daf0bf`, headless Compatibility renderer, project 1280x720 canvas_items/keep/fractional settings. No controller or display hardware is exercised.

Command (replace the local engine path on other PCs):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/dev.ps1 check -GodotBin C:/tools/Godot4/Godot_v4.7.2-stable_win64_console.exe -TimeoutSeconds 15
```

Expected: bounded import completes; foundation and catalog completion markers appear; exit 0. Actual: exit 0, 7 foundation assertions and 60 catalog assertions passed. Final pre-commit logs are retained locally under ignored `build/logs/20261115-190106-941-10168/` (stdout/stderr per process plus `run.json`). The exponent-overflow negative fixture intentionally produces Godot's `Exponent too high` warning; the catalog rejects that nonfinite value. There are no unexpected engine/script errors.

| Delivered check through production interface | Actual result |
| --- | --- |
| Load native Zip/Bramble CharacterDefinition, seven MoveDefinitions each and their scenes/JSON | Both prepare successfully; repeated Zip selection has separate PreparedCharacter containers |
| Aggregate independent schema/editor errors | File/field errors include unknown/missing keys, forbidden JSON geometry, wrong numeric types/ranges, fast-fall ordering, bad version, invalid/missing/duplicate move IDs, unsupported shapes, invalid timing/offset/launch |
| Missing file, directory, malformed JSON, invalid root and missing Inspector path | All unavailable; syntax error includes line; no partial prepared selection returned |
| Save changed Zip mass/damage and prepare again | New settings change; active snapshot and Bramble stay unchanged |
| Delete/corrupt file, correct and retry in same process | Corrected preparation succeeds without editor/process restart |
| Mutate getter dictionaries and native shapes | Active snapshot, repeated selection and authored Resource stay unchanged |
| Instantiate two prepared scenes and change one's surface/hurtbox Resources | Other instance and authored scene unchanged |
| Change referenced move/scene shape after preparation | New preparation sees edits; old prepared move and instantiated scene retain prior dimensions |
| Root/shape transforms and unsupported hurtbox geometry | Rejected with scene paths; no rotated/scaled rectangles silently treated as translation-only |

The checks use `CharacterCatalog.prepare_match` and PreparedCharacter methods, actual ResourceLoader content, native RectangleShape2D/CharacterBody2D scenes, and real temporary file IO in `user://`. They do not invoke a parallel test-only validator. Test fixtures explicitly detach move arrays and shape Resources: shallow/external Resource aliasing cannot be used as proof of production isolation.

Development failure traces remain locally in `build/logs/20261115-185821-931-9100/` (GDScript inference compile error caught by the bounded runner), `20261115-185925-690-23948/` (test fixture external-Resource aliasing), and `20261115-185700-805-1576/` (sandbox prohibited normal editor-settings write during import). These were corrected or rerun with engine user-settings write access. Logs are machine-local diagnostics, not required source files.

Scope: A1 and content portions of A2 are delivered. Static original silhouettes and provisional tuning are present; attack pose animation/feedback is #19. Prepared settings contain no mutable Character state. Movement, jump/recovery consumption, damage, attack history, local pause, respawn and actual match lifetime must still be implemented and checked in #16/#17/#18. UI diagnostics/start gating, Developer Test restart, package JSON inclusion, physical feel/recovery reach, controllers and native Deck/performance acceptance remain their named later gates. No complete gameplay or hardware gate is claimed.
