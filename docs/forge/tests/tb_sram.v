`timescale 1ns/1ps
module tb_sram;
reg clk=0; always #18 clk=~clk;
reg rst_n=0,req=0,rnw=1;
reg [20:0] addr=0;
reg [15:0] wrdata=0;
reg [1:0] bsel=0;
wire cbeg,rrdy; wire [15:0] rddata,md;
wire [20:0] ma; wire [1:0] we_n,oe_n;
baseconf_sram dut(.*);
reg [7:0] lo[0:2097151],hi[0:2097151];
assign #10 md[7:0]=!oe_n[0] ? lo[ma] : 8'hzz;
assign #10 md[15:8]=!oe_n[1] ? hi[ma] : 8'hzz;
always @(posedge we_n[0]) if(rst_n) lo[ma]=md[7:0];
always @(posedge we_n[1]) if(rst_n) hi[ma]=md[15:8];
always @(negedge clk) if((we_n|oe_n)!=3) $fatal(1,"read/write overlap");
task access(input [20:0] a,input write,input [15:0] data,input [1:0] mask);
begin
 wait(dut.phase==2); @(negedge clk); addr=a;req=1;rnw=!write;wrdata=data;bsel=mask;
 @(posedge cbeg); @(negedge clk); req=0;
 repeat(3) @(negedge clk);
end endtask
integer i; reg [20:0] a;reg [15:0] d;
initial begin
 repeat(8) @(negedge clk);rst_n=1;
 for(i=0;i<200;i=i+1) begin
  a=$random;d=$random;
  access(a,1,d,3);access(a,0,0,0);
  if(rddata!==d || !rrdy) $fatal(1,"SRAM round trip %h got %h expected %h",a,rddata,d);
  access(a,1,16'h5a00,2);access(a,0,0,0);
  if(rddata!=={8'h5a,d[7:0]}) $fatal(1,"upper lane");
  access(a,1,16'h00a5,1);access(a,0,0,0);
  if(rddata!==16'h5aa5) $fatal(1,"lower lane");
 end
 access(21'h1fffff,1,16'h1234,3);access(21'h1fffff,0,0,0);
 if(rddata!==16'h1234) $fatal(1,"highest RAM word");
 $display("PASS sram: 200 random words, byte masks, highest address, bus turnaround");$finish;
end
initial begin #1000000; $fatal(1,"timeout"); end
endmodule
