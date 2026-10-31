`timescale 1ns/1ps
module tb_board;
reg clk=0;always #10 clk=~clk;
reg ftclk=0;always #15 ftclk=~ftclk;
reg sck=0,mosi=0,ss=1;
wire mosi_line = mosi;
wire [7:0] r,g,b;wire hs,vs,vclk,ft_oe;
wire [1:0] mio;assign mio[1]=1'b1;
karabas_go_top dut(.CLK_50MHZ(clk),.MCU_CS_N(ss),.MCU_SCK(sck),.MCU_MOSI(mosi_line),
 .MCU_SPI_FT_CS_N(1'b1),.MCU_SPI_SD2_CS_N(1'b1),.MCU_SPI_IO(mio),
 .VGA_R(r),.VGA_G(g),.VGA_B(b),.VGA_HS(hs),.VGA_VS(vs),.V_CLK(vclk),
 .FT_CLK(ftclk),.FT_OE_N(ft_oe),.FT_INT_N(1'b1),.FT_SPI_MISO(1'b1),
 .FDC_INDEX(1'b0),.FDC_TR00(1'b0),.FDC_WPRT(1'b0),.FDC_RDATA(1'b0),
 .TAPE_IN(1'b0),.FLASH_DO(1'b1),.SD_DET_N(1'b1));
task frame(input [7:0] command,address,value);
reg [23:0] bits;integer i;
begin bits={command,address,value};ss=0;#100;
 for(i=23;i>=0;i=i-1) begin mosi=bits[i];#31.25;sck=1;#31.25;sck=0;end
 #50;ss=1;#1000;end endtask
task control(input [7:0] value);begin frame(8'h09,0,value);end endtask
reg watch_reset=0;
always @(posedge dut.clk_bus) if(watch_reset && dut.machine.gs.RESET)
 $fatal(1,"OSD/Covox command unexpectedly reset GS");
initial begin
 #5000;control(2);
 if({r,g,b,hs,vs}!==26'bz || ft_oe!==0) $fatal(1,"FPGA must release DAC while FT buffer enabled");
 repeat(4) begin @(posedge ftclk);#1;if(vclk!==1) $fatal(1,"FT pixel clock high");
 @(negedge ftclk);#1;if(vclk!==0) $fatal(1,"FT pixel clock low");end
 control(0);if(ft_oe!==1 || dut.ft_video_active!==0) $fatal(1,"FT disable");
 wait(!dut.machine.storage_busy);frame(8'hfe,0,0);#5000;watch_reset=1;
 frame(8'h05,0,0);if(dut.covox_en!==0) $fatal(1,"Covox off");
 frame(8'h05,0,1);if(dut.covox_en!==1) $fatal(1,"Covox on");
 frame(8'h05,5,1);if(dut.kb_vga_60hz!==1 || dut.overlay.v_offset!==34) $fatal(1,"60Hz OSD position");
 frame(8'h05,5,0);if(dut.kb_vga_60hz!==0 || dut.overlay.v_offset!==64) $fatal(1,"50Hz OSD position");
 frame(8'h04,1,1);frame(8'h04,1,0);
 watch_reset=0;
 // Removing GS Reset moves NMI to register 7 and Reset to register 8.
 frame(8'h05,7,1);
 if(dut.kb_nmi!==1 || dut.btn_reset_n!==1 || dut.machine.gs.RESET!==0)
  $fatal(1,"NMI incorrectly resets core or GS");
 frame(8'h05,7,0);
 frame(8'h05,8,1);
 if(dut.machine.rst_n!==0 || dut.machine.gs.RESET!==1) $fatal(1,"OSD reset must reset core and GS");
 frame(8'h05,8,0);#5000;
 if(dut.machine.rst_n!==1 || dut.machine.gs.RESET!==0) $fatal(1,"OSD reset release");
 // Exercise F12 in every HID slot, with another held key and both modifiers.
 for(integer slot=1;slot<=6;slot=slot+1) begin
  frame(1,0,8'h03); // CS+SS must survive reset
  frame(1,slot==1 ? 2 : 1,8'h07); // D before F12 (MCU misses non-first-slot hotkeys)
  frame(1,slot,8'h45);
  if(dut.machine.rst_n!==0 || dut.machine.gs.RESET!==1) $fatal(1,"F12 slot %0d did not reset both CPUs",slot);
  if(dut.filtered_kb_status!==8'h03) $fatal(1,"Reset cleared held shift keys");
  frame(1,slot,0);#5000;
  if(dut.machine.rst_n!==1 || dut.machine.gs.RESET!==0) $fatal(1,"F12 release slot %0d",slot);
  if(dut.filtered_kb_status!==8'h03) $fatal(1,"Reset release cleared held shifts");
  if(slot==1 ? dut.filtered_keys[15:8]!==8'h07 : dut.filtered_keys[7:0]!==8'h07)
   $fatal(1,"Reset lost held D");
  frame(1,slot==1 ? 2 : 1,0);frame(1,0,0);
 end
 // Physical reset uses the same GS reset path.
 frame(8'h04,0,1);
 if(dut.machine.rst_n!==0 || dut.machine.gs.RESET!==1) $fatal(1,"Hardware reset did not reset GS");
 frame(8'h04,0,0);#5000;
 if(dut.machine.rst_n!==1 || dut.machine.gs.RESET!==0) $fatal(1,"Hardware reset release");
 $display("PASS board: FT video ownership; Covox/OSD changes preserve GS; OSD/hardware/F12 reset both CPUs; all F12 slots preserve held keys");$finish;
end
initial begin #2000000;$fatal(1,"board timeout");end
endmodule
