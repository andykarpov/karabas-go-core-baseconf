# BaseConf on Karabas GO B4

This is an experimental source port, not a released board image. The target is XC6SLX25-2-FTG256. Pin locations come from the GO-specific TSConf UCF; the hardware repository identifies B4 as the corresponding GO revision. The 183 assigned balls have been checked against the embedded B4 PCB net data. Schematic buffer polarity/test-point function review and physical timing validation remain outstanding.

## Source boundaries

`src/rtl/baseconf.v` adapts the NedoPC BaseConf top level. The pager, NMI/breakpoint logic, memory scheduler, port decoding, SD interface and extended video pipeline come from `external/zxevo.pentevo/fpga/baseconf/trunk`. `tools/forge.py prepare` copies selected sources into `build/baseconf/`, applies explicit transformations, and records SHA-256 hashes in `manifest.json`. Original HDL checkouts are not edited. Locked repository commits are in `config/sources.lock.json`.

`src/rtl/karabas_go_top.v` derives from the TSConf GO board wrapper. It retains the known RP2040 SPI command interface, HID parser, OSD overlay, mouse accumulator, PCM5102 output and GO pin names. The CPU is T80pa using positive/negative clock enables. The board's physical Z80 pins and AVR SPI link are not synthesized.

## Memory and timing

| Resource | Mapping | Implementation |
|---|---|---|
| BaseConf RAM | Full 4 MB, 256 × 16 KB pages | Both 2M × 8 SRAM chips, shared 21-bit word address |
| GS memory | Byte addresses 000000–1FFFFF | Low 64 KiB in FPGA dual-port block RAM; remaining space at unchanged SDRAM addresses; reference mapper with memory WAIT input |
| BaseConf ROM | SDRAM byte addresses 200000–27FFFF | 32 × 16 KB pages, loaded from the 512 KB `zxevo.rom` |
| MCU ROM upload | Logical addresses 00000000–0007FFFF | Translated to SDRAM 200000–27FFFF |
| MCU GS ROM upload | Logical addresses 80000000–80007FFF | Loaded into GS block RAM 000000–007FFF |
| Font | 2 KB | Initialized inferred dual-port RAM; replaces Altera-only wrapper |

BaseConf deliberately stores **even CPU bytes in the upper SRAM lane** and odd bytes in the lower lane. The CPU and video logic retain that convention. SDRAM ROM/GS byte addressing is conventional, with even bytes in the lower lane. These conventions are independent.

At power-up BaseConf maps ROM31 into **every** 16 KB window. BIOS must program ATM page registers and enable paging before RAM appears. The integrated diagnostic does this using Z80 I/O; it does not force the mapper.

The SRAM adapter preserves the four-clock BaseConf memory cycle and its `cbeg`/read-data timing. SRAM output enable is disabled before changing direction; byte-write data stays valid after WE rises. The BaseConf scheduler still allocates video bandwidth and applies CPU contention/stalls. The original CPU read-data transparent latch is replaced by an fclk register with a live-data bypass during `cpu_strobe`; this preserves same-cycle visibility while removing the fabric-generated latch clock.

The PLL retains the reference 50 MHz input, 84.0909 MHz system, 28.0303 MHz bus and 7.974 MHz FDC clocks. Shared ROM/GS SDRAM now uses the 84 MHz domain, following the working TSConf memory service rate. It retains inverted clock forwarding, CL2/BL1, explicit precharge, 214 µs initialization and autonomous refresh. DQ captures into 16 I/O registers on the rising edge following device CAS+2, allowing another half-cycle for output-clock and input delays; the arbiter consumes the captured byte on the next clock. This capture phase differs from TSConf’s falling-edge register. Address mapping is unchanged.

Candidate 26102802 stores the GS ROM and first RAM bank (low 64 KiB) in dual-port block RAM. CPU reads complete without T2 waits in the short workload; loader writes use the other port. GS memory above 64 KiB retains its SDRAM address, so total capacity and software paging are unchanged. See [full-ROM audio testing](gs-audio.md).

The GS CPU stays at 14.015 MHz; its interrupt divider runs every 374 enables (about 37.47 kHz), independently of the 50/60 Hz video selection. The old 28 MHz memory controller stalled the CPU enough to lose sample service. The new benchmark matches the zero-wait GS reference with and without competing ROM reads. Real Dune playback still needs listening acceptance. See [GS timing diagnosis](gs-timing.md) for measurements and timing-model limits.

A 16-entry loader queue absorbs individual MCU writes. Each 28 MHz write pulse is accepted exactly once in the 84 MHz domain. Firmware burst capability advertises 1 MHz so it cannot overrun the conservative memory service at the reference burst rate; classic command frames remain 16 MHz. Invalid upload addresses or queue overflow latch a fault and hold CPU reset. Reset remains asserted until initialization/upload drain finishes. ROM completions carry an address/write tag, so a DOS page change during a fetch forces a fresh read.

## Inputs and menu

