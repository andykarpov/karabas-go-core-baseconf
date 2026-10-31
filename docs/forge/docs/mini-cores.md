# BaseConf cores for GO, Mini and Mini G

Current release: **26102806** applies to GO, Mini and Mini G, removes GS Reset/Menu+G, couples GS to core reset and recognizes F12 in every HID slot. See [reset controls](reset-controls.md) for EVO boot choices and verification. New [kg1/kg2/kg3 packages and evidence](reset-controls.md#completed-candidate-26102806) pass all offline checks. Earlier release/installation records below are retained as history.

The project now has separate board targets. Mini packages are experimental, built without physical Mini hardware. Their bitstreams are generated from BaseConf, not renamed GO or TSConf binaries.

| Target | Build directory | Package | Board interface |
|---|---|---|---|
| `go` (default) | `build/baseconf/` | `baseconf.kg1` | Existing GO B4 VGA, I2S DAC, physical floppy and DB9 firmware input |
| `mini` | `build/baseconf-mini/` | `baseconf.kg2` | Older Mini reference pin map, HDMI, sigma-delta analog audio, USB input |
| `minig` | `build/baseconf-minig/` | `baseconf.kg3` | Mini rev. G pin map, HDMI, dedicated I2S DAC, USB input |

The existing GO release remains **26102804**. Mini and Mini G use **26102805**. Both Mini targets pass the final simulations, stock-BIOS ERS/4096 KB check and both ISE timing modes. The [release directory](../build/releases/multi-board-26102805) contains all three packages, checksums, input snapshots and reports; [machine-readable summary](evidence/multi-board-26102805.json).

## Features and differences

All targets retain BaseConf's 4 MB main-RAM mapping, extended video, Nemo IDE logic, USB keyboard/mouse, two logical joystick mappings including [SEGA](joysticks.md), TurboSound/FM, 2 MB GS and Win+Esc OSD. The Mini wrappers connect SRAM, SDRAM, SD2 and CF/expansion signals according to their respective reference UCFs. Actual memory parts, connectors and timing margins need checking on the precise board revision.

Mini and Mini G do not have the supplied GO physical floppy interface or physical DB9 polling. Their builds remove Firefly's physical controller and leave absent-FDC reads to the machine's default bus response. USB pads can supply the two logical joysticks. This does not add image-based floppy emulation or the original ZX-Evo AVR mount service. Optional ADC and ESP32 audio input are not enabled.

Mini analog output uses signed-to-offset-binary conversion into the reference sigma-delta DAC; its HDMI audio is nominally 44.1 kHz. Mini G uses the reference dedicated I2S DAC wiring and nominally 48 kHz HDMI audio. These output sample clocks do not alter the fixed GS CPU/interrupt clocks or depend on VSync.

## HDMI adaptations

- Blanking travels in the spare scan-doubler RAM bit alongside RGB, then through the same final output register. Read-valid follows the synchronous RAM latency, preventing a stale active-video flag at line start.
- Actual video tests check 720 active pixels per line, 576 active lines at 50 Hz and 480 at 60 Hz, and all 416 OSD pixel rows in ZX, 320-pixel, 640-pixel and text modes. These are BaseConf rasters, not a promise that every HDMI display supports them.
- The MCU's FT-video control selects FT812 input for HDMI; returning to the core preserves the OSD path.
- Clock programming starts one complete DCM transaction per measured FT frequency. Reset stays asserted through programming/source changes and is stretched after release. It is not repeatedly restarted while shifting configuration bits.
- Timing is checked for both FT and core pixel clocks. The core pass retains the asynchronous FT-to-pixel FIFO bound while removing the FT-generated clock periods and the asynchronous core-to-pixel bound. This exposes the real related-clock setup/hold requirements of core video.

The supplied reference's FT frequency controller can select 72/80 MHz, but its 5× serializer clock then exceeds the declared Spartan-6 -2 DCM limit. The build's FT implementation analysis covers up to 64 MHz; higher FT modes are not certified. Core video uses approximately 28.03 MHz.

## Rebuild and verify

Run from the core root (`forge/cores/zx-evo-base/`); place the board flag before the command:

```sh
python3 tools/forge.py --board minig prepare
python3 tools/forge.py --board minig elaborate
python3 tools/forge.py --board minig test --suite all
python3 tools/forge.py --board minig lint
python3 tools/forge.py --board minig video-test
python3 tools/forge.py --board minig hdmi-test
python3 tools/forge.py --board minig bios --simulator verilator --milliseconds 2500 --trace --require-menu
python3 tools/forge.py --board minig ise --docker
python3 tools/forge.py --board minig package
```

Use `--board mini` for kg2. Default commands continue to target GO. Do not regenerate a target while its BIOS/ISE run is active. Original references under `external/` are unchanged; explicit adaptations live in `tools/forge.py`. No new downloaded tools are needed. See [tools](tools.md) and the [build skill](../skills/forge-build/SKILL.md).

Machine simulations use an explicit HDMI boundary sink. The separate HDMI test uses the actual transmitter, GHDL-translated VHDL and ISE's vendor clock models in Icarus. It checks pixels and coherent stereo samples at the transmitter input during core/FT40/FT64/core transitions; it is not a physical TMDS capture. Its FT source matches the vendor DCM model's integer-picosecond rounding to avoid artificial FIFO drift. The image lacks GCC for ISim, so no ISim pass is claimed.

## Hardware acceptance still needed

The Mini UCF is labeled rev. C and contains later clock-routing modifications; no separate Mini schematic repository is supplied locally. Check the exact older-board revision before loading kg2. Mini G has its own incompatible rev. G pin map.

On each actual board verify FPGA loading, ERS startup, HDMI lock at both rasters, FT/core transitions, OSD, USB inputs, audio/GS playback, main RAM, and CF/SD access. Packages do not update MCU firmware or boot cores. No Mini hardware test or board transfer was performed during development.

## Completed build 26102805

| Board | Package | Occupied slices | LUTs | Normal / core timing errors |
|---|---|---:|---:|---:|
| GO B4, retained 26102804 | [kg1](../build/releases/multi-board-26102805/baseconf.kg1) | 3,355 / 3,758 | 10,305 | 0 / not applicable |
| Mini | [kg2](../build/releases/multi-board-26102805/baseconf.kg2) | 3,684 / 3,758 (98%) | 11,844 | 0 / 0 |
| Mini G | [kg3](../build/releases/multi-board-26102805/baseconf.kg3) | 3,660 / 3,758 (97%) | 11,768 | 0 / 0 |

Both Mini builds use 37 RAMB16 and 6 RAMB8 blocks. Resource headroom is limited. [Checksums](../build/releases/multi-board-26102805/SHA256SUMS), [Mini evidence](evidence/mini-26102805.json), [Mini G evidence](evidence/minig-26102805.json), [reference pin comparison](evidence/mini-pin-reference-26102805.json), [GO preservation check](evidence/go-preserved-26102805.json).

Final checks passed: adapter/GS/keyboard/HID/SEGA/board-control/OSD regressions; structural checks of the machine path; real raster/blanking/OSD tests; actual HDMI transport and audio tests; 2500 ms stock-BIOS simulation; FPGA synthesis/map/route/BitGen and both timing passes; independent package header, ROM/FPGA and menu verification. BIOS, video, HDMI, package and ISE evidence agree on each target's final input manifest. The GO full regression suite was also rerun and its regenerated implementation inputs are identical to 26102804.

Mini SHA-256: `2ca11544605ba65b8814d494eb2235dc0f076a75e580f78a9536996fb326a6c1`.

Mini G SHA-256: `1d1876251de93d4adf02a69d290e3cd37b3d77cac58485e0b4847c40a09edc99`.

No device, MCU firmware, SD card or CF contents were changed for this release. Physical Mini/Mini G acceptance remains outstanding.
