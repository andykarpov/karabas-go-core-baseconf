# Progress

## Current result — 2026-10-28

An **experimental FPGA package, build 26102800**, is implemented and has completed ISE 14.7 synthesis/map/route/BitGen. TRCE reports zero setup/hold errors for the current constraints. The final design uses 9,836 LUTs, 5,701 slice registers, 3,370/3,758 occupied slices and **zero latches**. External-interface timing/CDC and physical acceptance still have the limits listed below.

The unmodified BIOS reaches its menu and reports **4096 KB** in simulation after the final RTL changes. All adapter/CPU/HID/board regressions pass. The package has been copied to the connected Karabas SD1, readback-verified, and listed by the live firmware. **Physical BaseConf startup/display, CF/FDC media, audio and Dune remain unverified.** See [hardware test steps](hardware-test.md) and [ISE evidence](evidence/ise-26102800.json).

### Implemented

- GO B4 board wrapper and ISE project generation for XC6SLX25-2-FTG256.
- BaseConf pager, CPU scheduler, extended video and port logic, with T80pa CPU enables.
- Four-clock SRAM adapter retaining all 4 MB, including BaseConf's even-byte/upper-lane convention.
- Separate 512 KB ROM plus 2 MB GS storage in SDRAM, initialization, refresh, arbitration, upload queue/bounds fault and tagged ROM completion for DOS page changes.
- Inferred initialized font RAM replacing the Altera-only wrapper.
- Reference Firefly-derived real FDC, Nemo CF, TurboSound FM, GS and DAC paths integrated in the top level.
- RP2040 USB keyboard matrix/PS2 key buffer, mouse, both joystick mappings, RTC and OSD menu integration. Win+Esc is provided by the reference firmware.
- Local Icarus/GHDL/Yosys/ABC/Verilator packages with download hashes, source revision locks, build manifest, reproducible commands and documented skills.
- Dune TRD/SpectrumProg media structure/checksums checked and unchanged copies staged under `build/media/`.

### Passed checks

- All 183 assigned signal balls match B4 PCB net data with documented aliases and no duplicate balls. This is a PCB naming/placement check, not electrical polarity validation.
- Complete board HDL elaborates using the actual translated T80 and HID logic.
- Yosys process conversion/flattening/tristate resolution finishes with **zero structural check problems**. Its 54 distinct warnings include inherited declarations, memory-to-register conversion and tristate handling; this is not an ISE timing/resource result.
- SRAM: 200 randomized words, byte masks, highest address and turnaround.
- SDRAM storage: ROM/GS isolation, byte lanes, address bounds, concurrent requests, refresh and in-flight ROM page changes.
- Integrated CPU diagnostic at 3.5, 7 and 14 MHz: ROM31 fetch, CPU-driven ATM mapper setup, SRAM read/write/compare including RAM255:FFFF, branch and border output.
- CPU I/O regression at all three speeds: CMOS readback with exactly one MCU update per write, modern BD configuration/breakpoint readback, Nemo/divIDE word byte sequences, and Firefly track/sector/system registers.
- MCU SPI at 16 MHz: PS2 make/break FIFO/clear, USB key press/release, both OSD-selectable joystick inputs, mouse deltas/buttons/wheel and OSD command delivery.
- Board video ownership: MCU FT-video enable releases all FPGA RGB/sync outputs and selects the FT clock; disabling it returns ownership to the FPGA.
- Seven project skills are documented; the two new skills cover Docker ISE and board access. Tool command-line help and bootstrap verification run successfully.

### Important findings/fixes

The initial CPU diagnostic incorrectly assumed that reset exposed Spectrum RAM and conventional SRAM byte lanes. BaseConf actually mirrors ROM31 into every window until the BIOS programs the ATM mapper. Tests now perform that setup through Z80 instructions.

ROM/GS address separation is explicit and tested, including a GS address which would alias ROM if the offset were wrong. A DOS page change invalidates an outstanding/completed ROM response so a stale ROM byte cannot satisfy the CPU wait.

The reference wrapper's HID output is six bits, not five; the board wrapper now exposes all six at the parser boundary and selects five for BaseConf. Floating legacy scancode wiring is connected, unused PSG inputs are tied high, and the input-only MCU burst-select has no FPGA driver.

The MCU's FT-video enable now also controls FPGA RGB/sync tristates and video clock selection. This aligns shared video-bus ownership with the existing FT output-enable control, including when the MCU displays its OSD.

### Next gate

