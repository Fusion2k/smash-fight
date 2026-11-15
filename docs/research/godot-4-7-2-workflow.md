# Portable Godot 4.7.2 development workflow

Research date: 2026-11-15. Supports [Research a portable Godot 4.7.2 development workflow](https://github.com/Fusion2k/smash-fight/issues/6) and [Scope the first playable Smash Fight](https://github.com/Fusion2k/smash-fight/issues/1). This is evidence and a set of bounded options, not an architecture decision or an implemented setup.

## Version and distribution evidence

Godot's [version-specific download archive](https://godotengine.org/download/archive/4.7.2-stable/) identifies **4.7.2-stable, 18 August 2026**, with Standard and .NET desktop distributions for Windows, Linux, and macOS, plus Standard and .NET export templates. It lists multiple CPU architectures; choose the asset for each development host rather than copying one Windows executable to every PC. Its Android and web editors do not establish that those are desired game export targets.

The [official source release tag](https://github.com/godotengine/godot/releases/tag/4.7.2-stable) points to commit prefix `ed1daf0`. Separately, running the current host's `C:\tools\Godot4\Godot_v4.7.2-stable_win64_console.exe --version` returned `4.7.2.stable.official.ed1daf0bf`. The version and commit prefix agree with the public release. This observation does not verify the downloaded binary's checksum or prove that other PCs have it.

Versioned [4.7 documentation](https://docs.godotengine.org/en/4.7/tutorials/editor/command_line_tutorial.html) exists. It is a minor-version documentation branch, not an immutable 4.7.2 executable specification; consult the selected binary's `--help` as well.

## Executable discovery and pinning options

Proposed project contract: commit the required release (`4.7.2-stable`) and selected distribution, plus reproducible commands; let each PC locate its own executable. The current `project.godot` advertises `4.7` and Forward Plus, which is not an exact executable selection mechanism. This is a repository observation, not a new requirement.

| Option | Benefit | Cost or boundary |
| --- | --- | --- |
| Explicit command argument or local `GODOT_BIN` environment variable | Supports side-by-side engines and arbitrary installation directories | Each PC supplies one setting; launcher must validate it |
| Executable named `godot` on `PATH` | Simple terminal and editor integration | PATH can resolve another release; always validate first |
| Bootstrap a version-specific archive into an ignored tool directory | Can make clean-machine/CI setup repeatable | Requires host/architecture selection, download integrity verification, caching and maintenance |

These are proposed wrapper conventions, not Godot-recognized environment variables. A future launcher could resolve explicit override, then `GODOT_BIN`, then `PATH`; print the resolved path and full `--version`; reject a mismatch before importing or editing. Require `4.7.2.stable.official` for official releases, recording the full observed string for diagnostics. Decide explicitly whether to require the commit hash too. A version check alone cannot distinguish every Standard/.NET capability; C# setup also needs a real build check. Godot's [CLI guide](https://docs.godotengine.org/en/4.7/tutorials/editor/command_line_tutorial.html) documents PATH use and macOS's `Godot.app/Contents/MacOS/Godot` executable location.

## Language and tooling alternatives

| Choice | Reproducibility implications | Target implications |
| --- | --- | --- |
| GDScript with Standard editor | Engine-specific, gradually typed language; no separate C# SDK prerequisite | Does not introduce the C# web-export restriction |
| C# with .NET editor | Requires separately installed .NET SDK; external C# editor is useful; commit project/solution and SDK selection policy | Desktop support; Android/iOS support is experimental; no Godot 4 C# web export |

Sources: [GDScript reference](https://docs.godotengine.org/en/4.7/tutorials/scripting/gdscript/gdscript_basics.html), [C# distribution and platform support](https://docs.godotengine.org/en/4.7/tutorials/scripting/c_sharp/index.html), and [C# prerequisites/editor guidance](https://docs.godotengine.org/en/4.7/tutorials/scripting/c_sharp/c_sharp_basics.html). The latter still phrases its numeric SDK minimum in terms of **Godot 4.5** (.NET 8, or .NET 9 for Android); this research does not treat that wording as a freshly verified 4.7.2/target SDK matrix. Validate the generated project's framework and target-specific workloads before choosing an exact SDK. No local .NET engine or C# project build was tested here. C# iOS export requires macOS according to the platform-support page.

If C# is chosen, [Microsoft's `global.json`](https://learn.microsoft.com/en-us/dotnet/core/tools/global-json) supports SDK selection and explicit `rollForward`/`allowPrerelease` policies. Exact pinning (`rollForward: disable`) and controlled patch roll-forward are alternatives with different update costs; neither installs the SDK. Confirm the policy on every intended development OS. Language, development OS list, export targets, and editor remain open choices.

## What travels through Git

Commit source assets, scenes/resources, scripts, `project.godot`, asset `.import` metadata and generated `.uid` sidecars. Rebuild `.godot/` caches after cloning. [Import-process documentation](https://docs.godotengine.org/en/4.7/tutorials/assets_pipeline/import_process.html) explains `.import` metadata and regenerable imported data; the [UID introduction](https://godotengine.org/article/uid-changes-coming-to-godot-4-4/) explains why UID sidecars belong in version control. Preserve sidecars when moving their source files.

The current repository already ignores `.godot/` and uses `.gitattributes` with `* text=auto eol=lf`. The [VCS guide](https://docs.godotengine.org/en/4.7/tutorials/best_practices/version_control_systems.html) also excludes generated `*.translation` files; consider adding that rule if CSV translations arrive. LFS is an optional large-asset decision, not a prerequisite for this starter. A Git editor plugin is optional; normal Git commands work independently.

Once targets are chosen, commit `export_presets.cfg`, use relative build destinations, ignore build output, install the matching 4.7.2 templates/distribution on build hosts, and supply platform SDKs and credentials separately. [Export documentation](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_projects.html) distinguishes presets from confidential `.godot/export_credentials.cfg`, and requires presets/templates for CLI export. Review presets for machine-specific SDK paths. The current checkout has no export presets; no export was verified.

For game paths, use `res://` for project resources and `user://` for writable user data. Optional editor self-contained mode uses `_sc_`/`._sc_` next to the binary and stores settings/data/cache in `editor_data/`; it can help carry editor preferences but does not install target SDKs or make a Windows binary cross-platform. [Godot data-path documentation](https://docs.godotengine.org/en/4.7/tutorials/io/data_paths.html) also documents macOS placement and the limitation that exported games do not inherit this mode.

## Checks available for a future launcher or CI

Here `godot` means the resolved, version-checked executable; paths and preset names are placeholders until those files exist. Run commands sequentially and stop on failure.

```text
godot --version
godot --headless --path <repo> --import
godot --headless --path <repo> --check-only --script res://path/to/script.gd
godot --headless --path <repo> --script res://checks/run.gd
godot --headless --path <repo> --quit-after 120 res://path/to/smoke_scene.tscn
godot --headless --path <repo> --export-release "<chosen preset>" <existing-build-directory/output>
```

The [CLI reference](https://docs.godotengine.org/en/4.7/tutorials/editor/command_line_tutorial.html) defines these flags: import waits for resources; check-only parses the specified script; quit-after bounds iterations, not elapsed time. Add an external timeout. Parsing is not gameplay testing; importing is not exhaustive scene execution. Use a project check runner with explicit success/failure exit codes through [SceneTree.quit](https://docs.godotengine.org/en/4.7/classes/class_scenetree.html#class-scenetree-method-quit), retained logs, and known assertions. A future runner must be verified to fail on an intentional assertion failure. Headless checks cannot establish rendering, controller feel, audio behavior or performance on the target device; retain interactive and exported-build smoke checks.

For C#, a separate compiler/build check is needed (the CLI also exposes `--build-solutions`); a GDScript parser check does not validate C#. No test framework or CI provider is selected here.

## Local validation and remaining decisions

On this Windows host, `--version` and `--help` were inspected, and `--headless --path . --import` completed with **exit code 0** in a fresh isolated worktree containing the starter project. The import created ignored cache data and left tracked project files unchanged. There are no gameplay scenes/scripts or main scene in that checkout, so no runtime, behavioral, C#, export, cross-OS, or graphical verification is claimed.

Before implementing setup automation, decide: development host OS/architectures; first export target(s); GDScript versus C#; executable-discovery contract; exact engine/distribution and any SDK policy; and which meaningful project behavior a check runner should assert. The evidence supports a shared version contract with machine-local executable resolution. It does not require a machine-specific path or a Windows-only workflow.
