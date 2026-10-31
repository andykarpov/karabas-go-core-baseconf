#!/usr/bin/env python3
"""Extract a Spectrum screen from a BIOS simulation's SRAM dump.

This renders RAM bitmap/attribute bytes using the standard Spectrum palette.
It is a software memory view, not a capture of the FPGA VGA/palette pipeline.
All output is kept inside the project. Python standard library only.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import zlib

ROOT = Path(__file__).resolve().parents[1]


def region(path, start, count):
    result = []
    address = 0
    for line in path.open():
        line = line.split('//')[0]
        for token in line.split():
            if token.startswith('@'):
                address = int(token[1:], 16)
                continue
            if start <= address < start + count:
                if any(c in token.lower() for c in 'xz'):
                    raise ValueError(f'{path}: unknown data at word {address:06x}')
                result.append(int(token, 16))
            address += 1
            if address >= start + count:
                if len(result) != count:
                    raise ValueError(f'{path}: missing bytes in requested region')
                return result
    raise ValueError(f'{path}: dump ends before requested region')


def png(screen, flash_phase):
    rows = bytearray()
    for y in range(192):
        rows.append(0)  # PNG filter: none
        for x in range(256):
            bitmap = screen[((y & 0xc0) << 5) | ((y & 7) << 8) | ((y & 0x38) << 2) | (x >> 3)]
            attr = screen[6144 + (y >> 3) * 32 + (x >> 3)]
            ink = bool(bitmap & (128 >> (x & 7))) ^ bool(flash_phase and attr & 128)
            color = attr & 7 if ink else (attr >> 3) & 7
            level = 255 if attr & 64 else 205
            rows.extend((level if color & 2 else 0, level if color & 4 else 0, level if color & 1 else 0))
    def chunk(kind, data):
        return struct.pack('!I', len(data)) + kind + data + struct.pack('!I', zlib.crc32(kind + data) & 0xffffffff)
    return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('!2I5B', 256, 192, 8, 2, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(rows)) + chunk(b'IEND', b''))


def signature_bytes(screen, rectangles):
    """Bitmap and attributes of rectangles in 8x8 character coordinates."""
    result = bytearray()
    for x, y, width, height in rectangles:
        for scan in range(y * 8, (y + height) * 8):
            offset = ((scan & 0xc0) << 5) | ((scan & 7) << 8) | ((scan & 0x38) << 2)
            result.extend(screen[offset + x:offset + x + width])
        for row in range(y, y + height):
            result.extend(screen[6144 + row * 32 + x:6144 + row * 32 + x + width])
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build', type=Path, default=ROOT / 'build/baseconf', help='Directory containing bios-sram-hi/lo.hex')
    parser.add_argument('--page', type=int, choices=range(256), metavar='0..255', default=5, help='16 KB physical RAM page (default: 5)')
    parser.add_argument('--flash-phase', action='store_true', help='Invert flashing attributes')
    parser.add_argument('--output', type=Path, default=ROOT / 'build/bios-screen', help='Project-local output directory')
    parser.add_argument('--require-menu', action='store_true', help='Require the pinned stock-ROM menu banner, 4096 KB label and menu rectangle signature')
    args = parser.parse_args()
    try:
        args.build = (ROOT / args.build).resolve()
        out = (ROOT / args.output).resolve()
        if not out.is_relative_to(ROOT):
            raise ValueError('Output must stay inside the project')
        high = region(args.build / 'bios-sram-hi.hex', args.page * 8192, 3456)
        low = region(args.build / 'bios-sram-lo.hex', args.page * 8192, 3456)
        screen = bytes(value for pair in zip(high, low) for value in pair)
        out.mkdir(parents=True, exist_ok=True)
        (out / 'screen.json').unlink(missing_ok=True)
        (out / 'screen.scr').write_bytes(screen)
        (out / 'screen.png').write_bytes(png(screen, args.flash_phase))
        metadata = {'ram_page': args.page, 'screen_sha256': hashlib.sha256(screen).hexdigest(),
                    'description': 'SRAM software view with standard Spectrum colors; not captured VGA',
                    'flash_phase': args.flash_phase}
        if args.require_menu:
            expected = json.loads((ROOT / 'config/bios-menu-signature.json').read_text())
            rom_hash = hashlib.sha256((args.build / 'roms/baseconf.rom').read_bytes()).hexdigest()
            digest = hashlib.sha256(signature_bytes(screen, expected['rectangles'])).hexdigest()
            if args.page != 5 or rom_hash != expected['rom_sha256'] or digest != expected['signature_sha256']:
                raise ValueError('Stock-ROM menu signature does not match; inspect the trace and screen')
            metadata['menu_signature'] = digest
            print('PASS BIOS screen: pinned stock menu, 4096 KB banner and menu rectangle')
        (out / 'screen.json').write_text(json.dumps(metadata, indent=2) + '\n')
        print(f'Extracted RAM page {args.page}: {out.relative_to(ROOT)}/screen.png')
    except (OSError, ValueError) as exc:
        parser.exit(1, f'ERROR: {exc}\n')


if __name__ == '__main__':
    main()