ISE implementation is complete for candidate 26102800. The connected board lists the new package. The next gate is selecting it and observing BIOS/OSD startup; the documented USB protocol does not provide core selection or video capture. See [plan](plan.md), [problems](problems.md), [validation](validation.md) and [tools](tools.md).

### Continuation: stock ROM compatibility

The actual board simulation now runs the unmodified 512 KB stock ROM with GS ROM, MCU SPI RTC initialization, and a reproducible power-on RAM pattern. The BIOS computes a resident-program CRC before clearing RAM, so unknown-filled simulation RAM was unsuitable. Longer runs use pinned Verilator; short four-state Icarus runs remain available.

This exposed and fixed duplicate RTC host updates (two CPU writes previously caused eight MCU updates), the old BE/new BD configuration-port mismatch, and overly broad PSG read decoding. Modern BD page readback and restricted breakpoint writes are covered by CPU regressions. A BIOS trace and SRAM screen extraction workflow is documented in the new [bios-validation skill](../skills/bios-validation/SKILL.md).

The 3.5-second stock-ROM run displayed the main menu and 4096 KB memory label. Visually reviewed stable screen regions form the pinned signature in `config/bios-menu-signature.json`; `bios_inspect.py --require-menu` checks them and the ROM hash. This is a software-screen check, not FPGA VGA or electrical validation.

The Firefly regression exposed undefined free-running counter startup and a 14 MHz write-address capture problem. Explicit INIT values start the counters; the 8 MHz host receiver now saves the register address while the write is active, so it cannot select a new CPU address at write release. Track/sector readback and the system/side latch now pass at 3.5, 7 and 14 MHz. Sector flux/CRC and physical drives remain untested.

Final verification: all adapter/CPU/HID/board regressions pass, Spartan-6 resource mapping passes its structural check (9,788 LUTs, 6,336 flip-flops), and the final RTL passes the stock-ROM menu signature after 2500 ms of simulation. [Screen evidence](evidence/stock-bios-menu.png) and [provenance](evidence/stock-bios-menu.json) are retained under `docs/evidence/`.

### Historical pause — 2026-10-27

At the user's request, work is paused until a later session; the user plans to prepare ISE. [Handover](handover.md) records the validated state, exact resume commands, build gates and remaining acceptance work. No HDL changes were made in this handover step.

### 2026-10-28: Docker ISE implementation started

The user supplied ISE through Docker. The installed image reports XST 14.7 P.20131013. Added `../../../tools/ise_docker.py --build-root build --workdir baseconf`, `forge.py ise --docker`, and a validated `ise-docker` skill. The first actual synthesis is running; fit, routing and timing results are pending. The previous missing-ISE blocker is resolved.

### 2026-10-28: routed candidate and live SD1 transfer

Fixed the generated XST script's blank-line command boundary. ISE exposed the inherited CPU read-data latch as a gated/fabric clock; replaced it with an fclk register and transparent-window bypass. All CPU speeds and the 2500 ms stock-menu check pass after this change. Added explicit 16 MHz SPI MOSI setup/hold and MISO output constraints. Included headers and BitGen settings in build provenance; failed ISE runs invalidate completion evidence.

The final ISE result has zero timing errors, fully routed signals and no inferred latches. Worst reported margins include 4.287 ns for the bus clock, 0.989 ns for the provisional SDRAM output budget, and 4.847 ns for MCU MISO. This does not close unmodeled external-interface timing. Reports are retained in [timing](evidence/ise-26102800-timing.txt) and [utilization](evidence/ise-26102800-utilization.txt).

Package: `build/baseconf/baseconf.kg1`, 1,300,309 bytes; SHA-256 `d9b72181435388442e898bd17885eb2980983b112ce8deb7d268f77186cf6c97`.

After the user connected the board, USB core listing worked. SD1 was exported, identified as the Karabas 1.9 GB FAT16 card, and mounted temporarily at a project path inside a container. Added only `baseconf.kg1`; verified its bytes and all existing root core/config hashes; synced/unmounted/ejected. The [live firmware list](evidence/board-core-list-26102800.txt) contains ZX Evolution BaseConf 26102800. SD2 and CF were not written. User display/Win+Esc feedback is pending.

Final consistency checks passed: ISE and BIOS evidence share the same generated-input manifest, artifact hashes match, package payloads match their inputs, documentation links resolve, and both new skills validate. A 60-second USB listen captured no output; physical startup remains awaiting display feedback.

### 2026-10-28: Dune files on SD2

