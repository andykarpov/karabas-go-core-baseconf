# Keyboard shortcuts

Applies to ZX Evolution BaseConf **26102806** on Karabas GO (`kg1`), Mini (`kg2`) and Mini G (`kg3`).

## PC keyboard names

| Name in these docs / OSD | PC keyboard key |
|---|---|
| Menu / Win | Windows (Meta) key; either left or right, not the context-menu key |
| CS — Caps Shift | Shift, left or right |
| SS — Symbol Shift | Ctrl, left or right |
| Reset | F12, or a board button configured for core reset |

## OSD and core controls

Use these while the core is running. For a Win combination, hold Win, press the other key, then release both.

| Shortcut | Action |
|---|---|
| Win+Esc | Open or close the OSD |
| Win+F6 | Toggle Covox Off / On (covox #FB and the Soundrive ports) |
| Win+F7 | Cycle PSG Mix: ABC / ACB / Mono |
| Win+F8 | Switch PSG Type: AY3-8912 / YM2149F |
| Win+F9 | Switch video raster: 50 Hz / 60 Hz |
| Win+J | Cycle the left joystick mapping |
| Win+R | Cycle the right joystick mapping |
| Win+P | Toggle CPU pause |
| F11 | Request NMI; behavior depends on the running software |
| F12 | Reset the core and GS together |

OSD only (no shortcut): **SAA1099**, **OPL2** and **ZiFi RS232** (TS ZiFi on the ESP8266, the RS232 ports of TS-Conf and of the Evo on the USB serial port), On by default. Off mutes the device and frees its ports.

Joystick choices are Kempston, Sinclair1, Sinclair2, Cursor, QAOPM, QAOPS and SEGA. See [joystick setup and mappings](joysticks.md).

**GS Reset and Win/Menu+G were removed in 26102806.** Use F12 or OSD Reset to reset GS together with the core. Win+G now reaches the core as an ordinary G key. F11 does not reset GS.

## EVO reset combinations

Close the OSD first. Hold the selection key(s), press and release **F12**, then keep the selection held until the chosen destination appears. Release the selection afterward. You can use the physical core-reset button in place of F12.

| EVO combination | PC keyboard combination | Destination |
|---|---|---|
| CS+Reset | Shift+F12 | ROM BASIC 128 |
| SS+Reset | Ctrl+F12 | ROM BASIC 48 |
| D+Reset | D+F12 | Built-in demo |
| C+Reset | C+F12 | Color test |
| H+Reset | H+F12 | Help |
| S+Reset | S+F12 | CMOS setup |
| 0+Reset | 0 (zero)+F12 | Clear resident/autoboot selection and recover the EVO service boot path; release 0 to continue |
| Two or more Spectrum keys+Reset | For example A+B+F12, A+B+C+F12 or Shift+Ctrl+F12 | Keyboard test |

For example, hold **Shift**, tap **F12**, wait for BASIC 128, then release Shift. For the keyboard test, hold **A+B**, tap **F12**, wait for the test, then release A+B.

**0 is the exception to waiting for a destination before releasing the key:** the BIOS waits for 0 to be released before continuing. Its recovery check takes precedence over the later multi-key selection. If a saved alternate-ROM setting bypasses the EVO service, use 0+Reset to recover it first.

The keyboard test counts distinct Spectrum matrix keys. F12 does not count, and left Shift plus right Shift counts as one CS key. Shift+Ctrl supplies two keys, CS+SS. Keys must still be held when the BIOS scans them after reset.

These choices use the stock EVO ROM. Ten reset-selection cases per board pass in simulation. The user confirms the hotkeys work on **GO, Mini and Mini G**; this task is complete. [Acceptance record](forge/docs/evidence/hotkey-acceptance-26102806.json). See [reset implementation, verification and packages](forge/docs/reset-controls.md).
