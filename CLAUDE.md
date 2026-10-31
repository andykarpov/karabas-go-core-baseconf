# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

ZX Evolution BaseConf (NedoPC) on the Karabas Go, Mini and Mini G boards: Xilinx Spartan-6 XC6SLX25-2, ISE 14.7 (XST). The port is by Sergei Lemeshev (lordamot), made in his workspace karabas-forge (closed after the move, lordamot/karabas-forge#1) and moved here on 2026-10-31. `src/` holds the output of the forge `prepare` for build 26102806 (the patched sources of zxevo.pentevo, karabas-go-core-tsconf and karabas-go-modules) with the paths of this repo: no generator any more, the files are edited directly. `docs/sources.md` lists the origin of every path and the changes made to the shared sources; `docs/forge/` is the archive of the forge core directory (plans, problems, tests, the flow `tools/forge.py`); its paths and commands refer to the forge workspace.

Keep the authorship: `README.md` / `README.ru.md` name the author of the port and the upstream authors and licenses (GPL-3.0-or-later; TS-Conf parts MIT, `docs/licenses/`; the ROMs keep their own terms). Keep both READMEs in step with the OSD of `core*.json`.

## Related repositories (siblings in `..`)

- `karabas-go-modules` (submodule `modules/`, at `cff5087`, the revision karabas-go-core-tsconf had): only files this port did not change come from it. The two changed ones are `src/rtl/kg/kg_osd_overlay.v` (`v_offset` input) and `src/rtl/kg/pll_reset.v` (held reset fix, Mini boards). Moving to modules master is a later step: it changes the bitstream and needs a hardware check.
- `karabas-go-core-tsconf`: the origin of `src/rtl/{T80,sound,vg93,mcu,hdmi}` and of the board wrappers.
- `karabas-go-firmware`: no firmware change is needed (EVO RTC mode `rtc_mode` 2, burst caps with `BURST_MAX_MHZ` 1 on Go / Mini G, 0 on Mini).
- `karabas-go-tools`: `make_core.py` (a copy in `src/`) packs `core.json` (Go), `core_mini.json`, `core_minig.json` into `baseconf.kg1` / `kg2` / `kg3`.

## Build

- `cd src && make` builds the three boards (`make go`, `make mini`, `make minig`; steps `<board>-xst`, `-impl`, `-core`; `make <board>-report`). The Mini boards also need `make <board>-coremode` (trce without the FT mode constraints of HDMI, `pcf_core.py`).
- The ISE commands and options are those of `forge.py ise` (map / par defaults on Go, `-ol high -t 2` Mini, `-ol high -t 1` Mini G): with them the sources reproduce the forge bitstreams. Change them only on purpose (the usual default of new cores is `-t 2`).
- Inputs per board: `karabas_<board>.prj` (the order of the files is that of forge), `.xst`, `.ucf`, `.ut`. Go and the Mini boards differ in `rtl/mini/` (no physical FDC, HDMI blanking) and the top.
- Builds take 10..30 minutes: run them in the background, one board at a time, do not edit RTL while XST runs, and do not build all boards without need. The Mini builds use 96-98 % of the slices.
- The `.bin` and `.kg*` files are committed as the release.
