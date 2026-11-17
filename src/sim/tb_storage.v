`timescale 1ns / 1ps
// tb_storage: baseconf_storage with sdram_model (iverilog). The loader fills ROM bytes at the burst pace of
// the Mini G (one byte every 21 clk, the queue must not overflow: fault = 0), the FL item fills OPL4 bytes,
// then the main CPU (ROM reads), the GS (reads / writes above its 64 KiB of block RAM) and the OPL4 (reads
// of port 2, back to back) run together: the data is checked and the clocks from a request to its done
// are counted (mean / max) for the ROM and the GS.
// `define OLD: the storage before the OPL4 (baseconf_sdram, one port, CL 2), for the latency to compare.
module tb_storage;

reg clk = 0;
always #5.946 clk = ~clk;           // 84.09 MHz

reg reset = 1;
reg rom_req = 0, rom_wr = 0;
reg [18:0] rom_addr = 0;
reg [7:0] rom_din = 0;
wire [7:0] rom_dout;
wire rom_done;
reg gs_req = 0, gs_wr = 0;
reg [20:0] gs_addr = 0;
reg [7:0] gs_din = 0;
wire [7:0] gs_dout;
wire gs_done;
reg loader_act = 0, loader_wr = 0;
reg [31:0] loader_addr = 0;
reg [7:0] loader_data = 0;
wire busy, fault;
reg fl_wr = 0;
reg [31:0] fl_a = 0;
reg [7:0] fl_d = 0;
reg [21:0] opl_addr = 0;
reg opl_req = 0;
wire opl_ack;
wire [15:0] opl_rdata;

wire [12:0] sa;
wire [1:0] sba, sdqm;
wire sras, scas, swe, sclk;
wire [15:0] sdq;

baseconf_storage dut(.clk(clk), .reset(reset),
	.rom_req(rom_req), .rom_wr(rom_wr), .rom_addr(rom_addr), .rom_din(rom_din), .rom_dout(rom_dout),
	.rom_done(rom_done),
	.gs_req(gs_req), .gs_wr(gs_wr), .gs_addr(gs_addr), .gs_din(gs_din), .gs_dout(gs_dout), .gs_done(gs_done),
	.loader_act(loader_act), .loader_wr(loader_wr), .loader_addr(loader_addr), .loader_data(loader_data),
	.busy(busy), .fault(fault),
`ifndef OLD
	.fl_wr(fl_wr), .fl_a(fl_a), .fl_d(fl_d),
	.opl_addr(opl_addr), .opl_req(opl_req), .opl_we(1'b0), .opl_wdata(8'd0), .opl_ack(opl_ack),
	.opl_rdata(opl_rdata), .sdram_init_n(1'b1),
`endif
	.sdram_clk(sclk), .sdram_a(sa), .sdram_ba(sba), .sdram_dqm(sdqm), .sdram_ras_n(sras),
	.sdram_cas_n(scas), .sdram_we_n(swe), .sdram_dq(sdq));

`ifdef OLD
sdram_model #(.CL(2), .ROW_BITS(12)) chip(.clk(clk), .ba(sba), .a(sa), .dqm(sdqm), .ras_n(sras), .cas_n(scas),
	.we_n(swe), .dq(sdq));
`else
sdram_model #(.CL(3), .ROW_BITS(12)) chip(.clk(clk), .ba(sba), .a(sa), .dqm(sdqm), .ras_n(sras), .cas_n(scas),
	.we_n(swe), .dq(sdq));
