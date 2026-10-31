# Core workspace and future extraction

The core root is `forge/cores/zx-evo-base/`. Commands in this core's README, docs and skills assume that working directory unless stated otherwise. GO, Mini and Mini G are board targets of the same core.

| Directory | Contents |
|---|---|
| `src/rtl/` | Maintained core RTL and board wrapper |
| `src/constraints/` | Maintained timing constraints |
| `res/` | Exact BIOS, font, FDC microcode and test-media inputs; hashes/provenance in `manifest.json` |
| `config/` | Core menu, BIOS signature and required source revisions |
| `external/` | Pinned ZX Evo and Dune source checkouts |
| `tools/` | Core build, source-bootstrap entry point, BIOS, GS audio and media helpers |
| `tests/` | Core-specific testbenches and simulation models |
| `docs/`, `skills/`, `prompts/` | Core documentation, workflows and historical task records |
| `bin/`, `build/`, `tmp/` | Core-specific downloads, generated outputs and scratch data |

Shared Karabas references and toolchains remain in the [Forge workspace](../../../../README.md). The local `bin/` is initially empty. Shared HDL binaries are used directly without copying them per core.

## Path resolution

Core tools derive the core root from their own location. Relative build/output/resource arguments are core-relative. `forge.py --build-dir build/<name>` selects an isolated output directory; place it before the subcommand. Default output names remain `build/baseconf`, `build/baseconf-mini` and `build/baseconf-minig`.

The shared workspace is found by its `config/forge.json` marker. `KARABAS_FORGE_ROOT` overrides discovery. Missing workspaces fail with a setup message. Core sources and writable build/temp data remain inside the core. Shared helpers take an explicit `--project` or `--build-root`.

```sh
# From this core directory, within the current Forge layout:
python3 tools/bootstrap.py sources
python3 tools/forge.py --board mini --build-dir build/check-mini prepare
python3 ../../../tools/check_board.py --project . --ucf build/baseconf/karabas_go.ucf
python3 ../../../tools/ise_docker.py --build-root build --workdir baseconf xst -help
```

## Separate repository

Copy this core's maintained files, including `LICENSE`, `.gitignore`, `config/`, `res/`, `src/`, `tools/`, `tests/`, docs and skills. The core-local ignore file excludes downloaded references, tools, scratch and build output. No nested Git repository is created by this migration.

Provision the shared Forge workspace separately, then point to it explicitly:

```sh
export KARABAS_FORGE_ROOT=/path/to/karabas-forge
python3 "$KARABAS_FORGE_ROOT/tools/bootstrap.py" binaries
python3 tools/bootstrap.py sources
python3 tools/forge.py prepare
python3 tools/forge.py elaborate
```

Core `config/sources.lock.json` retains required shared revisions as `scope: forge` entries and local references as `scope: core`. The bootstrap helper validates both without changing existing mismatched checkouts. The separated core still requires the shared tooling/dependencies; bundling that infrastructure into an independent distribution is a later choice. Relative links and examples using `../../../` address the present monorepo; after extraction use `$KARABAS_FORGE_ROOT` for shared documentation/utilities.

## Resources and historical paths

`res/` is the build input authority. Its manifest records source repository revisions and original paths, or identifies user-supplied media whose upstream revision is unknown. `prepare` verifies resource checksums before generating outputs. Update the manifest deliberately when changing a resource; copying it here does not change its original license.

The pre-move core root was the Forge root. Historical prompt records, evidence JSON/logs and release snapshots retain those paths verbatim. Translate old core paths to this directory; old `rtl/` means `src/rtl/`, `config/timing.ucf` means `src/constraints/timing.ucf`, and `external/dune/` means `res/media/dune/`. Shared `bin/`, Karabas references and Xilinx paths still refer to the Forge root.

Existing compiled simulation caches may embed old absolute paths. Re-run `prepare` and `elaborate` before simulation; the relocation verification uses fresh `build/reorganization-check/<board>/` directories. Preserved releases and evidence are not rewritten. The full move inventory and original maintained-file backup are under the shared ignored `tmp/reorganization/`; the concise verification record is [reorganization evidence](evidence/reorganization.json).
