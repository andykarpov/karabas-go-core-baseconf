# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

ZX Evolution BaseConf (NedoPC) on the Karabas Go, Mini and Mini G boards: Xilinx Spartan-6 XC6SLX25-2, ISE 14.7 (XST). The port is by Sergei Lemeshev (lordamot), made in his workspace karabas-forge (closed after the move, lordamot/karabas-forge#1) and moved here on 2026-10-31. `src/` started as the output of the forge `prepare` for build 26102806 (the patched sources of zxevo.pentevo, karabas-go-core-tsconf and karabas-go-modules) with the paths of this repo: no generator any more, the files are edited directly. `docs/sources.md` lists the origin of every path and the changes made to the shared sources; `docs/forge/` is the archive of the forge core directory (plans, problems, tests, the flow `tools/forge.py`); its paths and commands refer to the forge workspace.

Keep the authorship: `README.md` / `README.ru.md` name the author of the port and the upstream authors and licenses (GPL-3.0-or-later; TS-Conf parts MIT, `docs/licenses/`; the ROMs keep their own terms). Keep both READMEs in step with the OSD of `core*.json`.

## Related repositories (siblings in `..`)

- `karabas-go-modules` (submodule `modules/`, master): the shared modules come from it unchanged (`kg_osd_overlay` with `V_OFFSET_IN`, modules #19). Only `src/rtl/hdmi/pll_reset.v` is still a local copy (the held reset fix, Mini boards) until the fix is in modules.
- `karabas-go-core-tsconf`: the origin of `src/rtl/{T80,sound,vg93,mcu,hdmi}` and of the board wrappers.
- `karabas-go-firmware`: no firmware change is needed (EVO RTC mode `rtc_mode` 2, burst caps with `BURST_MAX_MHZ` 1 on Go / Mini G, 0 on Mini).
- `karabas-go-tools`: `make_core.py` (`src/make_core.py` is a symlink to `../../karabas-go-tools/make_core/make_core.py`) packs `core.json` (Go), `core_mini.json`, `core_minig.json` into `baseconf.kg1` / `kg2` / `kg3`.

## Build

- `cd src && make` builds the three boards (`make go`, `make mini`, `make minig`; steps `<board>-xst`, `-impl`, `-core`; `make <board>-report`). The Mini boards also need `make <board>-coremode` (trce without the FT mode constraints of HDMI, `pcf_core.py`).
- `src/Makefile` is that of the other cores (TS-Conf): map / par `-ol high`, cost table `-t 2` on every board. Build 26102806 of forge (commit `50177ec`) used other options, so its bitstreams are not reproduced any more.
- Inputs per board: `karabas_<board>.prj`, `.xst` (defines `HW_ID1` Go, `HW_ID2` Mini, `HW_ID2 HW_ID3` Mini G), `.ucf`, `.ut`. The board code is under `` `ifdef HW_ID1 `` in `baseconf.v` and the video, and in the tops `karabas_<board>_top.v` (after those of TS-Conf). Every Mini / Mini G top must drive `FT_CLK_OUT` (8 MHz).
- Builds take 10..30 minutes: run them in the background, one board at a time, do not edit RTL while XST runs, and do not build all boards without need. The Mini builds use 96-98 % of the slices.
- The `.bin` and `.kg*` files are committed as the release.
