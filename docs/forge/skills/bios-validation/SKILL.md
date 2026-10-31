---
name: bios-validation
description: Run and inspect the unmodified BaseConf ROM in the Karabas GO board simulation, including RTC initialization, power-on RAM, traces and screen-memory extraction.
---

Work from the core root (`forge/cores/zx-evo-base/`). Read `docs/problems.md` and `docs/validation.md` first.

1. Run `python3 tools/forge.py prepare` and `python3 tools/forge.py elaborate` after HDL changes.
2. Run `python3 tools/forge.py bios --simulator verilator --milliseconds 2500 --trace --require-menu` for the stock-menu regression. Omit `--require-menu` for shorter diagnostic observations. Use `--simulator icarus` for a shorter four-state comparison. See `../../../skills/local-hdl/SKILL.md` for pinned simulator setup and limits.
3. Inspect `build/baseconf/tb_bios.log` and `bios-trace.log`. The harness initializes a deterministic RAM pattern, deposits stock ROM images without patching them, and sends RTC/EEPROM initialization through actual MCU SPI. It does not emulate an inserted CF card or floppy disk.
4. Run `python3 tools/bios_inspect.py --page 5 --require-menu` to extract and check the standard Spectrum menu screen. The expected ROM hash and stable screen rectangles are in `config/bios-menu-signature.json`, based on a visually reviewed stock boot. This is a specific firmware/menu regression, not a general OCR or memory-size test. Omit `--require-menu` to inspect arbitrary snapshots; `--page 7` selects the alternate screen. Use a separate project-local `--output` to keep both. The tool checks unknown data and writes `screen.scr`, `screen.png` and provenance under `build/bios-screen/`. `--help` documents all options.

The build runner clears old dump/result files at startup and writes `bios-result.json` after successful completion (and signature acceptance when requested). Its hashes link the observation to generated inputs, testbench, ROMs and outputs. Do not use a previous screenshot to label a later failed run successful.

The image is a software view of bitmap/attribute RAM using standard colors; it does not verify FPGA video output, extended modes or programmed palettes. Keep observations separate from assertions. A finished simulation or a plausible image is insufficient by itself to claim successful BIOS boot, peripheral interoperability, or Dune gameplay. Do not edit the stock ROM to hide an HDL compatibility defect.
