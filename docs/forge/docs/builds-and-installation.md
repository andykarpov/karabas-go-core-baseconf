# ZX Evolution BaseConf: builds and installation

The **26102806** bundle contains the GO, Mini and Mini G FPGA cores, matching RP2040 firmware,
embedded BaseConf/GS ROMs, supplied Dune media, checksums and validation reports.
The FPGA images are unchanged from the reset/hotkey release: freshly generated inputs match
all three implemented source manifests exactly. This is a verified distribution bundle, not
an AY-audio correction.

## Choose the matching pair

Paths below are relative to the extracted archive, or this core's `bin/` directory.

| Board | FPGA core for SD1 | RP2040 firmware for RPI-RP2 | Outputs |
|---|---|---|---|
| Karabas GO B4 | `kg1/baseconf.kg1` | `kg1/karabas-go-firmware.uf2` | VGA and I2S DAC |
| Karabas Mini, older pin map | `kg2/baseconf.kg2` | `kg2/karabas-mini-firmware.uf2` | HDMI and analog stereo |
| Karabas Mini G, rev G | `kg3/baseconf.kg3` | `kg3/karabas-minig-firmware.uf2` | HDMI and I2S DAC |

The older Mini reference uses a rev-C pin map with later clock-routing changes; Mini G has a
different pin map. Select files for the actual board. All three use XC6SLX25-2-FTG256.

The UF2 files are **byte-for-byte identical to the corresponding UKNC MC-0511 bundle's
controller firmware**, renamed here for general use. They retain the UKNC menu/HDD fixes and
standard BaseConf protocol. If you already installed that UF2 on this board, skip flashing:
you can keep both cores on SD1 and select either from the same chooser. This is RP2040
firmware, not a Raspberry Pi Linux image. BaseConf's FPGA changes do not themselves require
a new MCU firmware; the UF2 is included to provide the requested complete set.

## Install

1. Extract `baseconf-26102806-all.zip`. Retain your previous core package and firmware.
2. Copy the matching `baseconf.kg1`, `.kg2`, or `.kg3` to the **root of SD1**. Keep the board's
   existing `boot.kg1`, `boot.kg2`, or `boot.kg3` browser. Keep UKNC and other cores alongside it.
   Replace the previous BaseConf package rather than leaving duplicate BaseConf entries.
   The two ROM payloads are embedded; no separate ROM copy is needed.
3. Eject/unmount SD1 cleanly and return it to the board.
4. If updating the controller, enter RP2040 **BOOTSEL**: hold **Boot**, press/release **Reset**,
   then release **Boot**. Alternatively, send `AT+KARABAS=boot` through USB serial.
5. Copy the matching `.uf2` to the USB drive **RPI-RP2**. The board restarts automatically.
   The `.kg*` file goes on SD1, and the `.uf2` goes on RPI-RP2.
6. Select **ZX Evolution BaseConf** from the core chooser.

If the display is vertically cropped, use **Win+F9** or OSD **VGA Hsync → 60 Hz**; that
setting resolved the previously reported cropping on the tested monitor.

The archive's `SHA256SUMS` covers every supplied file. On a system with `sha256sum`, run
`sha256sum -c SHA256SUMS` from the extracted directory. Per-board manifests record the core,
controller and implementation hashes. These commands and the release script do not flash
hardware or write a card.

## Controls and startup

- **Win+Esc:** open/close OSD. “Menu” in the OSD means the Windows/Meta key, not the context-menu key.
- **F12:** reset the main CPU and GS together. **F11:** NMI.
- **Shift+F12:** BASIC 128. **Ctrl+F12:** BASIC 48.
- Hold **D**, tap **F12**, and keep D held until entry: built-in demo. C, H and S select the
  color test, help and CMOS setup respectively.
- Hold **A+B**, tap F12, and keep A+B held until entry: keyboard test.
- For saved autoboot/resident-state recovery: hold **0**, tap F12, then **release 0** to continue.

Close the OSD before EVO reset selections. For ordinary selections, keep the held keys down
until the destination appears, then release them. Zero recovery is the exception described
above. GS Reset/Win+G is removed; F12 resets GS with the core.

Both joystick menus include SEGA keyboard mapping. Physical GO pads and USB logical mappings
are described in [joystick setup](joysticks.md). Mini boards use USB input and do not have
GO's physical DB9 scanning or physical floppy interface. See [all hotkeys](hotkeys.md) and
[reset controls](reset-controls.md).

## Supplied media

