`timescale 1ns/1ps
// Unmodified stock ROM, actual board wrapper and MCU/HID/RTC logic.
// Only external memories, absent peripherals and MCU commands are modeled.
module tb_bios;
reg clk=0; always #10 clk=~clk;
reg sck=0,mosi=0,ss=1;
wire mosi_line=mosi;
wire [1:0] mio; assign mio[1]=1'b1;
wire [20:0] ma; wire [15:0] md; wire [1:0] mw,mr;
wire sclk; wire [12:0] sa; wire [1:0] ba,dqm;
wire ras,cas,we; wire [15:0] dq;
tri1 [15:0] ide_d;
tri1 sd_do;
wire [7:0] r,g,b; wire hs,vs;
karabas_go_top dut(.CLK_50MHZ(clk),.MCU_CS_N(ss),.MCU_SCK(sck),.MCU_MOSI(mosi_line),
 .MCU_SPI_FT_CS_N(1'b1),.MCU_SPI_SD2_CS_N(1'b1),.MCU_SPI_IO(mio),
 .MA(ma),.MD(md),.MWR_N(mw),.MRD_N(mr),
 .SDR_CLK(sclk),.SDR_A(sa),.SDR_BA(ba),.SDR_DQM(dqm),
 .SDR_WE_N(we),.SDR_RAS_N(ras),.SDR_CAS_N(cas),.SDR_DQ(dq),
 .WD(ide_d),.SD_DO(sd_do),.SD_DET_N(1'b1),
 .VGA_R(r),.VGA_G(g),.VGA_B(b),.VGA_HS(hs),.VGA_VS(vs),
 .FT_CLK(1'b0),.FT_INT_N(1'b1),.FT_SPI_MISO(1'b1),
 .FDC_INDEX(1'b0),.FDC_TR00(1'b0),.FDC_WPRT(1'b0),.FDC_RDATA(1'b0),
 .TAPE_IN(1'b0),.FLASH_DO(1'b1));
sdram_model ram(sclk,sa,ba,dqm,ras,cas,we,dq);
sram_model mainram(ma,md,mw,mr);
task frame(input [7:0] command,address,value);
reg [23:0] bits; integer bitno;
begin
 bits={command,address,value};ss=0;#100;
 for(bitno=23;bitno>=0;bitno=bitno-1) begin
  mosi=bits[bitno];#31.25;sck=1;#31.25;sck=0;
 end
 #50;ss=1;#1000;
end endtask
reg [7:0] rom[0:524287],gsrom[0:32767];
integer i,fd,n,milliseconds=50,trace_fd,fetches=0,io_count=0,frames=0,elapsed_ms=0;
// Optional stock-ROM reset dispatch regression (1..10); normal BIOS run unchanged.
integer reset_case=0, zero_loops=0;
reg reset_selected=0, zero_resident=0, zero_autoboot=0;
reg bonus_entered=0;
reg [15:0] bonus_target;
function [7:0] bonus_byte(input integer address);
 integer word_address;
 begin
  word_address=5*8192+(address-16'h4000)/2;
  bonus_byte=address[0] ? mainram.lo[word_address] : mainram.hi[word_address];
 end
endfunction
task reset_pass;
 begin
  $display("PASS BIOS reset case=%0d pc=%04h rom=%02h at %0t",reset_case,dut.machine.a,dut.machine.rompg,$time);
  $fclose(trace_fd);$finish;
 end
endtask
reg running=0,prev_m1=1,prev_io=1;
reg [15:0] last_pc=0;
initial begin
 if($value$plusargs("milliseconds=%d",milliseconds)) begin end
 if($value$plusargs("reset_case=%d",reset_case)) begin end
 trace_fd=$fopen("bios-trace.log","w");
 fd=$fopen("roms/baseconf.rom","rb");n=$fread(rom,fd);$fclose(fd);
 if(n!=524288) $fatal(1,"Wrong stock ROM size");
 fd=$fopen("roms/gs105b.rom","rb");n=$fread(gsrom,fd);$fclose(fd);
 if(n!=32768) $fatal(1,"Wrong GS ROM size");
 wait(!dut.machine.storage_busy);
 // Real power-on RAM contains bits, not four-state X. A reproducible nonzero
 // pattern lets the BIOS reject resident-program CRCs without poisoning T80.
 for(i=0;i<2097152;i=i+1) begin
  mainram.lo[i]=(i^(i>>8)^8'ha5)&255;
  mainram.hi[i]=~((i^(i>>8)^8'ha5)&255);
  ram.mem[i]=16'ha55a;
 end
 // Fast initial image deposit; loader transactions have separate regressions.
 for(i=0;i<262144;i=i+1) ram.mem[1048576+i]={rom[2*i+1],rom[2*i]};
 for(i=0;i<65536;i=i+1) dut.machine.storage.gs_local[i]=8'ha5;
 for(i=0;i<32768;i=i+1) dut.machine.storage.gs_local[i]=gsrom[i];
 // Erased EEPROM plus valid RTC control/time data. The stock BIOS owns defaults.
 for(i=0;i<256;i=i+1) frame(8'hfa,i,8'hff);
 frame(8'hfa,8'h00,8'h00);frame(8'hfa,8'h02,8'h00);frame(8'hfa,8'h04,8'h12);
 frame(8'hfa,8'h06,8'h02);frame(8'hfa,8'h07,8'h27);frame(8'hfa,8'h08,8'h10);
 frame(8'hfa,8'h09,8'h26);frame(8'hfa,8'h0a,8'h00);frame(8'hfa,8'h0b,8'h02);
 frame(8'hfa,8'h0c,8'h00);frame(8'hfa,8'h0d,8'h80);
 if(reset_case!=0) begin
  frame(4,0,1);
  case(reset_case)
   1: frame(1,0,2); // CS = left Shift
   2: frame(1,0,1); // SS = left Ctrl
   3: frame(1,1,8'h07); // D
   4: frame(1,1,8'h06); // C
   5: frame(1,1,8'h0b); // H
   6: frame(1,1,8'h16); // S
   7: frame(1,1,8'h27); // 0
   8: begin frame(1,1,8'h04);frame(1,2,8'h05);end // A+B
   9: begin frame(1,1,8'h04);frame(1,2,8'h05);frame(1,3,8'h06);end // A+B+C
   10: frame(1,0,3); // CS+SS
  endcase
  frame(1,6,8'h45); // F12 last: the firmware's first-slot shortcut check misses it
 end
 frame(8'hfe,0,0);running=1;
 if(reset_case!=0) begin
  frame(4,0,0);#20000;
  if(dut.machine.rst_n!==0 || dut.machine.gs.RESET!==1) $fatal(1,"F12 did not hold both CPUs reset");
  frame(1,6,0);
 end
 repeat(milliseconds) begin
  #1000000;
  elapsed_ms=elapsed_ms+1;
  // Stock BIOS explicitly waits for release of 0 after clearing resident/autoboot.
  if(reset_case==7 && zero_loops>=2 && !reset_selected) begin
   frame(1,1,0);reset_selected=1;
  end
  if(elapsed_ms%100==0 || elapsed_ms==milliseconds) begin
  $display("BIOS t=%0t pc=%04h rom=%02h fetches=%0d io=%0d frames=%0d border=%h",$time,last_pc,dut.machine.rompg,fetches,io_count,frames,dut.machine.border);
  $display(" bus a=%h di=%h mreq=%b rd=%b wait=%b romreq=%b done=%b stall=%b/%b phase=%b state=%d tag=%h gsreq=%b gsack=%b",dut.machine.a,dut.machine.cpu_di,dut.machine.mreq_n,dut.machine.rd_n,dut.machine.wait_n,dut.machine.rom_req,dut.machine.rom_done,dut.machine.cpu_stall,dut.machine.zclk_stall,dut.machine.zpos,dut.machine.storage.state,dut.machine.storage.rom_tag,dut.machine.gs_req,dut.machine.gs_done);
  end
 end
 if(reset_case!=0) $fatal(1,"Stock BIOS reset case %0d never reached expected destination",reset_case);
 $fclose(trace_fd);
 $writememh("bios-sram-hi.hex",mainram.hi);
 $writememh("bios-sram-lo.hex",mainram.lo);
 $display("BIOS observation ended: no automatic boot-success assertion yet");
 $finish;
end
always @(negedge vs) if(running) frames=frames+1;
always @(posedge dut.clk_bus) if(running) begin
 prev_m1<=dut.machine.m1_n;prev_io<=dut.machine.iorq_n;
 if(!dut.machine.m1_n && prev_m1) begin
  last_pc=dut.machine.a;fetches=fetches+1;
  // These ROM PCs are checked against the pinned ROM hash by bios-reset-test.
  if(reset_case!=0) begin
   if(dut.machine.rompg==31 && dut.machine.a<16'h4000) begin
    if(dut.machine.a==16'h0398) zero_resident=1;
    if(dut.machine.a==16'h0388) zero_autoboot=1;
    if(dut.machine.a==16'h01a7) zero_loops=zero_loops+1;
    if(dut.machine.a==16'h02e4) begin
     if(reset_case<8) $fatal(1,"Single reset key wrongly selected keyboard test");
     reset_selected=1;
    end
    if(dut.machine.a==16'h02f5 && reset_case==3) reset_selected=1;
    if(dut.machine.a==16'h0264 && reset_case==7) begin
     if(!reset_selected || !zero_resident || !zero_autoboot) $fatal(1,"0 did not clear flags and wait for release");
     reset_pass;
    end
   end
   if((reset_case==1 || reset_case==2) && dut.machine.a==0 &&
      dut.machine.rompg==(reset_case==1 ? 30 : 28)) reset_pass;
   if(reset_case==3 && reset_selected && dut.machine.a==16'h5ff8) reset_pass;
   if((reset_case>=4 && reset_case<=6 || reset_case>=8) && dut.machine.a==16'h6000) begin
    if(bonus_byte(16'h6000)!=8'h01 || bonus_byte(16'h6011)!=8'hda ||
       bonus_byte(16'h601a)!=8'hca || bonus_byte(16'h6023)!=8'hc2)
     $fatal(1,"Unexpected unpacked stock CMOS/help dispatch");
    case(reset_case)
     4: bonus_target={bonus_byte(16'h601c),bonus_byte(16'h601b)}; // COLTEST
     5: bonus_target={bonus_byte(16'h6025),bonus_byte(16'h6024)}; // PRHELP
     6: bonus_target=16'h6026; // CDE0
     default: begin
      if(!reset_selected) $fatal(1,"Keyboard test bypassed multi-key branch");
      bonus_target={bonus_byte(16'h6013),bonus_byte(16'h6012)}; // TSTKEY
     end
    endcase
    bonus_entered=1;
   end
   if(bonus_entered && dut.machine.a==bonus_target) reset_pass;
  end
  if($test$plusargs("trace")) $fdisplay(trace_fd,"FETCH %0t %02h:%04h",$time,dut.machine.rompg,last_pc);
 end
 if(!dut.machine.iorq_n && prev_io && dut.machine.m1_n) begin
  io_count=io_count+1;
  $fdisplay(trace_fd,"IO %0t %s %04h %02h rtc=%02h",$time,dut.machine.wr_n?"R":"W",dut.machine.a,dut.machine.d,dut.rtc_addr);
 end
end
initial begin #10000000000;$fatal(1,"BIOS harness watchdog");end
endmodule