At the user's request, copied the unchanged supplied `dune.trd` (655,360 bytes) and `DUNE.DAT` (3,223,552 bytes) to the root of the connected Karabas **SD2** card. Its USB model is SD Card 2; filesystem FAT32, UUID 8125-1A1C. Byte comparisons and SHA-256 matched the originals; existing root files were unchanged; the card was unmounted and cleanly ejected. SD1 and CF were not written during this transfer. [Transfer evidence](evidence/dune-sd2-transfer.json). File presence is verified; TRD mounting/gameplay remains unverified because the original AVR virtual-drive service is absent.

### Hardware feedback and GS timing investigation

The supplied `ers.jpg` shows physical ERS startup with 4096 KB and `dune.jpg` shows Dune rendering. The user reports that the monitor's vertical cropping disappears with 60 Hz selected in OSD; no video RTL change was made. They also report GS playback about twice too slow. The GS CPU enable and interrupt divider are independent of VSync. A four-channel IRQ benchmark reproduces lost sample service through the conservative memory path, and an 84 MHz memory implementation based on the working TSConf timing is under test.

### GS correction — candidate 26102801

Compared the working TSConf GS path, reproduced sample-service loss in a real GS/T80 benchmark, and moved shared SDRAM service to the existing 84 MHz clock. GS remains at 14 MHz with its independent fixed interrupt divider. The original controller services 41/74 reference interrupts alone, or 29/75 with ROM contention; the revised controller services 74/74 and 75/75. Both normal and approximate routed-read delay cases pass and stereo samples match.

Routing review prompted later DQ capture into input registers; a negative test demonstrates that the earlier capture fails with approximate I/O delays. The 4 ns input budget is narrower than the old release's 8 ns but remains an FPGA-only budget, not complete board setup/hold closure. Preserved loader pulse uniqueness across the 28/84 MHz domains and existing memory isolation/refresh checks. All regression suites and the structural check pass. Stock-BIOS simulation and ISE are running for the final candidate. [Diagnosis and reproduction](gs-timing.md).

Final candidate 26102801 passes the 2500 ms stock-BIOS/4096 KB signature with the same manifest as ISE. ISE reports zero errors for the declared constraints, no latches, 9,828 LUTs and 3,352 occupied slices. Generic package SHA-256: `abef39ec1b2db0e662879ffb18d8c4eebd871d8cb770fa8f49b6b9674f571df9`.

Backed up the actual SD1 package and found only the user's saved 60 Hz selection differed from the previous release (byte 517). Preserved the OSD block in the new transfer copy, replaced only `baseconf.kg1`, verified bytes and every other root file hash, synced/unmounted/ejected. Firmware now lists 26102801. Installed SHA-256: `b3f3ffc0cac1dc70ee7c6c7e490e3f26c323540e0a17da66bbb14c62e125639b`. Updated forge/board skills document the regression and mutable settings. No SD2 or CF files changed in this update. Next: user selects the new core and compares Dune music tempo/pitch/stereo. [Transfer record](evidence/gs-sd1-transfer-26102801.json).

### Follow-up: remaining distortion and OSD clipping

User confirms 26102801 is much better, but reports intermittent GS distortion/slowdown and a Dune memory-check failure until power cycling. The OSD photo establishes footer clipping at 60 Hz. Candidate 26102802 uses FPGA block RAM for GS low 64 KiB and moves the OSD origin according to raster. Short tests now have zero GS memory waits; full-page marks, stock BIOS and ISE pass. Real-ROM intro recordings reproduce old underruns (299 by 9.23 seconds); the new core records zero through 13.29 seconds. Both controllers pass cold/F3 warm memory checks with 62 usable pages and byte-for-byte MOD upload. Matching ten-second WAVs are saved; longer controller runs were intentionally stopped after collecting that evidence, while the reference completed 30 seconds. [Details and recordings](gs-audio.md). A later user MP4 will provide physical audio evidence.

Final 26102802 checks: adapter/CPU/GS/HID regressions, expanded board controls and OSD pixels, structural lint, 2500 ms stock-BIOS/4096 KB menu and ISE all pass within their stated coverage. ISE uses 9,905 LUTs, 3,351 slices, 38 RAMB16 and 6 RAMB8, with zero declared timing errors. Package/ROM payload checks pass. SD1 replacement preserves Covox off and 60 Hz, readback matches, other root files are unchanged, and the card was cleanly ejected. Live firmware lists 26102802. [Transfer](evidence/gs-sd1-transfer-26102802.json), [implementation](evidence/ise-26102802.json). SD2 and CF were untouched. The original physical 1Mb error remains unreproduced; next is the user's updated-core listening/OSD check and MP4.

