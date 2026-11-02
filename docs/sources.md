# Sources

Where the files of `src/` come from and what the port changed in them. The changes were made by
`prepare` of the forge flow ([forge/tools/forge.py](forge/tools/forge.py)); here they are part of
the files. Build 26102806 of forge is commit `50177ec` (its bitstreams byte for byte); since then the
core is on karabas-go-modules master and has its own board tops (below, "Since the move").

| Path in `src/` | Origin |
|---|---|
| `rtl/baseconf.v`, `rtl/karabas_*_top.v` | the port: BaseConf `top.v` and the TS-Conf board wrappers, adapted (`HW_ID1` Go, `HW_ID2` Mini, `HW_ID2 HW_ID3` Mini G, in the `.xst`) |
| `rtl/baseconf_sram.v`, `rtl/baseconf_sdram.v`, `rtl/baseconf_storage.v`, `rtl/baseconf_keyboard_filter.v`, `rtl/video_fontrom.v` | the port (new) |
| `rtl/zxevo/` | [zxevo.pentevo](https://github.com/aaydev/zxevo.pentevo) `ec1405e`, `fpga/baseconf/trunk` (`z80`, `mem`, `video`, `spihub`, `common`, `dram`) |
| `rtl/T80`, `rtl/sound`, `rtl/mcu` | [karabas-go-core-tsconf](https://github.com/andykarpov/karabas-go-core-tsconf) `edb2060`, `src/rtl` |
| `rtl/vg93` (with `vg93-microcode-rom.hex`) | karabas-go-core-tsconf `8a1ce1f`, `src/rtl/vg93`, unchanged: `hrdy_fdc` + the VG93 model of [FD1793_1818VG93](https://github.com/demyanenko-d/FD1793_1818VG93) on clk_bus (as in Profi) |
| `rtl/uart`, `rtl/sound/{covox.vhd,saa1099.v,saa1099_compressor_lut.hex,opl2_top.v,opl2_clk.v,jtopl}` | karabas-go-core-tsconf `8a1ce1f`, unchanged: TS ZiFi + TS / Evo RS232 (`zifi.vhd`), covox / Soundrive, SAA1099, OPL2 on [JTOPL](https://github.com/jotego/jtopl) |
| `rtl/adc` | karabas-go-core-tsconf `d728bcc`, `src/rtl/adc` (the PCM1808 ADC, the I2S of the ESP32) |
| `../modules` | [karabas-go-modules](https://github.com/andykarpov/karabas-go-modules) master, unchanged |
| `roms/baseconf.rom` | NedoPC SVN `svn://svn.nedopc.com/pentevo` r1368 `rom/zxevo_fe.rom` (ERS 0.61.01 with `DOS_FE`, unpatched; needs the TR-DOS emulation traps below) |
| `atm_font.hex` | zxevo.pentevo `fpga/baseconf/trunk/video/atm.fnt` (as hex) |
| `roms/gs105b.rom` | karabas-go-core-tsconf `src/roms` |
| `karabas_*.ucf` | the pins of the TS-Conf ucf of the board, the timing of the port |
| `karabas_*.xst`, `karabas_*.ut` | TS-Conf (the include dirs of this tree) |

The upstream of `rtl/zxevo` is the NedoPC SVN `svn://svn.nedopc.com/pentevo` (the GitHub copy
zxevo.pentevo has the same `fpga/baseconf/trunk`). `fpga/baseconf/trunk` has not changed since r930
(2021); the BaseConf of the official `zxevo_fw.bin` (`cfgs/standalone_base_trdemu`) is
`fpga/base_trdemu/trunk`. Taken from it (r1368) into our `fpga/baseconf` files:

- the TR-DOS emulation traps: `zdos.v` (`in_trdemu`, `trdemu_wr_disable`; no trap while the palette is
  written, r1112), `atm_pager.v` (window 0 = RAM page `#FE` in the emulation), `zports.v` (`fdd_mask` =
  `#13BD`, no `vg_cs_n` for a masked drive, `vg_rdwr_fclk`, `#FF` reads `{intrq, drq, 1, bits 4..0 last
  written}`), wired in `baseconf.v`; on the Go the `#FF` reads come from `zports`, not `hrdy_fdc`;
- `zports.v`: the SD read buffer (r996), the `savelij` ports `#2F`, `#4F`, `#6F`, `#8F` removed.

Not taken: the code / data cache of `zmem.v`, the 8 bit Kempston, the ATM3 444 palette and the ULAplus
raster change, the removal of the `xxBE` reads; the branch `fpga/base_trdemu/newirq` (work in progress).

## Changes to the BaseConf sources

All files: the include of `tune.v` is `baseconf_tune.vh` (empty: no simulation-only code), the
cp1251 comments are UTF-8.

- `zports.v`: the registers clocked by `zclk` run on `fclk` with `zpos`; the three transparent IDE
  trigger latches are `fclk` registers; blocking assignments of the ATM registers are non-blocking;
  `xxBD` reads as `xxBE` (the register map of the newer `base_trdemu` that the BIOS uses), breakpoint
  writes only at `10BD` / `11BD`; the output `shadow_out`.
- `zmem.v`: the CPU read latch clocked by `cpu_strobe` is an `fclk` register with a bypass while
  `cpu_strobe` is high.
- `zclock.v`: the power-up values of the simulation are kept for the FPGA (INIT values).
- `zdos.v`: a non-blocking assignment. `atm_pager.v`, `zint.v`: the `SIMULATE` blocks are always
  in; `zint.v` drives 1 instead of Z.
- Mini / Mini G (`` `ifndef HW_ID1 ``): `baseconf.v` without the physical floppy controller (its
  outputs inactive) and with `VGA_BLANK` from the video; `video_top.v` / `video_vga_double.v` carry
  the blanking through the spare bit of the scan doubler RAM (for HDMI).

## Changes to the TS-Conf and modules sources

- `sound/gs.v`: a `MEM_WAIT_n` input (GS memory in SDRAM / block RAM), the bank of the address
  valid at once.
- `mcu/hid_parser.vhd`: joystick mode 6 SEGA (all twelve buttons as Spectrum keys); the six key slots are decoded
  one per clock by one case (as in the spec256 core), the matrix taken every 6 clocks: 2168 -> 1085 LUT.
- `mcu/hid_parser.vhd`, the RTC registers of the ZX Evolution AVR: reg D bit 6 = F12 held; F0..FF with the
  EEPROM flag (reg C bit 7) off, its power-up state as on the AVR: a write sets the type (not sent to the mcu),
  a read gives the version string of the type (0 = the core build id, 1 = the firmware build id, from the
  mcu as `kg_mcu` `CORE_BUILD` / `FW_BUILD`; date from the YYMMDD digits) or the PS/2 log (type 2).
- `sound/turbosound.v`: the AY I/O ports read FF.
- `kg_osd_overlay.v`: the vertical offset of the OSD is an input (`v_offset`: 50 / 60 Hz); now
  `V_OFFSET_IN` of karabas-go-modules (#19).

## Since the move

- karabas-go-modules master (the new inputs of `kg_mcu` tied off), `kg_osd_overlay` with `V_OFFSET_IN`.
- The Mini copies of `baseconf.v`, `video_top.v`, `video_vga_double.v` merged into the shared files
  (`` `ifdef HW_ID1 ``), the same code for every board as before.
- The Mini and Mini G tops rewritten after those of TS-Conf: `FT_CLK_OUT` 8 MHz (it was not driven:
  the FT812 had no clock, its audio output hums into the analog outputs), the PCM1808 ADC (line in,
  the MIDI synth of the Mini G) and on the Mini G the ESP32 I2S mixed into the sound (`audio_mixer`
  of TS-Conf), `MIDI_CLK` on the Mini, the I2S DAC on the flash pins of the Mini, the analog output
  of the Mini at the level of TS-Conf (a quarter of full scale), `audio_en` of HDMI off with the
  DVI-only setting of the firmware.
- `src/Makefile` of the other cores (cost table 2 on every board).
- The HDMI of the Mini boards (the core or the FT812) is `kg_hdmi_ft` of karabas-go-modules
  `rtl/video/hdmi` (#20: the `hdmi_top` / `hdmi_pll` of TS-Conf and menu with the held reset fix
  of `pll_reset.v`); the local `rtl/hdmi` is gone.
- ROM bursts of the MCU at 32 MHz on the Mini G, 16 MHz on Go / Mini (`BURST_MAX_MHZ` of `kg_mcu`,
  1 MHz before): the queue of `baseconf_storage` writes a byte into the SDRAM faster than a burst
  brings one, so `BURST_READY` stays 1. The ROMs of the Mini G load in 0.56 s (5.7 s before).