`endif

integer errors = 0;
function [7:0] rom_pat(input [18:0] x); rom_pat = x[7:0] ^ x[15:8] ^ {x[18:16], 5'h15}; endfunction
function [7:0] gs_pat(input [20:0] x); gs_pat = x[7:0] + x[15:8] + {x[20:16], 3'h3}; endfunction
function [7:0] fl_pat(input [20:0] x); fl_pat = x[7:0] ^ 8'h5a ^ x[12:5]; endfunction

// ---------------------------------------------------------------- the loader at the burst pace
integer i;
localparam N = 2048;
task load_byte(input [31:0] adr, input [7:0] val);
	begin
		loader_addr <= adr; loader_data <= val; loader_wr <= 1;
		repeat (3) @(posedge clk);          // ld_wr = one clk_bus
		loader_wr <= 0;
		repeat (18) @(posedge clk);
	end
endtask
task fl_byte(input [31:0] adr, input [7:0] val);
	begin
		fl_a <= adr; fl_d <= val; fl_wr <= 1;
		repeat (3) @(posedge clk);
		fl_wr <= 0;
		repeat (18) @(posedge clk);
	end
endtask

// ---------------------------------------------------------------- the clients
integer rom_n = 0, rom_sum = 0, rom_max = 0;
integer gs_n = 0, gs_sum = 0, gs_max = 0;
integer opl_n = 0;
reg run = 0;
reg [8*8-1:0] dummy;

task rom_read(input [18:0] adr);
	integer c;
	begin
		rom_addr <= adr; rom_wr <= 0; rom_req <= 1; c = 0;
		@(posedge clk);
		while (!rom_done) begin @(posedge clk); c = c + 1; end
		if (rom_dout !== rom_pat(adr)) begin
			errors = errors + 1;
			if (errors < 8) $display("ROM %h: %h, expected %h", adr, rom_dout, rom_pat(adr));
		end
		rom_req <= 0;
		rom_n = rom_n + 1; rom_sum = rom_sum + c; if (c > rom_max) rom_max = c;
	end
endtask

task gs_access(input wr, input [20:0] adr, input [7:0] val);
	integer c;
	begin
		gs_addr <= adr; gs_wr <= wr; gs_din <= val; gs_req <= 1; c = 0;
		@(posedge clk);
		while (!gs_done) begin @(posedge clk); c = c + 1; end
		if (!wr && gs_dout !== val) begin
			errors = errors + 1;
			if (errors < 8) $display("GS %h: %h, expected %h", adr, gs_dout, val);
		end
		gs_req <= 0;
		@(posedge clk);
		if (!wr) begin gs_n = gs_n + 1; gs_sum = gs_sum + c; if (c > gs_max) gs_max = c; end
	end
endtask

// the OPL4: a read after each ack (the engine reads back to back in its busy frames)
`ifndef OLD
always @(posedge clk) begin
	if (opl_ack) begin
		if (opl_rdata[7:0] !== fl_pat({opl_addr[20:1], 1'b0}) || opl_rdata[15:8] !== fl_pat({opl_addr[20:1], 1'b1})) begin
			errors = errors + 1;
			if (errors < 8) $display("OPL %h: %h", opl_addr, opl_rdata);
		end
		opl_n = opl_n + 1;
		opl_req <= 0;
	end else if (run && !opl_req && !$test$plusargs("noopl")) begin
		opl_addr <= {$random} % N; opl_req <= 1;
	end
end
`endif

initial begin
	repeat (20) @(posedge clk);
	reset <= 0;
	@(posedge clk);
	while (busy) @(posedge clk);
	if (fault) begin errors = errors + 1; $display("fault after init"); end

	// the ROM loader (kind 0): N bytes of the main ROM; the FL item: N bytes of the OPL4 ROM
	loader_act <= 1;
	for (i = 0; i < N; i = i + 1) load_byte(i, rom_pat(i));
	loader_act <= 0;
	repeat (40) @(posedge clk);
	if (fault) begin errors = errors + 1; $display("fault: the loader queue overflowed"); end
`ifndef OLD
	for (i = 0; i < N; i = i + 1) fl_byte(i, fl_pat(i));
	repeat (40) @(posedge clk);
`endif
	// the GS writes its pattern above 64 KiB
	for (i = 0; i < 512; i = i + 1) gs_access(1, 21'h10000 + i * 37, gs_pat(21'h10000 + i * 37));

	// everything together
	run <= 1;
	fork
		begin : rom_side
			integer k;
			for (k = 0; k < 3000; k = k + 1) begin
				rom_read({$random} % N);
				repeat (6 + {$random} % 18) @(posedge clk);    // a 14 MHz Z80: one M cycle = 18..24 clk
			end
		end
		begin : gs_side
			integer k;
			reg [20:0] ad;
			for (k = 0; k < 3000; k = k + 1) begin
				ad = 21'h10000 + ({$random} % 512) * 37;
				gs_access(0, ad, gs_pat(ad));
				repeat ({$random} % 12) @(posedge clk);
			end
		end
	join
	run <= 0;
	repeat (40) @(posedge clk);

	$display("ROM reads %0d: mean %0d.%02d max %0d clk; GS reads %0d: mean %0d.%02d max %0d clk; OPL4 reads %0d",
		rom_n, rom_sum / rom_n, (rom_sum * 100 / rom_n) % 100, rom_max,
		gs_n, gs_sum / gs_n, (gs_sum * 100 / gs_n) % 100, gs_max, opl_n);
	if (chip.errors) $display("sdram_model: %0d timing errors", chip.errors);
	$display("tb_storage: %0d errors", errors + chip.errors + fault);
	$finish;
end

initial begin
	#200_000_000;
	$display("tb_storage: timeout");
	$finish;
end

endmodule
