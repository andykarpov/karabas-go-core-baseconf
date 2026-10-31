# Core toolchain and board workflow notes

Run commands from the core root. Shared tools and skills live in the Forge workspace; see [workspace layout](workspace.md). These notes retain the core-specific implementation and board-transfer details.


## ise-docker

Use `python3 tools/forge.py prepare` then `python3 tools/forge.py ise --docker` from the project root. Read `docs/architecture.md` and `docs/problems.md` before changing hardware interfaces.

The user's `../../../external/xilinx-ise/xilinx` launcher invokes `docker.i74.de:5000/xilinx-ise:latest` through `/usr/local/bin/wrapper`. Its `$(pwd)/../build` mount depends on the caller's directory and `-it` requires a terminal. The maintained `../../../tools/ise_docker.py --build-root build --workdir baseconf` batch adapter uses the same wrapper with an immutable image digest, an explicit project `build/` mount at `/build`, and selects `/build/baseconf` after the wrapper changes directory. It does not change the supplied launcher or pull/rebuild images.

For one tool: `python3 ../../../tools/ise_docker.py --build-root build --workdir baseconf xst -help`. Use `--workdir` for another existing directory inside project `build/`; `--license` or `XILINX_LIC` selects a license. The default supplied license is `~/.Xilinx/Xilinx.lic`, mounted read-only. Do not copy its contents into logs. No host directory outside this project is writable through the adapter. Container network is disabled; the local license/image must be available.

Outputs and per-tool logs go in `build/baseconf/`. Diagnose XST, NGDBuild, MAP, PAR, TRCE and BitGen failures in that order. Edit maintained `src/rtl/`, `config/`, or reference transformations in `tools/forge.py`; regenerate rather than editing generated HDL. Run relevant simulations after RTL changes. ISE uses original VHDL; simulation uses GHDL-translated equivalents.

Inspect fit, actual timing, unconstrained paths, CDC and external bus budgets before `python3 tools/forge.py package`. Packaging provenance and a passing timing report are required; hardware acceptance remains separate. Document the image identity and observed ISE version in `docs/tools.md`, and current build results in progress/problems/plan.

For Mini and Mini G use `python3 tools/forge.py --board mini ise --docker` or `--board minig`. The adapter selects each isolated build directory with `workdir=OUT`. The flow runs a second TRCE pass on the same routed design with core-mode constraints; packaging requires both reports to pass. Do not regenerate inputs while either implementation or BIOS is active.

The supplied image lacks `/usr/bin/gcc`, so its ISim `fuse` cannot finish compilation. `forge.py --board <mini|minig> hdmi-test` instead extracts the supplied unisim Verilog sources into that target's build directory and runs local GHDL/Icarus. It does not install a compiler or change the image. Vendor files are simulation-only and must not be included in the synthesis project or redistributed as part of the core source release.

## local-hdl

Use `python3 tools/bootstrap.py binaries` to download the exact Ubuntu amd64 packages in shared `../../../config/binaries.lock.json`, verify SHA-256 and extract into `../../../bin/hdl/`. Requires a compatible Linux amd64 libc and `dpkg-deb`. Existing incorrect downloads fail verification; inspect/remove only that failed project-local download before retrying.

Use `tools/forge.py` for normal work. Its child processes set TMPDIR, HOME and XDG_CACHE_HOME to project-local paths. For manual commands:

```sh
export KARABAS_FORGE_ROOT="$(cd ../../.. && pwd)"
export TMPDIR="$PWD/tmp"
export GHDL_PREFIX="$KARABAS_FORGE_ROOT/bin/hdl/usr/lib/ghdl/mcode/vhdl"
export LD_LIBRARY_PATH="$KARABAS_FORGE_ROOT/bin/hdl/usr/lib/x86_64-linux-gnu"
"$KARABAS_FORGE_ROOT/bin/hdl/usr/bin/iverilog" -B "$KARABAS_FORGE_ROOT/bin/hdl/usr/lib/x86_64-linux-gnu/ivl" --help
"$KARABAS_FORGE_ROOT/bin/hdl/usr/bin/ghdl-mcode" --help
```

Icarus's `-B` and GHDL's `GHDL_PREFIX` are necessary for relocation. Generated objects/logs belong under `build/`. VHDL analysis needs `--std=08 -fsynopsys -fexplicit`. The build helper handles GHDL's emitted-name collision for the T80 ALU, Verilog's reserved `do` word, and top-level case differences; keep these translation-only adjustments out of the original reference checkout.

Downloaded `libgnat-15` is recorded for provenance but the supplied GHDL mcode binary does not dynamically link it. Do not substitute these tools for ISE place-and-route: they cannot produce a Spartan-6 programming image.

The binary lock also includes Yosys 0.52 and yosys-abc. `python3 tools/forge.py lint` uses the relocated Xilinx `cells_sim.v`/`cells_xtra.v`, deferred source elaboration, process conversion, flattening and tristate-to-logic conversion. Treat any remaining `check -assert` failures as unresolved wiring problems; read `build/baseconf/lint.log`. This flow does not run ABC or FPGA place-and-route.

Verilator 5.032 is pinned in the same binary lock. Its wrapper locates `../share/verilator` relative to `../../../bin/hdl/usr/bin`; do not set a system `VERILATOR_ROOT`. `../../../bin/hdl/usr/bin/verilator --help` describes its options. `python3 tools/forge.py bios --simulator verilator --milliseconds 300 --trace` compiles a timed stock-BIOS board simulation into `build/baseconf/verilator_bios_o3/` with the host's existing C++ compiler (`-O3`) and make. Build logs remain under `build/baseconf/`. No system installation is needed.

