// Port decode of opl4_kg (ZXM-MoonSound CPLD firmware 1.01: IN #C6 / #C7 moves the wave ports to #C2 / #C3).
// Run from src/rtl/sound/opl4:
//   iverilog -g2005 -o /tmp/t.out ../../../sim/tb_opl4_ports.v opl4_kg.v opl4.v opl4_powtab.v opl4_inctab.v opl3_fm_gen.v && vvp /tmp/t.out
// Prints errors=0 when the decode is right (a few seconds).
`timescale 1ns/1ps
module tb;
reg clk=0, clk28=0, rst=1; always #6 clk=~clk; always #18 clk28=~clk28;
reg [7:0] A=0, DI=0; reg iorq_n=1, m1_n=1, rd_n=1, wr_n=1, dos=0;
wire sel; wire [7:0] DO; wire irq; wire [21:0] ma; wire mreq, mwe; wire [7:0] mwd;
reg mack=0; always @(posedge clk) mack <= mreq && !mack;
opl4_kg u(.CLK(clk),.CLK28(clk28),.RESET(rst),.A(A),.DI(DI),.DO(DO),.IORQ_n(iorq_n),.M1_n(m1_n),.RD_n(rd_n),.WR_n(wr_n),
 .DOS(dos),.INTERP(1'b0),.SEL(sel),.IRQ(irq),.MEM_ADDR(ma),.MEM_REQ(mreq),.MEM_WE(mwe),.MEM_WDATA(mwd),.MEM_ACK(mack),
 .MEM_RDATA(16'h0),.OUT_L(),.OUT_R(),.SAMPLE_T());
integer err=0;
task chk(input [7:0] a, input d, input r, input exp); begin
  A=a; dos=d; #50; iorq_n=0; if(r) rd_n=0; else wr_n=0; #100;
  if (sel!==exp) begin err=err+1; $display("FAIL %h dos=%0d rd=%0d sel=%b exp=%b", a,d,r,sel,exp); end
  rd_n=1; wr_n=1; iorq_n=1; #400; end endtask
initial begin
  #300 rst=0; #300;
  chk(8'h7E,0,0,1); chk(8'h7F,0,1,1); chk(8'h7E,1,0,0); chk(8'h7F,1,1,0);
  chk(8'hC2,0,0,0); chk(8'hC3,0,1,0); chk(8'hC4,1,1,1); chk(8'hC5,1,0,1);
  chk(8'hC6,1,0,1);            // write C6: no switch
  chk(8'hC2,1,0,0);
  chk(8'hC6,1,1,1);            // read C6: switch
  chk(8'hC2,1,0,1); chk(8'hC3,1,1,1); chk(8'hC2,0,0,1); chk(8'h7E,0,0,0); chk(8'h7F,0,1,0);
  chk(8'hC4,0,1,1); chk(8'hC1,0,0,0); chk(8'hC8,0,0,0);
  m1_n=0; chk(8'hC4,0,1,0); m1_n=1;
  rst=1; #300 rst=0; #300;
  chk(8'h7E,0,0,1); chk(8'hC2,0,0,0);
  chk(8'hC7,0,1,1); chk(8'hC3,0,1,1); chk(8'h7F,0,1,0);
  $display("errors=%0d", err); $finish;
end
endmodule
