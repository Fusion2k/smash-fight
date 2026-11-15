# Smash Fight

A Godot 2D local multiplayer platform fighting game inspired by Super Smash Bros. Ultimate, with original characters and art. Players build damage, launch opponents out of the arena, and compete for the last remaining stocks.

The project is being scoped through GitHub Issues. Start with [Scope the first playable Smash Fight](https://github.com/Fusion2k/smash-fight/issues/1) for the current decision map, completed research, and outstanding questions.

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

The SteamOS/native Linux delivery path and 1080p/60 FPS goal are agreed targets. Internal rendering resolution, scaling, and renderer selection remain design decisions; 1080p describes the TV output target. Track the remaining setup and verification choices in [Choose the cross-PC setup and daily development workflow](https://github.com/Fusion2k/smash-fight/issues/9) and [Define first-playable acceptance checks and the implementation handoff](https://github.com/Fusion2k/smash-fight/issues/10).

## First playable

- Complete, restartable two-player local matches.
- Two distinct characters and one simple arena.
- Rising damage percentages, knockback, ring-outs, and stocks.
- Responsive movement and combat, with basic player/damage/stock displays and enough feedback to judge game feel.
- Placeholder art where useful during development.

Detailed movement, attacks, defense, recovery, and match rules are being specified in [Define first-playable movement and combat rules](https://github.com/Fusion2k/smash-fight/issues/2).

## Design direction

- Give scenes and gameplay modules clear responsibilities and small interfaces. Keep ordinary changes local and avoid monolithic scenes or scripts.
- Keep each character's modifiable stats together in a human-editable character file. The format and schema are still to be chosen.
- Keep character definitions separate from mutable match state. Two instances of the same character must be able to act independently.
- Keep the project portable between development PCs; resolve the Godot executable locally rather than embedding one machine's installation path.

See [Define Godot scene responsibilities and gameplay module interfaces](https://github.com/Fusion2k/smash-fight/issues/8) and [Choose the character file schema and tuning workflow](https://github.com/Fusion2k/smash-fight/issues/7) for the decisions behind these areas.

## Opening the project

1. Install Godot **4.7.2** for your development PC. The scripting language and Standard/.NET distribution choice remain open.
2. Clone this repository and import the root [`project.godot`](project.godot) through Godot's Project Manager.
3. Read the relevant GitHub issue before making changes, along with the [glossary](GLOSSARY.md) and any applicable architectural decision records under `docs/adr/`.

On the current Windows PC, Godot is installed under `C:\tools\Godot4`. Other PCs may use a different location. The repository currently contains the starter project configuration and icon; gameplay scenes and a runnable match are upcoming work.

The completed [Research a portable Godot 4.7.2 development workflow](https://github.com/Fusion2k/smash-fight/issues/6) covers version checks, imports, export templates, and verification options. A shared launcher and automated gameplay test suite have not yet been established.

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
- [Godot 4.7 documentation](https://docs.godotengine.org/en/4.7/)
- [Godot 4.7.2 download archive](https://godotengine.org/download/archive/4.7.2-stable/)
- [Valve Steam Deck specifications](https://www.steamdeck.com/en/tech)
- [Valve Steam Deck compatibility guidance](https://partner.steamgames.com/doc/steamhardware/compat)
