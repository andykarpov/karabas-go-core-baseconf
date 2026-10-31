# Gluk startup investigation — 2026-10-28

The user confirms the 26102802 OSD is good, but reports startup into Gluk instead of ERS. The user subsequently confirmed that holding 0 across resets restored persistent ERS startup. The saved reset target was recoverable; preventing shortcut leakage is the follow-up fix.

## Established facts

The 26102801/26102802 manifests differ only in the storage adapter, top-level OSD wiring, overlay and package metadata. BaseConf ROM, reset/pager/RTC/HID logic and EEPROM-bank selection are unchanged. The last stock BIOS simulation reached ERS using erased EEPROM, so it did not test the board's persisted CMOS values. BaseConf uses physical EEPROM bank 1, while the reference TSConf configuration uses bank 0. Copying the package's OSD block does not read or replace physical EEPROM bank 1.

The stock ROM reads CMOS ED bits 1:0 to select its reset target: 0 = EVO/ERS, 1 = Gluk, 2 = ProfROM, 3 = custom. ERS's G action cycles this setting and updates its CMOS checksum. These facts come from `rom/page0/source/services.a80`, `rom/global_vars.a80` and `rom/mainmenu/src/main.a80` in the local ZX-Evo reference.

A targeted MCU/HID observation reproduces Menu+G as a pressed Spectrum G matrix bit. The provided firmware's `input_route()` waits for the UI to handle a hotkey, then forwards it whenever the OSD remains closed. A GS-reset trigger leaves it closed. The HID parser does not suppress matrix keys while a Meta modifier is held. Thus using Menu+G over ERS can alter its saved reset target. This path also existed before 26102802. It is a plausible cause, not proof of the user's sequence or the currently running MCU firmware behavior. [Observation log](evidence/gluk-hotkey-observation-26102802.txt), [test snapshot](evidence/tb_hid_hotkey_observation.v), [manifest evidence](evidence/gluk-boot-investigation-26102802.json).

## Recovery and next decision

Hold the main keyboard's 0 key while resetting the core, then release 0. Stock ROM bypasses the selected reset target and clears the target bits when entering ERS. It also disables resident-program/autoboot checks for this recovery. If F12 does not trigger with 0 held, use the board's core-reset button: the provided firmware checks only the first HID key slot for global hotkeys, so key order can matter.

Recovery is confirmed. The exact original key sequence is not confirmed. Avoid repeated blind resets of CMOS, changing the EEPROM bank or forcing ERS unconditionally: those would discard or override legitimate settings before the cause is established. On older builds, invoke GS Reset from the open OSD instead of Menu+G over ERS. Build 26102803 filters both the Spectrum matrix and PS/2 keybuffer, including make/break sequences.

If the recovery fails or Gluk returns without an intentional target change, investigate RTC read/write integrity and the board's persisted values. USB serial has no supported EEPROM dump or keyboard-injection command, so current board CMOS has not been read by the host. The recovery and subsequent shortcut fix are now accepted by the user.

## Prevention in candidate 26102803

`src/rtl/baseconf_keyboard_filter.v` sits between the MCU and HID parser. It reserves Win/Menu+Escape, G, J, R, P and F6–F9, matching the package shortcuts. Matrix suppression follows all six HID slots and stays latched until each shortcut key is released, even if Win is released first. Other keys and Ctrl/Shift/Alt retain normal behavior. The original hotkey bytes still reach MCU-side controls.

The PS/2 path tracks left/right Win from complete set-2 events, buffers E0/F0 prefixes with their key, and drops shortcut make/repeat/break events as a unit. Releases for a key forwarded before Win was held are preserved. Pause's eight-byte sequence passes intact. It does not remap the ROM's G command, force a boot target or clear CMOS. The firmware reference remains unchanged.

The new standalone keyboard-filter regression covers all nine reserved keys, all six HID slots, both Win keys, release ordering, repeat suppression, normal presses, extended make/break and Pause. The existing MCU/HID regression now drives the actual filter and asserts no G matrix bit or PS/2 bytes from Menu+G, then verifies plain G works. Implementation and physical shortcut acceptance are tracked in progress.

Candidate 26102803 is now installed and listed. All filter/MCU/HID/board regressions, structural lint, 2500 ms ERS-menu simulation and declared ISE timing constraints pass. [Implementation](evidence/ise-26102803.json), [transfer](evidence/shortcut-sd1-transfer-26102803.json). The user confirmed recovered ERS startup and GS audio on 26102802; the subsequent “all works” reply confirms acceptance of the new shortcut iteration.
