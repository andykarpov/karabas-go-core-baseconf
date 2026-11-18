#!/bin/bash
# tb_gs_storage (ISim): the GS on z80-silicon with baseconf_storage and sdram_model, the test ROM
# gs_memtest.asm (sjasmplus) in the block RAM, its RAM tests in the block RAM and in the SDRAM (port 2)
# while the OPL4 reads port 2. Prints "tb_gs_storage: 0 errors"; fails on any other count.
# Usage: src/sim/run_gs_sim.sh [path to ISE_DS/settings64.sh]
set -e
SETTINGS=${1:-/opt/Xilinx/14.7/ISE_DS/settings64.sh}
SIM="$(cd "$(dirname "$0")" && pwd)"
R="$(dirname "$SIM")/rtl"
SJASM=${SJASM:-$(command -v sjasmplus || echo /opt/sjasmplus/sjasmplus)}
OUT="$SIM/build/gs"
mkdir -p "$OUT"
cd "$OUT"
"$SJASM" --nologo --raw=gs_memtest.bin "$SIM/gs_memtest.asm" > sjasm.log || { cat sjasm.log; exit 1; }
xxd -p -c 1 gs_memtest.bin > gs_memtest.hex
set --
source "$SETTINGS" > /dev/null
vlogcomp -work work "$SIM/lib/ODDR2.v" "$SIM/sdram_model.v" "$R/ram/sdram2p.v" "$R/baseconf_storage.v" \
	"$R/z80-silicon/z80_silicon_cen.v" "$R/z80-silicon/z80s_t80pa.v" "$R/sound/gs.v" \
	"$SIM/tb_gs_storage.v" > vlogcomp.log || { grep ERROR vlogcomp.log; exit 1; }
fuse -top work.tb_gs_storage -o tb_gs_storage.exe > fuse.log || { grep ERROR fuse.log; exit 1; }
echo "run all; quit" > run.tcl
./tb_gs_storage.exe -tclbatch run.tcl > tb_gs_storage.log 2>&1 || true
grep -E "ERROR|tb_gs_storage" tb_gs_storage.log | head -20
grep -q "tb_gs_storage: 0 errors" tb_gs_storage.log || { echo "tb_gs_storage FAILED"; exit 1; }
