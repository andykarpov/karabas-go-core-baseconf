#!/usr/bin/env python3
"""Render a repository MOD through the actual GS RTL/stock ROM into a stereo WAV.

Uses project-local Verilator and an SDRAM protocol model, or zero-wait reference
RAM. Runs the stock 2 MB memory check and uploads through GS host ports. This is
simulated audio, not a recording of the physical Karabas DAC.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import wave
sys.dont_write_bytecode = True
from paths import CORE_ROOT as ROOT, HDL_ROOT as HDL, core_path


def environment():
    env = os.environ.copy()
    for name, relative in [('TMPDIR', 'tmp'), ('HOME', 'tmp/home'), ('XDG_CACHE_HOME', 'tmp/cache')]:
        path = ROOT/relative
        path.mkdir(parents=True, exist_ok=True)
        env[name] = str(path)
    env['LD_LIBRARY_PATH'] = str(HDL/'lib/x86_64-linux-gnu')
    env['PYTHONDONTWRITEBYTECODE'] = '1'
    return env


def local_path(value):
    path = core_path(value)
    if not path.is_relative_to(ROOT):
        raise argparse.ArgumentTypeError('Paths must stay inside this project')
    return path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--module', type=local_path, default=ROOT / 'res/media/external.mod', help='Intro text-screen MOD by default')
    parser.add_argument('--mode', choices=['controller', 'reference'], default='controller', help='Actual shared SDRAM path or identical GS with zero-wait RAM')
    parser.add_argument('--storage-source', type=local_path, default=ROOT/'src/rtl', help='Directory containing maintained or archived baseconf_storage.v/baseconf_sdram.v')
    parser.add_argument('--extract-run', type=local_path, help='Extract an exact-length WAV from an existing run with verified upload, without rerunning the simulator')
    parser.add_argument('--seconds', type=int, default=30, help='Playback seconds, 1..60; intro becomes heavier after about 7 and 22 seconds')
    parser.add_argument('--output', type=local_path, required=True, help='New project-local run directory; contains source snapshots, log, PCM and WAV')
    args = parser.parse_args()
    if not 1 <= args.seconds <= 60:
        parser.error('--seconds must be 1..60')
    if args.output.exists():
        parser.error('--output must be a new directory, preserving earlier recordings')
    if args.extract_run:
        source = args.extract_run
        log = (source/'run.log').read_text()
        if 'GS MOD upload verified byte-for-byte' not in log or 'GS playing at' not in log:
            parser.error('Source run has not verified its upload and started playback')
        size = args.seconds*44100*4
        with (source/'audio.pcm').open('rb') as f:
            pcm = f.read(size)
        if len(pcm) != size:
            parser.error(f'Source has only {len(pcm)/176400:.2f} recorded seconds; wait for {args.seconds}')
        args.output.mkdir(parents=True)
        with wave.open(str(args.output/'audio.wav'), 'wb') as wav:
            wav.setparams((2, 2, 44100, 0, 'NONE', 'not compressed'))
            wav.writeframes(pcm)
        shutil.copyfile(source/'provenance.json', args.output/'source-provenance.json')
        (args.output/'source-run.log').write_text(log)
        result = {'source': str(source.relative_to(ROOT)), 'seconds': args.seconds,
                  'description': 'Exact-length playback excerpt after stock memory/warm-reset and byte-for-byte upload checks; no claim that the longer source run finished.',
                  'source_run_finished': 'PASS GS audio' in log,
                  'wav_sha256': hashlib.sha256((args.output/'audio.wav').read_bytes()).hexdigest()}
        (args.output/'provenance.json').write_text(json.dumps(result, indent=2)+'\n')
        print(f'Saved verified-upload {args.seconds}s excerpt: {args.output.relative_to(ROOT)}/audio.wav')
        return
    data = args.module.read_bytes()
    if not 1084 <= len(data) <= 1048576 or data[1080:1084] != b'M.K.':
        parser.error('Expected a four-channel M.K. MOD of at most 1 MiB')
    out = args.output
    out.mkdir(parents=True)
    sources = [ROOT/'build/baseconf/ghdl/gs.v', ROOT/'build/baseconf/ghdl/t80s.v',
               args.storage_source/'baseconf_storage.v', args.storage_source/'baseconf_sdram.v',
               ROOT/'tests/sdram_model.v', ROOT/'tests/tb_gs_audio.v']
    copied = []
    for source in sources:
        dest = out/source.name
        shutil.copyfile(source, dest)
        copied.append(dest)
    rom = (ROOT/'build/baseconf/roms/gs105b.rom').read_bytes()
    for name, contents in [('rom.hex', rom), ('module.hex', data)]:
        (out/name).write_text(''.join(f'{b:02x}\n' for b in contents))
    record = {'mode': args.mode, 'seconds': args.seconds, 'module': str(args.module.relative_to(ROOT)),
              'module_sha256': hashlib.sha256(data).hexdigest(), 'rom_sha256': hashlib.sha256(rom).hexdigest(),
              'sources_sha256': {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in copied}}
    (out/'provenance.json').write_text(json.dumps(record, indent=2)+'\n')
    print('Compiling GS audio harness...', flush=True)
    compile_cmd = [HDL/'bin/verilator', '--binary', '--timing', '-j', '2', '-Wno-fatal', '-CFLAGS', '-O3',
               '--top-module', 'tb_gs_audio', f'-GREFERENCE={int(args.mode=="reference")}',
               *(['+define+GS_LOCALMEM'] if 'gs_local' in (args.storage_source/'baseconf_storage.v').read_text() else []),
               '--Mdir', out/'obj', *copied]
    with (out/'compile.log').open('w') as log:
        result = subprocess.run([str(x) for x in compile_cmd], cwd=out, env=environment(), stdout=log, stderr=subprocess.STDOUT)
    if result.returncode:
        raise SystemExit(f'Compile failed; inspect {out.relative_to(ROOT)}/compile.log')
    print('Running stock GS boot, memory check, MOD upload and playback...', flush=True)
    cmd = [str(out/'obj/Vtb_gs_audio'), f'+rom={out/"rom.hex"}', f'+module={out/"module.hex"}',
           f'+size={len(data)}', f'+pcm={out/"audio.pcm"}', f'+seconds={args.seconds}']
    with (out/'run.log').open('w') as log:
        result = subprocess.run(cmd, cwd=out, env=environment(), stdout=log, stderr=subprocess.STDOUT)
    if result.returncode or 'PASS GS audio' not in (out/'run.log').read_text():
        raise SystemExit(f'GS run failed; inspect {out.relative_to(ROOT)}/run.log')
    with wave.open(str(out/'audio.wav'), 'wb') as wav:
        wav.setparams((2, 2, 44100, 0, 'NONE', 'not compressed'))
        wav.writeframes((out/'audio.pcm').read_bytes())
    record['wav_sha256'] = hashlib.sha256((out/'audio.wav').read_bytes()).hexdigest()
    record['result'] = (out/'run.log').read_text().split('PASS GS audio:')[-1].splitlines()[0].strip()
    (out/'provenance.json').write_text(json.dumps(record, indent=2)+'\n')
    print(f'Saved {out.relative_to(ROOT)}/audio.wav; {record["result"]}')


if __name__ == '__main__':
    main()
