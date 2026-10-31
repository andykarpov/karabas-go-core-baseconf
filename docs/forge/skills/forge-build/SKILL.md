---
name: forge-build
description: Prepare, simulate, build and package BaseConf for Karabas GO B4, Mini and Mini G using project-local tools/forge.py and pinned HDL references.
---

Run from the core root (`forge/cores/zx-evo-base/`). Read `docs/architecture.md` and `docs/problems.md` before changing interfaces.

- `python3 tools/bootstrap.py sources` verifies/fetches locked reference commits; it refuses to switch an existing checkout.
- `python3 tools/forge.py prepare` creates the ISE project, adapted reference HDL, ROMs and initialization files in `build/baseconf/`.
- `python3 tools/forge.py elaborate` uses GHDL synthesis to translate CPU/HID VHDL for Icarus, then elaborates the complete board. This is a mixed-language simulation preparation step, not FPGA synthesis or proof of fit.
- `python3 tools/forge.py test --suite all` runs adapter tests and a small integrated Z80 diagnostic. `--suite adapters` skips VHDL translation prerequisites; `--suite boot` runs only the integrated diagnostic.
- `python3 tools/forge.py ise --settings bin/Xilinx/14.7/ISE_DS/settings64.sh` requires an actual project-local ISE installation. Review timing and unconstrained paths before packaging/programming.

Edit `src/rtl/`, `config/`, and explicit reference transformations in `tools/forge.py`; regenerate, rather than editing `build/`. Never use the TSConf reference bitstream as a BaseConf result. Simulation models in `tests/` must not enter the ISE source list. Full verification still needs a B4 board and Dune/storage/input/audio acceptance.

`tools/forge.py --help` and each subcommand's `--help` describe supported options. Preserve all upstream copyright and license notices when adapting modules.

Use `python3 tools/forge.py lint` after elaboration for a structural check with local Yosys. The `hid` test suite is also available independently. `test --suite boot` runs the diagnostic at 3.5, 7 and 14 MHz.

Use `python3 tools/forge.py resources` for a preliminary Yosys/GHDL Spartan-6 resource estimate. The resulting `resource-stat.json` is not evidence of ISE packing, fit or timing. CPU diagnostics also cover CMOS update counts, modern BD configuration/breakpoint readback and Nemo/divIDE byte sequencing.

Use `test --suite board` to check shared FT/FPGA video bus ownership through MCU SPI controls. This test is also included in `--suite all`.

Use `python3 tools/forge.py bios --milliseconds 50 --trace` for a four-state stock-BIOS observation, or add `--simulator verilator` for longer runs. This uses the unmodified ROM, actual MCU/HID/RTC and deterministic power-on RAM. Memory images are deposited directly; ROM transport is tested separately. Inspect `tb_bios.log`, `bios-trace.log` and `bios-sram-{hi,lo}.hex` under `build/baseconf/`. An observation finishing is not a passing boot assertion or a hardware result.

After a genuine ISE run, `python3 tools/forge.py package` checks input/bitstream hashes and the timing result, then invokes the pinned Karabas packager to create `build/baseconf/baseconf.kg1`. The underlying packager is `../../../external/karabas-go-tools/make_core/make_core.py`; use `--help` for its two positional arguments and run it in the directory referenced by the JSON. Do not bypass provenance checks to package a placeholder or unrelated bitstream.

The supplied Docker ISE installation is now available: use `python3 tools/forge.py ise --docker`. Read `../../../skills/ise-docker/SKILL.md` for image identity, license mount and individual-tool diagnostics. The native `--settings` option remains available.

Use `test --suite gs` after GS clock, memory, arbitration or capture changes (also in `all`). It compares the actual GS/T80 against a zero-wait GS with a four-channel interrupt workload, first alone then with competing ROM traffic. Both the normal and approximate routed-delay models must match the reference service rate and stereo samples. See [GS timing diagnosis](../../docs/gs-timing.md) for the TSConf comparison, clock independence, measured baseline and model limits. The test does not execute Dune's music player or certify PCB timing. Do not compensate for memory stalls by changing the GS interrupt divider or tying it to video timing.

The 84 MHz storage domain samples each 28 MHz loader write pulse once; preserve this guard and its queue test. Capture-edge changes require reviewing the SDRAM output-clock delay and input path together: a passing FPGA-only datapath constraint is insufficient. Regenerate before implementation, and do not regenerate inputs during an active BIOS/ISE run because their provenance uses the manifest hash.

