#!/usr/bin/env python3
"""Prepare, validate and package BaseConf for Karabas GO B4, Mini and Mini G.

Use --board before the command (default: go). Mini artifacts are isolated under
build/baseconf-mini and build/baseconf-minig; the accepted GO path is unchanged.
Machine simulations use an HDMI boundary sink; hdmi-test checks the real HDMI
transport with GHDL/Icarus and the supplied ISE unisim clock models.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
sys.dont_write_bytecode = True

from paths import CORE_ROOT as ROOT, FORGE_ROOT, HDL_ROOT as HDL, core_path
BUILD = ROOT / 'build'
OUT = BUILD / 'baseconf'
BOARD = 'go'
TARGET = 'karabas_go'
EXTENSION = 'kg1'
BASE = ROOT / 'external/zxevo.pentevo/fpga/baseconf/trunk'
TS = FORGE_ROOT / 'external/karabas-go-core-tsconf/src'
MODULES = FORGE_ROOT / 'external/karabas-go-core-tsconf/modules/rtl'


def environment():
    env = os.environ.copy()
    for name, rel in [('TMPDIR', 'tmp'), ('HOME', 'tmp/home'), ('XDG_CACHE_HOME', 'tmp/cache')]:
        path = ROOT / rel
        path.mkdir(parents=True, exist_ok=True)
        env[name] = str(path)
    env['LD_LIBRARY_PATH'] = str(HDL / 'lib/x86_64-linux-gnu')
    env['GHDL_PREFIX'] = str(HDL / 'lib/ghdl/mcode/vhdl')
    env['PYTHONDONTWRITEBYTECODE'] = '1'
    return env


def run(args, cwd=None, logfile=None):
    cwd = OUT if cwd is None else cwd
    if logfile:
        with Path(logfile).open('w') as stream:
            result = subprocess.run([str(x) for x in args], cwd=cwd, env=environment(),
                                    text=True, stdout=stream, stderr=subprocess.STDOUT)
        output = Path(logfile).read_text()
    else:
        result = subprocess.run([str(x) for x in args], cwd=cwd, env=environment(),
                                text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        output = result.stdout
    if result.returncode:
        print(output[-14000:])
        raise RuntimeError(f'Command failed ({result.returncode}): {args}')
    return output


def replace_once(text, old, new):
    if text.count(old) != 1:
        raise RuntimeError(f'Upstream change: expected one occurrence of {old[:100]!r}')
    return text.replace(old, new)


def mini_source(name, text):
    """Explicit Mini-only adaptations; preserve the accepted GO implementation inputs."""
    if name == 'baseconf.v':
        text = replace_once(text, "    assign VGA_BLANK = 1'b0;", '')
        # Match the actual named output regardless of the inherited alignment.
        text, n = re.subn(r'(\.vcsync\s*\(vcsync\s*\),)', r'\1\n        .vblank_out(VGA_BLANK),', text)
        assert n == 1
        start = text.index('    hrdy_fdc fdc(')
        end = text.index('    reg [2:0] sound_div', start)
        text = text[:start] + '''    // Mini boards have no physical drive interface. Leave the I/O bus undriven
    // by an absent FDC and report inactive IRQ/DRQ to the port decoder.
    assign fdc_oe = 1'b0, fdc_oe_n = 1'b1, fdc_data = 8'h00;
    assign fdc_side = 1'b1, fdc_wg = 1'b0, fdc_wr_data = 1'b0;
    assign fdc_step = 1'b0, fdc_dir = 1'b0, fdc_motor = 1'b0, fdc_ds = 2'b00;
''' + text[end:]
    elif name == 'video_top.v':
        text = replace_once(text, 'output wire        vcsync,', 'output wire        vcsync,\n    output reg vblank_out = 1\'b1,')
        text = replace_once(text, 'wire [5:0] vga_color;', 'wire [5:0] vga_color;\n    wire vga_blank;\n    always @(posedge clk) vblank_out <= vga_on ? vga_blank : (hblank | vblank);')
        text = replace_once(text, '.pix_in(color),', '.pix_in(color),\n        .blank_in(hblank | vblank), .blank_out(vga_blank),')
    elif name == 'video_vga_double.v':
        text = replace_once(text, 'input  wire [ 5:0] pix_in,', 'input  wire [ 5:0] pix_in,\n    input wire blank_in,\n    output reg blank_out = 1\'b1,')
        text = replace_once(text, 'pix_out <= data_out[5:0];', "begin pix_out <= data_out[5:0]; blank_out <= data_out[6]; end")
        text = replace_once(text, "pix_out <= 6'd0;", "begin pix_out <= 6'd0; blank_out <= 1'b1; end")
        text = replace_once(text, ".wrdata({2'b00,pix_in})", ".wrdata({1'b0,blank_in,pix_in})")
        # The RAM read is synchronous. Gate the output by the previous address's
        # validity, not the new address (which exposes stale blank bits at line start).
        text = replace_once(text, '//read data', "reg read_valid = 1'b0;\n    always @(posedge clk) read_valid <= ptr_out[9:8]!=2'b11;\n\t//read data")
        start = text.index('//read data')
        text = text[:start] + replace_once(text[start:], "if( ptr_out[9:8]!=2'b11 )", 'if( read_valid )')

    elif name == 'hdmi_pll.v':
        # Program only a complete command after a valid measured FT frequency.
        # Source switches and global reset must not restart a command mid-shift.
        start = text.index('// detect freq change')
        end = text.index('// programming data', start)
        text = text[:start] + """// Defined startup and one complete programming transaction per frequency.
