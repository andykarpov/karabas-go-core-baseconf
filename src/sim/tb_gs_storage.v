`timescale 1ns / 1ps
// tb_gs_storage (ISim): the GS on z80-silicon (gs.v of TS-Conf, SILICON = 1) with baseconf_storage and
// sdram_model, wired as in baseconf.v. The ROM loader writes gs_memtest.bin (gs_memtest.asm of TS-Conf) at
// 80000000 (the GS block RAM) while the GS is held; the GS then writes / reads its RAM in the block RAM
// (#4000) and in the SDRAM (pages 2..5, port 2), while the OPL4 reads port 2 back to back. Prints the
// speed of the GS in the timed loop of the ROM and "tb_gs_storage: 0 errors".
module tb_gs_storage;

reg clk = 0, fclk = 0;
always #5.946 clk = ~clk;              // 84.09 MHz
always #17.838 fclk = ~fclk;           // 28.03 MHz, its edges on edges of clk

reg st_reset = 1, gs_reset = 1;
reg loader_act = 0, loader_wr = 0;
reg [31:0] loader_addr = 0;
reg [7:0] loader_data = 0;
wire busy, fault;

reg [2:0] sound_div = 0;
always @(posedge fclk) sound_div <= sound_div + 1'b1;

wire [20:0] gs_addr;
wire [7:0] gs_din, gs_dout, gs_do;
wire gs_rd_n, gs_wr_n, gs_done, gs_oe;
wire [14:0] gs_l, gs_r;
wire gs_req = !gs_rd_n || !gs_wr_n;
gs gs(.CLK(fclk), .RESET(gs_reset),
	.CE(sound_div[0]), .CE_N(!sound_div[0]), .MEM_WAIT(gs_req && !gs_done), .SAMPLE_T(),
	.A(16'hFFFF), .DI(8'hFF), .DO(gs_do), .OE(gs_oe), .WR_n(1'b1), .RD_n(1'b1),
	.IORQ_n(1'b1), .M1_n(1'b1), .MA(gs_addr), .MDI(gs_din), .MDO(gs_dout),
	.MRFSH_n(), .MWE_n(gs_wr_n), .MRD_n(gs_rd_n), .OUT_L(gs_l), .OUT_R(gs_r));

reg [21:0] opl_addr = 0;
reg opl_req = 0;
wire opl_ack;
wire [15:0] opl_rdata;
integer opl_n = 0;
reg opl_run = 0;
always @(posedge clk) begin
	if (opl_ack) begin opl_req <= 0; opl_n = opl_n + 1; end
	else if (opl_run && !opl_req) begin opl_addr <= opl_addr + 22'd2; opl_req <= 1; end
end

wire [12:0] sa;
wire [1:0] sba, sdqm;
wire sras, scas, swe, sclk;
wire [15:0] sdq;
wire [7:0] rom_dout;
wire rom_done;
baseconf_storage storage(.clk(clk), .reset(st_reset), .sdram_init_n(1'b1),
	.rom_req(1'b0), .rom_wr(1'b0), .rom_addr(19'd0), .rom_din(8'd0), .rom_dout(rom_dout), .rom_done(rom_done),
	.gs_req(gs_req), .gs_wr(!gs_wr_n), .gs_addr(gs_addr), .gs_din(gs_dout), .gs_dout(gs_din), .gs_done(gs_done),
	.loader_act(loader_act), .loader_wr(loader_wr), .loader_addr(loader_addr), .loader_data(loader_data),
	.busy(busy), .fault(fault),
	.fl_wr(1'b0), .fl_a(32'd0), .fl_d(8'd0),
	.opl_addr(opl_addr), .opl_req(opl_req), .opl_we(1'b0), .opl_wdata(8'd0), .opl_ack(opl_ack),
	.opl_rdata(opl_rdata),
	.sdram_clk(sclk), .sdram_a(sa), .sdram_ba(sba), .sdram_dqm(sdqm), .sdram_ras_n(sras),
	.sdram_cas_n(scas), .sdram_we_n(swe), .sdram_dq(sdq));
sdram_model #(.CL(3), .ROW_BITS(8)) sdr(.clk(clk), .ba(sba), .a(sa), .dqm(sdqm), .ras_n(sras), .cas_n(scas),
	.we_n(swe), .dq(sdq));

reg [7:0] rom [0:1023];
integer i, errors = 0, rom_len = 0;
initial begin
	for (i = 0; i < 1024; i = i + 1) rom[i] = 8'hxx;
	$readmemh("gs_memtest.hex", rom);
	for (i = 0; i < 1024; i = i + 1) if (rom[i] !== 8'hxx) rom_len = i + 1;
end

// the port #03 of the GS (port_xx03_reg): #55 the timed loop starts, #AA all passed, 1..6 a failed test
reg [7:0] res = 0;
real t55 = 0, taa = 0;
always @(posedge fclk) if (gs.port_xx03_reg != res) begin
	res = gs.port_xx03_reg;
	$display("tb_gs_storage: port #03 = %h at %0.0f ns", res, $realtime);
	if (res == 8'h55) t55 = $realtime;
	if (res == 8'hAA) taa = $realtime;
end

initial begin
	repeat (20) @(posedge clk);
	st_reset <= 0;
	@(posedge clk);
	while (busy) @(posedge clk);
	loader_act <= 1;
	for (i = 0; i < rom_len; i = i + 1) begin
		loader_addr <= 32'h80000000 + i; loader_data <= rom[i]; loader_wr <= 1;
		repeat (3) @(posedge clk);
		loader_wr <= 0;
		repeat (18) @(posedge clk);
	end
	repeat (40) @(posedge clk);
	loader_act <= 0;
	opl_run <= 1;
	repeat (40) @(posedge clk);
	gs_reset <= 0;
	wait (res == 8'hAA || (res != 8'h00 && res != 8'h55));
	repeat (100) @(posedge clk);
	if (res != 8'hAA) begin errors = errors + 1; $display("tb_gs_storage: the GS test failed: %h", res); end
	if (fault) begin errors = errors + 1; $display("tb_gs_storage: storage fault"); end
	errors = errors + sdr.errors;
	if (sdr.errors) $display("tb_gs_storage: %0d errors of the SDRAM model", sdr.errors);
	$display("tb_gs_storage: GS %0.2f MHz in the timed loop (17500 T in %0.0f ns), OPL4 %0d reads",
		17500.0 * 1000.0 / (taa - t55), taa - t55, opl_n);
	$display("tb_gs_storage: %0d errors", errors);
	$finish;
end

initial begin
	#20_000_000;
	$display("tb_gs_storage: timeout, port #03 = %h", res);
	$display("tb_gs_storage: 1 errors");
	$finish;
end

endmodule
