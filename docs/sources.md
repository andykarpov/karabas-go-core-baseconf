# Sources

Where the files of `src/` come from and what the port changed in them. The changes were made by
`prepare` of the forge flow ([forge/tools/forge.py](forge/tools/forge.py)); here they are part of
the files.

| Path in `src/` | Origin |
|---|---|
| `rtl/baseconf.v`, `rtl/karabas_*_top.v` | the port: BaseConf `top.v` and the TS-Conf board wrappers, adapted |
| `rtl/baseconf_sram.v`, `rtl/baseconf_sdram.v`, `rtl/baseconf_storage.v`, `rtl/baseconf_keyboard_filter.v`, `rtl/video_fontrom.v` | the port (new) |
| `rtl/mini/` | the Mini / Mini G variants of `baseconf.v`, `video_top.v`, `video_vga_double.v` (below) |
| `rtl/zxevo/` | [zxevo.pentevo](https://github.com/aaydev/zxevo.pentevo) `ec1405e`, `fpga/baseconf/trunk` (`z80`, `mem`, `video`, `spihub`, `common`, `dram`) |
| `rtl/T80`, `rtl/sound`, `rtl/vg93`, `rtl/mcu`, `rtl/hdmi` | [karabas-go-core-tsconf](https://github.com/andykarpov/karabas-go-core-tsconf) `edb2060`, `src/rtl` |
| `rtl/kg/` | two files of karabas-go-modules `cff5087`, changed (below) |
| `../modules` | [karabas-go-modules](https://github.com/andykarpov/karabas-go-modules) `cff5087` (the revision TS-Conf had), unchanged files only |
| `roms/baseconf.rom`, `atm_font.hex` | zxevo.pentevo `rom/zxevo.rom`, `fpga/baseconf/trunk/video/atm.fnt` (as hex) |
| `roms/gs105b.rom`, `vg93-microcode-rom.hex` | karabas-go-core-tsconf `src/roms`, `src/rtl/vg93` |
| `karabas_*.ucf` | the pins of the TS-Conf ucf of the board, the timing of the port |
| `karabas_*.xst`, `karabas_*.ut` | TS-Conf (the include dirs of this tree) |

## Changes to the BaseConf sources

All files: the include of `tune.v` is `baseconf_tune.vh` (empty: no simulation-only code), the
cp1251 comments are UTF-8.

- `zports.v`: the registers clocked by `zclk` run on `fclk` with `zpos`; the three transparent IDE
  trigger latches are `fclk` registers; blocking assignments of the ATM registers are non-blocking;
  `xxBD` reads as `xxBE` (the register map of the newer `base_trdemu` that the BIOS uses), breakpoint
  writes only at `10BD` / `11BD`; register `13BD` reads 0 (no virtual drives); the output `shadow_out`.
- `zmem.v`: the CPU read latch clocked by `cpu_strobe` is an `fclk` register with a bypass while
  `cpu_strobe` is high.
- `zclock.v`: the power-up values of the simulation are kept for the FPGA (INIT values).
- `zdos.v`: a non-blocking assignment. `atm_pager.v`, `zint.v`: the `SIMULATE` blocks are always
  in; `zint.v` drives 1 instead of Z.
- Mini / Mini G (`rtl/mini/`): `baseconf.v` without the physical floppy controller (its outputs
  inactive) and with `VGA_BLANK` from the video; `video_top.v` / `video_vga_double.v` carry the
  blanking through the spare bit of the scan doubler RAM (for HDMI).

## Changes to the TS-Conf and modules sources

- `sound/gs.v`: a `MEM_WAIT_n` input (GS memory in SDRAM / block RAM), the bank of the address
  valid at once.
- `mcu/hid_parser.vhd`: joystick mode 6 SEGA (all twelve buttons as Spectrum keys).
- `sound/turbosound.v`: the AY I/O ports read FF.
- `vg93/hrdy_fdc.v`: INIT values of the free-running counters. `vg93/vg93_host_bus.v`: the register
  address is taken with the written data (a 14 MHz CPU changes it before the 8 MHz side sees the end
  of the write).
- `hdmi/hdmi_pll.v` (Mini boards): one whole DCM programming per measured FT frequency, the reset
  held over it.
- `rtl/kg/kg_osd_overlay.v`: the vertical offset of the OSD is an input (`v_offset`: 50 / 60 Hz).
- `rtl/kg/pll_reset.v` (Mini boards): a held reset request is not overridden by the stretch counter.
