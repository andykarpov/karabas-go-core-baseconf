# GS distortion and OSD follow-up — 2026-10-28

The user reports that 26102801 improves GS speed substantially, but some sounds remain distorted and slow. Disabling Covox does not fix it. Dune subsequently reported “GS Check 1Mb error” until a full power cycle. The new `osd.jpg` shows the menu's lower rows clipped while 60 Hz is selected. The user will provide a physical MP4 after this iteration and requests simulated recording of the intro text-screen music.

All media and project state used for this work stay in this repository. Other project folders are independent and are not modified. The board's USB interface has no audio capture command; the following recordings are simulated GS output.

## Stronger playback test

The earlier four-channel ISR test verified interrupt service, but did not run the GS ROM's software mixer. Its passing result was insufficient to establish sustained Dune playback. `tools/gs_audio.py` now runs the actual GS/T80 RTL with the unmodified 1.05b ROM, its full memory check and host protocol, and the core's `res/media/external.mod` intro tune. The same GS runs against zero-wait memory as a reference.

The test requires 62 usable 32 KiB pages (the GS's 2 MB map, excluding reserved pages), repeats the count after the F3 warm reset used by Dune, and checks the uploaded module byte-for-byte before parsing. It records stereo PCM/WAV and counts the ROM's buffer-underrun path at 13B9. The test's first host driver was too quick after a status flag cleared; those exploratory runs were stopped and are not playback evidence. The corrected driver includes a host instruction delay and upload verification.

The old controller, new on-chip-memory candidate and zero-wait reference all passed the stock memory check, retained 62 pages after warm reset, and verified the intro upload. The original physical “1Mb error” was not reproduced and remains unresolved.

The old 26102801 controller first records underruns near 6.23 seconds into playback: 8 then, 105 at 7.23 seconds, 202 at 8.23 seconds and 299 at 9.23 seconds. Candidate 26102802 records zero through 13.29 seconds. The zero-wait reference completes 30 seconds with zero underruns. This reproduces a digital cause of the reported distortion/slowdown without changing the GS clock or interrupt divider.

Matching 10-second stereo, 44.1 kHz, 16-bit simulated recordings:

- [Old 26102801](../build/gs-audio/26102801-intro-10s/audio.wav)
- [New 26102802](../build/gs-audio/26102802-intro-10s/audio.wav)
- [Zero-wait reference](../build/gs-audio/reference-intro-10s/audio.wav)

The old/new controller runs were planned for 30 seconds but deliberately stopped after these complete excerpts and sufficient telemetry were captured. They are not completed 30-second tests. Their logs and provenance retain that distinction. The [reference run](../build/gs-audio/reference-verified/audio.wav) completed the full 30 seconds. The later, denser passage of the tune still needs controller/physical testing.

After aligning each waveform to the reference using its first second, relative RMS difference during seconds 7–9 is 1.339 for the old core and 0.047 for the new core. This is a waveform comparison, not a perceptual audio-quality score. Initial sample phases differ. [Comparison metrics and clip hashes](evidence/gs-intro-comparison-26102802.json); [run logs and provenance](evidence/gs-audio-26102802).

Candidate 26102802 is copied to SD1 with saved 60 Hz and Covox-off settings preserved; byte readback and other root-file hashes match, the card was cleanly ejected, and the live firmware lists 26102802. Physical OSD and listening acceptance await the user’s check and MP4.

## Candidate 26102802

The GS's low 64 KiB now use dual-port FPGA block RAM: its 32 KiB ROM and the first 32 KiB RAM bank, including the fixed workspace and playback buffers. The rest of the 2 MB GS address map remains in SDRAM at its original addresses. Main-ROM storage remains separate. This removes memory waits from the short ISR benchmark (13,231 T2 waits before, zero now) and prevents GS workspace accesses from competing with main-ROM SDRAM traffic.

Loader writes to the GS ROM reach the block RAM; main-ROM uploads still reach SDRAM. Tests cover both byte lanes, the BRAM/SDRAM boundary, 63 RAM pages with eight marks per page, held requests, refresh, address separation and the one-shot loader pulse. The expanded real-ROM run exercises the complete cold memory check and F3 warm reset.

The source changes fit the XC6SLX25: 38 RAMB16 and 6 RAMB8 blocks (41 full-block equivalents out of 52), 9,905 LUTs, 5,807 slice registers and 3,351 occupied slices (89%). Declared ISE constraints pass and the 2500 ms stock BaseConf menu/4096 KB check passes. Complete external SDRAM timing and physical audio still require acceptance.

The board SPI regression verifies that Covox toggles and opening/closing the OSD do not assert GS reset. The OSD GS-reset control is tested separately from main reset. This establishes the FPGA control wiring; it does not establish what happened during the reported physical failure.

## OSD geometry

The inherited menu offset was 72 normalized lines. Its 26 rows occupy 208 lines, ending at line 280, beyond the 262-line 60 Hz raster. Changing BaseConf's raster did not change that fixed menu origin.

The new origin is 34 lines at 60 Hz and 64 at 50 Hz. Against the BaseConf visible windows, the pixel test observes:

| Raster | Visible VGA lines | Complete OSD VGA lines |
|---|---|---|
| 60 Hz, 524 total VGA lines | 36–515 | 68–483 |
| 50 Hz, 640 total VGA lines | 48–623 | 128–543 |

All 26 rows, including the footer, fit with margins. The test also switches between rasters while running. The patch is an explicit adaptation of the pinned overlay in `forge.py`; the external repository is unchanged. Physical monitor positioning still needs the updated-board check.

Commands and interpretation are documented in the [GS audio skill](../skills/gs-audio/SKILL.md). Use `forge.py test --suite osd` for menu visibility and `--suite board` for the actual MCU switch/reset wiring.

Physical follow-up: the user subsequently reports “GS Sounds ok now” and confirms the OSD is good on 26102802. Candidate 26102803 changes keyboard shortcut isolation only; its GS/audio/storage and OSD sources are unchanged. The isolated earlier 1Mb error remains unreproduced.
