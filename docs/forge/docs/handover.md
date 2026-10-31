# Handover — current state, 2026-10-28

**2026-10-31 distribution:** [complete bundle and instructions](builds-and-installation.md).
`tools/release.py` verifies unchanged 26102806 FPGA inputs/packages and the shared RP2040
firmware from sibling `mc0511`, then writes `bin/kg1`, `bin/kg2`, `bin/kg3` and the all-board
ZIP with Dune media. No board transfer or AY fix. Existing hardware feedback remains scoped
to its recorded tests; the assembled controller/core pair awaits separate acceptance.

Current candidate: **26102806** applies to GO, Mini and Mini G, removes GS Reset/Menu+G, couples GS to core reset and recognizes F12 in every HID slot. See [reset controls](reset-controls.md) for EVO boot choices and verification. All 30 stock-ROM reset selections, all three normal ERS/4096 KB boots, full regressions/lint and ISE/package checks pass; Mini video/HDMI and both timing modes pass too. New outputs are isolated in `build/reset-26102806/<board>/`; the release is `build/releases/reset-26102806/`. Earlier release/installation records below are retained as history.

**Hotkey/reset-selection task done:** the user confirms the hotkeys work on GO, Mini and Mini G. [Acceptance record](evidence/hotkey-acceptance-26102806.json).

Still unresolved: remote AY noise on Mini/Mini G (both HDMI and analog) with GS reportedly clean. The [AY investigation](ay-audio.md) compares TSConf and records 18 passing CPU-driven tests. No confirmed root cause or production fix yet; ZX-Format 2 and same-board kg3 recordings are supplied; package identity/settings remain unknown. The new exact-player/trace tests are documented in the investigation, including a correction to historical 3.5 MHz test coverage. `test --suite ay` is now included in `all`. The [HDMI recheck](hdmi-audio.md) finds identical kg3 sample/divider/packet handling; new `hdmi-audio-test` and fresh transport tests pass both Mini targets.

Workspace update: this core now lives at `forge/cores/zx-evo-base/`, including GO/Mini/Mini G. Run core commands from there. Maintained sources are in `src/`, resources in `res/`; shared tools, HDL binaries and Karabas/Xilinx references remain at the Forge root. See [workspace and extraction notes](workspace.md). Historical evidence/release/prompt paths are preserved verbatim; use the path mapping in those notes. Migration verification uses fresh `build/reorganization-check/<board>/` outputs.

## Earlier build and installation records

Candidate **26102804 is installed on SD1 and listed by firmware** with current settings preserved. It adds the requested SEGA keyboard mapping to both OSD joystick selectors. The preceding 26102803 GS/OSD/shortcut iteration was accepted by the user (“all works”). Physical acceptance of the new SEGA mode remains pending.

Previous Mini port task: **Mini kg2 and Mini G kg3, build 26102805**, are available alongside the unchanged GO kg1 in [the release directory](../build/releases/multi-board-26102805). Both pass regressions, real video/HDMI simulations, ERS/4096 KB at 2500 ms and normal/core-mode ISE timing with zero errors. Independent package checks and input manifests agree. Mini uses 98% of slices, Mini G 97%. No physical Mini hardware was available and no board/media transfer was performed. [Build guide, package links, hashes and limits](mini-cores.md).

Use `python3 tools/forge.py --board mini <command>` or `--board minig`; the flag precedes the command and outputs stay in `build/baseconf-mini/` / `build/baseconf-minig/`. Default output directory names are retained; current 26102806 implementation inputs differ from these older builds. `video-test` and `hdmi-test` are new commands; the latter uses local GHDL/Icarus and vendor unisim models extracted from the supplied Docker image because its ISim lacks GCC. Skills and docs are updated. Do not use the machine-test HDMI sink as transport evidence.