reg [7:0] prev_hdmi_freq = 0;
reg prev_vdac2_sel = 0;
reg program_start = 0;
always @(posedge clk_ref) begin
    program_start <= 0;
    prev_vdac2_sel <= vdac2_sel;
    if (reset) begin
        prev_hdmi_freq <= 0;
        prev_vdac2_sel <= 0;
    end else if (vdac2_sel && prog_done && !(|prog_en) &&
                 hdmi_freq != 8'd28 && prev_hdmi_freq != hdmi_freq) begin
        program_start <= 1;
        prev_hdmi_freq <= hdmi_freq;
    end
end

""" + text[end:]
        text = text.replace('reg [24:0] prog_data, prog_en;', 'reg [24:0] prog_data = 0, prog_en = 0;')
        text = replace_once(text, 'if (hdmi_reset) begin',
                            'if (reset) begin\n        prog_data <= 0; prog_en <= 0;\n    end else if (program_start) begin')
        text = replace_once(text, '(vdac2_sel) ? (~locked_dcm || reset) : (hdmi_reset || reset)',
                            'reset || (prev_vdac2_sel != vdac2_sel) || program_start || '
                            '(vdac2_sel && (!locked_dcm || !prog_done || (|prog_en) || prev_hdmi_freq != hdmi_freq))')
    elif name == 'pll_reset.v':
        # Hold reset continuously while requested, then stretch for eight cycles.
        # The upstream second independent if could override a held reset request.
        text = replace_once(text, 'if (pll_rst_cnt > 0)', 'else if (pll_rst_cnt > 0)')
    return text


def mini_top(text):
    """Reuse the maintained machine/MCU/OSD body, with reference Mini pin interfaces."""
    reference = (TS / f'rtl/{TARGET}_top.v').read_text()
    header_end = reference.index('\n);') + len('\n);')
    body = text[text.index('   );') + len('   );'):]
    # No GO physical floppy pins or DAC bus drivers on either Mini.
    body = re.sub(r'\s*\.fdc_\w+\(FDC_\w+\),', '', body)
    body = body.replace('baseconf machine (', "baseconf machine (\n        .fdc_rdata(1'b0), .fdc_wprt(1'b1), .fdc_tr00(1'b0), .fdc_index(1'b0),\n        .VGA_BLANK(video_blank),")
    body = body.replace('wire video_hsync;', 'wire video_hsync;\n    wire video_blank;')
    body = body.replace("\tassign BEEPER = audio_beeper;", '')
    start = body.index('// FT812 and FPGA share')
    end = body.index('assign espcs_in', start)
    body = body[:start] + body[end:]
    body = re.sub(r'^assign FT_OE_N.*\n', '', body, flags=re.M)
    body = body.replace('MCU_SPI_IO[0]', 'MCU_IO[1]').replace('MCU_SPI_IO[1]', 'MCU_IO[0]')
    body = body.replace('MCU_SPI_FT_CS_N', 'MCU_IO[3]').replace('MCU_SPI_SD2_CS_N', 'MCU_IO[2]')
    body = body.replace('.BURST_MAX_MHZ(1)', '.BURST_MAX_MHZ(0)' if BOARD == 'mini' else '.BURST_MAX_MHZ(1)')
    body = body.replace('// MCU_SPI_IO[1] is input-only (burst chip select), so it has no FPGA driver.', '// MCU_IO[0] is the input-only burst chip select.')
    body = body.replace('// burst transfers: firmware IO0 (GPIO14) = MCU_IO[0] (M11), IO1 (GPIO2) = MCU_IO[1] (N9)', '// Mini firmware: IO0 = burst chip select, IO1 = ready.')
    start = body.index('//---------- DAC')
    end = body.index('//--------- OSD', start)
    if BOARD == 'minig':
        body = re.sub(r'^\s*assign ESP_(RESET|BOOT)_N.*\n', '', body, flags=re.M)
        body = re.sub(r'\s*// midi clk\s*ODDR2 u_midi_clk \(.*?\);', '', body, flags=re.S)
        body = body.replace('.midi_reset_n(MIDI_RESET_N)', '.midi_reset_n()')
        # Recompute offsets after removing assignments above.
        start = body.index('//---------- DAC'); end = body.index('//--------- OSD', start)
        dac = '''kg_pcm5102 #(.DIV_BITS(2)) PCM5102(
    .clk(clk_bus), .reset(areset), .left(audio_out_l), .right(audio_out_r),
    .din(DAC_DAT), .bck(DAC_BCK), .lrck(DAC_WS));
assign ESP32_SPI_CS_N = 1'b1;
'''
        # Same global SCK routing and raw FT passthrough as the Mini G reference.
        body = body.replace('.MCU_SCK(MCU_SCK)', '.MCU_SCK(mcu_sck)')
        body = body.replace('mcu_ft_spi_on ? mcu_ft_sck : ftclk', 'mcu_ft_spi_on ? mcu_sck_ibufg : ftclk')
        clocks = '''wire mcu_sck_ibufg, mcu_sck;
IBUFG ibufg_mcu_sck(.I(MCU_SCK), .O(mcu_sck_ibufg));
BUFG bufg_mcu_sck(.I(mcu_sck_ibufg), .O(mcu_sck));
'''
    else:
        dac = '''kg_sigma_delta_dac #(.MSBI(15)) dac_l(.clk(clk_bus), .reset(areset),
    .din({~audio_out_l[15],audio_out_l[14:0]}), .dout(AUDIO_L));
kg_sigma_delta_dac #(.MSBI(15)) dac_r(.clk(clk_bus), .reset(areset),
    .din({~audio_out_r[15],audio_out_r[14:0]}), .dout(AUDIO_R));
'''
        body = body.replace('.FT_RESET()', '.FT_RESET(mcu_ft_reset)')
        clocks = "wire mcu_ft_reset;\nassign FT_RESET = ~mcu_ft_reset;\n"
    # Offsets must be computed after all substitutions.
    start = body.index('//---------- DAC'); end = body.index('//--------- OSD', start)
    body = body[:start] + dac + '\n' + body[end:]
    hdmi = '''
// Unused ADC interface: no clock drive or contention with an external master.
assign ADC_CLK = 1'b0;
assign ADC_BCK = 1'bZ;
assign ADC_LRCK = 1'bZ;
ODDR2 u_ft_clk(.Q(FT_CLK_OUT), .C0(clk_8mhz), .C1(~clk_8mhz), .CE(1'b1),
    .D0(1'b1), .D1(1'b0), .R(1'b0), .S(1'b0));
wire ft_clk_ibufg, ft_clk_int;
IBUFG ibufg_ft_clk(.I(FT_CLK), .O(ft_clk_ibufg));
BUFG bufg_ft_clk(.I(ft_clk_ibufg), .O(ft_clk_int));
hdmi_top #(.SAMPLERATE(SAMPLE_RATE), .CLKRATE(28030303)) hdmi_top(
    .clk(ft_clk_int), .clk_ref(clk_bus), .clk_ref_pll(pll_clk[2]), .clk_8(clk_8mhz),
    .reset(areset || kb_reset || hw_btn[0]),
    .vga_rgb({osd_r,osd_g,osd_b}), .vga_hs(video_hsync), .vga_vs(video_vsync), .vga_de(~video_blank),
    .ft_rgb({VGA_R,VGA_G,VGA_B}), .ft_hs(VGA_HS), .ft_vs(VGA_VS), .ft_de(FT_DE),
    .ft_sel(ft_video_active), .audio_en(1'b1), .audio_l(audio_out_l), .audio_r(audio_out_r),
    .tmds_p(TMDS_P), .tmds_n(TMDS_N), .freq());
'''.replace('SAMPLE_RATE', '48000' if BOARD == 'minig' else '44100')
    return reference[:header_end] + body.replace('endmodule', clocks + hdmi + '\nendmodule')


def coremode_constraints():
    """Second STA mode, following pinned TSConf pcf_core.py without changing route."""
    drop = re.compile(r'^(TS_CLKGEN|TS_BUS_TO_PIX|TS_hdmi_top_hdmi_pll_(clkgen|clk0|clkfx|clkfx180)(_1)?)$')
    source = (OUT / f'{TARGET}.pcf').read_text()
    result, removed = [], []
    for match in re.finditer(r'(?ms)^(\S+) = (?:PERIOD|MAXDELAY).*?;\n|^.*?\n', source):
        name = match[0].split(' ', 1)[0]
        if match[1] and drop.match(name):
            removed.append(name)
        else:
            result.append(match[0])
    if not {'TS_CLKGEN', 'TS_BUS_TO_PIX'}.issubset(removed):
        raise RuntimeError('Missing FT timing constraints in PCF; cannot certify core mode.')
    (OUT / f'{TARGET}_core.pcf').write_text(''.join(result))
    (OUT / 'coremode-removed.json').write_text(json.dumps(removed, indent=2) + '\n')


def prepare():
    for resource in json.loads((ROOT / 'res/manifest.json').read_text())['resources']:
        path = ROOT / resource['path']
        if hashlib.sha256(path.read_bytes()).hexdigest() != resource['sha256']:
            raise RuntimeError(f'Resource checksum mismatch: {resource["path"]}')
    OUT.mkdir(parents=True, exist_ok=True)
    for entry in json.loads((ROOT / 'config/sources.lock.json').read_text())['repositories']:
        path = (FORGE_ROOT if entry.get('scope') == 'forge' else ROOT) / entry['path']
        actual = run(['git', '-C', path, 'rev-parse', 'HEAD'], cwd=ROOT).strip()
        if actual != entry['revision']:
            raise RuntimeError(f'{entry["path"]}: revision differs from sources.lock.json')
    if not (MODULES / 'mcu/kg_mcu.v').exists():
        raise RuntimeError('Missing pinned modules. Run tools/bootstrap.py sources.')
    files = []
    def put(source, rel, change=None):
        dest = OUT / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        try:
            text = source.read_text()
        except UnicodeDecodeError:
            text = source.read_text(encoding='cp1251')
        # Includes in the references are relative to source directories; normalize only
        # tune.v. The MCU and FDC headers remain in their include search paths.
        text = re.sub(r'`include "[^"\n]*tune.v"', '`include "baseconf_tune.vh"', text)
        if change:
            text = change(text)
        if BOARD != "go":
            text = mini_source(source.name, text)
        dest.write_text(text)
        if dest.suffix in ('.v', '.vhd'):
            files.append(dest.relative_to(OUT).as_posix())

    def zports(text):
        text = replace_once(text, 'output wire        external_port', 'output wire shadow_out,\n\toutput wire        external_port') if 'output wire        external_port' in text else text
        if 'output wire shadow_out' not in text:
            text = text.replace('module zports(', 'module zports(output wire shadow_out,')
        text = text.replace('always @(posedge zclk, negedge rst_n)', 'always @(posedge fclk, negedge rst_n)')
        # Gate only the three registers originally clocked by zclk.
        text = text.replace("else if( (a[15]==1'b0) && portfd_wr", "else if( zpos && (a[15]==1'b0) && portfd_wr")
        text = text.replace("else if( !a[12] && portf7_wr", "else if( zpos && !a[12] && portf7_wr")
        text = text.replace('always @(posedge zclk)', 'always @(posedge fclk) if (zpos)')
        # Infer registers instead of the three transparent IDE trigger latches.
        text = text.replace('always @* if( rd_n )', 'always @(posedge fclk) if( rd_n )')
        text = text.replace('always @* if( wr_n )', 'always @(posedge fclk) if( wr_n )')
        # Reset and clock branches of each register must use the same NBA semantics.
        text = re.sub(r'\b(atm_scr_mode|atm_turbo|atm_pen|atm_cpm_n|atm_pen2)(\s*)=(?!=)', r'\1\2<=', text)
        # Supplied ROM uses the newer base_trdemu/newirq register map at xxBD.
        # Keep the old xxBE read alias, but BE writes remain NMI exit only.
        text = replace_once(text, 'ZXEVBE: begin', 'ZXEVBE, ZXEVBRK: begin')
        text = replace_once(text, 'if( zxevbrk_wr_fclk)', "if( zxevbrk_wr_fclk && a[12:9]==4'h8 )")
        # This port has physical drives only; do not claim AVR virtual-drive slots.
        text = replace_once(text, "5'h12: portbemux = wrdisables;", "5'h12: portbemux = wrdisables;\n\t5'h13: portbemux = 8'h00; // physical FDC only")
        return text.replace('endmodule', 'assign shadow_out = shadow;\nendmodule')

    def zclock(text):
        # These power-up initial values synthesize in Spartan-6 as INIT attributes.
        text = text.replace('`ifdef SIMULATE\n\tinitial // simulation...', 'initial // Spartan-6 power-up values')
        text = replace_once(text, "\t\tzclk_out = 1'b0;\n\tend\n`endif", "\t\tzclk_out = 1'b0;\n\tend")
        return text

    def zmem(text):
        # The old transparent read latch uses cpu_strobe as a fabric clock.
        # Preserve its transparent window with a bypass; retain the completed
        # word on the next fclk edge, when the synchronous strobe falls.
        text = replace_once(text, 'always @* if( cpu_strobe ) // WARNING! ACHTUNG! LATCH!!!',
                            'always @(posedge fclk) if( cpu_strobe )')
        return replace_once(text, 'assign zd_out = cpu_wrbsel ? rd_buf[7:0] : rd_buf[15:8];',
                            'wire [15:0] read_word = cpu_strobe ? cpu_rddata : rd_buf;\n'
                            '\tassign zd_out = cpu_wrbsel ? read_word[7:0] : read_word[15:8];')

    for folder in ('z80', 'mem', 'video', 'spihub', 'common', 'dram'):
        for src in sorted((BASE / folder).glob('*.v')):
            if src.name in ('dram.v', 'zkbdmus.v', 'zwait.v', 'video_fontrom.v'):
                continue
            change = {'zports.v': zports, 'zclock.v': zclock, 'zmem.v': zmem,
                      'zdos.v': lambda s: s.replace("dos = 1'b1;", "dos <= 1'b1;"),
                      'atm_pager.v': lambda s: s.replace('`ifdef SIMULATE', '').replace('`endif', ''),
                      'zint.v': lambda s: s.replace("1'bZ", "1'b1").replace('`ifdef SIMULATE', '').replace('`endif', '')}.get(src.name)
            put(src, 'upstream/baseconf/' + folder + '/' + src.name, change)

    # Exact shared sources from TSConf's B4 project, excluding its machine/video,
    # GS SDRAM wrapper, optional OPL/SAA/UART, old BIOS and old board top.
    project_lines = (TS / 'karabas_go.prj').read_text().splitlines()
    if BOARD != 'go':
        project_lines += (TS / f'{TARGET}.prj').read_text().splitlines()
    for line in dict.fromkeys(project_lines):
        match = re.fullmatch(r'(verilog|vhdl) work "(.+)"', line)
        if not match:
            continue
        name = match[2]
        if name.startswith('../modules/'):
            source = TS / name
            rel = 'upstream/modules/' + name.split('../modules/')[1]
        elif (BOARD != 'go' and name.startswith('rtl/hdmi/')) or name.startswith('rtl/T80/') or name.startswith('rtl/sound/jt12/') or name.startswith('rtl/vg93/') or name in (
                'rtl/sound/gs.v', 'rtl/sound/turbosound.v', 'rtl/sound/ym2149.v',
                'rtl/sound/audio_mixer.v', 'rtl/mcu/hid_parser.vhd', 'rtl/mcu/usb_ps2_keybuf.v', 'rtl/bus_ce.v'):
            source = TS / name
            rel = 'upstream/tsconf/' + name
        else:
            continue
        def gs(s):
            s, n = re.subn(r'input wire\s+CE,', 'input wire CE,\n    input wire MEM_WAIT_n,', s)
            assert n == 1
            s = s.replace("(1'b1),\n\t.INT_n", '(MEM_WAIT_n),\n\t.INT_n')
            s = s.replace('.WAIT_n', ".OUT0(1'b0),\n\t.WAIT_n")
            # Bank address must be valid immediately when a memory request appears.
            s = re.sub(r'\n\t\tcase \(cpu_a_bus\[15:14\]\).*?\n\t\tendcase', '', s, flags=re.S)
            s = s.replace('assign MA = {mem, cpu_a_bus[13:0]};', '''always @* case (cpu_a_bus[15:14])
        2'b00: mem = 7'd0;
        2'b01: mem = 7'd2;
        default: mem = {port_xx00_reg,cpu_a_bus[14]};
    endcase
    assign MA = {mem, cpu_a_bus[13:0]};''')
            s = s.replace('cpu_a_bus[15:13] == 3)', 'cpu_a_bus[15:13] == 3 && MEM_WAIT_n)')
            return s
        change = gs if source.name == 'gs.v' else None
        if source.name == 'hid_parser.vhd':
            def hid_sega(s):
                # Append mode 6 without renumbering saved joystick selections.
                mapping = [('UP', 'Q'), ('DOWN', 'A'), ('LEFT', 'O'), ('RIGHT', 'P'),
                           ('A', 'Z'), ('B', 'X'), ('C', 'C'),
                           ('X', 'S'), ('Y', 'D'), ('Z', 'F'),
                           ('START', '0'), ('MODE', '9')]
                lines = ['\t\t\t\t-- SEGA: all twelve controls as Spectrum keys']
                for side in ('l', 'r'):
                    lines.append(f'\t\t\t\tif joy_type_{side} = "110" then')
                    for button, key in mapping:
                        lines.append(f"\t\t\t\t\tif joy_{side}(SC_BTN_{button}) = '1' then kb_data(ZX_K_{key}) <= '1'; end if;")
                    lines.append('\t\t\t\tend if;')
                marker = '\t\t\t\t-- sinclair 1'
                return replace_once(s, marker, '\n'.join(lines) + '\n\n' + marker)
            change = hid_sega
        if source.name == 'kg_osd_overlay.v':
            def osd_position(s):
                s = replace_once(s, 'input wire vsync_i,', 'input wire vsync_i,\n\tinput wire [10:0] v_offset,')
                return replace_once(s, '- V_OFFSET;', '- v_offset;')
            change = osd_position
        if source.name == 'turbosound.v':
            change = lambda s: s.replace('.ay_mode(AY_MODE),', ".ay_mode(AY_MODE),\n    .IOA_in(8'hff), .IOB_in(8'hff),")
        if source.name == 'hrdy_fdc.v':
            # Free-running counters need defined FPGA INITs as well as defined
            # four-state simulation startup; no disk/command behavior is bypassed.
            change = lambda s: s.replace('reg [2:0] f;', "reg [2:0] f = 3'd0;").replace(
                'reg [4:0] fa;', "reg [4:0] fa = 5'd0;")
        if source.name == 'vg93_host_bus.v':
            def fdc_host(s):
                s = replace_once(s, "reg wr_prev = 1'b0;", "reg wr_prev = 1'b0;\n    reg [1:0] wr_addr = 0;")
                s = replace_once(s, 'if (wr) dal_in <= dal_q;', 'if (wr) begin dal_in <= dal_q; wr_addr <= addr_q; end')
                # The next 14 MHz CPU address can arrive before the 8 MHz
                # receiver observes /WE release. Capture address with the data.
                return replace_once(s, 'case (addr_q)', 'case (wr_addr)')
            change = fdc_host
        put(source, rel, change)

    for src in sorted((TS / 'rtl/vg93').glob('*.vh')):
        put(src, 'upstream/tsconf/rtl/vg93/' + src.name)
    for src in sorted((MODULES / 'mcu').glob('*.vh')):
        put(src, 'upstream/modules/rtl/mcu/' + src.name)
    shutil.copyfile(ROOT / 'res/microcode/vg93-microcode-rom.hex', OUT / 'vg93-microcode-rom.hex')
    for src in sorted((ROOT / 'src/rtl').glob('*.v')):
        put(src, 'rtl/' + src.name)
    if BOARD != 'go':
        # Board wrapper is generated from the maintained GO body and reference pin interface.
        files.remove('rtl/karabas_go_top.v')
        put(ROOT / 'src/rtl/karabas_go_top.v', f'rtl/{TARGET}_top.v', mini_top)
    (OUT / 'baseconf_tune.vh').write_text('// BaseConf build options (no simulation-only behavior).\n')
    font = (ROOT / 'res/fonts/atm.fnt').read_bytes()
    if len(font) != 2048:
        raise RuntimeError('Font must have exactly 2048 bytes')
    (OUT / 'atm_font.hex').write_text('\n'.join(f'{b:02x}' for b in font) + '\n')
    # Port pin locations from the known GO wrapper; timing is maintained separately.
    pins = (TS / f'{TARGET}.ucf').read_text().split('# Timing constraints.')[0]
    timing = (ROOT / 'src/constraints/timing.ucf').read_text()
    if BOARD != 'go':
        timing += '# ---- Mini, Mini G: FT812 and HDMI' + (TS / f'{TARGET}.ucf').read_text().split('# ---- Mini, Mini G: FT812 and HDMI')[1].split('# ---- Mini G: ESP32 I2S')[0]
    (OUT / f'{TARGET}.ucf').write_text(pins + timing)
    (OUT / 'sources.json').write_text(json.dumps(files, indent=2) + '\n')
    includes = ['.', 'upstream/modules/rtl/mcu', 'upstream/tsconf/rtl/vg93']
    (OUT / f'{TARGET}.prj').write_text('\n'.join(
        f'{"vhdl" if f.endswith(".vhd") else "verilog"} work "{f}"' for f in files) + '\n')
    xst = (TS / f'{TARGET}.xst').read_text()
    if BOARD != 'go':
        xst = re.sub(r'^-define .*$', '', xst, flags=re.M)
        xst = '\n'.join(line for line in xst.splitlines() if line.strip())
    xst = xst.rstrip() + '\n-vlgincdir {' + ' '.join(includes) + '}\n'
    (OUT / f'{TARGET}.xst').write_text(xst)
    shutil.copyfile(TS / f'{TARGET}.ut', OUT / f'{TARGET}.ut')
    (OUT / 'roms').mkdir(exist_ok=True)
    shutil.copyfile(ROOT / 'res/roms/baseconf.rom', OUT / 'roms/baseconf.rom')
    shutil.copyfile(ROOT / 'res/roms/gs105b.rom', OUT / 'roms/gs105b.rom')
    core = json.loads((ROOT / 'config/core.json').read_text())
    if BOARD != 'go':
        core['bitstream'] = f'{TARGET}.bin'
    (OUT / 'core.json').write_text(json.dumps(core, indent=2) + '\n')
    hashes = {f: hashlib.sha256((OUT / f).read_bytes()).hexdigest() for f in files}
    for f in ('atm_font.hex', 'vg93-microcode-rom.hex', 'roms/baseconf.rom', 'roms/gs105b.rom',
              f'{TARGET}.prj', f'{TARGET}.ucf', f'{TARGET}.xst', f'{TARGET}.ut', 'baseconf_tune.vh', 'core.json'):
        hashes[f] = hashlib.sha256((OUT / f).read_bytes()).hexdigest()
    for header in sorted((OUT / 'upstream').rglob('*.vh')):
        hashes[header.relative_to(OUT).as_posix()] = hashlib.sha256(header.read_bytes()).hexdigest()
    (OUT / 'manifest.json').write_text(json.dumps(hashes, indent=2) + '\n')
    print(f'Prepared {len(files)} HDL files in {OUT.relative_to(ROOT)}')


def translate():
    work = OUT / 'ghdl'
    work.mkdir(exist_ok=True)
    files = json.loads((OUT / 'sources.json').read_text())
    ghdl = HDL / 'bin/ghdl-mcode'
    vhdl = [OUT / f for f in files if f.endswith('.vhd') and 'hid_parser' not in f and '/hdmi/' not in f]
    patched_t80 = work / 'T80.vhd'
    patched_t80.write_text((OUT / 'upstream/tsconf/rtl/T80/T80.vhd').read_text().replace('alu : T80_ALU', 'alu_instance : T80_ALU'))
    vhdl = [patched_t80 if p.name == 'T80.vhd' else p for p in vhdl]
    flags = ['--std=08', '-fsynopsys', '-fexplicit', '--workdir=' + str(work)]
    run([ghdl, '-a', *flags, *vhdl], logfile=work / 'analyze.log')
    generated = []
    for name in ('t80pa', 't80s'):
        path = work / (name + '.v')
        # GHDL emits an entire hierarchy per top. Synthesize separately; rename
        # generated implementation modules to prevent collisions between variants.
        result = run([ghdl, '--synth', *flags, '--out=verilog', '--no-formal', name])
        modules = re.findall(r'^module (\w+)', result, re.M)
        for module in sorted(set(modules), key=len, reverse=True):
            result = re.sub(r'\b' + module + r'\b', name if module.lower() == name else name + '_' + module, result)
        result = re.sub(r'\bdo\b', 'dout_internal', result)
        path.write_text(result)
        generated.append(str(path))
    # Explicit component binding lets GHDL leave the genuine Verilog key buffer
    # as a black box, subsequently linked by Icarus.
    hid = (OUT / 'upstream/tsconf/rtl/mcu/hid_parser.vhd').read_text()
    component = '''component usb_ps2_keybuf is port(
        clk, reset: in std_logic; kb_scancode: in std_logic_vector(7 downto 0);
        kb_scancode_upd, keybuf_rd, keybuf_reset: in std_logic;
        keybuf_data: out std_logic_vector(7 downto 0)); end component;
'''
    hid = hid.replace('architecture rtl of hid_parser is', 'architecture rtl of hid_parser is\n' + component)
    hid = hid.replace('entity work.usb_ps2_keybuf', 'usb_ps2_keybuf')
    path = work / 'hid_parser.vhd'
    path.write_text(hid)
    run([ghdl, '-a', *flags, path], logfile=work / 'hid_analyze.log')
    # stdout is HDL; warnings belong in a separate log.
    result = subprocess.run([str(ghdl), '--synth', *flags, '--out=verilog', '--no-formal', 'hid_parser'],
                            cwd=OUT, env=environment(), text=True, capture_output=True)
    (work / 'hid_synth.log').write_text(result.stderr)
    if result.returncode:
        raise RuntimeError(result.stderr)
    (work / 'hid_parser.v').write_text(result.stdout)
    generated.append(str(work / 'hid_parser.v'))
    return generated


def iverilog(sources, top, output):
    return run([HDL / 'bin/iverilog', '-B', HDL / 'lib/x86_64-linux-gnu/ivl', '-g2012',
        '-Wall', '-I.', '-Iupstream/modules/rtl/mcu', '-Iupstream/tsconf/rtl/vg93',
        '-s', top, '-o', output, *sources], logfile=Path(str(output) + '.compile.log'))


def elaborate():
    generated = translate()
    files = json.loads((OUT / 'sources.json').read_text())
    sources = [f for f in files if f.endswith('.v')]
    # GHDL specializes generic defaults; ISE uses the original generic instantiation.
    gs = OUT / 'upstream/tsconf/rtl/sound/gs.v'
    sim = OUT / 'ghdl/gs.v'
    sim.write_text(re.sub(r't80s #\(.*?\) z80_unit', 't80s z80_unit', gs.read_text()))
    sources = [str(sim) if f.endswith('/sound/gs.v') else f for f in sources]
    sources += generated + [str(ROOT / 'tests/xilinx_sim.v')]
    if BOARD != 'go':
        sources = [f for f in sources if '/hdmi/' not in f]
        sources.append(str(ROOT / 'tests/hdmi_boundary_model.v'))
    iverilog(sources, f'{TARGET}_top', OUT / 'elaborate.vvp')
    (OUT / 'simulation_sources.json').write_text(json.dumps(sources, indent=2) + '\n')
    print('Board elaboration passed (GHDL-translated CPU/HID, simulation clock primitives).')
    if BOARD != 'go':
        print('HDMI is a boundary sink in machine tests; run hdmi-test for the actual transmitter.')


def lint():
    sources = json.loads((OUT / 'simulation_sources.json').read_text())
    sources = [p for p in sources if not p.endswith('xilinx_sim.v')]
    # Use real Xilinx primitive declarations, never the behavioral PLL model.
    script = 'read_verilog -lib ' + str(HDL / 'share/yosys/xilinx/cells_sim.v') + '\n'
    script += 'read_verilog -lib ' + str(HDL / 'share/yosys/xilinx/cells_xtra.v') + '\n'
    script += 'read_verilog -defer -sv -I. -Iupstream/modules/rtl/mcu -Iupstream/tsconf/rtl/vg93 ' + ' '.join(sources) + '\n'
    script += f'hierarchy -check -top {TARGET}_top\nproc\nflatten\ntribuf -logic\nopt\ncheck -assert\nstat\n'
    (OUT / 'lint.ys').write_text(script)
    run([HDL / 'bin/yosys', '-s', 'lint.ys'], logfile=OUT / 'lint.log')
    print('Yosys process conversion and structural check passed; this is not ISE implementation.')


def resources():
    sources = json.loads((OUT / 'simulation_sources.json').read_text())
    sources = [p for p in sources if not p.endswith('xilinx_sim.v')]
    script = 'read_verilog -lib ' + str(HDL / 'share/yosys/xilinx/cells_sim.v') + '\n'
    script += 'read_verilog -lib ' + str(HDL / 'share/yosys/xilinx/cells_xtra.v') + '\n'
    script += 'read_verilog -defer -sv -I. -Iupstream/modules/rtl/mcu -Iupstream/tsconf/rtl/vg93 ' + ' '.join(sources) + '\n'
    script += f'hierarchy -check -top {TARGET}_top\nproc\nflatten\ntribuf -logic\n'
    script += f'synth_xilinx -family xc6s -top {TARGET}_top -flatten -ise\ncheck -assert\n'
    script += 'tee -o resource-stat.json stat -json\n'
    (OUT / 'resources.ys').write_text(script)
    run([HDL / 'bin/yosys', '-s', 'resources.ys'], logfile=OUT / 'resources.log')
    print('Spartan-6 resource estimate written to build/baseconf/resource-stat.json; not ISE fit/timing.')


def mini_board_bench(text):
    text = text.replace('karabas_go_top', f'{TARGET}_top')
    text = text.replace("wire [1:0] mio;assign mio[1]=1'b1;", "wire [5:0] mio;assign mio[0]=1'b1;assign mio[3:2]=2'b11;")
    text = re.sub(r' \.MCU_SPI_FT_CS_N.*?\n', ' .MCU_IO(mio' + ('[3:0]' if BOARD == 'mini' else '') + '),\n', text)
    text = re.sub(r' \.FDC_INDEX.*?\n', '', text)
    text = text.replace('.VGA_R(r),.VGA_G(g),.VGA_B(b),.VGA_HS(hs),.VGA_VS(vs),.V_CLK(vclk),',
                        ".VGA_R(8'h12),.VGA_G(8'h34),.VGA_B(8'h56),.VGA_HS(1'b0),.VGA_VS(1'b0),.FT_DE(1'b1),")
    text = text.replace('.FT_OE_N(ft_oe),', '')
    start = text.index(' if({r,g,b,hs,vs}')
    end = text.index(' wait(!dut.machine.storage_busy)', start)
    text = text[:start] + ''' if(dut.hdmi_top.ft_sel!==1 || dut.hdmi_top.ft_rgb!==24'h123456)
  $fatal(1,"MCU FT video takeover did not reach HDMI");
 if(mio[0]!==1 || mio[3:2]!==2'b11) $fatal(1,"MCU input pins driven by FPGA");
 control(0);if(dut.hdmi_top.ft_sel!==0) $fatal(1,"HDMI did not return to core video");
''' + text[end:]
    return text


def test(suite):
    if suite in ('ay', 'all'):
        ay_test()
    for name in (('sram', 'storage') if suite in ('adapters', 'all') else ()):
        sources = [str(ROOT / 'src/rtl' / f'baseconf_{name}.v')]
        if name == 'storage':
            sources += [str(ROOT / 'src/rtl/baseconf_sdram.v'), str(ROOT / 'tests/sdram_model.v')]
        sources += [str(ROOT / 'tests' / f'tb_{name}.v')]
        output = OUT / f'tb_{name}.vvp'
        iverilog(sources, f'tb_{name}', output)
        result = run([HDL / 'bin/vvp', output], logfile=OUT / f'tb_{name}.log')
        if f'PASS {name}' not in result:
            raise RuntimeError(result)
        print(result.strip())
    if BOARD != 'go' and suite == 'boot':
        raise RuntimeError('boot is the GO physical-FDC diagnostic; use bios for Mini CPU/ROM integration')
    if suite in ('boot', 'all') and BOARD == 'go':
        sources = json.loads((OUT / 'simulation_sources.json').read_text())
        sources += [str(ROOT / 'tests' / name) for name in ('tb_boot.v', 'sdram_model.v', 'sram_model.v')]
        output = OUT / 'tb_boot.vvp'
        iverilog(sources, 'tb_boot', output)
        for mode, plusargs in [('7mhz', []), ('14mhz', ['+turbo14']), ('3_5mhz', ['+slow35'])]:
            result = run([HDL / 'bin/vvp', output, *plusargs], logfile=OUT / f'tb_boot_{mode}.log')
            if 'PASS boot' not in result:
                raise RuntimeError(result)
            print(f'{mode}: {result.strip()}')
    if suite in ('gs', 'all'):
        sources = json.loads((OUT / 'simulation_sources.json').read_text())
        sources += [str(ROOT / 'tests' / name) for name in ('tb_gs_timing.v', 'sdram_model.v')]
        for mode, parameters in [('nominal', []), ('routed', ['-Ptb_gs_timing.ROUTED_IO=1'])]:
            output = OUT / f'tb_gs_{mode}.vvp'
            iverilog(sources + parameters, 'tb_gs_timing', output)
            result = run([HDL / 'bin/vvp', output], logfile=OUT / f'tb_gs_{mode}.log')
            if 'PASS gs timing' not in result:
                raise RuntimeError(result)
            print(f'{mode}: {result.strip()}')
    for name in (('keyboard_filter', 'hid', 'board', 'osd') if suite == 'all' else ((suite,) if suite in ('keyboard_filter', 'hid', 'board', 'osd') else ())):
        sources = json.loads((OUT / 'simulation_sources.json').read_text())
        output = OUT / f'tb_{name}.vvp'
        bench = ROOT / 'tests' / f'tb_{name}.v'
        if name == 'board' and BOARD != 'go':
            text = mini_board_bench(bench.read_text())
            bench = OUT / 'tb_board_mini.v'
            bench.write_text(text)
        iverilog(sources + [str(bench)], f'tb_{name}', output)
        result = run([HDL / 'bin/vvp', output], logfile=OUT / f'tb_{name}.log')
        if f'PASS {name}' not in result:
            raise RuntimeError(result)
        print(result.strip())


def ay_test():
    """CPU-driven AY register and signal checks, with FPGA-like zero startup state."""
    sources = json.loads((OUT / 'simulation_sources.json').read_text())
    sources += [str(ROOT / 'tests' / name) for name in ('tb_ay.v', 'sdram_model.v', 'sram_model.v')]
    obj = OUT / 'verilator_ay'
    run([HDL / 'bin/verilator', '--binary', '--timing', '-j', '2', '-Wno-fatal', '-CFLAGS', '-O3',
         '--top-module', 'tb_ay', '--Mdir', obj, '-I.', '-Iupstream/modules/rtl/mcu',
         '-Iupstream/tsconf/rtl/vg93', *sources], logfile=OUT / 'ay-compile.log')
    results = []
    for speed, flags in [('7mhz', []), ('14mhz', ['+turbo14']), ('3_5mhz', ['+slow35'])]:
        for kind, extra in [('ay', []), ('ym', ['+ym'])]:
            log = OUT / f'ay-{speed}-{kind}.log'
            result = run([obj / 'Vtb_ay', *flags, *extra], logfile=log)
            if 'PASS ay:' not in result:
                raise RuntimeError(result)
            print(f'{speed}/{kind}: {result.strip()}', flush=True)
            results.append({'speed': speed, 'type': kind, 'log': log.name,
                            'sha256': hashlib.sha256(log.read_bytes()).hexdigest()})
    (OUT / 'ay-result.json').write_text(json.dumps({
        'board': BOARD, 'passed': True, 'simulator': 'verilator',
        'manifest_sha256': hashlib.sha256((OUT / 'manifest.json').read_bytes()).hexdigest(),
        'testbench_sha256': hashlib.sha256((ROOT / 'tests/tb_ay.v').read_bytes()).hexdigest(),
        'cases': results,
        'limits': 'Two-state functional test; no routed timing, analog capture, envelope/music acceptance or hardware noise reproduction.'
    }, indent=2) + '\n')


def ise(settings, docker=False):
    settings = core_path(settings)
    if not docker and not any(settings.is_relative_to(root) for root in (ROOT, FORGE_ROOT)):
        raise RuntimeError('Use an ISE installation inside the core or shared Forge workspace.')
    if not docker and not settings.is_file():
        raise RuntimeError('ISE settings script not found; install ISE 14.7 under bin/ first.')
    manifest_hash = hashlib.sha256((OUT / 'manifest.json').read_bytes()).hexdigest()
    for filename, expected in json.loads((OUT / 'manifest.json').read_text()).items():
        if hashlib.sha256((OUT / filename).read_bytes()).hexdigest() != expected:
            raise RuntimeError(f'Generated input changed: {filename}; rerun prepare.')
    (OUT / 'ise-completed.json').unlink(missing_ok=True)
    if docker:
        import ise_docker
    (OUT / 'xst/projnav.tmp').mkdir(parents=True, exist_ok=True)
    steps = [
        ['xst', '-ifn', f'{TARGET}.xst', '-ofn', f'{TARGET}.syr'],
        ['ngdbuild', '-uc', f'{TARGET}.ucf', '-p', 'xc6slx25-ftg256-2', f'{TARGET}.ngc', f'{TARGET}.ngd'],
        ['map', '-p', 'xc6slx25-ftg256-2', '-w', '-o', f'{TARGET}_map.ncd', f'{TARGET}.ngd', f'{TARGET}.pcf'],
        ['par', '-w', f'{TARGET}_map.ncd', f'{TARGET}.ncd', f'{TARGET}.pcf'],
        ['trce', '-v', '10', '-u', '10', f'{TARGET}.ncd', '-o', f'{TARGET}.twr', f'{TARGET}.pcf'],
        ['bitgen', '-f', f'{TARGET}.ut', f'{TARGET}.ncd'],
    ]
    if BOARD != 'go':
        steps[2][3:3] = ['-ol', 'high', '-t', '2' if BOARD == 'mini' else '1']
        steps[3][1:1] = ['-ol', 'high']
    for command in steps:
        invocation = ise_docker.command(command, workdir=OUT, build_root=BUILD) if docker else [
            'bash', '-c', 'source "$1" >/dev/null; shift; exec "$@"', 'ise', settings, *command]
        print(f'Running ISE {command[0]}...', flush=True)
        run(invocation, logfile=OUT / (command[0] + '.log'))
    if BOARD != 'go':
        coremode_constraints()
        command = ['trce', '-v', '10', '-u', '10', f'{TARGET}.ncd', '-o', f'{TARGET}_core.twr', f'{TARGET}_core.pcf']
        invocation = ise_docker.command(command, workdir=OUT, build_root=BUILD) if docker else [
            'bash', '-c', 'source "$1" >/dev/null; shift; exec "$@"', 'ise', settings, *command]
        run(invocation, logfile=OUT / 'trce-core.log')
    if manifest_hash != hashlib.sha256((OUT / 'manifest.json').read_bytes()).hexdigest():
        raise RuntimeError('Build inputs regenerated during ISE; rerun the build.')
    (OUT / 'ise-completed.json').write_text(json.dumps({
        'manifest_sha256': hashlib.sha256((OUT / 'manifest.json').read_bytes()).hexdigest(),
        'bitstream_sha256': hashlib.sha256((OUT / f'{TARGET}.bin').read_bytes()).hexdigest(),
        'toolchain': ise_docker.IMAGE if docker else str(settings),
    }, indent=2) + '\n')
    for report in ([f'{TARGET}.twr'] if BOARD == 'go' else [f'{TARGET}.twr', f'{TARGET}_core.twr']):
        if 'All constraints were met' not in (OUT / report).read_text():
            (OUT / 'ise-completed.json').unlink(missing_ok=True)
            raise RuntimeError(f'Timing did not pass: {report}')
    print('ISE implementation and declared timing constraints passed. Hardware acceptance remains separate.')


def video_test():
    if BOARD == 'go':
        raise RuntimeError('video-test requires a Mini target with HDMI blanking')
    files = json.loads((OUT / 'sources.json').read_text())
    sources = [str(OUT / f) for f in files if '/baseconf/video/' in f or f.endswith('video_fontrom.v') or '/video/osd/' in f or f.endswith('kg_sdpram.v')]
    obj = OUT / 'verilator_video'
    run([HDL / 'bin/verilator', '--binary', '--timing', '-j', '2', '-Wno-fatal',
         '--top-module', 'tb_mini_video', '--Mdir', obj, '-I.', *sources, ROOT / 'tests/tb_mini_video.v'],
         logfile=OUT / 'video-compile.log')
    result = run([obj / 'Vtb_mini_video'], logfile=OUT / 'video-test.log')
    if 'PASS mini video' not in result:
        raise RuntimeError(result)
    (OUT / 'video-result.json').write_text(json.dumps({'passed': True, 'board': BOARD,
        'manifest_sha256': hashlib.sha256((OUT / 'manifest.json').read_bytes()).hexdigest(),
        'testbench_sha256': hashlib.sha256((ROOT / 'tests/tb_mini_video.v').read_bytes()).hexdigest(),
        'log_sha256': hashlib.sha256((OUT / 'video-test.log').read_bytes()).hexdigest()}, indent=2) + '\n')
    print(result.strip())


def hdmi_test():
    """Run the real HDMI transport with Icarus and ISE unisim, at the selected board audio rate."""
    if BOARD == 'go':
        raise RuntimeError('hdmi-test requires --board mini or minig')
    import ise_docker
    work = OUT / 'hdmi-test'
    work.mkdir(exist_ok=True)
    for name in ('w93', 'w08'):
        (work / name).mkdir(exist_ok=True)
    hdmi = OUT / 'upstream/modules/rtl/video/hdmi'
    rate = 44100 if BOARD == 'mini' else 48000
    tx = (hdmi / 'zhdmi_tx.vhd').read_text()
    tx = replace_once(tx, 'architecture rtl of hdmi_tx is\n', '''architecture rtl of hdmi_tx is
    component dvi port (CLK, RESET : in std_logic; RGB : in std_logic_vector(23 downto 0);
        HSYNC, VSYNC, DE : in std_logic; ENC_RED, ENC_GREEN, ENC_BLUE : out std_logic_vector(9 downto 0));
    end component;
''')
    tx = replace_once(tx, 'dvi: entity work.dvi port map(', 'dvi_inst: dvi port map(')
    (work / 'zhdmi_tx_sim.vhd').write_text(tx)
    ghdl = HDL / 'bin/ghdl-mcode'
    run([ghdl, '-a', '--std=93c', '--workdir=w93', '--work=unisim',
         MODULES.parent / 'sim/lint/unisim_stubs.vhd'], cwd=work, logfile=work / 'unisim.log')
    def synth(args, output, log):
        result = subprocess.run([str(x) for x in [ghdl, '--synth', *args]], cwd=work,
                                env=environment(), text=True, capture_output=True)
        (work / log).write_text(result.stderr)
        if result.returncode:
            raise RuntimeError(result.stderr[-10000:])
        (work / output).write_text(result.stdout)
    names = ['zhdmi_tmds_encoder', 'zhdmi_tmds_serializer_spartan6', 'zhdmi_audio_packetizer',
             'zhdmi_island_encoder', 'zhdmi_packet_gen', 'zhdmi_signaling']
    synth(['--std=93c', '--ieee=synopsys', '--workdir=w93', '-Pw93', '--out=verilog', f'-gSAMPLE_FREQ={rate}',
           *[hdmi / (name + '.vhd') for name in names], 'zhdmi_tx_sim.vhd', '-e', 'hdmi_tx'], 'hdmi_tx.v', 'ghdl93.log')
    p = work / 'hdmi_tx.v'
    tx = p.read_text()
    tx, count = re.subn(r'(module hdmi_tx\b.*?\);)', r'\1\nparameter SAMPLE_FREQ = 0;', tx, count=1, flags=re.S)
    assert count == 1
    p.write_text(tx)
    synth(['--std=08', '--ieee=synopsys', '--workdir=w08', '--out=verilog',
           hdmi / 'dvi_encoder.vhd', hdmi / 'dvi.vhd', '-e', 'dvi'], 'dvi.v', 'ghdl08.log')
    bench = (TS / 'sim/tb_hdmi_top.v').read_text()
    bench = bench.replace('28000000', '28030303').replace('#17.857 ', '#17.83784 ').replace('#62.5 ', '#62.7027 ')
    # DCM_CLKGEN's vendor model truncates period division to integer ps.
    # Match that model quantization in the FT source (same clock frequency,
    # independent phase) instead of introducing an artificial 1 ps/period drift.
    bench = bench.replace('real ft_half = 12.5;\nalways #(ft_half) ft_clk = ~ft_clk;',
        'integer ft_period_ps = 25081;\nalways begin\n'
        ' #((ft_period_ps / 2) / 1000.0) ft_clk = 1;\n'
        ' #((ft_period_ps - ft_period_ps / 2) / 1000.0) ft_clk = 0;\nend')
    bench = bench.replace('ft_half = 12.5;', 'ft_period_ps = 25081;').replace('ft_half = 6.944;', 'ft_period_ps = 15675;')
    bench = bench.replace('72 MHz', '64 MHz').replace("8'd72", "8'd64")
    bench = bench.replace('.SAMPLERATE(SAMPLERATE))', '.SAMPLERATE(SAMPLERATE), .CLKRATE(28030303))')
    bench = bench.replace('check_us * (SAMPLERATE / 1000) / 1000', '(check_us / 1000.0) * SAMPLERATE / 1000.0')
    (work / 'tb_hdmi_top.v').write_text(bench)
    synth(['--std=08', '--ieee=synopsys', '--workdir=w08', '--out=verilog',
           OUT / 'upstream/tsconf/rtl/hdmi/freq_counter.vhd', '-e', 'freq_counter'], 'freq_counter.v', 'ghdl-freq.log')
    # The supplied image has no C compiler for ISim. Use its genuine unisim
    # Verilog models with local Icarus instead; extract only inside build/.
    import tarfile
    models = work / 'xilinx'
    models.mkdir(exist_ok=True)
    archive = work / 'unisim.tar'
    if not (models / 'glbl.v').is_file():
        target = '/build/' + archive.relative_to(BUILD).as_posix()
        run(ise_docker.command(['/bin/tar', '-cf', target, '-C',
            '/opt/Xilinx/14.7/ISE_DS/ISE/verilog/src', 'unisims', 'glbl.v'], workdir=work, build_root=BUILD),
            cwd=work, logfile=work / 'extract.log')
        with tarfile.open(archive) as stream:
            stream.extractall(models, filter='data')
    # Vendor models rely on implicit wires; preceding user RTL sets nettype none.
    for model in (models / 'unisims').glob('*.v'):
        source = model.read_text()
        if not source.startswith('`default_nettype wire'):
            model.write_text('`default_nettype wire\n' + source)
    paths = [work / 'freq_counter.v', work / 'hdmi_tx.v', work / 'dvi.v',
             hdmi / 'pll_reset.v', OUT / 'upstream/modules/rtl/mem/kg_async_fifo.v',
             OUT / 'upstream/tsconf/rtl/hdmi/hdmi_pll.v', OUT / 'upstream/tsconf/rtl/hdmi/hdmi_top.v',
             work / 'tb_hdmi_top.v', models / 'glbl.v']
    run([HDL / 'bin/iverilog', '-B', HDL / 'lib/x86_64-linux-gnu/ivl', '-g2012',
         '-y', models / 'unisims', '-s', 'tb_hdmi_top', '-s', 'glbl',
         f'-Ptb_hdmi_top.SAMPLERATE={rate}', '-o', 'hdmi.vvp', *paths], cwd=work, logfile=work / 'compile.log')
    result = run([HDL / 'bin/vvp', 'hdmi.vvp'], cwd=work, logfile=work / 'simulation.log')
    if 'tb_hdmi_top: 0 errors' not in result:
        raise RuntimeError(result[-10000:])
    print('\n'.join(line for line in result.splitlines() if 'MHz' in line or 'errors' in line))
    (work / 'result.json').write_text(json.dumps({'passed': True, 'board': BOARD, 'audio_rate': rate,
        'manifest_sha256': hashlib.sha256((OUT / 'manifest.json').read_bytes()).hexdigest(),
        'testbench_sha256': hashlib.sha256((work / 'tb_hdmi_top.v').read_bytes()).hexdigest(),
        'log_sha256': hashlib.sha256((work / 'simulation.log').read_bytes()).hexdigest(),
        'coverage': 'Real HDMI transport and vendor clock models; core/FT40/FT64/core; pixels and stereo samples at TX input; no electrical capture'}, indent=2) + '\n')
    print(f'PASS HDMI {BOARD}: actual transport, audio {rate}, core/FT40/FT64/core switches; no electrical capture.')


def hdmi_audio_test():
    """Check audio packet contents and ACR under actual BaseConf 50/60 Hz blanking."""
    if BOARD == 'go':
        raise RuntimeError('hdmi-audio-test requires --board mini or minig')
    transport = OUT / 'hdmi-test'
    manifest_hash = hashlib.sha256((OUT / 'manifest.json').read_bytes()).hexdigest()
    if not (transport / 'result.json').exists() or json.loads((transport / 'result.json').read_text())['manifest_sha256'] != manifest_hash:
        hdmi_test()
    work = OUT / 'hdmi-audio-test'
    work.mkdir(exist_ok=True)
    rate = 44100 if BOARD == 'mini' else 48000
    files = json.loads((OUT / 'sources.json').read_text())
    sources = [str(OUT / f) for f in files if '/baseconf/video/' in f or f.endswith('video_fontrom.v') or f.endswith('kg_sdpram.v')]
    sources += [str(transport / 'hdmi_tx.v'), str(ROOT / 'tests/tb_hdmi_audio_packets.v')]
    cases = []
    for declared_clock in (28030303, 28000000):
        obj = work / f'verilator_{declared_clock}'
        log = work / f'packets-{declared_clock}.log'
        run([HDL / 'bin/verilator', '--binary', '--timing', '-j', '2', '-Wno-fatal',
             '--top-module', 'tb_hdmi_audio_packets', '--Mdir', obj, '-I.',
             f'-DHDMI_SIGNALING=signaling_{rate}', f'-GRATE={rate}',
             f'-GDECLARED_CLOCK={declared_clock}', *sources],
            logfile=work / f'compile-{declared_clock}.log')
        result = run([obj / 'Vtb_hdmi_audio_packets'], logfile=log)
        checks = [line for line in result.splitlines() if line.startswith('PASS HDMI packets:')]
        if len(checks) != 2:
            raise RuntimeError('HDMI audio packet checks incomplete')
        print('\n'.join(checks), flush=True)
        cases.append({'declared_clock': declared_clock, 'checks': checks,
                      'log_sha256': hashlib.sha256(log.read_bytes()).hexdigest()})
    (work / 'result.json').write_text(json.dumps({
        'passed': True, 'board': BOARD, 'nominal_audio_rate': rate,
        'manifest_sha256': manifest_hash,
        'testbench_sha256': hashlib.sha256((ROOT / 'tests/tb_hdmi_audio_packets.v').read_bytes()).hexdigest(),
        'cases': cases,
        'coverage': 'Actual ZX BaseConf raster at 50/60 Hz; signed stereo packet payload/order/parity, buffer capacity, ACR N/CTS, data-island clipping; BaseConf and reference sampler divisors.',
        'limits': 'Core-mode packet/signaling test; audio sampler stimulus modeled. Separate hdmi-test covers sampler CDC/PLL modes. No physical TMDS decoding or routed timing.'
    }, indent=2) + '\n')


def compile_bios(simulator='verilator'):
    bench_hash = hashlib.sha256((ROOT / 'tests/tb_bios.v').read_bytes()).hexdigest()
    sources = json.loads((OUT / 'simulation_sources.json').read_text())
    bench = ROOT / 'tests/tb_bios.v'
    if BOARD != 'go':
        text = bench.read_text().replace('karabas_go_top', f'{TARGET}_top')
        text = text.replace("wire [1:0] mio; assign mio[1]=1'b1;", "wire [5:0] mio; assign mio[0]=1'b1; assign mio[3:2]=2'b11;")
        text = re.sub(r' \.MCU_SPI_FT_CS_N.*?\n', ' .MCU_IO(mio' + ('[3:0]' if BOARD == 'mini' else '') + '),\n', text)
        text = re.sub(r' \.FDC_INDEX.*?\n', '', text)
        text = text.replace('.VGA_R(r),.VGA_G(g),.VGA_B(b),.VGA_HS(hs),.VGA_VS(vs),', ".VGA_R(8'd0),.VGA_G(8'd0),.VGA_B(8'd0),.VGA_HS(1'b0),.VGA_VS(1'b0),.FT_DE(1'b0),")
        text = text.replace('always @(negedge vs)', 'always @(negedge dut.video_vsync)')
        bench = OUT / 'tb_bios_mini.v'
        bench.write_text(text)
        bench_hash = hashlib.sha256(bench.read_bytes()).hexdigest()
    sources += [str(bench)] + [str(ROOT / 'tests' / name) for name in ('sdram_model.v', 'sram_model.v')]
    if simulator == 'verilator':
        obj = OUT / 'verilator_bios_o3'
        run([HDL / 'bin/verilator', '--binary', '--timing', '-j', '2', '-Wno-fatal', '-CFLAGS', '-O3',
             '--top-module', 'tb_bios', '--Mdir', obj,
             '-I.', '-Iupstream/modules/rtl/mcu', '-Iupstream/tsconf/rtl/vg93', *sources],
            logfile=OUT / 'verilator-bios-compile.log')
        args = [obj / 'Vtb_bios', '+milliseconds=600']
    else:
        output = OUT / 'tb_bios.vvp'
        iverilog(sources, 'tb_bios', output)
        args = [HDL / 'bin/vvp', output, '+milliseconds=600']
    return args, bench_hash


def bios_reset_test():
    from concurrent.futures import ThreadPoolExecutor
    (OUT / 'bios-reset-result.json').unlink(missing_ok=True)
    expected = json.loads((ROOT / 'config/bios-menu-signature.json').read_text())['rom_sha256']
    if hashlib.sha256((OUT / 'roms/baseconf.rom').read_bytes()).hexdigest() != expected:
        raise RuntimeError('Reset-dispatch PCs require the pinned stock ROM')
    manifest_hash = hashlib.sha256((OUT / 'manifest.json').read_bytes()).hexdigest()
    args, bench_hash = compile_bios()
    names = ['cs', 'ss', 'd', 'c', 'h', 's', '0', 'a+b', 'a+b+c', 'cs+ss']
    def check(item):
        index, name = item
        work = OUT / 'bios-resets' / name
        work.mkdir(parents=True, exist_ok=True)
        if not (work / 'roms').exists():
            (work / 'roms').symlink_to(OUT / 'roms', target_is_directory=True)
        for init in OUT.glob('*.hex'):
            if not (work / init.name).exists():
                (work / init.name).symlink_to(init)
        log = work / 'simulation.log'
        output = run([*args, f'+reset_case={index}'], cwd=work, logfile=log)
        if '$readmem file not found' in output:
            raise RuntimeError(f'Missing initialization image in reset test {name}')
        passes = [line for line in output.splitlines() if line.startswith('PASS BIOS reset')]
        if len(passes) != 1:
            raise RuntimeError(f'Stock BIOS did not confirm reset choice {name}')
        print(name + ': ' + passes[0], flush=True)
        return {'keys': name, 'passed': True, 'observation': passes[0],
                'log_sha256': hashlib.sha256(log.read_bytes()).hexdigest()}
    with ThreadPoolExecutor(max_workers=3) as pool:
        cases = list(pool.map(check, enumerate(names, 1)))
    if manifest_hash != hashlib.sha256((OUT / 'manifest.json').read_bytes()).hexdigest():
        raise RuntimeError('Build changed during reset tests')
    (OUT / 'bios-reset-result.json').write_text(json.dumps({
        'board': BOARD, 'manifest_sha256': manifest_hash, 'testbench_sha256': bench_hash,
        'rom_sha256': expected, 'cases': cases,
        'scope': 'Actual stock ROM dispatch after MCU/HID F12 reset; no hardware or complete BASIC/diagnostic UI acceptance'
    }, indent=2) + '\n')


def bios(milliseconds, trace, simulator, require_menu):
    manifest_hash = hashlib.sha256((OUT / 'manifest.json').read_bytes()).hexdigest()
    for name in ('bios-result.json', 'bios-sram-hi.hex', 'bios-sram-lo.hex', 'bios-trace.log', 'tb_bios.log'):
        (OUT / name).unlink(missing_ok=True)
    args, bench_hash = compile_bios(simulator)
    args[-1] = f'+milliseconds={milliseconds}'
    if trace:
        args.append('+trace')
    result = run(args, logfile=OUT / 'tb_bios.log')
    print(result.strip())
    if 'BIOS observation ended' not in result:
        raise RuntimeError('BIOS simulation did not reach its observation endpoint')
    if manifest_hash != hashlib.sha256((OUT / 'manifest.json').read_bytes()).hexdigest():
        raise RuntimeError('Generated build changed during BIOS simulation; rerun it')
    if require_menu:
        print(run([sys.executable, ROOT / 'tools/bios_inspect.py', '--build', OUT, '--output', OUT / 'bios-screen', '--require-menu'], cwd=ROOT).strip())
    record = {'simulator': simulator, 'milliseconds': milliseconds, 'menu_verified': require_menu,
              'manifest_sha256': manifest_hash, 'testbench_sha256': bench_hash,
              'artifacts_sha256': {name: hashlib.sha256((OUT / name).read_bytes()).hexdigest() for name in (
                  'roms/baseconf.rom', 'roms/gs105b.rom', 'tb_bios.log', 'bios-trace.log',
                  'bios-sram-hi.hex', 'bios-sram-lo.hex')}}
    (OUT / 'bios-result.json').write_text(json.dumps(record, indent=2) + '\n')


def verify_package(path):
    """Independently decode our package, checking payloads and OSD against inputs."""
    data = Path(path).read_bytes()
    config = json.loads((OUT / 'core.json').read_text())
    def require(condition, message):
        if not condition:
            raise RuntimeError('Package validation: ' + message)
    require(data[:4] == b'kgo1', 'wrong signature')
    require(data[4:36].decode('ascii').rstrip() == config['id'], 'wrong core ID')
    require(data[68:76].decode('ascii').rstrip() == config['build'], 'wrong build')
    require(data[88] == 2, 'EVO RTC mode missing')
    bit_size = int.from_bytes(data[80:84], 'big')
    rom_size = int.from_bytes(data[84:88], 'big')
    require(data[1024:1024+bit_size] == (OUT / config['bitstream']).read_bytes(), 'FPGA payload differs')
    pos = 1024 + bit_size
    for rom in config['roms']:
        size = int.from_bytes(data[pos:pos+4], 'big')
        address = int.from_bytes(data[pos+4:pos+8], 'big')
        pos += 8
        require(address == rom['address'], 'ROM destination differs')
        require(data[pos:pos+size] == (OUT / rom['filename']).read_bytes(), 'ROM payload differs')
        pos += size
    require(pos == 1024 + bit_size + rom_size, 'ROM block length differs')
    require(data[pos] == len(config['osd']), 'OSD item count differs')
    pos += 1
    selectors = {}
    for index, item in enumerate(config['osd']):
        types = {'S': 0, 'N': 1, 'T': 2, 'H': 3, 'P': 4}
        require(item['type'] in types, 'unsupported menu type in verifier')
        require(data[pos] == types[item['type']], 'OSD item type differs')
        name = data[pos+2:pos+18].decode('ascii').rstrip()
        default, count = data[pos+18:pos+20]
        require(name == item['name'][:16] and default == item.get('default', 0), 'OSD name/default differs')
        require(data[512+index] == item.get('default', 0), 'saved default differs')
        pos += 20
        options = [data[pos+i*16:pos+(i+1)*16].decode('ascii').rstrip() for i in range(count)]
        require(options == (item.get('options') or []), 'OSD options differ')
        if name in ('Joystick L', 'Joystick R'):
            require(options[-1] == 'SEGA', 'SEGA mode missing')
            selectors[name] = options
        pos += count*16
        hotkey = item.get('hotkey', '')
        require(data[pos:pos+16].decode('ascii').rstrip() == hotkey, 'OSD hotkey text differs')
        # Independently check the modifier/keycode bytes used by MCU dispatch.
        modifiers = {'Ctrl': 0x11, 'Shift': 0x22, 'Alt': 0x44, 'Menu': 0x88}
        keycodes = {chr(65+i): 4+i for i in range(26)}
        keycodes.update({f'F{i}': 0x39+i for i in range(1, 13)})
        modifier, keys = 0, []
        for part in hotkey.split('+') if hotkey else []:
            if part in modifiers:
                modifier |= modifiers[part]
            else:
                require(part in keycodes, f'unsupported verification hotkey {part}')
                keys.append(keycodes[part])
        require(len(keys) <= 1, 'more than one hotkey usage')
        require(data[pos+16:pos+18] == bytes([modifier, keys[0] if keys else 0]), 'OSD hotkey codes differ')
        pos += 21  # hotkey text, modifier/keycode, reserved
    require(pos == len(data), 'trailing or truncated package bytes')
    record = {'board': BOARD, 'build': config['build'], 'bytes': len(data),
              'package_sha256': hashlib.sha256(data).hexdigest(),
              'manifest_sha256': hashlib.sha256((OUT / 'manifest.json').read_bytes()).hexdigest(),
              'bitstream_and_roms_verified': True, 'osd_entries_verified': len(config['osd']),
              'joystick_selectors': selectors}
    (OUT / 'package-verified.json').write_text(json.dumps(record, indent=2) + '\n')
    print('PASS package: header, FPGA/ROM payloads, destinations, OSD settings and both SEGA selectors')


def package():
    if not (OUT / 'ise-completed.json').is_file():
        raise RuntimeError('No completed ISE build. Run forge.py ise with a project-local ISE 14.7 installation first.')
    proof = json.loads((OUT / 'ise-completed.json').read_text())
    for field, filename in [('manifest_sha256', 'manifest.json'), ('bitstream_sha256', f'{TARGET}.bin')]:
        if hashlib.sha256((OUT / filename).read_bytes()).hexdigest() != proof[field]:
            raise RuntimeError('Build provenance changed; rerun ISE for these inputs.')
    for filename, expected in json.loads((OUT / 'manifest.json').read_text()).items():
        if hashlib.sha256((OUT / filename).read_bytes()).hexdigest() != expected:
            raise RuntimeError(f'Build input changed since synthesis: {filename}')
    timing = (OUT / f'{TARGET}.twr').read_text()
    if 'All constraints were met' not in timing:
        raise RuntimeError('Timing report does not establish that all constraints were met.')
    if BOARD != 'go' and 'All constraints were met' not in (OUT / f'{TARGET}_core.twr').read_text():
        raise RuntimeError('Core-mode HDMI timing did not pass.')
    packer = FORGE_ROOT / 'external/karabas-go-tools/make_core/make_core.py'
    result = run([sys.executable, packer, 'core.json', f'baseconf.{EXTENSION}'], logfile=OUT / 'package.log')
    print(result.strip())
    verify_package(OUT / f'baseconf.{EXTENSION}')
    print(f'Created {OUT.relative_to(ROOT)}/baseconf.{EXTENSION}. Board acceptance is still required.')


def main():
    global OUT, BOARD, TARGET, EXTENSION
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--board', choices=['go', 'mini', 'minig'], default='go',
                        help='Board target; GO retains build/baseconf, Mini targets use build/baseconf-<board>')
    parser.add_argument('--build-dir', type=core_path, help='Output directory inside core build/ (relative paths are core-relative)')
    commands = parser.add_subparsers(dest='command', required=True)
    commands.add_parser('prepare', help='Generate the selected board project from maintained RTL and pinned references')
    commands.add_parser('elaborate', help='Translate VHDL and elaborate the full board in Icarus; not synthesis')
    commands.add_parser('lint', help='Convert RTL processes and structurally check with local Yosys; not place-and-route')
    commands.add_parser('resources', help='Estimate Spartan-6 resources using Yosys/GHDL; not ISE placement or timing')
    p = commands.add_parser('test', help='Run self-checking adapter/integrated CPU simulations')
    p.add_argument('--suite', choices=['adapters', 'boot', 'keyboard_filter', 'hid', 'board', 'osd', 'gs', 'ay', 'all'], default='all')
    p = commands.add_parser('ise', help='Run ISE 14.7 for the selected board using local installation or supplied Docker image')
    p.add_argument('--docker', action='store_true', help='Use the supplied pinned Docker ISE image')
    p.add_argument('--settings', default=str(FORGE_ROOT / 'bin/Xilinx/14.7/ISE_DS/settings64.sh'))
    p = commands.add_parser('bios', help='Observe unmodified stock BIOS in board simulation; not a hardware boot certificate')
    p.add_argument('--milliseconds', type=int, choices=range(1, 5001), metavar='1..5000', default=50,
                   help='Simulated runtime after MCU initialization (default: 50 ms)')
    p.add_argument('--trace', action='store_true', help='Record instruction fetch addresses as well as I/O in bios-trace.log')
    p.add_argument('--simulator', choices=['icarus', 'verilator'], default='icarus',
                   help='Icarus is four-state; Verilator is faster but uses two-state logic')
    p.add_argument('--require-menu', action='store_true', help='Fail unless the resulting SRAM screen matches the pinned stock menu signature')
    commands.add_parser('bios-reset-test', help='Verify stock-ROM reset choices through MCU/HID F12 and held keys')
    commands.add_parser('video-test', help='Check real BaseConf video blanking and OSD in both rasters and four mode families')
    commands.add_parser('hdmi-test', help='Simulate Mini HDMI using GHDL/Icarus and genuine ISE clock models')
    commands.add_parser('hdmi-audio-test', help='Check HDMI audio packets and ACR with actual BaseConf rasters')
    commands.add_parser('package', help='Package the completed, timing-passing target as baseconf.kg1/kg2/kg3')
    args = parser.parse_args()
    BOARD = args.board
    TARGET = 'karabas_' + BOARD
    EXTENSION = {'go': 'kg1', 'mini': 'kg2', 'minig': 'kg3'}[BOARD]
    OUT = args.build_dir or BUILD / ('baseconf' if BOARD == 'go' else 'baseconf-' + BOARD)
    if not OUT.is_relative_to(BUILD) or OUT == BUILD:
        parser.error('--build-dir must be a directory below core build/')
    try:
        if args.command == 'prepare': prepare()
        elif args.command == 'elaborate': elaborate()
        elif args.command == 'lint': lint()
        elif args.command == 'resources': resources()
        elif args.command == 'test': test(args.suite)
        elif args.command == 'ise': ise(args.settings, args.docker)
        elif args.command == 'bios-reset-test': bios_reset_test()
        elif args.command == 'video-test': video_test()
        elif args.command == 'hdmi-test': hdmi_test()
        elif args.command == 'hdmi-audio-test': hdmi_audio_test()
        elif args.command == 'bios': bios(args.milliseconds, args.trace, args.simulator, args.require_menu)
        else: package()
    except (RuntimeError, FileNotFoundError) as exc:
        parser.exit(1, f'ERROR: {exc}\n')

if __name__ == '__main__':
    main()
