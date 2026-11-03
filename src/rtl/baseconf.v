// ZX-Evo Base Configuration (c) NedoPC 2008,2009,2010,2011,2012,2013,2014,2015,2016,2019
//
// top-level

/*
    This file is part of ZX-Evo Base Configuration firmware.

    ZX-Evo Base Configuration firmware is free software:
    you can redistribute it and/or modify it under the terms of
    the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    ZX-Evo Base Configuration firmware is distributed in the hope that
    it will be useful, but WITHOUT ANY WARRANTY; without even
    the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
    See the GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with ZX-Evo Base Configuration firmware.
    If not, see <http://www.gnu.org/licenses/>.
*/

// Karabas GO B4 adaptation, 2026. Physical peripherals replaced below.



module baseconf
(
  // clocks, from the PLL of the top with phase 0: clk_bus is clk / 3, its edges are edges of clk
	input wire clk,       // 84 MHz: the SRAM controller, the SDRAM of the General Sound
	input wire clk_bus,   // 28 MHz: the machine
	input wire ce,        // clk: the clock before each edge of clk_bus
	input wire resetbtn_n,
	input wire resetkey_n, // F12 / OSD Reset / button only (not mcu_busy): also resets the ROM storage
	input wire resetgsbtn_n,
	input wire locked,
	output wire f1_out,

   // SRAM
   output wire [20:0] sram_addr,
   inout  wire [15:0] sram_data,
   output wire [1:0] sram_we_n,
   output wire [1:0] sram_rd_n,
  
	// VGA
	output wire [7:0] VGA_R,
	output wire [7:0] VGA_G,
	output wire [7:0] VGA_B,
	output wire       VGA_HS,
	output wire       VGA_VS,
	output wire VGA_BLANK,
	
	// SPI SD-Card
	output wire sdcs_n,
	output wire sdclk,
	output wire sddo,
	input  wire sddi,
	
	// SPI FT812 / ESP32
	output wire ftcs_n,
	output wire espcs_n,
	input wire espcs_in,
	output wire esp_ft_spi_dis,
	output wire ftclk,
	output wire ftdo,
	input wire ftdi,
	input wire ftint,
	output wire vdac2_sel,

	// digital audio
	output wire [15:0] audio_out_l,
	output wire [15:0] audio_out_r,
	output wire beep,

	// adc in
`ifdef HW_ID2	
	input wire [15:0] adc_in_l,
	input wire [15:0] adc_in_r,
`endif

`ifdef HW_ID3
    input wire [15:0] esp_in_l,
	 input wire [15:0] esp_in_r,
`endif

	// joystick
	input wire [7:0] joy_data,
	
	// mouse (mcu)
	output wire [2:0] mouse_addr,
	input wire [7:0] mouse_data,
	
	// keyboard (mcu)
	output wire[15:8] keyboard_addr,
	input wire[4:0] keyboard_data,
	input wire[7:0] keyboard_scancode,
	
	// rtc (mcu)
	output wire [7:0] rtc_addr,
	output wire [7:0] rtc_di,
	input wire [7:0] rtc_do,
	output wire rtc_wr,
	output wire rtc_rd,
	
	// uart (zifi)
	input wire uart_rx,
	output wire uart_tx,
	output wire uart_cts,
	
	// ide
	inout wire [15:0] ide_d,
	output wire ide_rs_n,
	output wire [2:0] ide_a,
	output wire ide_dir,
	output wire ide_cs0_n,
	output wire ide_cs1_n,
	output wire ide_rd_n,
	output wire ide_wr_n,
	input wire ide_rdy,
	
	// tape
	input wire tape_in,
	output wire tape_out,
	
	// osd switches
	input wire covox_en,  // covox #FB and Soundrive (covox.vhd of TS-Conf)
	input wire saa_en,    // SAA1099 on #FF (writes outside the shadow mode)
	input wire opl_en,    // OPL2 on #C4 / #C5
	input wire hdd_image, // the IDE device 0: 0 = the CF card, 1 = the image HDF0 (hdf_ata); HDF1 is device 1
	// image files of the mcu (kg_mcu ENABLE_IMG): HDF0 = slot 4, HDF1 = slot 5 (img_sdc, hdf_ata)
	input wire [7:0] img_mounted,
	input wire [63:0] img_size,
	input wire img_data_wr,
	input wire [8:0] img_data_addr,
	input wire [7:0] img_data,
	input wire img_result_wr,
	input wire [7:0] img_result,
	input wire [15:0] img_sum,
	output wire img_q_wr,
	output wire [23:0] img_q_di,
	input wire img_q_ack,
	input wire zifi_en,   // TS ZiFi (ESP8266) + TS RS232 + EVO RS232 #F8EF..#FFEF (USB UART of the mcu): zifi.vhd of TS-Conf
	input wire [1:0] psg_mix,
	input wire psg_type,
	input wire vga_60hz,
    input wire pause, input wire nmi_button,
	
	// fdc
`ifndef HW_ID2
	output wire fdc_side,
	input wire fdc_rdata,
	input wire fdc_wprt,
	input wire fdc_tr00,
	input wire fdc_index,
	output wire fdc_wg,
	output wire fdc_wr_data,
	output wire fdc_step,
	output wire fdc_dir,
	output wire fdc_motor,
	output wire [1:0] fdc_ds,
`endif
	
	// rom loader
	input wire loader_act,
	input wire [31:0] loader_a,
	input wire [7:0] loader_d,
	input wire loader_wr,

    // sdram
	output wire        sdram_clk,
	inout wire [15:0]  sdram_dq,
	output wire [12:0] sdram_a,
	output wire [1:0]  sdram_dqm,
	output wire [1:0]  sdram_ba,
	output wire        sdram_we_n,
	output wire        sdram_ras_n,
	output wire        sdram_cas_n,
	
	// usb uart
	input wire [7:0]   usb_uart_rx_data,
	input wire [7:0]	 usb_uart_rx_idx,
	output wire [7:0]  usb_uart_tx_data,
	output wire 		 usb_uart_tx_wr,
	output wire 		 usb_uart_tx_mode,
	output wire [7:0]  usb_uart_dll,
	output wire [7:0]  usb_uart_dlm,
	output wire        usb_uart_dll_wr,
	output wire        usb_uart_dlm_wr,
	
	// midi
	output wire        midi_reset_n,
	output wire        midi_tx,
	
	// iorq + wr
    output wire        iowr,
    output wire [15:0] ioa,
    output wire [7:0]  iod
);


    wire fclk = clk_bus;
    wire [15:0] a;
    wire [7:0] d, cpu_di;
    wire mreq_n, iorq_n, rd_n, wr_n, m1_n, rfsh_n;
    wire int_n, wait_n, clkz_out, spiint_n;
    wire csrom, romoe_n, romwe_n, ay_bdir, ay_bc1, ay_clk;
    wire iorq1_n, iorq2_n;
    wire iorqge1 = 1'b0, iorqge2 = 1'b0;
    wire drrdy, atm_pen2, vg_cs_n;
    wire [1:0] vred,vgrn,vblu;
    wire vhsync,vvsync,vcsync;
    wire storage_busy, storage_fault, rom_done;
    wire [7:0] rom_data;
    wire rom_req = csrom && !mreq_n && (!rd_n || !romwe_n);
    wire [7:0] fdc_data, ts_data, gs_data;
    wire fdc_oe, fdc_oe_n, gs_oe;
    wire fdc_busy, fdc_intrq, fdc_drq; // hrdy_fdc (Go): WAIT, bits 7, 6 of port #FF
    wire [7:0] zifi_data, opl_data; // read data of zifi and OPL2 (instances at the sound below)
    wire zifi_oe_n, opl_rd;
    wire ts_read = !iorq_n && !rd_n && a[15] && a[7:0]==8'hfd;
    // used by the CPU below, declared here: without `default_nettype none from the file before (hdmi_top.v
    // of TS-Conf) XST took them as implicit nets and failed on their declarations
    wire zpos, zneg;
    wire rst_n; // global reset
    wire gen_nmi;
    assign cpu_di = d_pre_out;
    t80pa cpu(.RESET_n(rst_n), .CLK(fclk), .CEN_p(zpos), .CEN_n(zneg),
        .WAIT_n(wait_n && (!rom_req || rom_done) && !fdc_busy), .INT_n(int_n),
        .NMI_n(!gen_nmi), .BUSRQ_n(1'b1), .M1_n(m1_n), .MREQ_n(mreq_n),
        .IORQ_n(iorq_n), .RD_n(rd_n), .WR_n(wr_n), .RFSH_n(rfsh_n),
        .OUT0(1'b1), .A(a), .DI(cpu_di), .DO(d), .DIRSet(1'b0),
        .R800_mode(1'b0), .DIR(212'd0));
    assign VGA_R = {4{vred}};
    assign VGA_G = {4{vgrn}};
    assign VGA_B = {4{vblu}};
    assign VGA_HS = vhsync;
    assign VGA_VS = vvsync;
`ifdef HW_ID1
    assign VGA_BLANK = 1'b0;
`else // Mini, Mini G

`endif
    assign ftcs_n=1'b1, espcs_n=1'b1, esp_ft_spi_dis=1'b0;
    assign ftclk=1'b0, ftdo=1'b1, vdac2_sel=1'b0;
    assign midi_reset_n=rst_n;
    assign ioa=a, iod=d, iowr=!iorq_n && !wr_n;
    assign f1_out=zpos;
    wire shadow;
	wire dos;


	wire zclk; // z80 clock for short

	wire rrdy;
	wire [15:0] rddata;

	wire [4:0] rompg;

	wire [7:0] zports_dout;
	wire zports_dataout;
	wire porthit;

	wire csrom_int;


	wire [39:0] kbd_data;
	wire [ 7:0] mus_data;
	wire kbd_stb,mus_xstb,mus_ystb,mus_btnstb,kj_stb;

	wire [ 4:0] kbd_port_data;
	wire [ 4:0] kj_port_data;
	wire [ 7:0] mus_port_data;




	wire [7:0] wait_read,wait_write;
	wire wait_rnw;
	wire wait_start_gluclock;
	wire wait_start_comport;
	wire wait_end;
	wire [7:0] gluclock_addr;
	wire [2:0] comport_addr;
	wire [6:0] waits;




	// config signals
	wire [7:0] not_used0;
	wire [7:0] not_used1;
	wire cfg_vga_on;
	//
	wire [1:0] modes_raster;
	wire       mode_contend_type = 1'b0; // 48/128/+2 or +2a/+3 TODO: take these signals from somewhere
	wire       mode_contend_ena  = 1'b1; // contention enable
	wire       contend;
	//
	wire [3:0] fdd_mask;

	// nmi signals
	wire clr_nmi;
	wire in_nmi;
	wire in_trdemu, trdemu_wr_disable; // TR-DOS emulation of base_trdemu (RAM page #FE)
	wire vg_rdwr_fclk;
	wire [1:0] vg_drv;
	wire [1:0] set_nmi;
	wire imm_nmi;
	wire nmi_buf_clr;

	// breakpoint signals
	wire brk_ena;
	wire [15:0] brk_addr;




	wire [15:0] ideout;
	wire [15:0] idein;
	wire idedataout;


	wire [7:0] zmem_dout;
	wire zmem_dataout;



	reg [3:0] ayclk_gen;


	wire [7:0] received;
	wire [7:0] tobesent;


	wire intrq,drq;
	wire vg_wrFF;


	wire        up_ena;
	wire [ 5:0] up_paladdr;
	wire [ 7:0] up_paldata;
	wire        up_palwr;




	assign zclk = ~clkz_out;


	// RESETTER
	wire genrst;

// rst_in_n of resetter is an asynchronous reset: its sources other than locked (a combination of signals of
	// other modules) are registered, so a glitch does not reset the Z80
	reg rst_req_n = 1'b0;
	always @(posedge fclk) rst_req_n <= resetbtn_n && !loader_act && !storage_busy;
resetter myrst(.clk(fclk), .rst_in_n(rst_req_n && locked), .rst_out_n(rst_n));
    defparam myrst.RST_CNT_SIZE = 6;












	assign ide_rs_n = rst_n;

	// The IDE bus of zports goes to the CF card (device 0, with hdd_image = 0) and to hdf_ata (the images:
	// device 0 with hdd_image = 1, device 1), as ide_mux of the Profi core: the card gets the strobes only
	// when it is device 0, the read data come from the card when it is device 0 and selected, else hdf_ata.
	wire [2:0] ide_a_i;
	wire ide_cs0_n_i, ide_cs1_n_i, ide_rd_n_i, ide_wr_n_i;
	wire hdf_dev, hdf_dev1_here;
	wire [15:0] hdf_dout;
	wire cf_sel = !hdd_image;
	assign ide_a = ide_a_i;
	assign ide_cs0_n = ide_cs0_n_i || !cf_sel;
	assign ide_cs1_n = ide_cs1_n_i || !cf_sel;
	assign ide_rd_n = ide_rd_n_i || !cf_sel;
	assign ide_wr_n = ide_wr_n_i || !cf_sel;
	assign ide_d = (idedataout && cf_sel) ? ideout : 16'hZZZZ;
	assign idein = (cf_sel && !hdf_dev) ? ide_d : hdf_dout;

	assign ide_dir = ~idedataout;





	wire [7:0] peff7;
	wire [7:0] p7ffd;


	wire romrw_en;
	wire cpm_n;
	wire fnt_wr;



	wire cpu_req,cpu_rnw,cpu_wrbsel,cpu_strobe;
	wire [20:0] cpu_addr;
	wire [15:0] cpu_rddata;
	wire [7:0] cpu_wrdata;

	wire cbeg,post_cbeg,pre_cend,cend;

	wire go;


	// AVR SDcard control
	wire       avr_lock_claim,
	           avr_lock_grant,
	           avr_sdcs_n,
	           avr_sd_start;
     	wire [7:0] avr_sd_datain;
	wire [7:0] avr_sd_dataout;

	// ZX SDcard control
	wire       zx_sdcs_n_val,
	           zx_sdcs_n_stb,
	           zx_sd_start;
	wire [7:0] zx_sd_datain;
	wire [7:0] zx_sd_dataout;


	wire tape_read; // data for tapein

	wire beeper_mux; // what is mixed to FPGA beeper output - beeper (0) or tapeout (1)

	wire [2:0] atm_scr_mode;

	wire atm_turbo;


	wire beeper_wr, covox_wr;



	wire [5:0] palcolor; // palette readback




	wire [1:0] int_turbo;
	wire cpu_next;
	wire cpu_stall;

	wire external_port;



//AY control
	always @(posedge fclk)
	begin
		ayclk_gen <= ayclk_gen + 4'd1;
	end

	assign ay_clk = ayclk_gen[3];





	// fix ATM2-style ROM addressing for PENT-like ROM layout.
	// this causes compications when writing to the flashROM from Z80
	// and need to split and re-build old ATM romfiles before burning in
	// flash
//	wire [1:0] adr_fix;
//	assign adr_fix = ~{ rompg[0], rompg[1] };
//	assign rompg0_n = ~adr_fix[0];
//	assign dos_n    =  adr_fix[1];
//	assign rompg2   =  1'b0;//rompg[2];
//	assign rompg3   =  1'b0;//rompg[3];
//	assign rompg4   =  1'b0;//rompg[4];



	wire [3:0] zclk_stall;

	zclock zclock
	(
		.fclk (fclk ),
		.zclk (zclk ),
		.rst_n(rst_n),

		.a(a),

		.mreq_n(mreq_n),
		.iorq_n(iorq_n),
		.m1_n  (m1_n  ),
		.rfsh_n(rfsh_n),

		.modes_raster     (modes_raster     ),
		.mode_contend_type(mode_contend_type),
		.mode_contend_ena (mode_contend_ena ),
		.mode_7ffd_bits   (p7ffd[2:0]       ),
		.contend          (contend          ),

		.zclk_out(clkz_out),

		.zpos(zpos),
		.zneg(zneg),


		.pre_cend(pre_cend),
		.cbeg    (cbeg    ),

		.zclk_stall( cpu_stall | (|zclk_stall) | pause ),
		.turbo     ( {atm_turbo,~(peff7[4])}   ),
		.int_turbo (int_turbo                  ),
		
		.external_port(external_port)
	);



	wire [7:0] dout_ram;
	wire ena_ram;
	wire [7:0] dout_ports;
	wire ena_ports;


	wire [3:0] border;

	wire drive_ff;
	wire drive_00;


	wire       atm_palwr;
	wire [5:0] atm_paldata;

	wire [7:0] fontrom_readback;




	wire int_start;



	// data bus out: either RAM data or internal ports data or 0xFF with unused ports
//	assign d = ena_ram ? dout_ram : ( ena_ports ? dout_ports : ( (drive_ff|drive_00) ? {8{drive_ff}} : 8'bZZZZZZZZ ) );

	wire [7:0] d_pre_out;
	wire d_ena;

assign d_pre_out = drive_00 ? 8'h00 :
        rom_req ? rom_data : ena_ram ? dout_ram :
        fdc_oe ? fdc_data : ts_read ? ts_data : gs_oe ? gs_data :
        !zifi_oe_n ? zifi_data : opl_rd ? opl_data :
        ena_ports ? dout_ports : 8'hff;
    assign csrom = csrom_int && !drive_00;


	zbus zxbus( .iorq_n(iorq_n), .rd_n(rd_n), .wr_n(wr_n), .m1_n(m1_n),
	            .iorq1_n(iorq1_n), .iorq2_n(iorq2_n), .iorqge1(iorqge1), .iorqge2(iorqge2),
	            .porthit(porthit), .drive_ff(drive_ff) );




	/////////////////////////////////////
	// ATM memory pagers instantiation //
	/////////////////////////////////////

	wire pager_off;

	wire        pent1m_ROM;
	wire [ 5:0] pent1m_page;
	wire        pent1m_ram0_0;
	wire        pent1m_1m_on;

	wire atmF7_wr_fclk;

	wire [3:0] dos_turn_off,
	           dos_turn_on;

	wire [ 7:0] page [0:3];
	wire [ 3:0] romnram;
	wire [ 3:0] wrdisable;

	// for reading back data via xxBE port
	wire [ 7:0] rd_pages [0:7];
	wire [ 7:0] rd_ramnrom;
	wire [ 7:0] rd_dos7ffd;
	wire [ 7:0] rd_wrdisables;

	generate

		genvar i;

		for(i=0;i<4;i=i+1)
		begin : instantiate_atm_pagers
			atm_pager #( .ADDR(i) ) atm_pager
			(
				.rst_n(rst_n),
				.fclk (fclk),
				.zpos (zpos),
				.zneg (zneg),
                                
				.za(a),
				.zd(d),
				.mreq_n(mreq_n),
				.rd_n  (rd_n),
				.m1_n  (m1_n),
                                
				.pager_off(pager_off),
                                
				.pent1m_ROM   (pent1m_ROM),
				.pent1m_page  (pent1m_page),
				.pent1m_ram0_0(pent1m_ram0_0),
				.pent1m_1m_on (pent1m_1m_on),
                                
                                
				.in_nmi(in_nmi),
				.in_trdemu(in_trdemu),
				.trdemu_wr_disable(trdemu_wr_disable),
                                
				.atmF7_wr(atmF7_wr_fclk),
                                
				.dos(dos),
                                
				.dos_turn_on (dos_turn_on[i]),
				.dos_turn_off(dos_turn_off[i]),
                                
				.zclk_stall(zclk_stall[i]),
                                
				.page     (page[i]     ),
				.romnram  (romnram[i]  ),
                        	.wrdisable(wrdisable[i]),
                                
				.rd_page0  (rd_pages[i  ]),
				.rd_page1  (rd_pages[i+4]),
                                
				.rd_ramnrom   ( {rd_ramnrom   [i+4], rd_ramnrom   [i]} ),
				.rd_dos7ffd   ( {rd_dos7ffd   [i+4], rd_dos7ffd   [i]} ),
				.rd_wrdisables( {rd_wrdisables[i+4], rd_wrdisables[i]} )
			);

		end

	endgenerate


	///////////////////////////
	// DOS signal controller //
	///////////////////////////

	zdos zdos( .rst_n(rst_n),

	           .fclk(fclk),

	           .dos_turn_on ( |dos_turn_on  ),
	           .dos_turn_off( |dos_turn_off ),

	           .cpm_n(cpm_n),
	           .atm_pen2(atm_pen2),

	           .dos(dos),

	           .zpos(zpos),
	           .m1_n(m1_n),
	           .in_trdemu   (in_trdemu   ),
	           .in_nmi      (in_nmi      ),
	           .clr_nmi     (clr_nmi     ),
	           .vg_rdwr_fclk(vg_rdwr_fclk),
	           .fdd_mask    (fdd_mask    ),
	           .vg_a        (vg_drv      ),
	           .romnram     (romnram[0]  ),
	           .trdemu_wr_disable(trdemu_wr_disable)
	         );




	///////////////////////////
	// Z80 memory controller //
	///////////////////////////

	zmem z80mem
	(
		.fclk (fclk ),
		.rst_n(rst_n),
		
		.zpos(zpos),
		.zneg(zneg),

		.cbeg     (cbeg     ),
		.post_cbeg(post_cbeg),
		.pre_cend (pre_cend ),
		.cend     (cend     ),
		
		.za    (a       ),
		.zd_in (d       ),
		.zd_out(dout_ram), 
		.zd_ena(ena_ram ), 
		.m1_n  (m1_n    ),
		.rfsh_n(rfsh_n  ), 
		.iorq_n(iorq_n  ), 
		.mreq_n(mreq_n  ),
		.rd_n  (rd_n    ), 
		.wr_n  (wr_n    ),

		.win0_romnram(romnram[0]),
		.win1_romnram(romnram[1]),
		.win2_romnram(romnram[2]),
		.win3_romnram(romnram[3]),

		.win0_page(page[0]),
		.win1_page(page[1]),
		.win2_page(page[2]),
		.win3_page(page[3]),

		.win0_wrdisable(wrdisable[0]),
		.win1_wrdisable(wrdisable[1]),
		.win2_wrdisable(wrdisable[2]),
		.win3_wrdisable(wrdisable[3]),

		.romrw_en(romrw_en),

		.rompg  (rompg  ),
		.romoe_n(romoe_n),
		.romwe_n(romwe_n),
		.csrom  (csrom_int),

		.cpu_req   (cpu_req   ),
		.cpu_rnw   (cpu_rnw   ),
		.cpu_wrbsel(cpu_wrbsel),
		.cpu_strobe(cpu_strobe),
		.cpu_addr  (cpu_addr  ),
		.cpu_wrdata(cpu_wrdata),
		.cpu_rddata(cpu_rddata),
		.cpu_stall (cpu_stall ),
		.cpu_next  (cpu_next  ),

		.int_turbo(int_turbo),
		.nmi_buf_clr(nmi_buf_clr)
	);




	wire [20:0] daddr;
	wire dreq;
	wire drnw;
	wire [15:0] drddata;
	wire [15:0] dwrdata;
	wire [1:0] dbsel;




baseconf_sram ram(.clk(fclk), .rst_n(rst_n), .addr(daddr),
        .req(dreq), .rnw(drnw), .cbeg(cbeg), .rrdy(drrdy),
        .rddata(drddata), .wrdata(dwrdata), .bsel(dbsel),
        .ma(sram_addr), .md(sram_data), .we_n(sram_we_n), .oe_n(sram_rd_n));


	wire [1:0] bw;

	wire [20:0] video_addr;
	wire [15:0] video_data;
	wire video_strobe;
	wire video_next;

	arbiter dramarb( .clk(fclk),
	                 .rst_n(rst_n),

	                 .dram_addr(daddr),
	                 .dram_req(dreq),
	                 .dram_rnw(drnw),
	                 .dram_cbeg(cbeg),
	                 .dram_rrdy(drrdy),
	                 .dram_bsel(dbsel),
	                 .dram_rddata(drddata),
	                 .dram_wrdata(dwrdata),

	                 .post_cbeg(post_cbeg),
	                 .pre_cend (pre_cend ),
	                 .cend     (cend     ),

	                 .go(go),
	                 .bw(bw),

	                 .video_addr(video_addr),
	                 .video_data(video_data),
	                 .video_strobe(video_strobe),
	                 .video_next(video_next),

	                 //.cpu_waitcyc(cpu_waitcyc),
			 .cpu_next (cpu_next),
	                 .cpu_req(cpu_req),
	                 .cpu_rnw(cpu_rnw),
	                 .cpu_addr(cpu_addr),
	                 .cpu_wrbsel(cpu_wrbsel),
	                 .cpu_wrdata(cpu_wrdata),
	                 .cpu_rddata(cpu_rddata),
	                 .cpu_strobe(cpu_strobe) );

	video_top video_top
	(
		.clk(fclk),

		.vred(vred),
		.vgrn(vgrn),
		.vblu(vblu),
		.vhsync(vhsync),
		.vvsync(vvsync),
		.vcsync(vcsync),
`ifndef HW_ID1 // Mini, Mini G
        .vblank_out(VGA_BLANK),
`endif

		.zxborder(border),

		.pent_vmode( {peff7[0],peff7[5]} ),
		.atm_vmode (atm_scr_mode),

		.scr_page(p7ffd[3]),

		.vga_on(cfg_vga_on),

		.modes_raster     (modes_raster     ),
		.mode_contend_type(mode_contend_type),
		
		.contend(contend),

		.cbeg     (cbeg     ),
		.post_cbeg(post_cbeg),
		.pre_cend (pre_cend ),
		.cend     (cend     ),

		.video_go    (go          ),
		.video_bw    (bw          ),
		.video_addr  (video_addr  ),
		.video_data  (video_data  ),
		.video_strobe(video_strobe),
		.video_next  (video_next  ),

		.atm_palwr  (atm_palwr  ),
		.atm_paldata(atm_paldata),
		
		.up_ena    (up_ena    ),
		.up_paladdr(up_paladdr),
		.up_paldata(up_paldata),
		.up_palwr  (up_palwr  ),

		.int_start(int_start),

		.fnt_a (a[10:0]),
		.fnt_d (d      ),
		.fnt_wr(fnt_wr ),

		.palcolor(palcolor),

		.fontrom_readback(fontrom_readback)
	);


// RP2040 HID/RTC replaces AVR SPI service.
    assign cfg_vga_on = 1'b1;
    assign modes_raster = {1'b0,vga_60hz};
    assign set_nmi[0] = nmi_button;
    assign tape_read = tape_in;
    assign avr_lock_claim = 1'b0;
    assign avr_sdcs_n = 1'b1;
    assign avr_sd_start = 1'b0;
    assign avr_sd_datain = 8'hff;
    assign rtc_addr = gluclock_addr;
    assign rtc_di = d;
    // The legacy AVR wait request is a level; kg_mcu_rtc expects one clock
    // per host write. Repeating it queues duplicate EEPROM/SPI updates.
    reg rtc_access_seen = 0;
    always @(posedge fclk) begin
        if (!rst_n) rtc_access_seen <= 0;
        else rtc_access_seen <= wait_start_gluclock;
    end
    assign rtc_rd = wait_start_gluclock && !rtc_access_seen && !rd_n;
    assign rtc_wr = wait_start_gluclock && !rtc_access_seen && !wr_n;
    assign wait_read = wait_start_comport ? 8'hff : rtc_do; // COMPORT: zifi.vhd answers #F8EF..#FFEF (no wait)
    assign spiint_n = 1'b1;

assign keyboard_addr = a[15:8];
    assign mouse_addr = a[10:8];
    assign kbd_port_data = keyboard_data;
    assign kj_port_data = joy_data[4:0];
    assign mus_port_data = mouse_data;


	zports zports( .zclk(zclk), .fclk(fclk), .rst_n(rst_n), .zpos(zpos), .zneg(zneg),
	               .din(d), .dout(dout_ports), .dataout(ena_ports),
	               .a(a), .iorq_n(iorq_n), .rd_n(rd_n), .wr_n(wr_n), .porthit(porthit),
	               .ay_bdir(ay_bdir), .ay_bc1(ay_bc1), .border(border),
	               .p7ffd(p7ffd), .peff7(peff7), .mreq_n(mreq_n), .m1_n(m1_n), .dos(dos),
	               .vg_intrq(fdc_intrq), .vg_drq(fdc_drq), .vg_wrFF(vg_wrFF), .vg_cs_n(vg_cs_n),
	               .vg_rdwr_fclk(vg_rdwr_fclk), .vg_drv(vg_drv), .fdd_mask(fdd_mask),
	               .idein(idein), .ideout(ideout), .idedataout(idedataout),
	               .ide_a(ide_a_i), .ide_cs0_n(ide_cs0_n_i), .ide_cs1_n(ide_cs1_n_i),
	               .ide_wr_n(ide_wr_n_i), .ide_rd_n(ide_rd_n_i),

		       .sd_cs_n_val(zx_sdcs_n_val),
		       .sd_cs_n_stb(zx_sdcs_n_stb),
		       .sd_start   (zx_sd_start  ),
		       .sd_datain  (zx_sd_datain ),
		       .sd_dataout (zx_sd_dataout),

	               .keys_in(kbd_port_data),
	               .mus_in (mus_port_data),
	               .kj_in  (kj_port_data ),

	               .tape_read(tape_read),

	               .gluclock_addr(gluclock_addr),
	               .comport_addr (comport_addr ),
	               .wait_start_gluclock(wait_start_gluclock),
	               .wait_start_comport (wait_start_comport ),
	               .wait_rnw  (wait_rnw  ),
	               .wait_write(wait_write),
	               .wait_read (wait_read ),
		
		.atmF7_wr_fclk(atmF7_wr_fclk),

		.atm_scr_mode(atm_scr_mode),
		.atm_turbo   (atm_turbo),
		.atm_pen     (pager_off),
		.atm_cpm_n   (cpm_n),
		.atm_pen2    (atm_pen2),

		.romrw_en(romrw_en),

		.pent1m_ram0_0(pent1m_ram0_0),
		.pent1m_1m_on (pent1m_1m_on),
		.pent1m_page  (pent1m_page),
		.pent1m_ROM   (pent1m_ROM),

		.atm_palwr  (atm_palwr  ),
		.atm_paldata(atm_paldata),

		.beeper_wr(beeper_wr),
		.covox_wr (covox_wr ),

		.fnt_wr(fnt_wr),
		.clr_nmi(clr_nmi),


		.pages(~{ rd_pages[7], rd_pages[6],
		          rd_pages[5], rd_pages[4],
		          rd_pages[3], rd_pages[2],
		          rd_pages[1], rd_pages[0] }),

		.ramnroms  ( rd_ramnrom    ),
		.dos7ffds  ( rd_dos7ffd    ),
		.wrdisables( rd_wrdisables ),

		.palcolor(palcolor),
		.fontrom_readback(fontrom_readback),
	
		.up_ena    (up_ena    ),
		.up_paladdr(up_paladdr),
		.up_paldata(up_paldata),
		.up_palwr  (up_palwr  ),

		.external_port(external_port),
        .shadow_out(shadow),

		.set_nmi(set_nmi[1]),

		.brk_ena (brk_ena ),
		.brk_addr(brk_addr)
	);


	zint zint(
		.fclk(fclk),
		.zpos(zpos),
		.zneg(zneg),

		.int_start(int_start),

		.iorq_n(iorq_n),
		.m1_n  (m1_n  ),

		.wait_n(spiint_n), // spiint_n is 1-0 signal, wait_n is Z-0

		.int_n(int_n)
	);

	znmi znmi
	(
		.rst_n(rst_n),
		.fclk(fclk),
		.zpos(zpos),
		.zneg(zneg),

		.rfsh_n(rfsh_n),
		.m1_n  (m1_n  ),
		.mreq_n(mreq_n),
		.csrom (csrom ),
		.a     (a     ),

		.int_start(int_start),

		.set_nmi(set_nmi),
		.imm_nmi(imm_nmi),
		.clr_nmi(clr_nmi),

		.drive_00(drive_00),

		.in_nmi (in_nmi ),
		.gen_nmi(gen_nmi),
		.nmi_buf_clr(nmi_buf_clr)
	);


	zbreak zbreak
	(
		.rst_n(rst_n),
		.fclk(fclk),
		.zpos(zpos),
		.zneg(zneg),

		.m1_n  (m1_n  ),
		.mreq_n(mreq_n),
		.a     (a     ),

		.imm_nmi(imm_nmi),

		.brk_ena (brk_ena ),
		.brk_addr(brk_addr)
	);






// Local RTC responds synchronously; stretch each service access for 4 bus clocks.
    reg [2:0] service_delay = 0;
    always @(posedge fclk) begin
        if (!rst_n || !wait_start_gluclock) service_delay <= 0;
        else if (service_delay != 4) service_delay <= service_delay + 1'b1;
    end
    assign wait_n = !wait_start_gluclock || service_delay == 4;









//	spi2 zspi( .clock(fclk), .sck(sdclk), .sdo(sddo), .sdi(sddi), .start(sd_start),
//	           .speed(2'b00), .din(sd_datain), .dout(sd_dataout) );
	spihub spihub(

		.fclk (fclk ),
		.rst_n(rst_n),

		.sdcs_n(sdcs_n),
		.sdclk (sdclk ),
		.sddo  (sddo  ),
		.sddi  (sddi  ),

		.zx_sdcs_n_val(zx_sdcs_n_val),
		.zx_sdcs_n_stb(zx_sdcs_n_stb),
		.zx_sd_start  (zx_sd_start  ),
		.zx_sd_datain (zx_sd_datain ),
		.zx_sd_dataout(zx_sd_dataout),

		.avr_lock_in   (avr_lock_claim),
		.avr_lock_out  (avr_lock_grant),
		.avr_sdcs_n    (avr_sdcs_n    ),
		.avr_sd_start  (avr_sd_start  ),
		.avr_sd_datain (avr_sd_datain ),
		.avr_sd_dataout(avr_sd_dataout)


	);





	  //////////////////////////////////////
	 // sound: beeper, tapeout and covox //
	//////////////////////////////////////





    // The FDC of TS-Conf / Profi (hrdy_fdc + the VG93 model of github.com/demyanenko-d/FD1793_1818VG93) on
    // clk_bus, the CPU clock (28 MHz): no clock domain crossing to the CPU bus. busy holds the CPU (WAIT) after a
    // write to a VG93 register until the model took it and paces the port accesses of a turbo CPU.
    // #FF read decode must be a level: vg_wrFF is only a write strobe.
`ifdef HW_ID1
    hrdy_fdc fdc(.clk(fclk), .ds80(1'b0), .reset(!rst_n), .ena_cpu(zpos),
        .a(a), .d(d), .wr_n(wr_n), .rd_n(rd_n), .iorq_n(iorq_n),
        .cs_n(vg_cs_n), .csff_n(!(shadow && a[7:0]==8'hff && !iorq_n)),
        .oe_n(fdc_oe_n), .dout(fdc_data), .busy(fdc_busy), .intrq_o(fdc_intrq), .drq_o(fdc_drq),
        .FDC_SIDE1(fdc_side), .FDC_RDATA(fdc_rdata),
        .FDC_WPRT(fdc_wprt), .FDC_TR00(fdc_tr00), .FDC_INDEX(fdc_index),
        .FDC_WG(fdc_wg), .FDC_WR_DATA(fdc_wr_data), .FDC_STEP(fdc_step),
        .FDC_DIR(fdc_dir), .FDC_MOTOR(fdc_motor), .FDC_DS(fdc_ds));
    // #FF reads come from zports ({intrq, drq, 1, last written bits 4..0}, as in base_trdemu); the FDC
    // still sees them (busy paces the CPU)
    assign fdc_oe = !fdc_oe_n && (a[7:0] != 8'hFF);
`else // Mini, Mini G
    // Mini boards have no physical drive interface. Leave the I/O bus undriven
    // by an absent FDC and report inactive IRQ/DRQ to the port decoder.
    // (the fdc_* ports are not there with HW_ID2)
    assign fdc_oe = 1'b0, fdc_oe_n = 1'b1, fdc_data = 8'h00;
    assign fdc_busy = 1'b0, fdc_intrq = 1'b0, fdc_drq = 1'b0;
`endif
    reg [2:0] sound_div = 0;
    always @(posedge fclk) sound_div <= sound_div + 1'b1;
    wire [7:0] s0a,s0b,s0c,s1a,s1b,s1c;
    wire [15:0] fm0,fm1;
    wire fm_ena;
    turbosound ts(.RESET(!rst_n), .CLK(fclk), .CE(sound_div==0),
        .BDIR(ay_bdir), .BC(a[14]), .DI(d), .DO(ts_data), .AY_MODE(!psg_type),
        .SSG0_AUDIO_A(s0a), .SSG0_AUDIO_B(s0b), .SSG0_AUDIO_C(s0c),
        .SSG1_AUDIO_A(s1a), .SSG1_AUDIO_B(s1b), .SSG1_AUDIO_C(s1c),
        .SSG0_AUDIO_FM(fm0), .SSG1_AUDIO_FM(fm1), .SSG_FM_ENA(fm_ena), .MIDI_TX(midi_tx));
    reg speaker=0, tape=0;
    always @(posedge fclk) begin
        if (!rst_n) begin speaker<=0; tape<=0; end
        else if (beeper_wr) begin speaker<=d[4]; tape<=d[3]; end
    end
    assign beep=speaker, tape_out=tape;

    // covox #FB and Soundrive (#0F, #1F, #3F, #4F, #5F): covox.vhd of TS-Conf; not in the shadow mode (the VG93
    // ports #1F..#7F and SAVPORT2 #4F there)
    wire [7:0] covox_a, covox_b, covox_c, covox_d, covox_fb;
    covox covox(.I_RESET(!rst_n), .I_CLK(fclk), .I_CS(covox_en), .I_ADDR(a[7:0]), .I_DATA(d),
        .I_WR_N(wr_n), .I_IORQ_N(iorq_n), .I_DOS(shadow),
        .O_A(covox_a), .O_B(covox_b), .O_C(covox_c), .O_D(covox_d), .O_FB(covox_fb));

    // SAA1099 (#01FF address, #00FF data): writes outside the shadow mode only (there #FF is the VG93 system
    // port and the ATM palette). 8 MHz enable from clk_bus: 8 / 28.0303 * 2^16 = 18704 (as TS-Conf)
    reg [16:0] acc8 = 17'd0;
    always @(posedge fclk) acc8 <= {1'b0, acc8[15:0]} + 17'd18704;
    wire saa_wr_n = iorq_n || wr_n || a[7:0] != 8'hFF || shadow || !saa_en;
    wire [7:0] saa_l, saa_r;
    saa1099 saa(.clk(fclk), .ena(acc8[16]), .rst_n(rst_n), .cs_n(1'b0), .a0(a[8]), .wr_n(saa_wr_n), .din(d),
        .out_l(saa_l), .out_r(saa_r));

    // OPL2 (#C4 address / status, #C5 data): opl2_top of TS-Conf (jtopl)
    wire opl_port = a[7:1] == 7'b1100010 && opl_en;
    wire opl_cs_n = !(m1_n && !iorq_n && opl_port);
    assign opl_rd = !opl_cs_n && !rd_n;
    wire [15:0] opl_l, opl_r;
    opl2_top opl(.clk(fclk), .reset(!rst_n), .din(d), .a(a[0]), .dout(opl_data), .wr_n(wr_n), .cs_n(opl_cs_n),
        .out_l(opl_l), .out_r(opl_r));

    // TS ZiFi (ESP8266 on the UART pins, #BFEF..#C7EF), TS RS232 and EVO RS232 (16550, #F8EF..#FFEF; in the EVO
    // the AVR answered them) on the USB UART of the mcu: zifi.vhd of TS-Conf
    wire zifi_oe_n_int;
    assign zifi_oe_n = zifi_oe_n_int || !zifi_en;
    zifi zifi(.CLK(fclk), .RESET(!locked), .DS80(1'b0), .A(a), .DI(d), .DO(zifi_data),
        .IORQ_N(iorq_n || !zifi_en), .RD_N(rd_n), .WR_N(wr_n), .ZIFI_OE_N(zifi_oe_n_int), .ENABLED(),
        .USB_UART_RX_DATA(usb_uart_rx_data), .USB_UART_RX_IDX(usb_uart_rx_idx),
        .USB_UART_TX_DATA(usb_uart_tx_data), .USB_UART_TX_WR(usb_uart_tx_wr), .USB_UART_TX_MODE(usb_uart_tx_mode),
        .USB_UART_DLL(usb_uart_dll), .USB_UART_DLM(usb_uart_dlm),
        .USB_UART_DLL_WR(usb_uart_dll_wr), .USB_UART_DLM_WR(usb_uart_dlm_wr),
        .UART_RX(uart_rx), .UART_TX(uart_tx), .UART_CTS(uart_cts));
    wire [20:0] gs_addr;
    wire [7:0] gs_din,gs_dout;
    wire gs_rd_n,gs_wr_n,gs_done;
    wire [14:0] gs_l,gs_r;
    wire gs_req = !gs_rd_n || !gs_wr_n;
    gs gs(.CLK(fclk), .RESET(!rst_n || !resetgsbtn_n),
        .CE(sound_div[0]), .MEM_WAIT_n(!gs_req || gs_done),
        .A(a), .DI(d), .DO(gs_data), .OE(gs_oe), .WR_n(wr_n), .RD_n(rd_n),
        .IORQ_n(iorq_n), .M1_n(m1_n), .MA(gs_addr), .MDI(gs_din), .MDO(gs_dout),
        .MRFSH_n(), .MWE_n(gs_wr_n), .MRD_n(gs_rd_n), .OUT_L(gs_l), .OUT_R(gs_r));
    // F12 hang experiment: the ROM storage and its SDRAM controller were reset by !locked only, so a stuck
    // ROM access survived every Z80 reset. Reset them by the reset keys too (not by rst_n: storage_busy
    // holds rst_n during the SDRAM init, a loop), synchronized to clk.
    reg [1:0] storage_key_rst = 2'b00;
    always @(posedge clk) storage_key_rst <= {storage_key_rst[0], !resetkey_n};
    baseconf_storage storage(.clk(clk), .reset(!locked || storage_key_rst[1]),
        .rom_req(rom_req), .rom_wr(!romwe_n), .rom_addr({rompg,a[13:0]}),
        .rom_din(d), .rom_dout(rom_data), .rom_done(rom_done),
        .gs_req(gs_req), .gs_wr(!gs_wr_n), .gs_addr(gs_addr), .gs_din(gs_dout),
        .gs_dout(gs_din), .gs_done(gs_done),
        .loader_act(loader_act), .loader_wr(loader_wr), .loader_addr(loader_a), .loader_data(loader_d),
        .busy(storage_busy), .fault(storage_fault), .sdram_clk(sdram_clk),
        .sdram_a(sdram_a), .sdram_ba(sdram_ba), .sdram_dqm(sdram_dqm),
        .sdram_ras_n(sdram_ras_n), .sdram_cas_n(sdram_cas_n), .sdram_we_n(sdram_we_n), .sdram_dq(sdram_dq));
    audio_mixer mix(.clk(fclk), .mute(pause), .mode(psg_mix), .speaker(speaker), .tape_in(tape_in),
        .ssg0_a(s0a), .ssg0_b(s0b), .ssg0_c(s0c), .ssg1_a(s1a), .ssg1_b(s1b), .ssg1_c(s1c),
        // an OSD switch Off also mutes the device (its registers keep what was written)
        .covox_a(covox_en ? covox_a : 8'd0), .covox_b(covox_en ? covox_b : 8'd0),
        .covox_c(covox_en ? covox_c : 8'd0), .covox_d(covox_en ? covox_d : 8'd0),
        .covox_fb(covox_en ? covox_fb : 8'd0), .saa_l(saa_en ? saa_l : 8'd0), .saa_r(saa_en ? saa_r : 8'd0),
        .gs_l(gs_l), .gs_r(gs_r), .fm_l(fm0), .fm_r(fm1), .fm_ena(fm_ena),
`ifdef HW_ID2
        .adc_l(adc_in_l), .adc_r(adc_in_r),
`endif
`ifdef HW_ID3
        .esp_l(esp_in_l), .esp_r(esp_in_r),
`endif
        .opl3_l(opl_en ? opl_l : 16'd0), .opl3_r(opl_en ? opl_r : 16'd0), .audio_l(audio_out_l), .audio_r(audio_out_r));


    // Virtual hard disks: the image files HDF0 / HDF1 of the mcu (slots 4, 5) as ATA devices 0 / 1 on the Nemo
    // IDE ports, hdf_ata + img_sdc of karabas-go-modules, as in the Profi core
    wire [7:0] sdc_img_mounted;
    wire [63:0] sdc_img_size;
    wire [1:0] hdf_rd, hdf_wr;
    wire [31:0] hdf_sector;
    wire sdc_busy, sdc_done, sdc_error, sdc_byte_in_strobe;
    wire [2:0] sdc_slot;
    wire [8:0] sdc_byte_addr;
    wire [7:0] sdc_byte_in_data, hdf_out_data;
    wire hdf_own = sdc_slot[2:1] == 2'b10;
    wire sdc_active, hdf_led; // activity (no LED / OSD icon on these boards)
    img_sdc #(.OUT_LATENCY(3), .TIMEOUT(24'd5600000), .RETRIES(2'd3)) img_sdc(.clk(fclk), .reset(!locked),
        .img_mounted(img_mounted), .img_size(img_size), .img_data_wr(img_data_wr), .img_data_addr(img_data_addr),
        .img_data(img_data), .img_result_wr(img_result_wr), .img_result(img_result), .img_sum(img_sum),
        .img_q_wr(img_q_wr), .img_q_di(img_q_di), .img_q_ack(img_q_ack),
        .sdc_img_mounted(sdc_img_mounted), .sdc_img_size(sdc_img_size),
        .sdc_rd({2'b00, hdf_rd, 4'b0000}), .sdc_wr({2'b00, hdf_wr, 4'b0000}), .sdc_sector(hdf_sector),
        .sdc_busy(sdc_busy), .sdc_done(sdc_done), .sdc_error(sdc_error), .sdc_slot(sdc_slot),
        .sdc_byte_in_strobe(sdc_byte_in_strobe), .sdc_byte_addr(sdc_byte_addr), .sdc_byte_in_data(sdc_byte_in_data),
        .sdc_byte_out_data(hdf_out_data), .active(sdc_active));
    hdf_ata hdf_ata(.clk(fclk), .reset(!locked), .ata_reset(!rst_n), .dev0_en(hdd_image), .dev(hdf_dev),
        .dev1_here(hdf_dev1_here), .a(ide_a_i), .cs_n({ide_cs1_n_i, ide_cs0_n_i}), .rd_n(ide_rd_n_i), .wr_n(ide_wr_n_i),
        .din(ideout), .dout(hdf_dout), .img_mounted(sdc_img_mounted[5:4]), .img_size(sdc_img_size),
        .sdc_rd(hdf_rd), .sdc_wr(hdf_wr), .sdc_sector(hdf_sector), .sdc_busy(sdc_busy && hdf_own),
        .sdc_done(sdc_done && hdf_own), .sdc_error(sdc_error), .sdc_byte_in_strobe(sdc_byte_in_strobe && hdf_own),
        .sdc_byte_addr(sdc_byte_addr), .sdc_byte_in_data(sdc_byte_in_data), .sdc_byte_out_data(hdf_out_data),
        .led(hdf_led));

endmodule
