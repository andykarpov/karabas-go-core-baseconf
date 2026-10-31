# Source attribution

This combined BaseConf adaptation is distributed under GPL-3.0-or-later; see `LICENSE`. Original notices remain in adapted source and generated copies. Third-party components retain their own license notices and conditions.

- ZX-Evo Base Configuration: NedoPC; original top, paging, ports, video and SD logic, GPL-3.0-or-later. Reference is the provided `zxevo.pentevo` checkout.
- Karabas GO TSConf wrapper/peripherals: Andy Karpov and contributors including Oleh Starychenko; repository MIT notice is retained under `docs/licenses/`. Individual imported components retain their own headers.
- T80: Daniel Wallner, FPGA Arcade and subsequent contributors; BSD-style notices in the VHDL source.
- JT12/JT03 FM: Jose Tejada and contributors; GPL notices in the individual sources.
- Physical FDC: Firefly-derived Karabas TSConf `vg93` implementation; original source headers and microcode remain in the imported build tree.
- Karabas shared MCU, memory, OSD, cursor, clock and DAC modules: the pinned `karabas-go-modules` checkout, with its source-level notices.
- Core packaging: upstream `karabas-go-tools/make_core/make_core.py`, pinned alongside the firmware protocol reference.
- Hardware: Karabas GO hardware/documentation is CC BY-NC-SA 4.0 according to its repository; hardware files are reference material, not relicensed by this project.

`config/sources.lock.json` records repository URLs/revisions. Shared `../../../config/binaries.lock.json` records tool-package URLs/SHA-256. The generated `build/baseconf/manifest.json` records exact HDL/configuration/ROM input hashes. ROMs and game files are supplied reference assets; they are not authored or relicensed here. Preserve their original provenance when distributing a build.

New files: `src/rtl/baseconf_sram.v`, `src/rtl/baseconf_sdram.v`, `src/rtl/baseconf_storage.v`, `src/rtl/video_fontrom.v`, testbenches and Python tooling. `src/rtl/baseconf.v` and `src/rtl/karabas_go_top.v` are adaptations, not clean-room reimplementations.

Mini/Mini G HDMI uses the pinned Karabas HDMI clock/transport wrapper and zhdmi transmitter by François Galea (GPL-3.0-or-later notices retained). Target wrappers inherit the respective Karabas top-level copyright headers. ISE unisim files extracted for local simulation remain vendor simulation material under build/, are absent from synthesis manifests, and are not included in the source/package release.

Core resource origins and checksums are recorded in `res/manifest.json`. BIOS, font, microcode and game fixtures moved without byte changes; original attribution and terms still apply.