Mini adaptations are explicit in `tools/forge.py`: board headers/wiring, absent physical FDC, audio outputs, blanking carried alongside scan-doubler pixels with matching read-valid latency, and complete HDMI DCM programming/reset handling. The separate core-mode timing pass retains the external FT-to-pixel asynchronous bound. Original `external/` sources are untouched. Additional physical acceptance is needed on the exact Mini revision; no separate Mini schematic repo is present locally.

## SEGA result — 26102804

SEGA is appended as option 6 (`110`), retaining existing option numbers and defaults. Up/Down/Left/Right map to Q/A/O/P; A/B/C to Z/X/C; X/Y/Z to S/D/F; START to 0; MODE to 9. Each port independently selects the mode. Both ports in SEGA merge the same keys; one can coexist with Kempston on the other. This maps Spectrum matrix keys through the existing MCU joystick packets and does not generate PS/2 events. [User setup and mapping](joysticks.md).

`tools/forge.py prepare` applies an explicit transformation to the pinned VHDL HID parser. External sources are untouched. The only changed implementation inputs versus 26102803 are `core.json` and adapted `hid_parser.vhd`; GS/audio/storage/OSD geometry and the shortcut filter are unchanged. `tests/tb_hid.v` exercises all twelve keys/releases per port, simultaneous keys, combined row reads, live mode changes, both ports, USB typing and mixed Kempston. All regression suites and structural lint pass.

Stock BIOS reaches ERS and the 4096 KB signature at 2500 ms, using the same manifest as ISE. ISE passes declared constraints with zero timing errors, no latches, 10,305 LUTs, 6,204 slice registers, 3,355/3,758 slices, 38 RAMB16 and 6 RAMB8. External board timing coverage remains provisional. Independent package parsing verifies both seven-option selectors and all FPGA/ROM payloads. [Validation](validation.md).

Generic package SHA-256: `9da320b0c3fcf60679e95f8ce8ea533d4d953c49779e18b64ef58f183fb9bd00`. Installed with current saved settings: `d5675fc72d33e35b1bc63dcfb7b47a7c559b70bb8fb53eba65e148b6c2fda1a1`. Both saved joystick modes were Kempston, Covox off and raster 60 Hz. Backed up actual prior card image as `build/board/baseconf-26102803-from-sd1.kg1` (it differs from the generic release only in saved OSD bytes). SD1 readback and other root hashes pass; clean eject completed. SD2, CF and physical EEPROM were untouched. Release and relevant source snapshots are under `build/releases/26102804/`.

## Next observation and accepted baseline

User selects 26102804, opens Win+Esc and chooses SEGA for the connected port, then tests directions/buttons in a game's redefine-keys screen. Repeat on the other port. Supplied MCU firmware still reserves START+C / START+MODE for OSD and START+X for reboot; these actual restrictions are documented. No MCU update was made.

26102803's Win/Menu shortcut isolation remains intact and accepted. Both HID matrix and PS/2 paths filter reserved shortcuts through key release. Plain G still works; the saved ERS reset target was recovered with 0+reset. [Boot investigation](boot-regression.md).

GS audio and OSD are accepted on the board. Low 64 KiB GS BRAM remains unchanged. Earlier old/new intro WAVs and provenance are linked from [audio validation](gs-audio.md): 299 old-core underruns by 9.23 s versus zero through 13.29 s with BRAM. Controller runs were intentionally stopped after complete ten-second excerpts; only the zero-wait reference completed 30 seconds. The original intermittent physical 1Mb error remains unreproduced despite cold/F3-warm checks passing with 62 usable pages.

All media clues and mutable work stay in this repository. Other folders are independent projects. Do not regenerate build inputs during BIOS/ISE runs; the evidence uses manifest hashes. The 84 MHz SDRAM timing budgets remain partial PCB timing coverage, and loader pulse uniqueness must be preserved.

## Workspace rules and tools

