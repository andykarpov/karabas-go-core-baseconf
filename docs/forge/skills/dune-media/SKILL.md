---
name: dune-media
description: Validate and stage this project's supplied Dune TR-DOS and SpectrumProg test media using tools/media.py, without modifying game files or claiming gameplay validation.
---

Run `python3 tools/media.py --source res/media/dune` to inspect file sizes, SHA-256, TR-DOS catalogue extents, overlap/count consistency and the SpectrumProg signature. Add `--stage` to copy unchanged inputs and a manifest into `build/media/`.

The checker requires the supplied 640 KB double-sided 80-track TRD layout and files named `dune.trd` and `DUNE.DAT`. It does not emulate the game, create a filesystem image, or validate every internal SpectrumProg block. Do not infer a successful FPGA test from this report.

Read `docs/validation.md` for the 14 MHz, storage and GS acceptance steps. The original AVR “mount A:” service is not implemented by this port. Use a real floppy/Gotek workflow or implement a mount service before treating the game README's original boot sequence as available.

For the user's physical Karabas, place `dune.trd` and `DUNE.DAT` at **SD2 root**: SD2 is wired to the FPGA BaseConf SPI port; SD1 is the MCU core-package card. Use `../../../tools/board_serial.py --project . --command msc2` and the board-access workflow after identifying the exported device as Karabas `SD Card 2`. Preserve existing files and compare the copied bytes/checksums. A successful copy makes the files present on that card; it does not implement AVR virtual-drive mounting or demonstrate gameplay.
