# B4 hardware test procedure

Use the [hotkey reference](hotkeys.md) for current OSD controls and EVO reset combinations on GO, Mini and Mini G. In 26102806, core reset also resets GS; the historical GS Reset/Menu+G acceptance procedure below applies only to older builds.

Target setup reported by the user on 2026-10-28: **Karabas GO B4, two SD cards and CF**. A physical floppy drive or Gotek has not been confirmed. The board was subsequently connected as USB 2e8a:000a. Serial core listing and SD1 export work. Candidate `baseconf.kg1` build 26102800 was added to SD1 and readback-verified; existing root core/config hashes were unchanged and the card cleanly ejected. The live firmware lists the candidate. A subsequent user-requested transfer added `dune.trd` and `DUNE.DAT` to SD2 root with verified hashes and clean eject. CF was not written. The supplied ers.jpg and dune.jpg establish physical ERS startup with 4096 KB and Dune rendering. The user reports that 60 Hz fixes vertical cropping. Candidate 26102802's OSD and GS audio are now confirmed good. ERS startup was restored with 0+reset after a saved-target change; candidate 26102803 isolates reserved keyboard shortcuts to prevent a repeat. See current [progress](progress.md) for build/transfer status.

## Access needed for direct assistance

Connect the board's USB **device** connection to the development host with a data cable. The USB host connection used for keyboard/mouse is a different interface. Identify the board's serial device before sending commands. The pinned firmware documents `AT+KARABAS=list` (core list), `AT+KARABAS=msc` (SD1 exposed as USB storage), and `AT+KARABAS=msc2` (SD2 exposed). Installed firmware may differ; confirm its identity/features first. The board stops normal operation in mass-storage mode. Ejecting returns it to normal operation.

The current firmware's documented serial commands do not provide a core-load command, framebuffer capture or keyboard injection. A USB connection alone therefore does not establish an autonomous end-to-end test path. Initial core selection and keyboard/mouse/joystick interaction require a person or additional verified control equipment. VGA capture or a person reporting the display is needed to assess actual startup; USB logs alone cannot prove it.

See the [reference firmware USB/SD instructions](../../../../external/karabas-go-firmware/README.md). Do not use `AT+KARABAS=boot` for normal core loading: it enters firmware BOOTSEL update mode.

## Package and first boot

1. Use the newly built `build/baseconf/baseconf.kg1` only after its ISE/provenance checks pass. Check the build identity against the current progress/evidence record. It remains an experimental hardware-test candidate.
2. Copy it as a new core file to **SD1**, the MCU/core-browser card, using the established board transfer workflow. Keep the existing boot core and other cores. Do not format either SD card or CF. Under this project's workspace rule, any agent-controlled host transfer workspace/mount must be inside the project and the target media must first be identified.
3. Eject the card/USB storage correctly, return to the core browser and select **ZX Evolution BaseConf**. The package embeds BaseConf and GS ROMs; separate ROM files on SD are unnecessary.
4. Record cold-start and reset behavior, the displayed memory size (expected 4096 KB), and any failure text. The simulation reference is [this menu](evidence/stock-bios-menu.png). `Baseconf: NONE` / `AVR Boot: NONE` are known missing AVR version-service fields and are not by themselves a boot failure.
5. Test Win+Esc OSD, navigation, 50/60 Hz selection, reset and NMI. Test keyboard keys and held/released modifiers, mouse motion/buttons, and each joystick with different OSD mappings before testing both together.

## Storage and Dune

- SD1 contains the Karabas core packages. SD2 is connected to the FPGA's BaseConf SPI path; neither the MCU file browser nor the original AVR virtual floppy-mount service is automatically a BaseConf virtual disk implementation.
- Start CF acceptance with identification and reads from existing known files. Record card model, configured Nemo/divIDE mode and behavior at 3.5/7/14 MHz. Do not infer real CF timing from the simulated ATA register responder. Reserve write tests for an explicitly chosen disposable test file/area.
- Real Firefly floppy acceptance needs a physical drive/Gotek and known test media. Without one, report this feature as untested.
- Dune assets in `build/media/` are checksum-checked staging copies; matching files are now also present at SD2 root (see [transfer evidence](evidence/dune-sd2-transfer.json)). Establish the actual available SD2/CF boot path before giving a game-launch recipe. The original “mount A:” workflow depends on an absent AVR service and is not a proven option here.
- Once loaded, check Dune at 14 MHz: title/menu, mission controls and sustained TurboSound/FM/GS music. GS has 2 MB addressing; candidate 26102802 adds fast GS ROM/workspace BRAM after 26102801 accelerated SDRAM service while retaining the fixed GS CPU/interrupt clocks. Compare the same music against TSConf, including tempo/pitch/stereo, and repeat at both raster settings where the monitor allows.

## Result record

For each test retain: package SHA-256/build, MCU firmware version, board revision, connected media/devices, steps, expected/observed behavior, and logs/capture when available. Store evidence under `docs/evidence/` and larger captures under `build/`. Mark unperformed tests as pending rather than passed.

The first 60-second USB listen after the transfer captured no bytes. This neither proves a boot failure nor proves startup; later user photos and feedback, recorded above, establish physical display and an audio-speed problem.

## Shortcut acceptance for 26102803

At ERS, invoke Win/Menu+G and verify its displayed reset target does not change. Release Win before G, then repeat releasing G first. Reset normally and confirm ERS remains the startup target. Check plain typing and Win+Esc, and ensure the GS Reset action still works. The FPGA regression covers both matrix and PS/2 paths; physical keyboard/MCU event timing is the remaining check. Boot recovery with 0+reset is documented in [boot investigation](boot-regression.md).

26102803 follow-up: user reports “all works” after the requested shortcut/ERS check. Current iteration accepted; retain the above procedure for later regressions. No detailed per-key results or new capture were supplied.

## SEGA gamepad acceptance for 26102804

Select SEGA for the connected port in OSD, then use a game's redefine-keys screen to check Up/Down/Left/Right = Q/A/O/P, A/B/C = Z/X/C, X/Y/Z = S/D/F, START = 0 and MODE = 9. Repeat on the other port. Check held movement plus a button and that released buttons no longer act. Existing firmware START+C/START+MODE and START+X combinations remain reserved. See the [complete setup guide](joysticks.md). This physical check remains pending until user feedback; digital tests cover both port mappings.