The archive's `SD2/` folder contains unchanged `dune.trd` and `DUNE.DAT`. To use the existing
Dune setup, copy these two files to **SD2's root**, preserving any existing modified media,
and eject the card cleanly. `test-media/external.mod` is the supplied GS audio regression
sample; it is not needed for normal boot.

This port does **not** supply the original AVR virtual-drive/mount service or UKNC's HDD0
image menu. Copying a TRD onto a card does not mount it as a floppy. Dune display and GS
listening were observed previously, but the exact user launch sequence was not recorded;
use your established loader/setup. No unverified launch sequence is implied by this bundle.
GO has physical FDC support; Mini variants do not. Physical CF/FDC acceptance remains partial.

## Validation and remaining issues

All three FPGA builds pass synthesis, placement/routing, declared timing and independent
package decoding of FPGA/ROM payloads, addresses, OSD settings and hotkeys. Mini and Mini G
pass **both FT and core-mode timing**. Existing tests cover full regressions, stock BIOS
ERS/4096 KB startup and ten EVO reset choices per board. Current source regeneration matches
the routed manifests; unchanged FPGA binaries preserve this evidence.

The user confirmed hotkeys/reset selection work on all three boards. That feedback does not
cover all peripherals or establish acceptance of the newly assembled FPGA/controller pair.
Earlier GO GS/OSD listening checks are retained in the project records.

**AY noise on Mini/Mini G remains unresolved**, including reported HDMI and analog noise
while GS sounds correct. This bundle makes no AY/audio RTL changes. Other limits include
monitor compatibility, physical storage timing, sustained gameplay and FT modes above 64 MHz.
See [remaining issues](problems.md), [AY investigation](ay-audio.md), [Mini interfaces](mini-cores.md)
and [validation](validation.md). Vendor simulation models are excluded from the archive.

## Reproduce the bundle

Run from `forge/cores/zx-evo-base/` in this workspace. To verify and repackage the existing,
unchanged completed implementations and UKNC-compatible controller binaries:

```sh
python3 tools/release.py
```

This regenerates each board's inputs separately under `build/release-audit/`, checks them
against `build/reset-26102806/<board>/`, verifies both timing modes where applicable, reruns
package decoding, and checks controller source/binary provenance and RP2040 UF2 blocks.
It copies files to `bin/kg1`, `bin/kg2`, `bin/kg3`, then creates and reads back the ZIP.
The controller source bundle defaults to sibling `../mc0511`; override with
`--firmware-root /path/to/mc0511` when necessary.

For a fresh FPGA implementation, use the pinned references and shared local HDL/ISE tools:

```sh
for board in go mini minig; do
    out="build/distribution-26102806/$board"
    python3 tools/forge.py --board "$board" --build-dir "$out" prepare || exit
    python3 tools/forge.py --board "$board" --build-dir "$out" elaborate || exit
    python3 tools/forge.py --board "$board" --build-dir "$out" test --suite all || exit
    python3 tools/forge.py --board "$board" --build-dir "$out" lint || exit
    python3 tools/forge.py --board "$board" --build-dir "$out" bios-reset-test || exit
    python3 tools/forge.py --board "$board" --build-dir "$out" bios --simulator verilator --milliseconds 2500 --trace --require-menu || exit
    if [ "$board" != go ]; then
        python3 tools/forge.py --board "$board" --build-dir "$out" video-test || exit
        python3 tools/forge.py --board "$board" --build-dir "$out" hdmi-test || exit
        python3 tools/forge.py --board "$board" --build-dir "$out" hdmi-audio-test || exit
    fi
    python3 tools/forge.py --board "$board" --build-dir "$out" ise --docker || exit
    python3 tools/forge.py --board "$board" --build-dir "$out" package || exit
done
python3 tools/release.py --build-root build/distribution-26102806
```

To rebuild the shared RP2040 firmware, use its maintained UKNC overlay rather than copying
patches into this core. With PlatformIO installed in `../mc0511/build/venv`, run sequentially:

```sh
for board in go mini minig; do
    python3 ../mc0511/tools/firmware.py build --board "$board" || exit
    python3 ../mc0511/tools/bundle.py --board "$board" || exit
done
python3 tools/release.py
```

The UKNC bundle step also requires its matching completed FPGA build, as described in that
core's build guide. A rebuild can change binary hashes; hardware feedback remains scoped to
the versions actually tested. See [toolchain](toolchain.md) and [source attribution](attribution.md).
