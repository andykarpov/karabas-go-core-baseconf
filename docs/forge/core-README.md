# ZX Evolution BaseConf for Karabas GO / Mini / Mini G

Experimental core for **Karabas GO B4, Mini and Mini G**. Build **26102806** removes GS Reset/Menu+G, resets GS with the core and recognizes F12 in all six HID slots. The unmodified EVO ROM passes 30 reset-selection checks across the three targets. See [reset controls](docs/reset-controls.md), [validation](docs/validation.md) and [remaining issues](docs/problems.md).

Complete bundle: [baseconf-26102806-all.zip](bin/baseconf-26102806-all.zip), with KG1/KG2/KG3,
matching RP2040 UF2 firmware, supplied Dune media, checksums and validation reports.
See **[installation and rebuild instructions](docs/builds-and-installation.md)**.
Individual packages are in `bin/kg1`, `bin/kg2`, and `bin/kg3`.

The FPGA binaries retain 26102806; fresh generated inputs reproduce their timing-accepted
manifests exactly. The bundled controller firmware is identical to the corresponding UKNC
bundle, preserving its fixes. Hotkeys/reset selections were accepted on all three boards;
the Mini/Mini G AY-noise issue remains unresolved. No board transfer was performed for this
bundle, and the assembled FPGA/controller pairing has not been separately hardware-tested.

For keyboard controls, see the [hotkey reference](docs/hotkeys.md): OSD shortcuts, PC key names, EVO reset combinations and keyboard-test entry.

The core retains 4 MB main RAM, 2 MB GS, TurboSound/FM and [SEGA joystick mapping](docs/joysticks.md). See [Mini interfaces and limits](docs/mini-cores.md) and the [hardware test procedure](docs/hardware-test.md).

To resume work, read the [saved handover](docs/handover.md).

Start with [progress](docs/progress.md), [current plan](docs/plan.md), [problems](docs/problems.md), [architecture](docs/architecture.md) and [validation](docs/validation.md).

Run the following from `forge/cores/zx-evo-base/`. See [workspace layout and standalone use](docs/workspace.md).

```sh
python3 tools/bootstrap.py sources
python3 tools/bootstrap.py binaries
python3 tools/forge.py prepare
python3 ../../../tools/check_board.py --project . --ucf build/baseconf/karabas_go.ucf
python3 tools/forge.py elaborate
python3 tools/forge.py test --suite all
python3 tools/forge.py lint
python3 tools/forge.py resources
python3 tools/media.py --stage
```

Longer stock-ROM startup check and screen-memory extraction:

```sh
python3 tools/forge.py bios-reset-test
python3 tools/forge.py bios --simulator verilator --milliseconds 2500 --trace --require-menu
python3 tools/bios_inspect.py --require-menu
```

The extracted image is a software view of SRAM, not captured VGA output. See [BIOS validation](docs/validation.md) for the test assumptions and limits.

With the supplied Docker ISE 14.7 image:

```sh
python3 tools/forge.py ise --docker
# Inspect timing, resource fit, pad budgets and unconstrained paths first.
python3 tools/forge.py package
```

For a native installation, `ise --settings <project-local-settings64.sh>` remains available.

The package command requires completed ISE provenance, unchanged build inputs and a passing timing report. It produces `build/baseconf/baseconf.kg1`. It cannot turn a reference TSConf binary or HDL elaboration into a BaseConf image.

Source is under `src/rtl/` and `src/constraints/`, resources under `res/`, configurations/locks under `config/`, Python entry points under `tools/`, skills under `skills/`, original prompt/work records under `prompts/`. Shared HDL downloads stay in the Forge workspace’s `bin/`; core-specific downloads use local `bin/`, temporary data `tmp/`, and generated outputs `build/`. See [tools and skills](docs/tools.md) and [attribution](docs/attribution.md).