Final consistency review: all generated implementation inputs and maintained RTL match the built manifest; package, bitstream and retained BIOS/ISE hashes match. All three ten-second WAVs match their provenance. Documentation links resolve and both updated skills validate.

### 26102802 feedback: OSD accepted, Gluk boot reported

User confirms “OSD good!” and reports startup into Gluk instead of ERS. ROM/RTC/HID/reset code and EEPROM bank are unchanged between builds. Stock ROM selects the reset target from CMOS ED. Targeted simulation confirms Menu+G leaks G into the Spectrum matrix; ERS uses G to cycle that saved target, so this is a candidate cause, not a confirmed incident explanation. Requested the stock 0+reset recovery check and shortcut history. No core, firmware or board settings changed during this investigation. [Findings and recovery](boot-regression.md).

### Shortcut prevention and physical GS acceptance

User confirms holding 0 across resets restores ERS startup, and reports “GS Sounds ok now”. OSD and GS listening are accepted for 26102802. Candidate 26102803 adds a narrow keyboard filter for the package's reserved Win/Menu shortcuts in both HID matrix and PS/2-buffer paths. Initial targeted filter and MCU/HID regressions pass; full regressions, stock-BIOS check and ISE are running. GS/storage/audio and OSD RTL remain unchanged.

Final 26102803: all regressions and structural lint pass; stock BIOS reaches the ERS/4096 KB signature at 2500 ms. ISE reports zero timing errors for declared constraints, 10,388 LUTs, 6,192 slice registers, 3,411/3,758 occupied slices and no latches. GS/audio/storage/overlay sources match 26102802. Package payloads and the BIOS/ISE manifest agree. Backed up the actual SD1 package, preserved its settings, replaced only baseconf.kg1, verified readback and other root hashes, synced/unmounted/ejected. Firmware lists 26102803. [Transfer](evidence/shortcut-sd1-transfer-26102803.json), [implementation](evidence/ise-26102803.json). Next: user checks Menu+G does not change ERS's reset target, including both release orders. No MCU firmware, physical EEPROM, SD2 or CF changes were made by the host.

### 26102803 board acceptance

The user reports “all works” after installing 26102803 and the requested shortcut/ERS-reset check. The current GS, OSD and shortcut-prevention iteration is accepted on the board. No further RTL, package or board changes were made for this acknowledgment. Remaining feature-specific hardware tests stay listed separately. [Acceptance record](evidence/board-acceptance-26102803.json).

### SEGA keyboard mapping — candidate 26102804

User requests SEGA on both joystick selectors with directions Q/A/O/P, A/B/C = Z/X/C, X/Y/Z = S/D/F, START = 0 and MODE = 9, and asks for documentation. Added mode 6 without renumbering existing choices. The adapted HID parser maps all twelve controls into the Spectrum keyboard matrix. Extended MCU/HID tests pass for both ports, individual/combined controls, releases, mode changes, keyboard coexistence and mixed Kempston operation. [Setup and full mapping](joysticks.md) also documents the MCU's existing START combinations. Full regressions, stock BIOS and Docker ISE are running.

Final 26102804: full regression suite, structural lint, 2500 ms ERS/4096 KB BIOS signature and ISE declared timing constraints pass. ISE reports 10,305 LUTs, 6,204 slice registers, 3,355 occupied slices (89%), no latches, 38 RAMB16 and 6 RAMB8. Independent package parsing verifies FPGA/ROM payloads and both seven-option joystick menus. SD1 replacement is readback-verified, other root files are unchanged, and the card cleanly ejected. Current saved settings are preserved (both joystick selectors remain Kempston); SEGA is available for explicit selection. Only package metadata and HID joystick mapping differ from accepted 26102803. Physical pad/redefine-keys acceptance remains pending. [Mapping](joysticks.md), [implementation](evidence/ise-26102804.json), [package check](evidence/sega-package-26102804.json).

Live firmware lists 26102804. [Transfer and listing evidence](evidence/sega-sd1-transfer-26102804.json).

### Mini and Mini G feasibility assessment

