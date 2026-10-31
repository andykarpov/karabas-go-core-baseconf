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
	input wire clk8,      // 8 MHz: the FDC (Go)
	input wire ce,        // clk: the clock before each edge of clk_bus
	input wire resetbtn_n,
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
	input wire covox_en,
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
    wire ts_read = !iorq_n && !rd_n && a[15] && a[7:0]==8'hfd;
    assign cpu_di = d_pre_out;
    t80pa cpu(.RESET_n(rst_n), .CLK(fclk), .CEN_p(zpos), .CEN_n(zneg),
        .WAIT_n(wait_n && (!rom_req || rom_done)), .INT_n(int_n),
        .NMI_n(!gen_nmi), .BUSRQ_n(1'b1), .M1_n(m1_n), .MREQ_n(mreq_n),
        .IORQ_n(iorq_n), .RD_n(rd_n), .WR_n(wr_n), .RFSH_n(rfsh_n),
        .OUT0(1'b1), .A(a), .DI(cpu_di), .DO(d), .DIRSet(1'b0),
        .R800_mode(1'b0), .DIR(212'd0));
    assign VGA_R = {4{vred}};
    assign VGA_G = {4{vgrn}};
    assign VGA_B = {4{vblu}};
    assign VGA_HS = vhsync;
    assign VGA_VS = vvsync;
    assign VGA_BLANK = 1'b0;
    assign ftcs_n=1'b1, espcs_n=1'b1, esp_ft_spi_dis=1'b0;
    assign ftclk=1'b0, ftdo=1'b1, vdac2_sel=1'b0;
    assign uart_tx=1'b1, uart_cts=1'b1;
    assign usb_uart_tx_data=8'd0, usb_uart_tx_wr=1'b0, usb_uart_tx_mode=1'b0;
    assign usb_uart_dll=8'd0, usb_uart_dlm=8'd0, usb_uart_dll_wr=1'b0, usb_uart_dlm_wr=1'b0;
    assign midi_reset_n=rst_n;
    assign ioa=a, iod=d, iowr=!iorq_n && !wr_n;
    assign f1_out=zpos;
    wire shadow;
	wire dos;


	wire zclk; // z80 clock for short

	wire zpos,zneg;

	wire rst_n; // global reset

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
	wire gen_nmi;
	wire clr_nmi;
	wire in_nmi;
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

resetter myrst(.clk(fclk), .rst_in_n(resetbtn_n && locked && !loader_act && !storage_busy), .rst_out_n(rst_n));
    defparam myrst.RST_CNT_SIZE = 6;












	assign ide_rs_n = rst_n;

	assign ide_d = idedataout ? ideout : 16'hZZZZ;
	assign idein = ide_d;

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

	           .dos(dos)
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
    assign wait_read = wait_start_comport ? 8'hff : rtc_do;
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
	               .vg_intrq(fdc_data[7]), .vg_drq(fdc_data[6]), .vg_wrFF(vg_wrFF), .vg_cs_n(vg_cs_n),
	               .idein(idein), .ideout(ideout), .idedataout(idedataout),
	               .ide_a(ide_a), .ide_cs0_n(ide_cs0_n), .ide_cs1_n(ide_cs1_n),
	               .ide_wr_n(ide_wr_n), .ide_rd_n(ide_rd_n),

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
        if (!rst_n || !(wait_start_gluclock || wait_start_comport)) service_delay <= 0;
        else if (service_delay != 4) service_delay <= service_delay + 1'b1;
    end
    assign wait_n = !(wait_start_gluclock || wait_start_comport) || service_delay == 4;









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





    // Keep the Firefly-derived physical drive path, including its own #FF latch.
    // #FF read decode must be a level: vg_wrFF is only a write strobe.
    hrdy_fdc fdc(.clk(fclk), .clk_8(clk8), .reset(!rst_n), .turbo_fdc(1'b0),
        .a(a), .d(d), .m1_n(m1_n), .wr_n(wr_n), .rd_n(rd_n), .iorq_n(iorq_n),
        .cs_n(vg_cs_n), .csff_n(!(shadow && a[7:0]==8'hff && !iorq_n)),
        .oe_n(fdc_oe_n), .dout(fdc_data), .FDC_SIDE1(fdc_side), .FDC_RDATA(fdc_rdata),
        .FDC_WPRT(fdc_wprt), .FDC_TR00(fdc_tr00), .FDC_INDEX(fdc_index),
        .FDC_WG(fdc_wg), .FDC_WR_DATA(fdc_wr_data), .FDC_STEP(fdc_step),
        .FDC_DIR(fdc_dir), .FDC_MOTOR(fdc_motor), .FDC_DS(fdc_ds));
    assign fdc_oe = !fdc_oe_n;
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
    reg [7:0] covox=0;
    always @(posedge fclk) begin
        if (!rst_n) begin speaker<=0; tape<=0; covox<=0; end
        else begin
            if (beeper_wr) begin speaker<=d[4]; tape<=d[3]; end
            if (covox_wr) covox<=d;
        end
    end
    assign beep=speaker, tape_out=tape;
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
    baseconf_storage storage(.clk(clk), .reset(!locked),
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
        .covox_a(8'd0), .covox_b(8'd0), .covox_c(8'd0), .covox_d(8'd0),
        .covox_fb(covox_en ? covox : 8'd0), .saa_l(8'd0), .saa_r(8'd0),
        .gs_l(gs_l), .gs_r(gs_r), .fm_l(fm0), .fm_r(fm1), .fm_ena(fm_ena),
        .opl3_l(16'd0), .opl3_r(16'd0), .audio_l(audio_out_l), .audio_r(audio_out_r));

endmodule