Verilator uses two-state logic and a test-only SRAM variant with 10 ns address-to-data delay and ideal OE switching. Use Icarus for four-state/pin-driver checks, and compare startup behavior between simulators before trusting a long compiled run. Uninitialized physical RAM must be modeled with reproducible bits for the BIOS resident-program CRC; X-filled RAM can poison CPU state. Neither simulator is an electrical timing model.

`python3 tools/forge.py resources` invokes Yosys `synth_xilinx -family xc6s -ise`, including the local ABC executable, to estimate mapped resources. Read `resource-stat.json` and `resources.log`. Resource mapping succeeds only when the subsequent structural check passes; it still does not establish ISE fit/timing or produce a programming image.

Mini HDMI: `forge.py --board mini hdmi-test` (or minig) splits GHDL synthesis into VHDL-93c for the packet generator/transmitter and VHDL-2008 for DVI. It uses component binding for DVI, matching the pinned reference simulation, and Icarus with the supplied ISE unisim models. A simulation-only `default_nettype wire` prefix restores implicit-wire semantics required by those vendor files. FT test periods match the vendor DCM model's integer-picosecond truncation; independent rounded half-periods introduce artificial FIFO drift. Machine/BIOS tests use `tests/hdmi_boundary_model.v` instead, explicitly excluding HDMI behavior from those results.

## board-access

Read `docs/hardware-test.md` and `docs/problems.md`. Use `python3 ../../../tools/board_serial.py --project . --help`. The tool discovers exactly one `usb-Karabas_Go_*-if00` serial link, uses 115200 baud, and stores logs only inside the project. `--command list` is a read-only firmware core-list query. `--command listen --seconds 60` captures serial output without sending bytes. `--command msc` / `msc2` reboot the board into SD1/SD2 USB mass-storage mode; use them only as part of the user's requested transfer/test workflow. `sd2test` reads SD2 and requires the boot core. A timeout/no response does not prove that a command succeeded.

Identify USB vendor/product, serial and block-device ancestry again after every re-enumeration; never assume `/dev/sda` remains the board. The tested device reports vendor 2e8a, product 000a, manufacturer Karabas. Preserve existing media; never format cards or overwrite unrelated files. `AT+KARABAS=boot` is a firmware update command, not normal FPGA core loading, and is intentionally absent from this helper.

The host desktop may auto-mount SD1 outside the project. The user requires project-only paths. For the recorded transfer, unmount that identified partition via UDisks, then use a temporary container mount at `/build/board/sd1`, with only project `build/` writable as a host-directory bind. The supplied pinned ISE image contains mount/cp/cmp/sha256sum; this media operation needs only the identified partition as a device, `SYS_ADMIN`, and a per-container AppArmor exception to permit mounting. These privileges are not used by normal ISE builds. Keep network disabled, never use `--privileged`, trap unmount on exit, and do not touch another disk. Mount read-only first to check contents. If mounting/identity is uncertain, stop the media transfer and preserve the project artifact.

Stage a new core with a temporary filename, compare bytes, then rename to `baseconf.kg1` only when that target is absent. For later updates, establish replacement scope and retain the old candidate before replacing it. Hash existing root core/config files before and after; sync and unmount, then request UDisks Drive.Eject for the identified board drive. Query the serial list again after the board restarts. Record the copied SHA-256 and firmware listing. A successful transfer/listing is not a successful FPGA boot.

Firmware saves OSD switch selections in the package's 256-byte block at offsets 512–767. An installed package can therefore differ from the original release hash without changing its FPGA or ROM payloads. Back up the actual card copy and compare every byte before treating a mismatch as settings-only. If the new OSD layout is compatible, preserve those selections in a separate project-local transfer copy and record both the generic package hash and installed hash. Do not transplant settings across incompatible layouts or disregard differences outside that block. The GS update preserved the user's 60 Hz selection (byte 517). Mount cleanup must change the container's working directory out of the mount before unmounting.

The documented serial protocol has no core selection, keyboard injection or video capture command. Request user selection/display observations or use separately verified capture/control equipment. USB debug logs alone cannot validate graphics, audio or game controls. Keep hardware results separate from simulation evidence.

For Dune, export SD2 with `--command msc2`; the tested card identifies as model `SD_Card_2` (FAT32), while SD1 identifies as `SD_Card` (FAT16). Mount at `/build/board/sd2` and copy the validated `build/media/dune.trd` / `DUNE.DAT` to its root without modifying SD1 or CF. Re-identify the device each time; filesystem UUID/capacity are evidence, not a substitute for checking its USB ancestry/model.

## b4-pin-audit

After `python3 tools/forge.py prepare`, run `python3 ../../../tools/check_board.py --project . --ucf build/baseconf/karabas_go.ucf`. Use `--ucf path` for another project-local constraint file. The script decodes the embedded LZString JSON without executing HTML, checks the 16×16 U1 footprint orientation/pin 1, requires 183 distinct signal balls and compares declared aliases to B4 PCB net names. Results go to `build/board-pins.json`.

The BGA row letters skip I/O/Q/S. Active-low KiCad names use `~{NAME}`. The FPGA's SD port is the board's SD2; floppy nets use LFDC names. SRAM low/high byte strobes and named test-point nets have explicit aliases in the script.

Do not silently update aliases to hide a mismatch. Confirm the intended physical signal first. A PASS checks ball/net correspondence only: TP1–TP7 functions, buffer polarity, voltage, setup/hold and SDRAM clock capture still require schematic/device/timing review.
