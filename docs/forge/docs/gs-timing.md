# GS playback speed diagnosis — 2026-10-28

The user reports roughly half-speed General Sound playback in Dune. Selecting 60 Hz in OSD fixes the monitor's vertical cropping, but GS timing must remain independent of that setting.

## Cause and TSConf comparison

In `src/rtl/baseconf.v`, GS receives the fixed 28.0303 MHz bus clock and a divide-by-two enable: approximately 14.015 MHz. The imported GS interrupt counter expires every 374 enables, about 37.47 kHz. Neither signal depends on the raster selection. Changing the interrupt divider would mask the memory bottleneck and change the intended sound rate.

The working pinned TSConf reference uses a 14 MHz GS CPU and an **84 MHz SDRAM controller**: see `../../../external/karabas-go-core-tsconf/src/rtl/sound/gs_top.v`, `src/rtl/sound/gs.v`, and `src/rtl/ram/sdram.vhd`. The VHDL memory controller uses an inverted forwarded clock, two clocks from ACT to CAS, CL2, and falling-edge data capture. This is the controller instantiated by GS; the other SDRAM source in that tree is not the relevant implementation.

Our original shared ROM/GS controller ran at 28 MHz and used long transactions plus arbitration. Its WAIT input correctly prevented bad reads, but the resulting CPU stalls made sample interrupts go unserviced. A synthetic four-channel ISR reproduces the slowdown against an identical GS/T80 with zero-wait memory:

| 2 ms workload | Original controller | Revised controller | Zero-wait reference |
|---|---:|---:|---:|
| GS alone | 41 | 74 | 74 |
| GS plus competing main-ROM reads | 29 | 75 | 75 |

Numbers count serviced interrupts, not generated timer periods. Both GS timers generate 149 periods over the two phases. The revised test also checks identical nonzero stereo samples. These results establish a reproducible memory-service problem and its correction for this workload; they do not execute Dune's player or establish an exact speed ratio for every tune.

## Implementation

`baseconf_storage` and `baseconf_sdram` now use the existing 84.0909 MHz PLL output. The controller keeps the original byte/bank/row mapping, ROM/GS isolation, startup delay, periodic refresh and explicit precharge. It returns completion while precharge recovers, allowing arbitration to overlap recovery. GS CPU and interrupt clocks are unchanged. A 28 MHz loader write pulse spans three memory clocks, so a one-shot guard enqueues it once; the storage regression checks this behavior.

DQ is captured into all 16 input registers, then the addressed byte is selected. The final capture uses the **rising edge following CAS+2**, half a clock later than the TSConf implementation. The first 84 MHz trial's falling-edge capture passed an ideal read model but failed when approximate forwarded-clock and input delays were included. The later edge passes both cases without adding an arbiter cycle.

The read model was corrected to CL2 semantics: data begins driving after the clock following READ and is valid by the second clock. See the manufacturer's [Micron MT48LC16M16A2 SDRAM data sheet](https://www.alliancememory.com/wp-content/uploads/Micron_256M_SDRAM_PartNo.MT48LC16M16A2.pdf). This is the timing reference used by the model, not a claim that the physical board's chip marking has been inspected.

The test uses a 4.3 ns forwarded-clock delay, 6 ns clock-to-data delay and 3 ns data hold; a second case adds 3.7 ns to the read-input path, based on the first routed candidate. Command/write propagation, PCB skew, process/voltage/temperature corners and complete setup/hold are not modeled. The old falling-edge trial services 0/74 interrupts in that delayed case; the final edge services 74/74 and 75/75.

An exploratory 3 ns FPGA input-path constraint failed all 16 lanes: component delays alone were 3.280 ns and the routed maximum was 3.679 ns. The final input budget is 4 ns, with the later capture edge. This replaces the original release's 8 ns budget. It is a pad-to-register budget, **not full external SDRAM timing closure**; board timing review and physical memory/audio acceptance remain required.

## Reproduce and accept

Run `python3 tools/forge.py prepare`, `python3 tools/forge.py elaborate`, then `python3 tools/forge.py test --suite gs` (also included in `--suite all`). The test compares interrupt service and sample values with a reference, rather than merely checking divider constants. Logs are `build/baseconf/tb_gs_nominal.log` and `tb_gs_routed.log`.

The integrated CPU diagnostic now polls Firefly track/sector readback within its overall timeout. Faster ROM fetches exposed the old fixed NOP delay as too short for the controller's microcode update; no FDC RTL was changed for that test adjustment.

Build candidate: **26102801**. Keep 26102800 under `build/releases/26102800/` for rollback. Once implementation and stock-BIOS checks pass, update SD1, then replay the same Dune music. Confirm tempo, pitch, stereo and stable playback at both 50/60 Hz where the monitor permits; the 60 Hz setting can remain selected for normal use. USB serial provides neither audio capture nor automatic core selection, so the final listening test requires the user or capture hardware.

Final status: candidate 26102801 passes all regressions, stock-BIOS signature and declared ISE constraints. It is verified on SD1 and listed by live firmware, with the saved 60 Hz setting preserved. See [transfer evidence](evidence/gs-sd1-transfer-26102801.json). Physical music acceptance is pending.
