#!/bin/bash
# baseconf_storage on sdram_model (iverilog, a few seconds): the new storage (sdram2p, the OPL4 on port 2)
# (each at three read windows of sdram_model) and the one before (OLD: baseconf_sdram from git HEAD~ of the OPL4 change, for the latency to compare).
# Prints the latencies and "tb_storage: 0 errors" of each; fails on any other count.
set -e
SIM="$(cd "$(dirname "$0")" && pwd)"
R="$(dirname "$SIM")/rtl"
OUT="$SIM/build/storage"
mkdir -p "$OUT"
cd "$OUT"
# the read window at the DQ flip-flops: typical (6 ns), fast and slow corners of the Go (karabas_go.twr)
for SK in 6.0 4.0 8.5; do
	iverilog -g2012 -DSKEW=$SK -DTAC=5.4 -DTOH=3.0 -o tb_new "$SIM/tb_storage.v" "$SIM/sdram_model.v" \
		"$SIM/lib/ODDR2.v" "$R/ram/sdram2p.v" "$R/baseconf_storage.v"
	echo "new, SKEW $SK ns:"; vvp -n tb_new | tee new.log | grep -v "^VCD"
	grep -q "tb_storage: 0 errors" new.log || { echo "tb_storage (new, SKEW $SK) FAILED"; exit 1; }
done
if [ "$1" = "old" ]; then
	git -C "$R" show 7b3f856:src/rtl/baseconf_storage.v > old_storage.v
	git -C "$R" show 7b3f856:src/rtl/baseconf_sdram.v > old_sdram.v
	iverilog -g2012 -DOLD -o tb_old "$SIM/tb_storage.v" "$SIM/sdram_model.v" old_sdram.v old_storage.v
	echo "old:"; vvp -n tb_old | tee old.log
fi
