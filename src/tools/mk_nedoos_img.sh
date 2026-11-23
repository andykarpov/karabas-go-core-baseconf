#!/bin/bash
# NedoOS on a virtual HDD of the BaseConf core (OSD Disks: HDD = Image, HDF0 = the image, IDE Nemo master).
#
#   mk_nedoos_img.sh nedoos.zip nedoos.img [size_mb]
#
# nedoos.zip: the NedoOS distribution for ZX Evo (sd_boot.$C, bin/, ini/, ... at its root).
# The image: MBR, one FAT32 partition (type 0x0C, from LBA 2048, hidden sectors 2048) with the files of the zip.
# No root needed (sfdisk, mkfs.fat, mtools).
#
# Boot: put the image on SD1, select it as HDF0, power-cycle the board (ERS keeps the partition list in RAM),
# in the ERS FAT browser select the HDD Nemo master partition and run sd_boot.$C. The kernel asks the ERS
# device manager which volume it was started from and takes E: (partition 1) as the system drive.
# For "B. HDD boot" of ERS run hddfdisk in NedoOS once and press B on the partition (writes zxldr and
# the boot sectors 2..3 of the image).
set -euo pipefail
ZIP="${1:?usage: $0 nedoos.zip out.img [size_mb]}"
OUT="${2:?usage: $0 nedoos.zip out.img [size_mb]}"
SIZE_MB="${3:-256}"
for t in unzip sfdisk mkfs.fat mcopy; do
	command -v "$t" >/dev/null || { echo "$t not found" >&2; exit 1; }
done
TMP="$(mktemp -d)"
trap 'rm -rf -- "${TMP:?}"' EXIT
unzip -q "$ZIP" -d "$TMP"
[ -f "$TMP/sd_boot.\$C" ] || echo "warning: no sd_boot.\$C at the root of $ZIP" >&2
rm -f -- "$OUT"
truncate -s "${SIZE_MB}M" "$OUT"
printf 'label: dos\nstart=2048, type=c, bootable\n' | sfdisk -q "$OUT"
SECT=$(( SIZE_MB * 2048 - 2048 ))
mkfs.fat -F 32 -s 4 -h 2048 -n NEDOOS --offset 2048 "$OUT" $(( SECT / 2 )) >/dev/null
export MTOOLS_SKIP_CHECK=1
for e in "$TMP"/*; do
	mcopy -s -m -Q -i "$OUT@@1M" "$e" ::/
done
mdir -i "$OUT@@1M" ::/
