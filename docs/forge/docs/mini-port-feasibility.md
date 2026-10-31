# BaseConf for Karabas Mini and Mini G: feasibility

Assessed 2026-10-28 from the sources supplied under `external/`.

Follow-up: implementation was subsequently requested. Current commands and validation status are in [Mini cores](mini-cores.md); the text below records the original feasibility assessment.

**Yes: we can develop, simulate, implement and package both targets without owning either board.** The existing Docker ISE 14.7 toolchain is suitable. Producing a package is distinct from establishing that its video, memory and peripherals work on a physical board. No BaseConf `.kg2` or `.kg3` was built during this assessment.

## Targets and package format

| Extension | Target | FPGA in the supplied TSConf projects |
|---|---|---|
| `.kg1` | Karabas GO | XC6SLX25-2-FTG256 |
| `.kg2` | Karabas Mini, older revisions | XC6SLX25-2-FTG256 |
| `.kg3` | Karabas Mini G, rev. G | XC6SLX25-2-FTG256 |

These are board identifiers, not successive file-format versions. All three use the same `kgo1` container: header, bitstream, ROMs and OSD configuration. The MCU selects the extension for its compiled board target. Each needs a bitstream synthesized with its own wrapper and constraints; renaming the GO package is insufficient.

Sources: [packager documentation](../../../../external/karabas-go-tools/make_core/README.md), [packager implementation](../../../../external/karabas-go-tools/make_core/make_core.py), [firmware board configuration](../../../../external/karabas-go-firmware/src/config.h), [core browser](../../../../external/karabas-go-firmware/src/app_core_browser.cpp), [three-board ISE Makefile](../../../../external/karabas-go-core-tsconf/src/Makefile).

## What we already have

The TSConf repository supplies separate Mini and Mini G top-level HDL, pin constraints, source lists, XST scripts, BitGen settings and package JSON. It also includes an HDMI transmitter, simulation harness and a second timing-analysis pass for core-video mode. These are concrete porting references, not BaseConf binaries.

The MCU firmware already has GO/Mini/Mini G build configurations and common keyboard, mouse, USB gamepad, OSD and ROM-loader protocols. Building the FPGA package does not require a connected MCU or a firmware rebuild. Compatibility with a particular installed firmware version would still need checking.

References: [Mini wrapper](../../../../external/karabas-go-core-tsconf/src/rtl/karabas_mini_top.v), [Mini G wrapper](../../../../external/karabas-go-core-tsconf/src/rtl/karabas_minig_top.v), [firmware environments](../../../../external/karabas-go-firmware/platformio.ini), [HDMI simulation](../../../../external/karabas-go-core-tsconf/src/sim/run_hdmi_sim.sh), [core-mode timing helper](../../../../external/karabas-go-core-tsconf/src/pcf_core.py).

## Required BaseConf work

1. **Separate build targets and provenance.** `tools/forge.py` currently hardcodes GO source lists, top module, filenames and constraints. Add an explicit board selector and isolated build directories, manifests, timing reports and packages. Preserve the existing GO regression and release path.
2. **Board wrappers and pin audit.** Adapt clocks, MCU SPI/burst wiring, SRAM, SDRAM, CF/expansion bus, SD and peripheral resets from each reference. Mini G reroutes clocks and adds dedicated I2S pins; its UCF explicitly declares incompatibility with older Mini revisions. The GO timing budgets cannot simply be inherited as board timing evidence.
3. **HDMI and active-video timing.** Current `src/rtl/baseconf.v` ties `VGA_BLANK` to zero. The reference HDMI wrapper consumes `~video_blank` as data enable, so directly connecting the current signal would assert active video continuously. Export real scan-doubled blanking aligned with RGB and sync, then test 50/60 Hz, extended graphics and OSD. Preserve the MCU's FT812 boot-menu takeover and verify transitions between FT and core clocks.
4. **Audio outputs.** Mini uses sigma-delta analog audio and nominal 44.1 kHz HDMI audio; Mini G uses dedicated I2S DAC and nominal 48 kHz HDMI audio. Adapt the output transport while retaining independent GS CPU/interrupt timing and the accepted low-64-KiB BRAM fix. VSync must not control GS speed.
5. **Available peripherals.** Retain shared BaseConf memory, Nemo IDE, keyboard/mouse, OSD and sound logic where the target interfaces permit it. The reference wrappers expose CF/expansion signals and SD2, but exact physical attachment and memory parts require a schematic/revision audit. Disable or define absent physical floppy behavior; image-based floppy emulation would be separate work, because our current core does not implement the original AVR virtual-drive service.