- Project: `/var/www/own/karabas-forge/forge/cores/zx-evo-base`; target B4 / XC6SLX25-2-FTG256. Write only inside the project. Use `tmp/`, `bin/`, `build/`, and standalone Python tools in `tools/` with CLI help.
- Maintain progress/plan/problems and numbered prompt records. Tools and binaries have project-local skills under `skills/`; do not install them globally.
- Edit `src/rtl/`, `config/` and explicit transformations in `tools/forge.py`. Keep pinned `external/` sources unchanged. Regenerate `build/baseconf/` with `prepare`; do not regenerate while BIOS or ISE is running because provenance uses the manifest hash.
- Most implementation files remain untracked. No commit was requested. `bin/`, `build/`, `external/`, and `tmp/` are ignored; a Git-only backup omits them.
- ISE is available via the user's Docker image and `../../../tools/ise_docker.py --build-root build --workdir baseconf`. Use `python3 tools/forge.py ise --docker`; the project skill documents the pinned image, build-only writable bind and read-only license. No installer is needed.

Useful commands after a source change:

```sh
python3 tools/forge.py prepare
python3 tools/forge.py elaborate
python3 tools/forge.py test --suite all
python3 tools/forge.py lint
python3 tools/forge.py bios --simulator verilator --milliseconds 2500 --trace --require-menu
python3 tools/forge.py ise --docker
python3 tools/forge.py package
```

`test --suite gs` selects the short GS benchmark; `--suite osd` checks menu visibility; `--suite board` checks MCU controls/reset wiring. BIOS and ISE may run concurrently after preparation, with no source regeneration. Passing FPGA datapath constraints and simulation are distinct from board acceptance.

## Hardware and media

The connected board identifies as USB 2e8a:000a, serial D26610685F233021. Use `../../../tools/board_serial.py --project . --command list` to verify the current core list. `msc` exports SD1 (1.9 GiB FAT16, UUID 3F19-B304); `msc2` exports SD2 (14.6 GiB FAT32, UUID 8125-1A1C). Re-identify USB ancestry/model/partition on every re-enumeration. Do not assume the device is always `/dev/sda1`.

The project-only transfer procedure is in [board-access](../../../../skills/board-access/SKILL.md) and [hardware tests](hardware-test.md): unmount any desktop automount, mount only the identified partition inside an ephemeral supplied-image container at `/build/board/sd1`, retain the previous BaseConf package, preserve other files, compare/hash, sync/unmount, cleanly eject via UDisks, then verify the firmware list. Do not update MCU firmware or touch CF as part of a core replacement.

Unchanged `dune.trd` and `DUNE.DAT` are already verified at SD2 root. The user has reached the Dune display, but the exact launch path has not been recorded. Original AVR virtual-drive/COM/version services remain absent; avoid assuming a particular mounting workflow. USB serial provides no core selection, audio/video capture or input injection. The user must select the updated core and report the listening result.

## Remaining acceptance

1. Check SEGA mode on each physical joystick port with a game redefine-keys screen. The GS/OSD/shortcut baseline is already accepted.
2. Repeat physical boot/reset/memory checks for the new image; confirm stable sustained playback and gameplay at 14 MHz.
3. Physical CF/Nemo reads/writes, real Firefly floppy/Gotek operations, CRC/write protection and bus timing.
4. Keyboard PS/2 buffer, mouse, two independently mapped joysticks, OSD/NMI/reset and extended graphics/palette/font patterns.
5. TurboSound/FM and GS 2 MB capacity/audio acceptance, plus remaining external timing/CDC review.

Latest detailed logs are `tmp/sega-{tests,lint,bios,ise}.log` and `build/baseconf/`. Retained reports/hashes are under `docs/evidence/`. See [progress](progress.md), [plan](plan.md), [problems](problems.md), [validation](validation.md), and [tools/skills](tools.md). Prompt record 17 covers SEGA mapping and documentation; 16 records prior board acceptance. Prompt record 15 covers confirmed recovery, GS audio acceptance and this prevention fix; 14 covers Gluk startup investigation. Prompt record 13 covers the remaining distortion, OSD photo, repository-only media boundary and user recording/check replies; records 11 and 12 retain the earlier GS/TSConf work.