USB enumeration and physical joystick sampling happen in RP2040 firmware. The FPGA receives USB HID reports, PS/2 make/break bytes, mouse deltas, joystick values, RTC updates and OSD commands. Keyboard matrix reads and the ZX-Evo key buffer at RTC F0–FF use the reference HID parser. Reserved Win/Menu shortcuts are filtered from both paths through key release. Build 26102806 removes the GS Reset command and Menu+G binding; G is now an ordinary key. Core reset resets GS as well, and raw F12 is detected in all six HID slots so a preceding boot-selection key cannot hide it from reset detection. The keyboard parser/filter remain alive across core reset, preserving held CS/SS and other keys for the stock ROM. See [reset controls](reset-controls.md). RTC 0C selects/clears the key buffer. The local RTC service has a four-bus-clock wait; unsupported AVR COM service reads return FF.

RTC read/write strobes are one bus clock per CPU access. The original AVR wait request remains asserted across several clocks and must not directly drive `kg_mcu_rtc`: that queued duplicate EEPROM updates. CPU regressions check write counts and readback at all three CPU speeds.

The supplied ROM follows the newer `fpga/base_trdemu/trunk` register map in `rom/ports_evo.a80`: configuration reads use **xxBD**, breakpoint writes use **10BD/11BD**, and BE writes exit NMI. The older `baseconf/trunk` decoder is adapted accordingly; BE configuration reads remain a legacy alias. Register 13BD reads zero because only physical floppy drives are implemented. Unsupported virtual-drive mask writes are ignored. The original unrestricted BD breakpoint write would corrupt the breakpoint on a 13BD access and is now qualified by the register index.

TurboSound reads require low address byte FD, matching the BaseConf port decoder. A low-nibble-only decode incorrectly intercepted mirrored BD configuration reads with address bit 15 set.

Win+Esc is handled by firmware `src/input/input.cpp`; FPGA `kg_osd_overlay` renders the transmitted menu. Its normalized vertical origin is 34 lines at 60 Hz and 64 at 50 Hz, keeping all 26 rows inside the visible raster. `config/core.json` and wrapper register indexes agree:

| Index | Setting |
|---|---|
| 0 | Covox on/off |
| 1 | PSG ABC / ACB / mono |
| 2 | AY / YM type |
| 3 | Left joystick mapping |
| 4 | Right joystick mapping |
| 5 | 50 / 60 Hz raster |
| 6 | CPU pause |
| 7 | NMI |
| 8 | Reset (core and GS) |

Both joystick mappings offer Kempston, Sinclair1, Sinclair2, Cursor, QAOPM, QAOPS and SEGA (appended as mode 6 in 26102804). SEGA maps directions to Q/A/O/P, A/B/C to Z/X/C, X/Y/Z to S/D/F, START to 0 and MODE to 9. See [joystick setup and mapping](joysticks.md). If both are Kempston, the reference HID implementation gives the left port priority. Select different mappings for independent two-player input.

## Storage, graphics and audio

- CF uses the BaseConf Nemo/divIDE decode and 16-bit data latch, wired to the GO CF pins. Z80-clocked port registers become bus-clock registers with `zpos` enables; IDE trigger latches become bus-clock registers. Electrical CF timing and card interoperability need measurement.
- The physical floppy implementation is the TSConf Firefly-derived `hrdy_fdc`/`vg93_*` path and microcode ROM. The #FF read decode is a level separate from its write strobe. Drive selects come directly from the controller's motor/drive decode.
- The FDC wrapper's free-running divider/data-separator counters have explicit FPGA INIT values. Its 8 MHz host receiver captures the register address together with data while a write is active; at 14 MHz the CPU can change its address before that receiver observes write release. Register tests poll BUSY after force-interrupt instead of assuming instantaneous command completion.
- BaseConf ZX/Pentagon, ATM 320×200 16-color, 640×200 multicolor, and 80×25 text pipelines are retained. The original 2-bit-per-channel output is replicated to the 8-bit VGA DAC. There is no TSConf tile/sprite engine in this port.
- TurboSound FM uses the two JT03 paths and reference mixer. GS uses its own T80s and shared SDRAM. Beeper, tape output and Covox use BaseConf port strobes.
- FT812 is used only by the MCU passthrough; CPU VDAC/ZiFi/OPL/SAA extensions from TSConf are not implemented. They are outside the requested feature set.
- MCU FT-video enable releases the FPGA's shared RGB/sync bus and selects the FT video clock. The board simulation checks takeover and release through actual MCU SPI commands.

## Simulation limits

Tests use a protocol-checking SDRAM model, a 10 ns SRAM model and GHDL-translated T80/HID. Clock primitive models are simulation-only and excluded from ISE. Test success establishes the tested digital contracts, not routing timing, FPGA resource fit, analog signal integrity, stock BIOS completion or Dune gameplay. See [validation](validation.md) and [problems](problems.md).

## Mini and Mini G variants

GO, Mini and Mini G share the maintained reset/input implementation. `forge.py --board mini|minig prepare` derives target wrappers from the maintained GO body and the reference Mini pin interfaces. Explicit Mini-only transformations provide scan-doubled blanking, remove physical FDC logic, and adapt HDMI clock programming/reset and sigma-delta/I2S audio. MCU FT takeover selects HDMI's FT input. Main memory, GS, input/shortcut and OSD logic are shared. See [Mini architecture and validation](mini-cores.md) for package paths, supported interfaces and offline verification limits.