The Mini firmware returns zero for both physical joystick ports and reports no physical floppy. USB HID/XInput pads are merged separately into the two logical joystick reports, so the SEGA keyboard mapping can remain available for supported USB pads. GO's two physical DB9 connectors and Firefly drive interface are not automatically transferable features.

Sources: [current build tool](../tools/forge.py), [current video output](../src/rtl/baseconf.v), [Mini constraints](../../../../external/karabas-go-core-tsconf/src/karabas_mini.ucf), [Mini G constraints](../../../../external/karabas-go-core-tsconf/src/karabas_minig.ucf), [HDMI wrapper](../../../../external/karabas-go-core-tsconf/src/rtl/hdmi/hdmi_top.v), [Mini firmware board layer](../../../../external/karabas-go-firmware/src/board/board_mini.cpp), [input aggregation](../../../../external/karabas-go-firmware/src/input/input.cpp).

## What can be verified without hardware

| Offline verification | What it establishes |
|---|---|
| HDL elaboration, structural checks and existing CPU/BIOS/input/GS tests | Internal contracts and preservation of shared BaseConf behavior |
| Added video/audio tests at both rasters | Active-video windows, OSD bounds, clock-switch handling and audio sample delivery within the models |
| ISE synthesis, map, route, timing and BitGen for each board | Actual FPGA fit, a generated bitstream and compliance with the declared constraints |
| FT-video and core-video timing passes | Both clock selections are checked; the reference Makefile explains why one pass is insufficient |
| Independent package parsing and payload hashes | Correct target metadata, ROMs, menu and newly generated bitstream are packaged |

These checks cannot demonstrate monitor HDMI lock, analog/I2S audio quality, actual memory timing margins, CF/SD behavior, electrical pin compatibility or successful board loading. An offline release should say **built, simulated and timing-checked; untested on Mini/Mini G**, with the exact checks recorded.

## Remaining uncertainty and proposed order

- The present GO build uses 3,355/3,758 slices (89%) and 38 RAMB16 plus 6 RAMB8 blocks. HDMI adds resources; removal of GO-only interfaces may recover some. Fit is plausible but remains unproven until each BaseConf target is placed and routed. [Current implementation evidence](evidence/ise-26102804.json).
- There is no separate Mini hardware/schematic repository under `external/`. The supplied Mini UCF is labeled rev. C, while comments and firmware describe later clock modifications. Do not claim support for every older Mini revision from this file alone. Mini G has its own explicit rev. G pin map.
- Preserve conservative loader behavior while adapting pins. Reference Mini disables burst capability, whereas Mini G advertises 32 MHz; neither setting should be copied blindly into BaseConf.

If implementation is requested, start with **Mini G**, whose dedicated I2S output is closer to GO and whose reference uses dedicated clock routing, then adapt older Mini audio/clock variants. First add board selection and proper video blanking; next complete a Mini G implementation and both timing passes; finally port Mini and run the same checks. Keep the accepted GO path in regression throughout.

This assessment introduced no tools or downloaded binaries, so it requires no new tool skill. Existing [ISE skill](../../../../skills/ise-docker/SKILL.md) and [build skill](../skills/forge-build/SKILL.md) remain applicable; update the build skill when multi-board commands actually exist.
