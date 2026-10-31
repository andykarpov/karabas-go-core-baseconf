# The port in karabas-forge (archive)

Sergei Lemeshev ([lordamot](https://github.com/lordamot)) made this port in October 2026 in
[karabas-forge](https://github.com/lordamot/karabas-forge) (`forge/cores/zx-evo-base`, last commit
`c69c884`, 2026-10-31). The repository was to be closed when the core moved here
([karabas-forge#1](https://github.com/lordamot/karabas-forge/issues/1)). This directory keeps that
core directory as it was, for the record. Its paths point to the forge workspace, so its links and
commands do not work here.

| Here | What it is |
|---|---|
| `core-README.md` | the README of the core in forge |
| `docs/` | plans, progress, problems, architecture, the audio / GS / reset / HDMI investigations, the hardware test procedure |
| `docs/evidence/` | the test and build records (the ISE timing reports over 100 KB are left out) |
| `tools/forge.py` | the flow of forge: `prepare` (took the sources of zxevo.pentevo, karabas-go-core-tsconf and karabas-go-modules and changed them, see [../sources.md](../sources.md)), the simulations, ISE, packaging |
| `tests/` | the testbenches (BIOS start, SRAM / SDRAM models, AY, GS, HID, OSD, storage, ...) run by `forge.py test` |
| `config/` | `core.json`, the pinned revisions (`sources.lock.json`) |
| `prompts/` | the tasks of the work, in order |
| `skills/` | the work instructions of forge |
| `res-manifest.json`, `res-README.md` | the origin and SHA-256 of the ROMs, the font, the microcode and the test media |

The test media of forge (Dune `.trd` / `.dat`, the GS music module) are not kept here.

The sources in `../../src` are the output of `forge.py prepare` for the three boards at build
26102806 (the input manifests `3ae3933a` Go, `4f5c0712` Mini, `0027551c` Mini G, the same as in
`docs/evidence/reset-26102806.json`), with the paths of this repository.