Inspected the supplied TSConf wrappers/projects, MCU firmware and packager. `.kg2` targets Mini and `.kg3` Mini G; all use the same package format and XC6SLX25/ISE toolchain. Offline development, simulation, implementation and packaging are feasible. Required work includes target-specific wrappers/pins, real video blanking for HDMI, audio outputs and build isolation. Fit and physical compatibility remain unproven; the current GO build occupies 89% of slices, and separate Mini hardware schematics are absent locally. No Mini core was implemented or built, and installed GO 26102804 remains unchanged. [Full assessment](mini-port-feasibility.md).

### Mini / Mini G implementation in progress

User requests actual kg2/kg3 packages alongside the existing kg1. Added isolated board targets, explicit wrapper transformations, absent-FDC behavior, analog/I2S/HDMI audio wiring and MCU FT-video takeover. HDMI blanking travels with RGB through the scan-doubler; a real video test exposed and fixed its read-valid pipeline edge. Both rasters and all four mode families now preserve 720 active pixels per line and all 26 OSD rows. First ISE trials fit at 97–98% slices. HDMI simulation exposed clock-reset handling and model-period quantization; reset adaptations and matched model periods are under test. Final implementation, BIOS and transport validation are running. GO release 26102804 remains unchanged; no hardware transfer is part of this step.

### Mini / Mini G packages complete — 26102805

Generated genuine BaseConf kg2 and kg3 packages. Mini uses 3,684 slices (98%) and Mini G 3,660 (97%); both use 37 RAMB16 + 6 RAMB8 and pass normal/FT plus core-video timing with zero errors. Final adapter/GS/HID/SEGA/board/OSD checks, real video blanking/mode tests, HDMI pixels/audio/clock-switch tests and 2500 ms stock-BIOS ERS/4096 KB checks pass. Independent parsing verifies FPGA/ROM payloads and menus; each target's BIOS/video/HDMI/ISE/package evidence shares its final manifest. [Release guide and packages](mini-cores.md).

The HDMI adaptation now programs exactly one complete transaction per valid measured frequency, holds reset through programming/source switches, and stretches release. The core timing pass retains the asynchronous FT FIFO bound; removing it would incorrectly apply synchronous hold checks across unrelated clocks. No constraints were globally disabled to obtain closure.

Release snapshots and all three files are in `build/releases/multi-board-26102805/`. The kg1 is the unchanged 26102804 generic package; a fresh source-generation comparison finds no GO input changes, and full GO regressions pass. Updated project skills validate and documentation/prompt history records the new commands. No binaries downloaded, no external source modifications and no board transfer. Mini packages remain untested on physical hardware; older Mini revision/clock wiring still requires a schematic audit.


## Forge workspace reorganization (2026-10-28)

Moved this project, including GO/Mini/Mini G targets, into `forge/cores/zx-evo-base/`. Shared Karabas references, ISE/HDL tools and board utilities remain at the Forge root. Core RTL/constraints now live in `src/`; authoritative BIOS, font, microcode and test-media inputs live in `res/` with checksums and provenance. Core-owned source locks retain exact shared dependency requirements. See [workspace layout and extraction](workspace.md).

All 13,148 moved files passed byte-level verification. Historical evidence, release snapshots and prompt records remain unchanged. Fresh preparation matches all three pre-move and accepted implementation manifests exactly. Packaging with the preserved ISE bitstreams produces byte-identical kg1/kg2/kg3 files. No new synthesis/place-and-route result is claimed.

Fresh validation passed on all boards: elaboration, all existing regression suites, structural lint, and 2500 ms stock-BIOS ERS/4096 KB menu verification. Mini/Mini G also passed real video and HDMI checks. Six shared/core path tests, source/resource checksums, GO B4 pin audit, media inspection/staging and the Docker XST adapter passed. Default generated source paths were refreshed; old compiled caches were retained under core `tmp/pre-relocation-caches/`. No hardware transfer or firmware/media change was performed. [Verification record](evidence/reorganization.json).


## AY noise follow-up (2026-10-28)

Remote feedback reports noisy AY on kg2/kg3 through HDMI and analog, with GS sounding correct. Compared 38 imported audio files against the pinned TSConf checkout; the AY/YM/JT03/mixer sources match. Mini analog gain differs by approximately four, but that difference cannot explain Mini G or HDMI, so no speculative production change was made.

Added the CPU-driven `test --suite ay` regression (also in `all`). All 18 board/speed/type combinations pass register readback on both chips, fixed stereo levels and an exact-period noise-disabled tone. Generated hardware manifests and existing packages remain unchanged. The unknown remote workload and physical noise remain unreproduced; [findings, limits and next evidence](ay-audio.md).

