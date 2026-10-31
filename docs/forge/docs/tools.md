# Tools and skills

Commands below run from the core root. Shared toolchain and board utilities live in the Forge workspace; see [workspace paths](workspace.md), [shared tools](../../../../docs/tools.md) and [core-specific toolchain notes](toolchain.md).

All tools are project-local. No system packages were installed. `bin/` and `build/` are ignored generated/downloaded directories; `tools/`, `skills/`, and `config/` are maintained source.

| Tool | Commands | Outputs / guidance |
|---|---|---|
| `tools/bootstrap.py` | `sources`, `binaries`, `--help` | Locked source commits or SHA-256-verified Ubuntu packages extracted under `../../../bin/hdl/` |
| `tools/forge.py` | `prepare`, `elaborate`, `test --suite all`, `ise --docker`, `test --suite gs`, `--help` | ISE inputs, translated simulation HDL, test executables and logs under `build/baseconf/` |
| Icarus Verilog 12.0-3 | Through `forge.py` | Verilog compilation and event simulation; relocatable tool needs `-B` |
| GHDL 5.0.1 | Through `forge.py` | VHDL analysis and Verilog export; relocatable tool needs `GHDL_PREFIX` |
| Verilator 5.032 | `forge.py bios --simulator verilator --milliseconds 300 --trace` | Faster timed, two-state board simulation using the existing host C++ compiler/make; generated executable and compile log stay under `build/baseconf/` |
| libgnat-15 | Downloaded/recorded, not required by this mcode executable | Kept in `../../../bin/hdl/` with package provenance |
| Xilinx ISE 14.7 | `forge.py ise` | Required for actual XC6SLX25 synthesis, map, route, timing and bitstream; available through the supplied Docker image (see below) |

The binary lock records package URLs and SHA-256 checked against the host's Ubuntu APT package metadata. Package copyright/license files are extracted under `../../../bin/hdl/usr/share/doc/`.

Skills: [forge-build](../skills/forge-build/SKILL.md), [local-hdl](../../../../skills/local-hdl/SKILL.md). They live inside the repository instead of a global skill directory to respect the write boundary. Both have YAML identity/description and concrete commands; neither assumes permission to flash a board.

The original prompt is `prompts/00 research.txt`. Subsequent numbered entries distinguish user follow-ups from assistant work records.

Additional checks and packaging:

- `python3 ../../../tools/check_board.py --project . --ucf build/baseconf/karabas_go.ucf` decodes the B4 interactive BOM and checks all 183 signal balls; [b4-pin-audit skill](../../../../skills/b4-pin-audit/SKILL.md).
- `python3 tools/media.py [--source res/media/dune] [--stage]` validates/stages the supplied TRD and SpectrumProg files with SHA-256; [dune-media skill](../skills/dune-media/SKILL.md).
- `python3 tools/forge.py lint` uses project-local **Yosys 0.52** and Xilinx primitive declarations for RTL process conversion and structural checks. It flattens hierarchy and resolves internal tristates before checking observable wiring. It does not place/route or estimate verified ISE fit. `yosys-abc` is downloaded with Yosys but not invoked by this check.
- `python3 tools/forge.py package` invokes pinned upstream `../../../external/karabas-go-tools/make_core/make_core.py` from the build directory. That script supports `--help`; its JSON paths are relative to the working directory. Packaging requires the actual current ISE output and a passing timing report. Candidate packages and their hashes are recorded under `docs/evidence/`.
- `python3 tools/forge.py bios --simulator verilator --milliseconds 500 --trace` runs the actual board with stock ROM and SPI-initialized RTC. Use Icarus for four-state comparisons. Unused PLL outputs 4/5 are held low in the test-only clock model; they are unconnected in the board wrapper. Re-enable their oscillators if the board begins using them.
- `python3 tools/bios_inspect.py --page 5` extracts a standard Spectrum screen from the simulation SRAM dump. It writes `.scr`, PNG and provenance under `build/bios-screen/`; [bios-validation skill](../skills/bios-validation/SKILL.md). This is a memory view, not an FPGA VGA capture.
- `python3 tools/forge.py resources` uses Yosys/ABC's `xc6s` mapping to produce a preliminary resource count in `resource-stat.json`. It uses translated CPU/HID logic and does not replace ISE inference, packing, placement, routing or timing.

ISE download check, 2026-10-27: AMD's [official ISE 14.7 archive](https://www.amd.com/en/support/downloads/adaptive-socs-and-fpgas/legacy-ise/v2012_4---14_7.html) lists the Linux installer. Its [download link](https://account.amd.com/en/forms/downloads/xef.html?filename=Xilinx_ISE_DS_Lin_14.7_1015_1.tar) leads through AMD's account service; the attempted request returned a session-establishment error rather than an installer. No authenticated download URL, installer or project-local installation was available. Place a legitimately obtained installer/installation under shared Forge `../../../bin/` to continue the ISE build. Downloads and installation must remain inside this project.

## Docker ISE 14.7 (provided 2026-10-28)

The user supplied `../../../external/xilinx-ise/xilinx` and an installed Docker image. `xst -help` confirms **Release 14.7, P.20131013 (lin64)**. The batch adapter uses image `docker.i74.de:5000/xilinx-ise@sha256:9a12826e3c0696e9b855a669a1e0f7a04fdd180126c735d62d325dae13b769bf`. No image download or installation was needed.

