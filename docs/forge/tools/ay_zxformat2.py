#!/usr/bin/env python3
"""Capture the supplied ZX-Format 2 intro's AY writes and replay the two CE phases.

Requires Fuse SDL 1.6.0 for capture, prepared/elaborated Forge sources for replay,
and numpy for WAV comparison. No user media or production sources are modified.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import wave

import forge
from paths import CORE_ROOT, core_path

DISK_SHA256 = '484a0195fd6a34bca5098f78101ef7d67a663e28d41ab362d7e0f17a8c711a01'
DEBUGGER = '''breakpoint port write 0xfd
commands 1
print 0xabcdef
print spectrum:frames
print ula:tstates
print z80:pc
print z80:af
print z80:bc
print z80:de
print z80:hl
print [z80:pc-2]
print [z80:pc-1]
print [z80:hl]
continue
end
breakpoint time 0 if spectrum:frames >= 1300
commands 2
exit
end'''


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def capture(disk, work):
    if sha(disk) != DISK_SHA256:
        raise ValueError('This extractor is specific to the supplied ZX-FORM2.TRD hash.')
    out = work / 'fuse-intro'
    out.mkdir(parents=True, exist_ok=True)
    trd = disk.read_bytes()
    memory = bytearray(65536)
    # Loader in FORM2n_m: CALL 5DF5 with HL=9C40 and B=47, then CALL 9C40.
    # Its BASIC part starts at sector 41; executable payload starts at sector 43.
    intro = trd[43 * 256:(43 + 0x47) * 256]
    memory[0x9c40:0x9c40 + len(intro)] = intro
    memory[0x5d3b:0x5d3b + 259] = trd[41 * 256:41 * 256 + 259]
    memory[0x61a5:0x61a9] = bytes.fromhex('40 9c 00 60')
    memory[0x6000:0x6004] = bytes.fromhex('f3 76 18 fd')
    header = bytearray(27)
    header[0] = 0x3f
    header[15:17] = (0x5c3a).to_bytes(2, 'little')
    header[23:25] = (0x61a5).to_bytes(2, 'little')
    header[25] = 1
    (out / 'intro.sna').write_bytes(header + memory[16384:])
    (out / 'intro-packed.bin').write_bytes(intro)
    (out / 'debugger.txt').write_text(DEBUGGER)
    args = ['stdbuf', '-oL', '-eL', 'fuse-sdl', '--no-autosave-settings',
            '--no-sound', '--speed', '10000', '--machine', '48',
            '--debugger-command', DEBUGGER, '--record', str(out / 'capture.rzx'),
            '--snapshot', str(out / 'intro.sna')]
    with (out / 'ports.log').open('w') as log:
        subprocess.run(args, cwd=out, check=True, timeout=90,
                       env=dict(os.environ, SDL_VIDEODRIVER='dummy', SDL_AUDIODRIVER='dummy'),
                       stdout=log, stderr=subprocess.STDOUT)
    (out / 'provenance.json').write_text(json.dumps({
        'disk_sha256': sha(disk), 'intro_sha256': sha(out / 'intro-packed.bin'),
        'ports_log_sha256': sha(out / 'ports.log'),
        'method': 'Unchanged extracted intro; 48K SNA entry at 9C40; disk loader bypassed.',
    }, indent=2) + '\n')


def parse_trace(work):
    log = work / 'fuse-intro/ports.log'
    provenance = json.loads((log.parent / 'provenance.json').read_text())
    if provenance['ports_log_sha256'] != sha(log) or provenance['disk_sha256'] != DISK_SHA256:
        raise ValueError('Capture provenance mismatch')
    rows = []
    register_values = {r: set() for r in range(11)}
    selected = None
    for block in log.read_text().split('0xabcdef\n')[1:]:
        frame, ts, pc, af, bc, de, hl, op1, op2, data = [
            int(line, 16) for line in block.splitlines()[:10]]
        if (op1, op2) == (0xed, 0x79) and bc == 0xfffd:
            data = af >> 8
            selected = data
        elif (op1, op2) == (0xed, 0xab) and bc == 0xbefd:
            # Fuse's callback sees B already decremented, but HL not yet decremented.
            register_values[selected].add(data)
        else:
            raise ValueError(f'Unexpected I/O instruction at {pc:04x}')
        rows.append((8 * (frame * 69888 + ts), bc, data))
    if len(rows) != 27918 or any(rows[i][0] >= rows[i + 1][0] for i in range(len(rows) - 1)):
        raise ValueError('Incomplete or non-monotonic capture')
    start = rows[0][0] - 256
    (work / 'trace.txt').write_text(''.join(f'{t-start} {p:04x} {d:02x}\n' for t, p, d in rows))
    return rows[-1][0] - start + 559104, {str(r): sorted(v) for r, v in register_values.items()}


def replay(work, prepared):
    cycles, registers = parse_trace(work)
    forge.OUT = prepared
    sources = json.loads((prepared / 'simulation_sources.json').read_text())
    sources.append(str(CORE_ROOT / 'tests/tb_ay_trace.v'))
    obj = work / 'verilator_trace'
    forge.run([forge.HDL / 'bin/verilator', '--binary', '--timing', '-j', '2',
               '-Wno-fatal', '-CFLAGS', '-O3', '--top-module', 'tb_ay_trace', '--Mdir', obj,
               '-I.', '-Iupstream/modules/rtl/mcu', '-Iupstream/tsconf/rtl/vg93', *sources],
              logfile=work / 'trace-compile.log')
    result = forge.run([obj / 'Vtb_ay_trace', f'+trace={work}/trace.txt',
                       f'+pcm={work}/trace.pcm', f'+cycles={cycles}'],
                      logfile=work / 'trace-replay.log')
    if 'PASS trace consumed 27918 writes' not in result:
        raise RuntimeError('Replay did not consume the complete capture')
    print(result.strip())
    return registers


def cpu_intro(work, prepared):
    parse_trace(work)
    memory = (work / 'fuse-intro/intro.sna').read_bytes()[27:]
    (work / 'intro-ram.hex').write_text(''.join(f'{byte:02x}\n' for byte in memory))
    forge.OUT = prepared
    sources = json.loads((prepared / 'simulation_sources.json').read_text())
    sources += [str(CORE_ROOT / 'tests' / f) for f in
                ('tb_zxformat2.v', 'sdram_model.v', 'sram_model.v')]
    obj = work / 'verilator_intro_checked'
    forge.run([forge.HDL / 'bin/verilator', '--binary', '--timing', '-j', '2',
               '-Wno-fatal', '-CFLAGS', '-O3', '--top-module', 'tb_zxformat2', '--Mdir', obj,
               '-I.', '-Iupstream/modules/rtl/mcu', '-Iupstream/tsconf/rtl/vg93', *sources],
              logfile=work / 'intro-checked-compile.log')
    result = forge.run([obj / 'Vtb_zxformat2', f'+ram={work}/intro-ram.hex',
                       f'+trace={work}/trace.txt'], logfile=work / 'intro-checked.log')
    if 'PASS intro: 660 writes match Fuse' not in result:
        raise RuntimeError('Actual intro test incomplete')
    (work / 'intro-result.json').write_text(json.dumps({
        'passed': True, 'writes_compared': 660, 'cpu_speed_asserted_mhz': 3.5,
        'speaker_covox_silent': True, 'gs_held_reset': True,
        'testbench_sha256': sha(CORE_ROOT / 'tests/tb_zxformat2.v'),
        'log_sha256': sha(work / 'intro-checked.log'),
        'trace_sha256': sha(work / 'trace.txt'),
        'limits': 'First 30 updates only; diagnostic boot and direct RAM deposit; no disk loader, ERS state, full intro or physical hardware.',
    }, indent=2) + '\n')
    print(result[-700:])


def analyze(work):
    import numpy as np
    cycles, registers = parse_trace(work)
    result = (work / 'trace-replay.log').read_text()
    if 'PASS trace consumed 27918 writes' not in result:
        raise ValueError('Replay incomplete')
    raw = np.fromfile(work / 'trace.pcm', dtype='<i2')
    if raw.size != (cycles // 636) * 4:
        raise ValueError('Unexpected PCM length')
    pcm = raw.reshape(-1, 4)
    # FPGA bus clock / decimation. WAV headers need an integer sample rate.
    rate = round((28_030_303 / 636))
    for name, columns in [('baseconf', slice(0, 2)), ('tsconf-phase', slice(2, 4))]:
        with wave.open(str(work / f'{name}-replay.wav'), 'wb') as wav:
            wav.setparams((2, 2, rate, 0, 'NONE', 'not compressed'))
            wav.writeframes(pcm[:, columns].astype('<i2').tobytes())
    x = pcm.astype(float)
    delta = x[:, :2] - x[:, 2:]
    metrics = {
        'writes': 27918, 'register_updates': 1269, 'samples_per_channel': len(x),
        'sample_rate': rate, 'duration_seconds': len(x) / rate,
        'max_absolute_sample_difference': float(abs(delta).max()),
        'difference_rms': float(np.mean(delta ** 2) ** .5),
        'signal_ac_rms': float(np.std(x[:, :2], axis=0).mean()),
        'correlation_left': float(np.corrcoef(x[:, 0], x[:, 2])[0, 1]),
        'correlation_right': float(np.corrcoef(x[:, 1], x[:, 3])[0, 1]),
        'register_values': registers, 'trace_sha256': sha(work / 'trace.txt'),
        'pcm_sha256': sha(work / 'trace.pcm'),
        'testbench_sha256': sha(CORE_ROOT / 'tests/tb_ay_trace.v'),
        'limits': 'Same captured bus stimulus; source-identical PSG/mixer with actual decoder/CE differences. Not a full TSConf machine, routed timing, GS, other mixer inputs or physical-output test.',
    }
    # A full-scale mismatch must not be silently called a passing comparison.
    metrics['phase_comparison_passed'] = metrics['difference_rms'] < 5 and metrics['max_absolute_sample_difference'] < 64
    (work / 'trace-result.json').write_text(json.dumps(metrics, indent=2) + '\n')
    print(json.dumps({k: v for k, v in metrics.items() if k != 'register_values'}, indent=2))
    if not metrics['phase_comparison_passed']:
        raise RuntimeError('CE-phase output difference exceeds the diagnostic bound')


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('action', choices=['capture', 'cpu-intro', 'replay', 'analyze', 'all'])
    p.add_argument('--disk', type=Path)
    p.add_argument('--build-dir', default='build/ay-zxformat2')
    p.add_argument('--prepared-dir', default='build/ay-zxformat2/minig')
    a = p.parse_args()
    work = core_path(a.build_dir)
    work.mkdir(parents=True, exist_ok=True)
    if a.action in ('capture', 'all'):
        if a.disk is None:
            p.error('--disk is required for capture')
        capture(a.disk.resolve(), work)
    if a.action in ('cpu-intro', 'all'):
        cpu_intro(work, core_path(a.prepared_dir))
    if a.action in ('replay', 'all'):
        replay(work, core_path(a.prepared_dir))
    if a.action in ('analyze', 'replay', 'all'):
        analyze(work)


if __name__ == '__main__':
    main()
