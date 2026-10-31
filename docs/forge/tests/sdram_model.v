`timescale 1ns/1ps
// Small protocol-checking SDRAM model, not a vendor analog/timing model.
module sdram_model #(
 parameter real T_AC=6.0, T_OH=3.0, INPUT_DELAY=0.0, CLOCK_DELAY=4.3
)(input clk,input [12:0] a,input [1:0] ba,dqm,
 input ras_n,cas_n,we_n,inout [15:0] dq);
reg [15:0] mem[0:2097151];
reg [12:0] row[0:3];reg [3:0] opened=0;
reg [15:0] data;reg drive=0;
reg [23:0] index;integer latency=0;integer refreshes=0;
integer cycles=0,activated[0:3],closed=0,last_refresh=-10;
integer last_write[0:3],j;
initial for(j=0;j<4;j=j+1) begin activated[j]=-100;last_write[j]=-100;end
reg configured=0;
assign dq=drive?data:16'hzzzz;
// Model the forwarded ODDR/pad clock delay. Commands/write data remain ideal;
// read INPUT_DELAY optionally approximates the FPGA input path as well.
wire device_clk;
assign #(CLOCK_DELAY) device_clk=clk;
always @(posedge device_clk) begin
 cycles=cycles+1;
 drive<=#(T_OH+INPUT_DELAY) 0;
 if(latency>0) begin
  latency=latency-1;
  if(latency==0) begin data<=#(T_AC+INPUT_DELAY) mem[index];drive<=#(T_AC+INPUT_DELAY) 1;end
 end
 case({ras_n,cas_n,we_n})
 3'b000: begin
  if(a!==13'h020 || ba!==0 || refreshes<2) $fatal(1,"SDRAM mode/init");
  configured=1;
 end
 3'b010: begin
  for(j=0;j<4;j=j+1) if(opened[j] && (a[10] || ba==j))
   if(cycles-activated[j]<4 || cycles-last_write[j]<2) $fatal(1,"SDRAM tRAS/tWR");
  if(a[10]) opened=0;else opened[ba]=0;
  closed=cycles;
 end
 3'b001: begin
  if(opened!=0 || cycles-closed<2 || cycles-last_refresh<6) $fatal(1,"SDRAM refresh/precharge timing");
  refreshes=refreshes+1;last_refresh=cycles;
 end
 3'b011: begin
  if(!configured || opened[ba] || cycles-closed<2 || cycles-last_refresh<6) $fatal(1,"SDRAM ACT timing/state");
  opened[ba]=1;row[ba]=a;activated[ba]=cycles;
 end
 3'b100,3'b101: begin
  if(!opened[ba] || cycles-activated[ba]<2) $fatal(1,"SDRAM access before ACT/tRCD");
  index={ba,row[ba],a[8:0]};
  if(index>=2097152) $fatal(1,"model capacity exceeded");
  if(!we_n) begin
   last_write[ba]=cycles;
   if(!dqm[0]) mem[index][7:0]=dq[7:0];
   if(!dqm[1]) mem[index][15:8]=dq[15:8];
  end else latency=1; // CL2 starts driving after the following edge, valid by edge +2
 end
 endcase
end
endmodule
