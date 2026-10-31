# Problems and remaining work

These are actual limits of the current result, not hypothetical release warnings.

| Priority | Open item | Consequence / next action |
|---|---|---|
| High | AY noise reported on Mini/Mini G | Remote user reports noise on HDMI and analog while GS plays correctly. ZX-Format 2 kg3 recordings confirm the comparison. Expanded OUTD tests and actual-player checks pass; full trace replay tests the TSConf CE-phase difference. Hardware cause remains unresolved. [Investigation](ay-audio.md). |
| Acceptance | SEGA mode 26102804 | All twelve controls on both ports pass digital tests; ISE/BIOS and SD1 readback pass. Physical gamepad/redefine-keys check pending. [Mapping](joysticks.md). |
| Hardware observation | Video vertical offset at 50 Hz | User reports that selecting 60 Hz in OSD fixes the monitor cropping. No video RTL change has been made. |
| Partial acceptance | Physical BIOS and Dune display observed | ers.jpg shows the ERS menu and 4096 KB; dune.jpg shows Dune rendering. Full controls, resets, storage and sustained gameplay acceptance remain incomplete. |
| High | GS listening accepted; sustained gameplay remains | User confirms GS sounds OK on 26102802. Actual intro comparison and recordings are retained; sustained gameplay remains a separate acceptance item. |
| High | Intermittent GS “1Mb error” | Physical failure after OSD interaction required power cycling. Both controller versions pass cold and F3 warm checks with 62 usable pages in simulation; cause remains unreproduced. |
| High | Real CF/FDC media acceptance absent | CPU tests cover both Nemo byte sequences and Firefly register/system accesses at all CPU speeds. Physical bus timing, restore/seek, sector read/write, CRC, write protect and card variants remain untested. |
| High | Dune gameplay not tested | Dune files are verified on SD2; the user supplied a rendering photo and reports GS playback. Record the working boot path and confirm mission controls and sustained corrected audio at 14 MHz. |
| Medium | Original AVR virtual-drive/COM services absent | COM reads return FF; the original BIOS “mount A:” workflow is not automatically supplied by the RP2040 integration. Physical FDC is the implemented path. |
| Medium | AVR firmware-version service absent | The simulated menu shows `Baseconf: NONE` and `AVR Boot: NONE`; the reference AVR version service is not emulated. This did not prevent the menu from starting. Karabas package identity remains in `core.json`. |
| Medium | Extended video/frame output and audio not measured | Retained BaseConf video and reference audio logic still need pixel-pattern, palette/font, stereo and FM acceptance. |
| Medium | Timing constraints are provisional | ISE passes the declared periods, cross-domain datapath budgets, SRAM/SDRAM budgets and MCU MOSI/MISO offsets. CF/FDC/SD/video pin timing, SDRAM board skew and CDC protocol acceptance remain incomplete. The inherited CPU latch clock has been removed. |
| Medium | PCB audit uses explicit net aliases | 183 ball/net matches pass. TP1–TP7 functions, buffer inversion and voltage still require schematic/electrical review. |
| Review | Inherited RTL warnings | Yosys structural check passes after hierarchy flattening/internal tristate resolution, but records 54 distinct warnings. Inspect `build/baseconf/lint.log` and the retained ISE reports. ISE also warns about the non-dedicated MCU SCK route, inactive/loadless pads, pull-ups on driven nets, and inactive scan-doubler addresses beyond its 1536-byte array. |

Resolved in 26102803: reserved shortcut leakage/Gluk startup prevention is accepted by the user after ERS recovery. GS audio and OSD are also accepted for this iteration.

Resolved: missing pinned shared modules; absent local simulators; Altera-specific font wrapper; full main-RAM preservation; ROM/GS aliasing guard; stale ROM completion on page changes; HID width and unused input wiring; duplicate RTC updates; modern BD port-map compatibility; broad PSG read decoding; FDC counter startup and 14 MHz write-address capture. Maintained source lives in `src/rtl/`; core-specific generated files are excluded by the core-local `.gitignore`.

The current package contains the newly generated BaseConf bitstream. No reference TSConf binary has been relabeled or packaged. Successful simulation and structural checking are not recorded as a successful board run.

Mini/Mini G: active-video timing, board wrappers and HDMI transport are implemented and their simulations pass. Final ISE/BIOS, both timing modes and package checks pass. Slices are nearly full (26102806: Mini 98%, Mini G 96%); further additions may require packing/logic optimization. Separate Mini schematics are absent locally and older revision/clock modifications need an audit. Physical floppy/DB9 support is absent on the supplied Mini interfaces. FT modes above 64 MHz are outside the declared implementation coverage. No Mini hardware validation is claimed. [Build guide and limits](mini-cores.md).

Current follow-up: 26102801 improves playback but does not fully resolve distortion/slowdown. The user reports a subsequent Dune “GS Check 1Mb error” that required power cycling; this remains unreproduced. Candidate 26102802 moves ROM/workspace into BRAM and passes cold/warm memory checks in the real-ROM harness. OSD clipping at 60 Hz is a separate confirmed fixed-origin error; the new pixel test passes both rasters. [Current evidence and limits](gs-audio.md).

Resolved in 26102806: user confirms hotkeys and EVO reset selections work on **GO, Mini and Mini G** and requested the task be marked done. [Acceptance record](evidence/hotkey-acceptance-26102806.json). The separate AY noise report remains open.
