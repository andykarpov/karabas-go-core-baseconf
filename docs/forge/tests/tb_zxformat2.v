`timescale 1ns/1ps
module tb_zxformat2;
reg clk=0;always #17.83784 clk=~clk;
reg clk8=0;always #62.7027 clk8=~clk8;
reg locked=0,resetbtn_n=0,loader_act=0,loader_wr=0;
reg [31:0] loader_a=0;reg [7:0] loader_d=0;
wire [20:0] ma;wire [15:0] md;wire [1:0] mw,mr;
wire sclk;wire [12:0] sa;wire [1:0] ba,dqm;wire ras,cas,we;wire [15:0] dq;
wire [15:0] ide_d;
wire [2:0] ide_a;wire ide_cs0,ide_cs1,ide_rd,ide_wr;
wire [7:0] rtc_a,rtc_di,rtc_do;
wire rtc_wr,rtc_rd;
assign rtc_do=8'hff;
wire [15:0] audio_l,audio_r;
reg psg_type=0;
reg fastclk=0;always #5.945946 fastclk=~fastclk;
baseconf dut(.clk(fastclk),.clk_bus(clk),.clk8(clk8),.ce(1'b1),.resetbtn_n(resetbtn_n),
 .resetgsbtn_n(1'b0),.locked(locked),.sram_addr(ma),.sram_data(md),.sram_we_n(mw),.sram_rd_n(mr),
 .audio_out_l(audio_l),.audio_out_r(audio_r),.VGA_R(r),.VGA_G(g),.VGA_B(b),.VGA_HS(hs),.VGA_VS(vs),.sddi(1'b1),
 .espcs_in(1'b1),.ftdi(1'b1),.ftint(1'b1),.joy_data(8'h00),.mouse_data(8'hff),
 .keyboard_data(5'b11111),.keyboard_scancode(8'd0),.rtc_do(rtc_do),.rtc_addr(rtc_a),
 .rtc_di(rtc_di),.rtc_wr(rtc_wr),.rtc_rd(rtc_rd),.uart_rx(1'b1),
 .ide_d(ide_d),.ide_a(ide_a),.ide_cs0_n(ide_cs0),.ide_cs1_n(ide_cs1),
 .ide_rd_n(ide_rd),.ide_wr_n(ide_wr),.ide_rdy(1'b1),.tape_in(1'b0),.covox_en(1'b1),.psg_mix(2'd1),
 .psg_type(psg_type),.vga_60hz(1'b0),.pause(1'b0),.nmi_button(1'b0),
 .fdc_rdata(1'b0),.fdc_wprt(1'b0),.fdc_tr00(1'b0),.fdc_index(1'b0),
 .loader_act(loader_act),.loader_a(loader_a),.loader_d(loader_d),.loader_wr(loader_wr),
 .sdram_clk(sclk),.sdram_dq(dq),.sdram_a(sa),.sdram_ba(ba),.sdram_dqm(dqm),
 .sdram_we_n(we),.sdram_ras_n(ras),.sdram_cas_n(cas),
 .usb_uart_rx_data(8'd0),.usb_uart_rx_idx(8'd0));
sdram_model ram(sclk,sa,ba,dqm,ras,cas,we,dq);
sram_model mainram(ma,md,mw,mr);
reg [7:0] program_bytes[0:4095];integer i,p,ram_start;
// Start in every ROM page to test the real reset pager selection.
task emit(input [7:0] byte_value);begin program_bytes[p]=byte_value;p=p+1;end endtask
task outport(input [15:0] port,input [7:0] value);
begin
 emit(8'h01);emit(port[7:0]);emit(port[15:8]);
 emit(8'h3e);emit(value);emit(8'hed);emit(8'h79);
end endtask
task incheck(input [15:0] port,input [7:0] mask,input [7:0] expected);
begin
 if($test$plusargs("fdc_trace")) $display("IN check pc=%h port=%h expected=%h",p,port,expected);
 emit(8'h01);emit(port[7:0]);emit(port[15:8]);
 emit(8'hed);emit(8'h78);emit(8'he6);emit(mask);
 emit(8'hfe);emit(expected);emit(8'h20);emit(8'hfe);
end endtask
task aywrite(input [7:0] register,value);
begin outport(16'hfffd,register);outport(16'hbffd,value);end endtask
integer j,phys,page,wr_count=0;reg [7:0] initial_ram[0:49151];reg old_wr=0;
reg [4095:0] ramfile,tracefile;
integer trace_fd,expected_cycle,expected_port,expected_data,fields;
always @(negedge clk) begin
 if(wr_count>0 && (dut.speaker!==0 || dut.covox!==0)) $fatal(1,"Unexpected speaker/Covox contribution");
 old_wr<=!dut.iorq_n&&!dut.wr_n;
 if(!old_wr&&!dut.iorq_n&&!dut.wr_n) begin
  if(dut.a[7:0]==8'hfd) begin
   fields=$fscanf(trace_fd,"%d %h %h\n",expected_cycle,expected_port,expected_data);
   if(fields!=3 || dut.a!==expected_port[15:0] || dut.d!==expected_data[7:0])
    $fatal(1,"Intro/Fuse write mismatch at %0d: port=%h data=%h expected=%h/%h",wr_count,dut.a,dut.d,expected_port,expected_data);
   $display("PORT %0t %h %h",$time,dut.a,dut.d);wr_count=wr_count+1;
   if(dut.int_turbo!==0) $fatal(1,"not 3.5 MHz");
   if(wr_count==660) begin $display("PASS intro: 660 writes match Fuse at verified 3.5 MHz; speaker/Covox silent");$finish;end
  end
  else if(dut.a[7:0]==8'hfe) $display("BEEPER %0t %h %h",$time,dut.a,dut.d);
 end
end
initial begin
 if(!$value$plusargs("trace=%s",tracefile)) $fatal(1,"missing trace");
 trace_fd=$fopen(tracefile,"r");if(!trace_fd) $fatal(1,"cannot open trace");
 if(!$value$plusargs("ram=%s",ramfile)) $fatal(1,"missing RAM");
 $readmemh(ramfile,initial_ram);
 p=0;emit(8'hf3);
 outport(16'h0ff7,8'h20);outport(16'h4ff7,8'h7a);
 outport(16'h8ff7,8'h7d);outport(16'hcff7,8'h7f);
 outport(16'h0377,8'h03);
 emit(8'hc3);emit(8'h04);emit(8'h60);page=p;
 outport(16'heff7,8'h10);
 emit(8'h31);emit(8'ha7);emit(8'h61); // SP as loader before CALL
 emit(8'hfd);emit(8'h21);emit(8'h3a);emit(8'h5c);
 emit(8'h3e);emit(8'h3f);emit(8'hed);emit(8'h47);
 emit(8'hc3);emit(8'h40);emit(8'h9c);
 #100;locked=1;wait(!dut.storage_busy);
 for(i=0;i<32;i=i+1) for(j=0;j<p;j=j+1) begin
  if(j%2) ram.mem[(25'h200000+i*16384+j)>>1][15:8]=program_bytes[j];
  else ram.mem[(25'h200000+i*16384+j)>>1][7:0]=program_bytes[j];
 end
 for(i=page;i<p;i=i+1) initial_ram[16'h2004+i-page]=program_bytes[i];
 for(i=0;i<49152;i=i+1) begin
  page=i<16384 ? 5 : i<32768 ? 2 : 0;phys=(page*16384+(i%16384))>>1;
  if(i%2) mainram.lo[phys]=initial_ram[i];else mainram.hi[phys]=initial_ram[i];
 end
 @(negedge clk);resetbtn_n=1;
end
initial begin #3000000000; $fatal(1,"intro timeout pc=%h writes=%0d",dut.a,wr_count);end
endmodule