`python3 tools/forge.py ise --docker` runs the complete implementation flow. `python3 ../../../tools/ise_docker.py --build-root build --workdir baseconf xst -help` runs an individual command; both tools have command-line help. The adapter retains the supplied image's wrapper/setup, removes the terminal requirement, explicitly mounts project `build/` at `/build`, and executes in `/build/baseconf`. The supplied shell launcher itself is unchanged. Its relative mount would otherwise depend on the invoking directory. The supplied license is mounted read-only; its contents are not logged. The image runs without network access. Container-local files are ephemeral; the only writable host mount is the project build directory.

See the [ISE Docker skill](../../../../skills/ise-docker/SKILL.md). The wrapper prints harmless no-terminal/job-control messages because its shebang requests an interactive login shell; the batch tool still executes. The earlier missing-ISE blocker is resolved. Actual build results are tracked in progress/problems.

## Board serial helper

`python3 ../../../tools/board_serial.py --project . --command list` queries the identified Karabas USB serial interface and saves `build/board/serial.log`. `--command listen --seconds 60` captures logs without sending commands. `msc` / `msc2` request an SD-export reboot; `sd2test` performs the firmware's SD2 read test in the boot core. This standalone Python tool uses only the standard library, rejects non-project log paths and requires an identified Karabas serial device. See the [board-access skill](../../../../skills/board-access/SKILL.md) and [hardware test guide](hardware-test.md). Eight project skills are now maintained, including the GS audio renderer described below.

The 2026-10-28 SD1 copy used the supplied image's existing mount/cp/cmp/sha256sum commands with one identified partition, a project build-directory bind, no network, SYS_ADMIN and a temporary AppArmor exception for mounting. Normal ISE runs use neither SYS_ADMIN nor that exception. The media was unmounted on container exit and ejected through UDisks. No extra binary download was needed.

GS throughput regression: `python3 tools/forge.py test --suite gs` runs the real GS/T80 with a synthetic four-channel interrupt workload against an identical zero-wait reference. It includes competing ROM requests and an approximate routed read-delay case. This suite is included in `all` and documented in [forge-build](../skills/forge-build/SKILL.md) and [GS timing](gs-timing.md). No new binary was downloaded for this test.

`python3 tools/gs_audio.py --help` documents the standalone, standard-library GS audio renderer. It uses the existing Verilator binary, snapshots run inputs and produces PCM/WAV/provenance inside a fresh `build/gs-audio/` directory. It defaults to Dune’s intro text-screen MOD. See [gs-audio skill](../skills/gs-audio/SKILL.md) and [audio validation](gs-audio.md). There are now eight project skills; no additional binary was downloaded.

SEGA gamepad mapping is tested by `forge.py test --suite hid` (also in `all`), with real MCU/OSD command frames and all twelve mapped controls on each port. See [joystick setup](joysticks.md) and the updated [build skill](../skills/forge-build/SKILL.md). No new tool or binary is required.

## Multi-board build commands

`forge.py --board go|mini|minig <command>` selects GO (`build/baseconf/`, kg1), Mini (`build/baseconf-mini/`, kg2), or Mini G (`build/baseconf-minig/`, kg3). The flag precedes the command. `video-test` checks real BaseConf blanking/OSD in both rasters and four mode families. `hdmi-test` checks actual HDMI pixel transport, audio samples and core/FT40/FT64/core switching using existing GHDL/Icarus and unisim sources extracted from the supplied ISE image. No new binaries were downloaded or installed. ISim was attempted but the image lacks its required GCC compiler; the maintained command uses Icarus instead.

Mini machine tests deliberately replace HDMI with a boundary sink; their BIOS/GS/input results are separate from `hdmi-test`. The ISE flow and packager require normal and core-video timing reports. Updated [build](../skills/forge-build/SKILL.md), [ISE](../../../../skills/ise-docker/SKILL.md) and [local HDL](../../../../skills/local-hdl/SKILL.md) skills describe these commands, clock-domain constraints and model limits.


`python3 tools/forge.py test --suite ay` adds CPU-driven PSG register and signal checks to `all`, using the existing Verilator/compiler toolchain. Results are `ay-result.json` and per-speed/type logs under the selected build directory. See [AY investigation](ay-audio.md).

`python3 tools/forge.py bios-reset-test` compiles the actual board/stock-ROM harness once, then checks ten held-key F12 selections in isolated run directories. It guards the ROM hash and saves `bios-reset-result.json`. Run separately on GO, Mini and Mini G after reset/input changes. See [reset controls](reset-controls.md).

`python3 tools/ay_zxformat2.py capture --disk ../../../ZX-FORM2.TRD`, followed by `cpu-intro` and `replay`, executes the supplied intro in Fuse, compares its first 660 writes against the real BaseConf CPU, and renders the full captured stream with BaseConf/TSConf audio-enable phases. Requires prepared/elaborated Mini G sources, Fuse SDL 1.6.0 and numpy. `analyze` reuses a completed replay. See [workload, commands and limits](ay-audio.md#zx-format-2-reproduction-2026-10-28).

`python3 tools/forge.py --board minig hdmi-audio-test` checks actual BaseConf 50/60 Hz blanking against HDMI stereo packet contents/order/parity, queue capacity, ACR N/CTS and data-island clipping. Repeat for `mini`. It runs the existing transport test first when matching generated transport artifacts are absent. See [HDMI audio comparison](hdmi-audio.md).
