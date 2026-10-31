# Joystick setup and SEGA keyboard mapping

Build **26102804** adds **SEGA** to both **Joystick L** and **Joystick R** in the core OSD. It makes a Sega pad act as twelve Spectrum keyboard keys, so games with a redefine-keys screen can use all of its controls.

## Select the mode

1. Connect the gamepad to the left or right joystick port.
2. Press **Win+Esc** to open the OSD.
3. Set **Joystick L** or **Joystick R**, matching the connected port, to **SEGA**. It follows **QAOPS** in the list.
4. Close the OSD and select keyboard controls in the game.
5. Open the game's redefine-keys screen and press the desired gamepad direction or button for each action. You can also assign the corresponding keyboard letters directly.

The mode is independently selectable for either port. Existing choices and saved selections retain their meanings; updating the core does not automatically enable SEGA.

## Mapping

| Gamepad control | Spectrum key |
|---|---|
| Up | Q |
| Down | A |
| Left | O |
| Right | P |
| A | Z |
| B | X |
| C | C |
| X | S |
| Y | D |
| Z | F |
| START | 0 (zero) |
| MODE | 9 |

Holding a control holds its key, and releasing it releases that key. Multiple buttons can be held together. Normal keyboard presses combine with the mapped pad keys. A six-button pad supplies X/Y/Z/MODE; only controls physically present on the pad can be used.

If both ports select SEGA, both pads use the same keys and their presses combine. For independent two-player controls, select different mappings when the game supports the resulting key sets. A SEGA-mapped pad can also coexist with a pad using Kempston on the other port.

## Firmware shortcuts

The supplied Karabas MCU firmware reserves these pad combinations independently of the core mapping:

- **START+C** or **START+MODE** opens/closes OSD.
- **START+X** reboots the board.

Individual START, MODE, C and X buttons still have the mappings above. Avoid assigning gameplay actions that require those reserved combinations together. These shortcuts belong to the MCU firmware; the SEGA option does not change them. The local reference is `../../../external/karabas-go-firmware/src/input/input.cpp` and `src/ui/osd_ui.h`.

## Implementation and verification

SEGA is option **6** (`110`) in both three-bit joystick selectors. The original six options remain at indexes 0–5. `tools/forge.py prepare` explicitly adapts the pinned HID parser; the external source checkout remains unchanged. Its existing 13-bit MCU joystick reports already contain all twelve controls. The new mapping sets Spectrum matrix keys, following the other keyboard-style joystick modes; it does not synthesize PS/2-buffer events.

`python3 tools/forge.py test --suite hid` drives real MCU SPI joystick and OSD switch frames. It checks every mapped key and release on both ports, all rows and combined row scans, simultaneous controls, live mode changes, both ports together, ordinary USB typing and mixed SEGA/Kempston modes. Physical gamepad/game acceptance is tracked in [progress](forge/docs/progress.md).
