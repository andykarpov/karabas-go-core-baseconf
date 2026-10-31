`timescale 1ns/1ps
// Compare a four-channel interrupt workload against the same GS with zero-wait RAM.
module tb_gs_timing;
parameter integer ROUTED_IO=0;
reg fast=0; always #5.945946 fast=~fast;
reg clk=0; always #17.837838 clk=~clk;
reg ce=0; always @(posedge clk) ce<=~ce;
reg reset=1, run_reset=1;
wire memclk;
`ifdef GS_LEGACY
assign memclk=clk;
`else
assign memclk=fast;
`endif
wire [20:0] addr,ref_addr;
wire [7:0] di,dout,ref_do;
wire rd_n,wr_n,ref_rd_n,ref_wr_n,done,busy,fault;
wire [14:0] l,r,ref_l,ref_r;
gs dut(.CLK(clk),.RESET(run_reset),.CE(ce),.MEM_WAIT_n(!(~rd_n|~wr_n)||done),
 .A(16'd0),.DI(8'd0),.WR_n(1'b1),.RD_n(1'b1),.IORQ_n(1'b1),.M1_n(1'b1),
 .MA(addr),.MDI(di),.MDO(dout),.MWE_n(wr_n),.MRD_n(rd_n),.OUT_L(l),.OUT_R(r));
reg [7:0] reference[0:65535];
gs ref_gs(.CLK(clk),.RESET(run_reset),.CE(ce),.MEM_WAIT_n(1'b1),
 .A(16'd0),.DI(8'd0),.WR_n(1'b1),.RD_n(1'b1),.IORQ_n(1'b1),.M1_n(1'b1),
 .MA(ref_addr),.MDI(reference[ref_addr[15:0]]),.MDO(ref_do),.MWE_n(ref_wr_n),.MRD_n(ref_rd_n),.OUT_L(ref_l),.OUT_R(ref_r));
always @(posedge clk) if(!ref_wr_n) reference[ref_addr[15:0]]<=ref_do;
wire sck;wire [12:0] a;wire [1:0] ba,dqm;wire ras,cas,we;wire [15:0] dq;
reg rom_req=0;reg [18:0] rom_addr=0;wire rom_done;
baseconf_storage storage(.clk(memclk),.reset(reset),.rom_req(rom_req),.rom_wr(1'b0),.rom_addr(rom_addr),.rom_din(8'd0),.rom_done(rom_done),
 .gs_req(~rd_n|~wr_n),.gs_wr(~wr_n),.gs_addr(addr),.gs_din(dout),.gs_dout(di),.gs_done(done),
 .loader_act(1'b0),.loader_wr(1'b0),.loader_addr(32'd0),.loader_data(8'd0),.busy(busy),.fault(fault),
 .sdram_clk(sck),.sdram_a(a),.sdram_ba(ba),.sdram_dqm(dqm),.sdram_ras_n(ras),.sdram_cas_n(cas),.sdram_we_n(we),.sdram_dq(dq));
// Approximate forwarded-clock and DQ input delays from the routed candidate.
// This exercises the capture window; it is not a full board timing model.
sdram_model #(.INPUT_DELAY(ROUTED_IO ? 3.7 : 0.0)) ram(sck,a,ba,dqm,ras,cas,we,dq);
integer i,p=0,acks=0,ref_acks=0,ticks=0,ref_ticks=0,waits=0,cen_count=0;
reg old_ack=0,old_ref_ack=0;
always @(posedge clk) if(!run_reset) begin
 if(!dut.cpu_iorq_n && !dut.cpu_m1_n && !old_ack) acks=acks+1;
 if(!ref_gs.cpu_iorq_n && !ref_gs.cpu_m1_n && !old_ref_ack) ref_acks=ref_acks+1;
 old_ack<=!dut.cpu_iorq_n && !dut.cpu_m1_n;old_ref_ack<=!ref_gs.cpu_iorq_n && !ref_gs.cpu_m1_n;
 if(ce && dut.cnt==373) ticks=ticks+1;
 if(ce && ref_gs.cnt==373) ref_ticks=ref_ticks+1;
 if(ce) begin cen_count=cen_count+1;if((!rd_n||!wr_n)&&!done && dut.z80_unit.tstate==3'd2) waits=waits+1;end
end
task bytecode(input [7:0] v);begin reference[p]=v;p=p+1;end endtask
task phase(input integer contend);
integer a0,b0;
begin
 a0=acks;b0=ref_acks;
 repeat(56000) begin
  @(negedge clk);
  if(contend) begin if(rom_req&&rom_done) begin rom_req=0;rom_addr=rom_addr+1;end else rom_req=1;end
 end
 $display("GS timing contention=%0d: serviced=%0d zero-wait=%0d",contend,acks-a0,ref_acks-b0);
 if(!$test$plusargs("baseline") && (acks-a0 < ref_acks-b0-1)) $fatal(1,"GS missed sample interrupts relative to zero-wait reference");
end endtask
initial begin
 for(i=0;i<65536;i=i+1) reference[i]=0;
 // DI; SP=5FFF; full volumes on all four channels; IM1; EI; HALT/JR HALT.
 bytecode('hf3);bytecode('h31);bytecode('hff);bytecode('h5f);bytecode('h3e);bytecode('h3f);
 for(i=6;i<=9;i=i+1) begin bytecode('hd3);bytecode(i);end
 bytecode('hed);bytecode('h56);bytecode('hfb);bytecode('h76);bytecode('h18);bytecode('hfd);
 p='h38;
 bytecode('hf5);bytecode('hc5);bytecode('hd5);bytecode('he5);
 for(i=0;i<4;i=i+1) begin bytecode('h3a);bytecode(0);bytecode('h60+i);reference['ha000+i*256]=32+i*40;end
 bytecode('h06);bytecode(6);bytecode('h10);bytecode('hfe);
 bytecode('he1);bytecode('hd1);bytecode('hc1);bytecode('hf1);bytecode('hfb);bytecode('hed);bytecode('h4d);
 for(i=0;i<65536;i=i+1) storage.gs_local[i]=reference[i];
 repeat(8) @(negedge clk);reset=0;wait(!busy);repeat(8) @(negedge clk);run_reset=0;
 phase(0);phase(1);
 if(ticks<140 || ref_ticks<140 || fault) $fatal(1,"GS timebase/fault");
 if(l!==ref_l || r!==ref_r || l===0 || r===0) $fatal(1,"GS channel sample/volume mismatch");
 $display("PASS gs timing: fixed 14MHz enables=%0d T2-waits=%0d, IRQ periods=%0d reference=%0d, stereo=%0d/%0d",cen_count,waits,ticks,ref_ticks,$signed(l),$signed(r));$finish;
end
initial begin #10000000;$fatal(1,"GS timing timeout");end
endmodule
