# AY noise investigation

Remote feedback reports substantial noise with AY sound on Mini kg2 and Mini G kg3, through both HDMI and analog output, while GS plays correctly. The maintainer has no device locally. ZX-Format 2 and same-board Mini G recordings are now supplied; package identity and saved settings remain unknown. **The reported hardware noise is not reproduced or fixed by this investigation.**

## Comparison with the pinned TSConf reference

The supplied `external/karabas-go-core-tsconf` reference is pinned at `edb2060c36164946622b71847e598ff01e6039f8` in the Forge workspace. The BaseConf-generated AY/YM generator (`ym2149.v`), JT03/JT12 sources and `audio_mixer.v` are byte-identical to that reference: 38 imported audio source files were checked. TurboSound's only local modification ties the unused PSG parallel-port inputs to FF.

Both integrations clock sound from the ~28.0303 MHz bus with a divide-by-eight PSG master enable. BaseConf uses a combinational divide decode; TSConf registers that decode, shifting its phase by one bus cycle without changing its frequency. BaseConf's CPU port decode deliberately uses the full FD low byte to avoid intercepting its BD configuration ports. Tests now exercise this path using the actual T80 CPU.

The Mini/Mini G machine transformations do not change TurboSound or the mixer. Optional ADC/ESP mixer branches are disabled in their BaseConf synthesis settings. The same mixed sample feeds HDMI and analog output, so reported clean GS playback makes a general output failure less likely, but does not prove the AY signal is correct on hardware.

One concrete difference is the older Mini's sigma-delta input:

```verilog
// Current BaseConf Mini
{~audio_out_l[15], audio_out_l[14:0]}
// TSConf Mini
{2'b00, !audio_mix_l[15], audio_mix_l[14:4], 2'b00}
```

The reference reduces the offset-binary value by approximately four and clears two additional low bits. BaseConf therefore uses roughly four times the DAC input gain. This difference could affect kg2 analog output; it is absent from HDMI and Mini G and cannot explain the complete reported symptom. Mini G uses the same PCM5102 divider as its TSConf reference. No output-gain change has been made speculatively.

## Added regression

From the core root:

```sh
python3 tools/forge.py --board mini --build-dir build/ay-investigation/mini prepare
python3 tools/forge.py --board mini --build-dir build/ay-investigation/mini elaborate
python3 tools/forge.py --board mini --build-dir build/ay-investigation/mini test --suite ay
```

Use `go` or `minig` and a corresponding output directory for the other targets. `ay` is also included in `test --suite all`. It requires the shared Verilator and existing host C++ build tools, as the BIOS test does.

`tests/tb_ay.v` runs a small diagnostic through the actual CPU, memory interfaces, BaseConf port decoder, TurboSound and mixer. The test writes and reads PSG registers 0–13 on both chips, checks distinct left/right chip contributions, then generates a noise-disabled ~438 Hz tone. Every output sample must be either silence or the expected amplitude, the opposite channel must remain silent, and tone edges must be exactly 32,000 bus clocks apart.

Historical result (speed-coverage correction below): all 18 labelled combinations passed: three board source targets, three CPU speeds (3.5/7/14 MHz), and AY/YM modes. Generated implementation manifests remain identical to the released builds. No production RTL, bitstream, package or device was changed. Detailed logs and `ay-result.json` live under `build/ay-investigation/<board>/`; [comparison and results](evidence/ay-noise-investigation.json) record hashes and limitations.

This is a two-state functional test with FPGA-like zero startup state, a synthetic ROM deposited into simulated memory, and GS held reset to isolate AY. It does not model an audible recording, an unknown game's envelope/noise workload, simultaneous GS playback, board electrical behavior or routed timing. Passing it does not disprove the remote observation.

## Initial feedback request (superseded by the supplied recordings)

The program, recordings and same-board comparison have now been supplied; see the ZX-Format 2 investigation below. Package/build identity remains useful. Also record whether the sound changes when selecting AY versus YM, changing PSG stereo mode, switching Covox off, or resetting GS. These are diagnostic distinctions, not proposed fixes. Until that evidence or a reproducible failure is available, the current packages remain unchanged.

## ZX-Format 2 reproduction (2026-10-28)

The user supplied `ZX-FORM2.TRD`, `kg3-baseconf-distorted.mp4` and `kg3-tsconf-plays.mp4` at the Forge root. The BaseConf filename includes **baseconf**, rather than the abbreviated name in the request. Both videos show the same X Design / ZX Format 2 intro on Mini G. BaseConf starts earlier, in ERS, which displays 3.5 MHz. Spectrogram inspection shows strong broadband content through the BaseConf music section, while the TSConf recording retains clear tonal structure. These are mono acoustic AAC recordings, not direct synchronized digital captures; their absolute amplitudes and sample values are not comparable. The exact package hashes and saved OSD settings remain unknown.

### Actual player and CPU checks

