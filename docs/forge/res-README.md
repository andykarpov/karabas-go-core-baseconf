# Core resources

These files are authoritative inputs to source preparation and tests. `manifest.json` records SHA-256, original paths, pinned revisions where known, and provenance. `forge.py prepare` verifies every listed file.

- `roms/baseconf.rom`: unchanged ZX Evo BIOS, staged as `roms/baseconf.rom` in generated builds.
- `roms/gs105b.rom`: unchanged General Sound 1.05b BIOS.
- `fonts/atm.fnt`: raw ATM font; preparation generates `atm_font.hex`.
- `microcode/vg93-microcode-rom.hex`: physical FDC microcode.
- `media/dune/`: supplied Dune TRD/DAT test media.
- `media/external.mod`: pinned Dune intro music used by the GS audio regression.

Original assets remain in their upstream source checkouts where applicable. Generated images belong in `build/`. These assets retain their original terms and are not relicensed by the core; see [attribution](../docs/attribution.md).
