# Current plan

Targets: Karabas GO B4, Mini and Mini G, Spartan-6 XC6SLX25-2-FTG256.

| Step | Status | Work |
|---|---|---|
| Distribution bundle | Done | KG1/KG2/KG3 plus matching shared RP2040 firmware, Dune media, checksums and [installation instructions](builds-and-installation.md); unchanged 26102806 FPGA inputs verified. |
| Reset/boot hotkeys | Done; accepted on all boards | 26102806 removes GS Reset/Menu+G, couples GS/core reset and detects F12 in every HID slot. Thirty stock-ROM selection cases pass; user confirms hotkeys work on GO, Mini and Mini G. See [controls](reset-controls.md). |
| Forge workspace reorganization | Done | Core moved to `forge/cores/zx-evo-base`; shared infrastructure stays at root; `src/` and checksummed `res/` separate maintained inputs. See [workspace notes](workspace.md). |
| Source and board research | Done | Locked reference commits, inspected firmware protocol, cross-checked 183 UCF balls with B4 PCB data |
| Local tools and skills | Done | Icarus/GHDL/Yosys/Verilator binaries and hashes; Python tools with help; eight documented project skills, including Docker ISE and board access |
| Source integration | Done, experimental | BaseConf machine/video/pager plus GO MCU/HID/OSD/FDC/CF/audio and memory adapters |
| Digital verification | Done for listed contracts | Full elaboration, structural check, memory tests, CPU/RTC/BD/Nemo/Firefly diagnostics at three speeds, MCU/HID tests |
| Media preparation | Done | Supplied Dune files checked, staged and copied to SD2 root with verified hashes and clean eject |
| Stock BIOS compatibility | Menu reached in simulation | Unmodified ROM displays main menu and 4096 KB RAM; fixed RTC/port-map compatibility bugs; physical boot and AVR service identity remain separate acceptance items |
| Resource estimate | Preliminary mapping passed | Yosys/GHDL Spartan-6 mapping and structural check; superseded by actual ISE results below |
| FPGA implementation | Candidate built | Build 26102804 completes ISE/BitGen with zero errors for current constraints; external timing/CDC acceptance remains |
| Hardware acceptance | Prior baseline accepted; SEGA check pending | 26102800 physical ERS/Dune observed; 60 Hz fixes monitor cropping. 26102804 copied with settings preserved; 26102803 accepted for GS/OSD/shortcuts; check physical SEGA mapping |
| GS playback correction | Physical listening accepted | User confirms GS sounds OK on 26102802; low 64 KiB BRAM and audio timing retained in 26102803 |
| OSD clipping | Pixel regression passes | Raster-specific offsets fit all 26 rows at 50/60 Hz; User confirms 26102802 OSD good |
| Boot target regression | Fix accepted on board | ERS recovered with 0+reset. Candidate 26102803 prevents reserved shortcut leakage; tests/BIOS/ISE and SD1 transfer pass; user confirms all works; see boot-regression.md |
| SEGA gamepad mapping | Implemented and copied | Mode 6 added to both OSD selectors; all twelve keys tested on both ports; BIOS/ISE pass; physical pad check pending; documentation in joysticks.md |
| Dune acceptance | Display and GS audio accepted | Confirm mission controls and sustained gameplay at 14 MHz |
| Mini / Mini G ports | Offline builds complete; hardware untested | 26102805 kg2/kg3 pass simulations, ERS/4096 KB, both timing modes and package checks. Existing kg1 retained. See [packages and limits](mini-cores.md). |

Work resumed on 2026-10-28 with the user-supplied Docker ISE 14.7 image. The [handover](handover.md) records the installed candidate and evidence; USB serial and SD1 transfer now work; photos and user audio feedback now establish startup; further video/control/audio observations still need the user or capture equipment. Commands, current evidence and limits are recorded in [validation](validation.md), [architecture](architecture.md) and [problems](problems.md).

Completion means a newly implemented, timing-checked bitstream with successful B4 acceptance. The current source/simulation result does not meet that final gate yet.