`FORM2n_m` contains a loader which reads 0x47 sectors starting at disk sector 43 into 9C40 and calls it. `tools/ay_zxformat2.py` verifies the supplied disk hash, extracts those unchanged intro bytes, and builds a 48K SNA with the loader's entry/stack context. Fuse SDL 1.6.0 executes the intro and logs its AY port writes. The captured screen matches the X Design screen in the videos. This bypasses disk loading and ERS; it does not emulate the complete magazine boot.

The 26-second Fuse run captures **27,918 port writes**, comprising 1,269 updates of registers 10 down to 0. The player uses `LD B,D / OUT (C),A / LD B,E / OUTD / DEC A`, with D=FF, E=BF and C=FD. OUTD decrements B before the bus write, so data goes to **BEFD**, a valid mirrored AY port. Fuse's debugger callback sees B decremented but HL not yet decremented: the data byte is `[HL]`. The retained extractor checks these instruction/port assumptions rather than interpreting every FD write as AY data.

There are no envelope-register writes. Register 6 stays zero; register 7 is 18 or 38 after the initial silent updates. Channels A/B have noise disabled, and C's volume stays zero for roughly the first 15 seconds. Thus the early recorded distortion is not the tune deliberately enabling audible AY noise. Later channel-C percussion does use noise.

`tests/tb_zxformat2.v` executes the unchanged extracted intro through the actual BaseConf T80, mapper and SRAM model. The first **660 port writes / 30 updates** must match Fuse exactly, with a 3.5 MHz mode assertion and silent speaker/Covox assertions. GS is held reset. This checks actual player execution, not a replay fed around the CPU. It covers the beginning of the intro only.

`tests/tb_ay.v` now also exercises the player's OUTD idiom and BEFD mirror with distinct values and register readback. All **18 board/speed/AY–YM cases** pass. A defect in the previous test setup was found: its purported 3.5 MHz case wrote EEF7 in shadow mode, which this upstream revision explicitly ignores. The corrected AY test leaves shadow mode, writes EFF7 and asserts `int_turbo`. Historical AY results labelled 3.5 MHz actually exercised 7 MHz; the new results supersede that coverage claim. The older `tb_boot.v` has the same speed-setup limitation and its historical 3.5 MHz label is not independent speed evidence.

### BaseConf versus TSConf audio integration

The 38 imported PSG/JT03/JT12/mixer files remain byte-identical to the local TSConf reference. `tests/tb_ay_trace.v` replays the full captured stream through two instances of those shared modules: BaseConf's FD decode and combinational divide-by-eight enable, versus TSConf's low-nibble-D decode and registered enable. The same captured instruction timestamps drive both, mapped at eight bus clocks per Fuse T-state with ideal 16-clock write pulses; this is not an exact reconstruction of every CPU bus edge. This specifically tests the integration differences; it is **not** a simulation of the complete TSConf machine.

Both paths render stereo ACB audio with other mixer inputs zero. Samples integrate 636 bus clocks before decimation to approximately 44.073 kHz, to avoid point-sampling aliases. The full 25.309-second replay includes the later noise percussion. Its output difference is 0.854 RMS sample units versus 2040.487 RMS signal units; maximum absolute difference is 16 units, and both channel correlations exceed 0.9999999. This nominal CE-phase difference does not explain the severe recorded distortion. Results and comparison WAVs are under `build/ay-zxformat2/`; the [retained evidence](evidence/ay-zxformat2.json) records hashes, measured differences and limits. This test separates the small CE-phase effect from a change in the PSG implementation. It does not reproduce board routing, physical clocks, ERS/loader state, simultaneous GS or other live mixer inputs.

### Reproduce

From the core root, with Fuse SDL 1.6.0, numpy and the existing local HDL tools available:

```sh
python3 tools/forge.py --board minig --build-dir build/ay-zxformat2/minig prepare
python3 tools/forge.py --board minig --build-dir build/ay-zxformat2/minig elaborate
python3 tools/forge.py --board minig --build-dir build/ay-zxformat2/minig test --suite ay
python3 tools/ay_zxformat2.py capture --disk ../../../ZX-FORM2.TRD
python3 tools/ay_zxformat2.py cpu-intro
python3 tools/ay_zxformat2.py replay
```

`analyze` regenerates WAVs and metrics from a completed replay without repeating simulation. Capture is deliberately specific to the supplied disk's hash. Generated data belongs in the core build directory; the user's original media and recordings remain untouched.

The hardware fault remains open. The new evidence makes an OUTD decode error, envelope bug, and the nominal one-clock CE phase difference poor explanations. The remaining useful distinction is between corrupted/stale PSG state or another live mixer contribution on hardware and a physical implementation/clock issue. An isolated PSG-output diagnostic and a register dump from the failing machine would distinguish these; simulation success alone does not choose between them. No production RTL or release package was changed.

## HDMI follow-up

The [HDMI audio audit](hdmi-audio.md) compares the complete downstream path against local TSConf and adds packet-level coverage under actual BaseConf blanking. Mini G has identical sample-divisor arithmetic as well as identical audio transport source; the small declared-clock difference changes the divider only on Mini. The AY hardware fault remains open.