## Shared GS/EVO reset controls (2026-10-28)

Build 26102806 removes the GS Reset OSD item and Menu+G hotkey, couples GS to the main stretched reset, and recognizes F12 in every HID slot. Held boot-selection keys survive reset. G is no longer reserved on HID/PS2. The stock ROM, MCU firmware and audio generators are unchanged.

Thirty stock-ROM reset choices pass across GO/Mini/Mini G: CS, SS, D, C, H, S, 0, A+B, A+B+C and CS+SS. Full regressions/lint, normal ERS/4096 KB startup at 2500 ms, ISE timing/package checks and Mini video/HDMI tests pass. Fresh preparation reproduces the implementation manifests. Packages, checksums and source/proof snapshots are in `build/releases/reset-26102806/`; [controls and evidence](reset-controls.md). No hardware transfer was performed; remote AY noise and physical reset acceptance remain open.

## Hotkey reference (2026-10-28)

Added [keyboard shortcuts](hotkeys.md) for all three targets: OSD/core controls, Win/CS/SS PC mappings, each requested EVO reset combination, keyboard-test examples, key-hold/release order and the 0 recovery exception. Linked it from the README, reset guide and hardware-test procedure; marked the old GS Reset acceptance instructions as historical. Checked all nine configured shortcuts and local links. Documentation-only update; release packages and validation snapshots are unchanged.

## Hotkeys accepted on all boards (2026-10-28)

User feedback: “hotkeys work”, followed by “work on all boards also - mark it done”. Marked the 26102806 hotkey/EVO reset-selection task **done for GO, Mini and Mini G** and updated the current plan, problems, hotkey guide, reset guide and handover. [Acceptance record](evidence/hotkey-acceptance-26102806.json). Release snapshots remain historical; the separate AY noise report is still open.

## ZX-Format 2 AY workload (2026-10-28)

Analyzed the supplied same-board Mini G recordings and extracted the unchanged intro from ZX-FORM2.TRD. Fuse captures 27,918 AY writes. The player uses OUTD to BEFD; it has no envelope writes and no audible noise channel during roughly the first 15 seconds. Expanded synthetic CPU tests pass all 18 board/speed/type cases; actual BaseConf execution matches Fuse for its first 660 writes at asserted 3.5 MHz. Speaker/Covox stay silent in that isolated test.

Corrected an AY test setup error: EEF7 writes in shadow mode were ignored, so the old slow35 label actually covered 7 MHz. The current AY harness leaves shadow mode, writes EFF7 and asserts the active speed. The older generic boot harness has the same historical coverage limitation, documented for follow-up.

The complete 25.309-second captured-stream replay compares BaseConf/TSConf decode and CE phase using their identical PSG/mixer modules. Difference RMS is 0.854 versus signal RMS 2040.487, with channel correlations above 0.9999999. That phase difference does not explain the recording. Added reproducible capture, actual-player and replay tools/tests, comparison WAVs and [evidence](evidence/ay-zxformat2.json). All production manifests still match 26102806. Hardware AY noise remains open; no production RTL, package or device change. [Detailed findings and limitations](ay-audio.md).

## HDMI audio recheck (2026-10-28)

Compared the released Mini/Mini G HDMI paths to local TSConf. Sample capture/CDC, PCM expansion, packetizer, ACR, signaling and serializer sources are identical. Mini G's integer sample divider is 583 in both cores. Only Mini's divider differs (634 versus 635); other changes are the existing PLL/reset corrections and always-enabled HDMI.

Added `hdmi-audio-test`: actual BaseConf 50/60 Hz ZX raster, stereo packet payload/order/parity, queue capacity, N/CTS and data-island clipping. All eight cases pass with at most three pending samples. Fresh existing transport/PLL-mode tests pass on both boards. Production manifests still match 26102806; no package/hardware changes. This does not reproduce or fix the AY hardware noise. [Audit and evidence](hdmi-audio.md).

## 2026-10-31 — complete distribution bundle

Revalidated 26102806 inputs for GO/Mini/Mini G against their completed ISE manifests: all identical. Added `tools/release.py` to independently verify packages and the matching shared UKNC-compatible RP2040 UF2s, collect Dune media and reports, and create/read back an archive with SHA-256 checksums. Installation/rebuild instructions are in [builds and installation](builds-and-installation.md). The controller binaries match the UKNC bundle exactly. No HDL/audio change or board transfer; Mini/Mini G AY noise remains unresolved.
