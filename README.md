# ZX Evolution BaseConf core for Karabas Go / Mini / Mini G

[Русская версия](README.ru.md)

The ZX Evolution (Pentevo) of NedoPC with its own FPGA configuration, **BaseConf**, on the Karabas Go
family of boards (Xilinx Spartan-6 XC6SLX25). It runs the stock ZX Evo BIOS (ERS) with 4 MB of RAM,
the extended video modes of the Evo, General Sound and TurboSound FM.

| Board | Core file | Video | Audio | Drives |
|---|---|---|---|---|
| Karabas Go | `baseconf.kg1` | VGA | I2S DAC (PCM5102) | physical floppy drives, CF, SD |
| Karabas Mini | `baseconf.kg2` | HDMI | HDMI, analog output (sigma-delta) | CF, SD |
| Karabas Mini G | `baseconf.kg3` | HDMI | HDMI, I2S DAC (PCM5102) | CF, SD |

## Authors

The port is the work of **Sergei Lemeshev** ([lordamot](https://github.com/lordamot)), made in
October 2026 in his workspace [karabas-forge](https://github.com/lordamot/karabas-forge) and moved
into this repository with his agreement
([karabas-forge#1](https://github.com/lordamot/karabas-forge/issues/1)). The history of the port
(its plans, problems, test records) is kept in [docs/forge](docs/forge/README.md).

It is built from:

- **ZX-Evo Base Configuration** (c) NedoPC 2008-2019: the pager, NMI and breakpoints, the memory
  scheduler, the ports, the SD interface and the video pipeline of the Evo, from
  [zxevo.pentevo](https://github.com/aaydev/zxevo.pentevo) at `ec1405e`
  (`fpga/baseconf/trunk`, in `src/rtl/zxevo`); the BIOS `roms/baseconf.rom` (`rom/zxevo.rom`)
  and the ATM font come from there too.
- **The TS-Conf core of Karabas Go** ([karabas-go-core-tsconf](https://github.com/andykarpov/karabas-go-core-tsconf),
  Andy Karpov and contributors, Oleh Starychenko among them): the board wrapper that the top levels
  derive from, General Sound (`gs.v`, ROM `roms/gs105b.rom`), TurboSound, the HID parser,
  the physical floppy controller (`hrdy_fdc` with the VG93 model of
  [FD1793_1818VG93](https://github.com/demyanenko-d/FD1793_1818VG93) and its microcode ROM).
- **T80** (Daniel Wallner, Sorgelig and others), **JT12 / JT03** (Jose Tejada),
  **zhdmi** (François Galea) and the shared modules of
  [karabas-go-modules](https://github.com/andykarpov/karabas-go-modules) (the MCU link, OSD, PLL,
  audio, HDMI), the submodule `modules`.

New in the port: `src/rtl/baseconf.v` and the board tops (adapted from BaseConf and TS-Conf),
`baseconf_sram.v` (4 MB in the two SRAMs), `baseconf_sdram.v` (ROM and GS memory in SDRAM),
`baseconf_storage.v`, `baseconf_keyboard_filter.v`, `video_fontrom.v`, and the changes to the shared
sources listed in [docs/sources.md](docs/sources.md).

## License

GPL-3.0-or-later, see [LICENSE](LICENSE). BaseConf, JT12 and zhdmi are GPL-3.0-or-later; the
TS-Conf core of Karabas Go is MIT ([docs/licenses/karabas-tsconf-MIT.txt](docs/licenses/karabas-tsconf-MIT.txt)),
T80 has its BSD-style notice; every source file keeps its own header. The ROMs in `src/roms` are
unchanged files of their projects (the ZX Evo BIOS of NedoPC, the General Sound ROM 1.05b as
shipped with the TS-Conf core) and keep their original terms: they are not relicensed here.

## Using it

Copy the core file of your board to the SD card (SD1). It works with the current firmware of the
board (no special firmware is needed). The OSD opens with Menu (Win) + Esc.

| Keys | Action |
|---|---|
| Menu+F6 | Covox on / off |
| Menu+F7 | PSG mix: ABC / ACB / mono |
| Menu+F8 | PSG type: AY-3-8912 / YM2149F |
| Menu+F9 | video: 50 Hz / 60 Hz |
| Menu+J, Menu+R | the mapping of the left / right joystick: Kempston, Sinclair 1, Sinclair 2, Cursor, QAOPM, QAOPS, SEGA |
| Menu+P | pause |
| F11 | NMI |
| F12 | reset (the core and GS) |

Shift, Ctrl and keys held over F12 choose the start of the Evo BIOS (Shift: BASIC 128, Ctrl: BASIC 48,
S: CMOS setup, 0: clears the boot choice, ...): [docs/hotkeys.md](docs/hotkeys.md). The joystick
mappings: [docs/joysticks.md](docs/joysticks.md).

## State

Build **26102806** of the port: the hotkeys and the reset choices of the BIOS are checked on Go, Mini
and Mini G hardware; the BIOS menu, 4096 KB of RAM and the Dune game (with GS) were seen running.
Open ([docs/problems.md](docs/problems.md)): AY noise on the Mini and Mini G, the physical floppy
drives and CF cards are not tested on hardware, the AVR services of the real Evo (virtual drives,
COM port) are not there. The Mini builds use 96-98 % of the slices.

## Building

ISE 14.7 (`ISE_SETTINGS`, default `/opt/Xilinx/14.7/ISE_DS/settings64.sh`), from `src/`:

```sh
git submodule update --init
cd src
make go          # baseconf.kg1; mini, minig for the others; make for all three
make go-report   # LUTs, slices, timing
```

`make_core.py` is a link to the sibling repo karabas-go-tools (cloned next to this one). Build 26102806
of karabas-forge is commit `50177ec`; the sources have changed since ([docs/sources.md](docs/sources.md)).
The Mini boards also need `make <board>-coremode` (the timing in the
mode of the core of HDMI).
