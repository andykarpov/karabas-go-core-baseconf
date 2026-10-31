# Reset controls — build 26102806

For everyday use, see the [hotkey reference](hotkeys.md), including OSD shortcuts, PC keyboard equivalents and step-by-step reset examples.

GO (`kg1`), Mini (`kg2`) and Mini G (`kg3`) share these controls. The OSD has nine entries: NMI is register 7 and Reset is register 8. GS Reset and its Menu+G hotkey are removed. Reset from F12, OSD or the physical core-reset button resets both the main CPU and GS. NMI does not reset GS. G, including Menu+G, now reaches the core as an ordinary G key.

## EVO boot selection

Hold the selection key(s), press and release **F12** (or the physical core-reset button), and keep the selection held until the destination appears. Release the selection afterward. On a PC keyboard, **Shift = CS**, **Ctrl = SS**; either left or right modifier works.

| Held key(s) | Stock EVO destination |
|---|---|
| CS | ROM BASIC 128 |
| SS | ROM BASIC 48 |
| D | Built-in demo |
| C | Color test |
| H | Help |
| S | CMOS setup |
| 0 | Clear resident/autoboot selection and recover the EVO service boot path; release 0 to continue |
| Two or more Spectrum matrix keys | Keyboard test (for example A+B, A+B+C or CS+SS) |

These are the stock ROM's selections, not replacement ROM code. Its early 0 recovery path waits for 0 to be released before scanning later choices. Left and right Shift both map to one CS matrix key; they do not count as two distinct Spectrum keys. F12 does not count as a matrix key. Persisted alternate-ROM settings can change the active service ROM; 0 is the existing recovery route.

The firmware reference checks OSD hotkeys only in `kbd.keycode[0]`. Holding D before F12 can put F12 in another slot and prevent the firmware from issuing reset. The FPGA now detects raw F12 in all six report slots, while preserving the other held keys for BIOS reads. The normal firmware Reset trigger remains supported. No MCU firmware update is needed for this core change with the inspected forwarding protocol.

The keyboard parser and reserved-shortcut filter reset at power-up, not on core reset. GS now follows the same stretched reset as the main CPU, including initialization and ROM loading. Its separate internal reset input remains available only to diagnostics that isolate AY.

## Reproduce verification

From the core directory, substitute `go`, `mini` or `minig`:

```sh
python3 tools/forge.py --board go --build-dir build/reset-26102806/go prepare
python3 tools/forge.py --board go --build-dir build/reset-26102806/go elaborate
python3 tools/forge.py --board go --build-dir build/reset-26102806/go test --suite all
python3 tools/forge.py --board go --build-dir build/reset-26102806/go bios-reset-test
```

`board` checks actual MCU SPI reset commands and every F12 slot, including retained selection keys. `hid` checks the matrix mapping and `keyboard_filter` checks removal of G from reserved shortcuts on HID and PS/2 paths. `bios-reset-test` executes the unchanged stock ROM after a real F12 reset and asserts the selected BASIC ROM, demo entry, unpacked diagnostic entry, or 0 recovery path. It includes two-key, three-key and modifier-only keyboard-test choices. The stock ROM hash guards the dispatch addresses used by this test.

The BIOS test verifies dispatch into each destination; it does not claim complete BASIC/demo/diagnostic UI acceptance or physical keyboard testing. The AY noise report on Mini/Mini G remains a separate unresolved issue.

## Completed candidate 26102806

Packages: [GO kg1](../build/releases/reset-26102806/baseconf.kg1), [Mini kg2](../build/releases/reset-26102806/baseconf.kg2), [Mini G kg3](../build/releases/reset-26102806/baseconf.kg3). [Checksums](../build/releases/reset-26102806/SHA256SUMS), [validation evidence](evidence/reset-26102806.json), [source and implementation snapshots](../build/releases/reset-26102806/).

All three targets pass the full HDL suites (including GS/AY), structural lint, ten stock-ROM reset selections each, 2500 ms normal BIOS startup with the pinned ERS/4096 KB screen signature, ISE implementation and declared timing, and independent package validation of FPGA/ROM payloads and all nine menu entries/hotkeys. Mini and Mini G also pass real video/HDMI tests and both FT/core timing reports. A fresh prepare reproduces each implemented manifest exactly. The BIOS reset tests initialize the normal font/microcode images and execute the unmodified ROM; they do not substitute a diagnostic ROM for its boot choices.

| Board | Occupied slices / 3758 | LUTs | Timing errors |
|---|---:|---:|---:|
| GO | 3382 | 10177 | 0 |
| Mini | 3683 | 11831 | 0 in both modes |
| Mini G | 3637 | 11695 | 0 in both modes |

Build outputs are isolated in `build/reset-26102806/<board>/`. Earlier releases and the installed GO 26102804 package are preserved. No board/media/MCU transfer was performed. These results establish digital reset/ROM dispatch and declared FPGA timing. Subsequent user feedback confirms the hotkeys work on all three boards; the hotkey/reset-selection task is complete. See the [acceptance record](evidence/hotkey-acceptance-26102806.json). The Mini/Mini G AY noise report is not claimed fixed.
