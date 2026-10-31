# HDMI audio comparison with local TSConf

Rechecked on 2026-10-28 against `external/karabas-go-core-tsconf`, using the released 26102806 Mini/Mini G generated sources and fresh simulation outputs. **No HDMI audio-path difference explaining the kg3 AY distortion was found.** The hardware AY fault remains open.

## Signal path

Both cores feed the mixer’s 16-bit stereo PCM directly to `hdmi_top`. TSConf's `audio_mix_l/r` are simple aliases of `audio_out_l/r`; there is no additional filtering, attenuation or sign conversion. BaseConf connects those outputs directly. Mini's analog sigma-delta gain difference is outside this HDMI path.

Both use the same physical clock configuration: 50 MHz × 37 / 2 / 33 = approximately 28.030303 MHz. A BUFG supplies `clk_bus`; the corresponding raw PLL output supplies the HDMI BUFGMUX. The mixer updates on the rising bus-clock edge, while HDMI captures samples on the falling edge.

`hdmi_top.v` is byte-identical. It holds each stereo sample, synchronizes a toggle into the pixel-clock domain, then converts 16-bit PCM to 24-bit PCM by appending eight zero bits. This preserves the sign and channel ordering: for example, 8000 becomes 800000. The packetizer, audio clock-regeneration generator, signaling, island encoder, TMDS encoder and Spartan-6 serializer are also byte-identical. There is no separate AY versus GS HDMI path.

## Differences checked

| Item | Local TSConf | BaseConf | Effect |
|---|---|---|---|
| Declared sampler reference clock | Default 28,000,000 | Explicit 28,030,303 | Integer divider comparison below |
| Mini G nominal sample rate | 48,000 | 48,000 | **Both divide by 583**, approximately 48,079.42 samples/s |
| Mini nominal sample rate | 44,100 | 44,100 | TSConf divides by 634 (~44,211.83/s); BaseConf by 635 (~44,142.21/s) |
| HDMI enable | `~dvi_only` | Always enabled | Equivalent while TSConf is in HDMI mode |
| HDMI reset input | `areset || kb_reset || hw_btn[0]` | Same | No difference at this boundary |
| PLL control/reset helper | Reference behavior | Defined startup, complete FT programming transactions, reset held through switching/programming | Existing porting corrections; no steady-state core-mode sample modification |

An intermediate investigation update incorrectly said the kg3 divider became 584. It does not: Verilog integer division truncates 28,030,303 / 48,000 to **583**. Only kg2's divider differs.

The reference's measured N/CTS clock-regeneration logic follows the actual sample cadence. The small kg2 divider change is not a kg3 explanation. No sample-rate or PLL production changes were made during this audit.

## New packet-level regression

The previous `hdmi-test` checks stereo samples **at the transmitter input**, including sample cadence, coherent stereo, 16-to-24-bit conversion, core/FT clock switching and vendor PLL models. That alone does not prove correct audio packet delivery.

`tests/tb_hdmi_audio_packets.v`, run by `hdmi-audio-test`, adds the actual BaseConf ZX video pipeline and the real translated HDMI signaling/island/packet/audio logic. It uses both real 50/60 Hz rasters, each board's audio rate, and both declared-clock values. Its signed stereo pattern crosses zero, wraps and exercises changing bits. It checks:

- Every delivered audio sample matches the accepted stereo sequence, including byte order and parity.
- The packetizer does not overflow; only bounded queued samples may remain when measurement ends.
- Audio clock-regeneration N and steady-state CTS match the sample divider.
- Encoded data-island packet intervals are not clipped by active video.

All eight packet cases passed (two boards × two clock declarations × two rasters). Every emitted sample matched; each measurement ended with one queued sample, and the maximum accepted-but-not-yet-delivered count was three. Both boards also passed fresh transport/PLL-mode tests with zero errors.

This is a core-mode functional test at the packet/signaling boundary. It models the sample strobe rather than re-testing the PLL/CDC; the separate existing transport test covers those. It does not independently decode physical TMDS, prove cable/receiver behavior, or replace routed timing analysis. The shared encoder/serializer source comparison is additional evidence, not hardware acceptance.

From the core root, after `prepare` and `elaborate`:

```sh
python3 tools/forge.py --board minig --build-dir build/ay-zxformat2/minig hdmi-audio-test
python3 tools/forge.py --board mini --build-dir build/ay-zxformat2/mini hdmi-audio-test
```

The command runs `hdmi-test` first if matching transport artifacts are absent. Each output directory contains `hdmi-test/result.json` and `hdmi-audio-test/result.json`, with logs and source-manifest hashes. [Retained audit evidence](evidence/hdmi-audio-comparison.json) lists exact source comparisons, differences and results.

The released normal/core-mode timing reports pass their declared constraints, but physical output timing retains the previously documented limits. The same fault reportedly affects analog output, and GS is reportedly clean; together with the shared kg3 HDMI path, this keeps the upstream AY/mixer state and physical implementation under investigation. It does not establish a particular root cause.
