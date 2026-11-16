# Smash Fight

A Godot 2D local multiplayer platform fighting game inspired by Super Smash Bros. Ultimate, with original characters and art. Players build damage, launch opponents out of the arena, and compete for the last remaining stocks.

The first-playable specification is accepted; implementation is tracked through GitHub Issues. Start with [Scope the first playable Smash Fight](https://github.com/Fusion2k/smash-fight/issues/1) for the completed decision map and research.

## Engine and platforms

| Area | Target |
| --- | --- |
| Engine | Godot **4.7**, pinned to **4.7.2** for this project |
| Final play environment | Steam Deck running **SteamOS**, using a **native Linux build** |
| Display and performance | Connected TV with **1920 x 1080 output at a steady 60 FPS**, including eventual four-player matches |
| Current development and testing | Windows, to speed up iteration |
| Multiplayer | Local only; two players in the first playable, designed to grow to four |
| Controls | Gamepads for play; keyboard for quick developer testing |

Windows is the initial iteration environment. Final platform acceptance will also require testing on the actual Steam Deck and TV setup, including external controllers, presentation, and performance.

The SteamOS/native Linux delivery path and 1080p/60 FPS goal are agreed targets. #9 accepts Compatibility and a 1280 ? 720 logical layout rendered at actual display resolution with fractional `canvas_items` scaling and fixed 16:9 framing; the 1080p TV fills the layout, while taller displays letterbox it. The accepted workflow is documented in [Development workflow](docs/development-workflow.md). See [Choose the cross-PC setup and daily development workflow](https://github.com/Fusion2k/smash-fight/issues/9) and [Define first-playable acceptance checks and the implementation handoff](https://github.com/Fusion2k/smash-fight/issues/10).

## First playable

- Complete, restartable two-player local matches.
- Two distinct characters and one simple arena.
- Rising damage percentages, knockback, ring-outs, and stocks.
- Responsive movement and combat, with basic player/damage/stock displays and enough feedback to judge game feel.
- Placeholder art where useful during development.

The agreed movement, attack, defense, recovery, and match rules are specified in [Define first-playable movement and combat rules](https://github.com/Fusion2k/smash-fight/issues/2). The agreed controls, controller ownership, selection, pause/reconnect, and developer keyboard path are specified in [Define gamepad ownership and the local match flow](https://github.com/Fusion2k/smash-fight/issues/4). These are specifications; gameplay implementation and playtest validation are still upcoming.

The [first-playable acceptance and implementation handoff](docs/first-playable-acceptance.md) is accepted in #10. It defines observable automated and human checks plus dependent implementation issues; it does not claim a playable build.

## Design direction

- Give scenes and gameplay modules clear responsibilities and small interfaces. Keep ordinary changes local and avoid monolithic scenes or scripts.
- Keep each character's physics tuning and per-attack damage in one human-editable JSON file referenced from Godot's editor. Author graphics-dependent properties, including hitboxes, hurtboxes, sizes, offsets, attack timing, and launch direction/strength, in the editor. The accepted schema and validation contract are specified in [character authoring](docs/architecture/character-authoring.md) and #7.
- Keep character definitions separate from mutable match state. Two instances of the same character must be able to act independently.
- Keep the project portable between development PCs; resolve the Godot executable locally rather than embedding one machine's installation path.

GDScript and built-in GodotPhysics2D are accepted in #8. See [Define Godot scene responsibilities and gameplay module interfaces](https://github.com/Fusion2k/smash-fight/issues/8) and [Choose the character file schema and tuning workflow](https://github.com/Fusion2k/smash-fight/issues/7) for the decisions behind these areas. The evolving [architecture documents](docs/architecture/README.md) include a [scene map](docs/architecture/scene-map.md), match-flow and combat diagrams, state/content constraints, and linked ADRs. The user confirmed #8's complete architecture on 2026-11-15, including native interval prediction/commit and chronological event ties. Scene paths are accepted implementation targets; gameplay scenes, integrated native scheduling and acceptance remain upcoming work.

## Opening the project

1. Install Godot **4.7.2** for your development PC. Use the Standard distribution and matching Standard export templates. GDScript is accepted in #8; [the #9 workflow](docs/development-workflow.md) documents portable local discovery, delivered check/editor commands, and future play/test/export commands.
2. Clone this repository and import the root [`project.godot`](project.godot) through Godot's Project Manager.
3. Read the relevant GitHub issue before making changes, along with the [glossary](GLOSSARY.md) and any applicable architectural decision records under `docs/adr/`.

On the current Windows PC, Godot is installed under `C:\tools\Godot4`. Other PCs may use a different location. The repository contains the launcher, engine/window and character-catalog checks, Compatibility/1280x720 layout configuration, and editor-authored Zip/Bramble Resources with physics/damage JSON. Runtime gameplay and a runnable match are upcoming work.

The separate [`prototype/combat-timing` branch](https://github.com/Fusion2k/smash-fight/tree/prototype/combat-timing) contains the runnable timing lab for #11. Its Windows launcher is **Run Combat Timing Lab.cmd** in that branch's worktree. See the [experiment evidence and instructions](docs/architecture/combat-timing-evidence.md); the main project does not run that lab.

The completed [Research a portable Godot 4.7.2 development workflow](https://github.com/Fusion2k/smash-fight/issues/6) covers version checks, imports, export templates, and verification options. The shared `tools/dev.ps1` launcher now delivers check/editor commands and foundation checks (#14); catalog checks are delivered in #15; automated gameplay checks are still upcoming.

## GitHub task workflow

[GitHub Issues in Fusion2k/smash-fight](https://github.com/Fusion2k/smash-fight/issues) are the source of truth for tasks, specifications, questions, and their resolutions. Use issues to request work; pull requests are for reviewing proposed code changes.

### Planning decisions

The wayfinder map organizes decisions that must be settled before implementation:

1. Open [Scope the first playable Smash Fight](https://github.com/Fusion2k/smash-fight/issues/1) and inspect its native child issues.
2. Choose the first open, unassigned child with no open blockers, or an explicitly requested eligible ticket. Assign it to the developer driving the work before starting.
3. Work according to its label: `wayfinder:grilling` for a human discussion, `wayfinder:research` for evidence, `wayfinder:prototype` for an experiment with human feedback, or `wayfinder:task` for prerequisite work.
4. Record the answer in a resolution comment, close the ticket, and add a named link plus a short gist to the map's **Decisions so far**.
5. Create newly revealed decision tickets and connect native parent/blocking relationships as needed.

Map and decision issues carry only `wayfinder:*` labels. They stay separate from implementation-task triage. Research artifacts may live on linked throwaway `research/` branches; those branches are not implementation branches and are not merged.

### Implementation tasks

1. Create an issue describing the problem or desired outcome, relevant decision/spec links, and observable acceptance criteria.
2. Triage it with the repository's labels:

   | Label | Meaning |
   | --- | --- |
   | `needs-triage` | Maintainer evaluation needed |
   | `needs-info` | More information needed |
   | `ready-for-agent` | Fully specified and ready for an agent |
   | `ready-for-human` | Requires human implementation |
   | `wontfix` | Will not be actioned |

3. Start ready work when its blockers are closed. Read its linked decisions, make a focused change, and keep the issue connected to the work.
4. Verify the acceptance criteria and record results and remaining limitations in the issue or linked pull request. Use Windows for quick iteration and Steam Deck checks where the acceptance criteria concern the final platform.
5. Post a resolution comment before closing the issue. Update affected documentation and record consequential architectural trade-offs when justified.

For CLI work, use `gh` and explicitly target `--repo Fusion2k/smash-fight`. The repository conventions are documented in [Issue tracker](docs/agents/issue-tracker.md), [Triage labels](docs/agents/triage-labels.md), and [Domain docs](docs/agents/domain.md).

## Reference documentation

- [Project glossary](GLOSSARY.md)
- [Architecture documents and diagrams](docs/architecture/README.md)
- [Scene map](docs/architecture/scene-map.md)
- [Player-slot identity decision](docs/adr/0001-player-slots-and-controller-assignment.md)
- [Godot 4.7 documentation](https://docs.godotengine.org/en/4.7/)
- [Godot 4.7.2 download archive](https://godotengine.org/download/archive/4.7.2-stable/)
- [Valve Steam Deck specifications](https://www.steamdeck.com/en/tech)
- [Valve Steam Deck compatibility guidance](https://partner.steamgames.com/doc/steamhardware/compat)
