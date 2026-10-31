`timescale 1ns/1ps
module tb_ay;
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
integer chip,regno;
reg [7:0] value,mask;
integer cycle,last_edge,edges,high_cycles,low_cycles;
reg previous;
initial begin
 psg_type=$test$plusargs("ym");
 p=0;
 emit(8'hf3);
 outport(16'h0ff7,8'h20);outport(16'h4ff7,8'h7a);
 outport(16'h8ff7,8'h7d);outport(16'hcff7,8'h7f);
 outport(16'h0377,$test$plusargs("turbo14") ? 8'h0b : 8'h03);
 // Leave permanent DOS, then execute in RAM to exit shadow mode. EEF7 is
 // deliberately ignored in shadow mode by this BaseConf revision.
 emit(8'hc3);emit(8'h00);emit(8'hc0);ram_start=p;
 outport(16'heff7,$test$plusargs("slow35") ? 8'h10 : 8'h00);
 // ZX-Format 2's real register-output sequence (LD B,D / OUT(C),A /
 // LD B,E / OUTD / DEC A), from the unpacked intro at A38F..A3DA.
 // Put distinct values in RAM, then transfer backwards to registers 10..0.
 for(regno=0;regno<11;regno=regno+1) begin
  emit(8'h3e);emit((regno*19+3)&255);
  emit(8'h32);emit(regno);emit(8'h80);
 end
 outport(16'hfffd,8'hff);
 emit(8'h21);emit(8'h0a);emit(8'h80); // LD HL,800A
 emit(8'h11);emit(8'hbf);emit(8'hff); // LD DE,FFBF
 emit(8'h0e);emit(8'hfd); // LD C,FD
 emit(8'h3e);emit(10); // LD A,10
 for(regno=10;regno>=0;regno=regno-1) begin
  emit(8'h42);emit(8'hed);emit(8'h79); // LD B,D; OUT(C),A
  emit(8'h43);emit(8'hed);emit(8'hab);emit(8'h3d); // LD B,E; OUTD; DEC A
 end
 for(regno=0;regno<11;regno=regno+1) begin
  mask=(regno==1 || regno==3 || regno==5) ? 8'h0f :
       (regno==6 || regno>=8) ? 8'h1f : 8'hff;
  outport(16'hfffd,regno);
  incheck(16'hfffd,mask,((regno*19+3)&255)&mask);
 end
 outport(16'h00fe,3);
 // Exercise each register through the real T80, port decoder and TurboSound bus.
 // The two chips get distinct patterns; no forced CPU or audio signals.
 for(chip=0;chip<2;chip=chip+1) begin
  outport(16'hfffd,chip==0 ? 8'hff : 8'hfe);
  for(regno=0;regno<14;regno=regno+1) begin
   value=(regno*19+chip*37+3)&255;
   mask=(regno==1 || regno==3 || regno==5 || regno==13) ? 8'h0f :
        (regno==6 || regno==8 || regno==9 || regno==10) ? 8'h1f : 8'hff;
   aywrite(regno,value);incheck(16'hfffd,mask,value&mask);
  end
  for(regno=0;regno<14;regno=regno+1) aywrite(regno,0);
  aywrite(7,8'h3f);
  aywrite(chip==0 ? 8 : 9,chip==0 ? 15 : 14);
 end
 // ACB: first chip A on left at 255; second chip B on right at AY=215/YM=192.
 outport(16'h00fe,1);
 for(i=0;i<64;i=i+1) emit(0);
 outport(16'hfffd,8'hfe);aywrite(9,0);
 outport(16'hfffd,8'hff);aywrite(0,250);aywrite(1,0);aywrite(7,8'h3e);
 outport(16'h00fe,2);
 emit(8'h76);emit(8'h18);emit(8'hfe);
 #100;locked=1;wait(!dut.storage_busy);
 for(i=0;i<32;i=i+1) begin
  for(integer j=0;j<p;j=j+1) begin
   if(j%2) ram.mem[(25'h200000+i*16384+j)>>1][15:8]=program_bytes[j];
   else ram.mem[(25'h200000+i*16384+j)>>1][7:0]=program_bytes[j];
  end
 end
 for(i=ram_start;i<p;i=i+1) begin
  if((i-ram_start)%2) mainram.lo[(i-ram_start)>>1]=program_bytes[i];
  else mainram.hi[(i-ram_start)>>1]=program_bytes[i];
 end
 @(negedge clk);resetbtn_n=1;
 wait(dut.border==1);repeat(16) @(negedge clk);
 if(dut.int_turbo!==($test$plusargs("turbo14") ? 2'b11 : $test$plusargs("slow35") ? 2'b00 : 2'b01))
  $fatal(1,"CPU speed selection failed: int_turbo=%b",dut.int_turbo);
 if(audio_l!==16'd8160 || audio_r!==(psg_type ? 16'd6144 : 16'd6880))
  $fatal(1,"AY constant signal is corrupted: L=%h R=%h",audio_l,audio_r);
 wait(dut.border==2);repeat(32) @(negedge clk);
 last_edge=-1;edges=0;high_cycles=0;low_cycles=0;previous=(audio_l!=0);
 // 16 half-periods of a ~438 Hz pure tone: noise disabled by register 7.
 for(cycle=0;cycle<512000;cycle=cycle+1) begin
  @(negedge clk);
  if(audio_r!==0 || (audio_l!==0 && audio_l!==8160))
   $fatal(1,"Unexpected AY sample cycle=%0d L=%h R=%h",cycle,audio_l,audio_r);
  if(audio_l==8160) high_cycles=high_cycles+1;else low_cycles=low_cycles+1;
  if((audio_l!=0)!=previous) begin
   if(last_edge>=0 && cycle-last_edge!=32000)
    $fatal(1,"AY tone edge spacing %0d, expected 32000 bus clocks",cycle-last_edge);
   previous=(audio_l!=0);last_edge=cycle;edges=edges+1;
  end
 end
 if(edges<15 || high_cycles<240000 || low_cycles<240000)
  $fatal(1,"AY tone stuck/unbalanced: edges=%0d high=%0d low=%0d",edges,high_cycles,low_cycles);
 $display("PASS ay: real CPU OUTD mirrored-port and register read/write on both chips; fixed stereo levels; pure tone %0d edges with exact period and no stray samples; type=%0d",edges,psg_type);
 $finish;
end
initial begin #30000000;
 $display("AY diagnostic CPU pc=%h border=%h reset=%b",dut.a,dut.border,dut.rst_n);
 $fatal(1,"AY diagnostic timeout (including register readback failure)");end
endmodule