Use `test --suite osd` to check actual overlay pixels against the BaseConf 50/60 Hz visible windows and switches between them (also in `all`). `board` additionally checks Covox/OSD controls do not reset GS, NMI remains independent, and OSD/physical/F12 resets reset the core and GS together. It exercises F12 in all six HID slots with held boot keys. Low 64 KiB GS storage is dual-port BRAM; adapter tests cover its loader path, the SDRAM boundary and marks across all 63 RAM pages. For actual ROM mixer playback, use the [gs-audio skill](../gs-audio/SKILL.md); the short ISR benchmark alone cannot establish sustained Dune playback.

Use `test --suite keyboard_filter` after reserved shortcut changes (also in `all`). Keep its HID usage and PS/2 set-2 tables aligned with the modified-key shortcuts in `config/core.json`; all six key slots and both Win keys matter. Suppressed keys must stay suppressed when Win is released first. Preserve matching breaks for previously forwarded makes and keep E0/F0 tokens and Pause intact. The `hid` suite checks the complete MCU/filter/parser path and the removed Menu+G binding forwards ordinary G, plus CS/SS, D/C/H/S/0 and multi-key matrix reports.

Joystick option 6 is SEGA on both ports; preserve existing option indexes 0–5 when extending the menu. `prepare` adapts the pinned VHDL HID parser with the mapping documented in [joystick setup](../../docs/joysticks.md). The `hid` suite sends actual MCU/OSD SPI frames and checks all twelve controls on both ports, releases, simultaneous keys, mode transitions, keyboard coexistence and mixed Kempston mapping. Joystick mappings affect Spectrum matrix reads; the MCU still owns pad polling and global START shortcuts.

## Mini and Mini G targets

Place `--board mini` or `--board minig` before the command. Their outputs are isolated in `build/baseconf-mini/` and `build/baseconf-minig/`; the default GO path stays `build/baseconf/`. Extensions are kg2 and kg3 respectively. Never relabel the GO bitstream. `prepare` derives each wrapper from the maintained GO body and the pinned target's external pin interface; board-specific transformations are explicit in `mini_top` and `mini_source`.

For either Mini target run `prepare`, `elaborate`, `test --suite all`, `video-test`, `hdmi-test`, `bios --simulator verilator --milliseconds 2500 --trace --require-menu`, `ise --docker`, then `package`. Mini `all` covers adapters, GS, keyboard/HID, board controls and OSD. GO's physical-FDC CPU diagnostic is excluded on Mini; stock BIOS supplies Mini CPU/ROM integration coverage. Machine simulations use a clearly named HDMI boundary sink. `hdmi-test` separately executes the actual HDMI transmitter and genuine vendor clock models; `video-test` exercises the actual BaseConf raster/scan-doubler and all OSD rows in both rasters and four video modes.

Mini blanking is carried in the scan-doubler RAM alongside pixels. Its valid-address flag must be delayed through the synchronous RAM read. Preserve continuous HDMI PLL reset during clock changes/programming, then stretch it after release. GS clocks remain independent of raster and HDMI sample rate.

Require both normal/FT and core-mode timing reports before packaging. Core-mode analysis drops FT-generated clock periods and the BUS_TO_PIX asynchronous bound, but retains FT_TO_PIX: the external FT clock remains asynchronous in core mode too. Removing that bound creates meaningless synchronous hold checks on the FIFO crossing. Review actual remaining paths rather than suppressing errors globally.

Mini references have no physical floppy/DB9 scanning. Retain USB logical joystick mappings; do not advertise physical GO interfaces. Builds remain hardware-untested until separately checked on the exact Mini revision. See [Mini port assessment](../../docs/mini-port-feasibility.md).

`package` also independently parses the output header, FPGA and ROM payloads/addresses, all OSD settings and both SEGA selectors against the generated inputs, saving `package-verified.json`. Treat validation failure as a failed package, even if the upstream packer exited successfully.


Use `test --suite ay` after PSG decode, clock, TurboSound or mixer changes (also included in `all`). It compiles a Verilator diagnostic using the actual T80 and checks both chips' register readback, fixed stereo levels and exact pure-tone periods in AY/YM modes at 3.5/7/14 MHz. Read [AY investigation](../../docs/ay-audio.md) for scope: this isolates AY with GS reset and does not certify arbitrary music/envelopes, routed timing or physical audio. A passing test does not establish that the remote kg2/kg3 AY noise report is fixed.

Use `bios-reset-test` after reset/input changes. It runs the pinned stock ROM through actual MCU/HID F12 reset with CS, SS, D, C, H, S, 0, A+B, A+B+C and CS+SS. It verifies BASIC ROM entry, demo entry, unpacked color/help/CMOS/keyboard-test dispatch, and 0 recovery with release; it is separate from `test --suite all`. Run on every board. Selection keys must remain held while the BIOS scans; see [reset controls](../../docs/reset-controls.md). The test does not certify physical keyboards or entire diagnostic screens.
