---
name: gs-audio
description: Reproduce GS playback, memory-check and underrun problems with the stock GS ROM and repository MOD music, rendering stereo WAVs through the actual GS/T80 RTL and comparing shared memory with a zero-wait reference.
---

Run from the core root (`forge/cores/zx-evo-base/`). Read [GS diagnosis](../../docs/gs-timing.md) and [audio validation](../../docs/gs-audio.md). Use `python3 tools/gs_audio.py --help`. All inputs, output directories, temporary files and tools must remain inside this project; other project folders have independent state. No microphone or physical board recording is made by this tool.

Prepare and elaborate maintained sources with `tools/forge.py` first, so `build/baseconf/ghdl/gs.v` and `t80s.v` match the current GS transformations. The renderer uses the existing project-local Verilator and host C++ compiler. It snapshots its HDL, ROM and module into a new run directory, then runs independently of later source regeneration.

For the Dune intro text-screen music:

```sh
python3 tools/gs_audio.py --mode reference --seconds 30 --output build/gs-audio/reference-new
python3 tools/gs_audio.py --mode controller --seconds 30 --output build/gs-audio/candidate-new
```

The default module is `res/media/external.mod`. `--module` selects another repository MOD. `--storage-source` selects a maintained or archived directory containing `baseconf_storage.v` and `baseconf_sdram.v`; the GS/T80 implementation still comes from the current elaborated build. Preserve source hashes when comparing releases. Existing output directories are rejected to preserve evidence.

The harness boots the unmodified GS 1.05b ROM, requires 62 usable 32 KiB pages, checks the count after its F3 warm reset, uploads via the B3/BB host interface and verifies every uploaded byte before the ROM converts samples. It then records stereo at 44.1 kHz and counts visits to the ROM's buffer-underrun handler at 13B9. This address is ROM-specific. Do not apply it to another ROM without rechecking its code.

Host polling must allow a real Z80 instruction delay after a flag clears: the GS can clear a flag before its IN cycle has sampled the latch. An unrealistically immediate next host write corrupts the module. A failed upload is not a valid playback comparison. An unfinished run can supply a verified excerpt only through the extraction mode below; do not call it a completed full-duration test. Compare song position and underrun counts as well as WAV shape; initial CPU/sample phase can differ without an audible defect.

These full RTL runs can take many minutes. `run.log` reports simulated progress once per second; WAV/provenance are finalized only after the explicit PASS marker. Do not confuse simulated seconds with wall time. No analog DAC, PCB setup/hold or physical audio is modeled; use the user's later MP4 for that comparison. Protocol/read-delay regressions and ISE timing remain separate checks.

To save a complete shorter excerpt from an already verified run without repeating simulation:

```sh
python3 tools/gs_audio.py --extract-run build/gs-audio/candidate-new --seconds 10 --output build/gs-audio/candidate-excerpt
```

Extraction requires the upload/start-playback markers and enough PCM bytes. It writes exactly the requested duration, copies source provenance/logs, and records whether the source has a completion marker. If the longer simulation is intentionally stopped, retain that fact in its provenance and report only the observed interval. A PASS marker means the requested capture completed; inspect its underrun count separately. The 26102802 comparison uses ten-second excerpts; only its zero-wait reference completed 30 seconds.
