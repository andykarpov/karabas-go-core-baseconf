`timescale 1ns/1ps
// Actual BaseConf video pipeline plus OSD: all four requested mode families,
// both rasters, and black pixels which must still be marked active by HDMI DE.
module tb_mini_video;
 reg clk=0; always #5 clk=~clk;
 reg [1:0] phase=0; always @(posedge clk) phase<=phase+1'b1;
 reg mode60=0; reg [2:0] mode=3; reg [15:0] command=0;
 wire [1:0] r,g,b; wire hs,vs,blank; wire [23:0] rgb;
 video_top dut(.clk(clk),.vred(r),.vgrn(g),.vblu(b),.vhsync(hs),.vvsync(vs),.vcsync(),.vblank_out(blank),
 .zxborder(4'd0),.pent_vmode(2'd0),.atm_vmode(mode),.scr_page(1'b0),.vga_on(1'b1),
 .modes_raster({1'b0,mode60}),.mode_contend_type(1'b0),
 .cbeg(phase==0),.post_cbeg(phase==1),.pre_cend(phase==2),.cend(phase==3),
 .video_strobe(phase==3),.video_next(phase==2),.video_data(16'd0),.video_addr(),.video_bw(),.video_go(),
 .atm_palwr(1'b0),.atm_paldata(6'd0),.up_ena(1'b0),.up_palwr(1'b0),.up_paladdr(6'd0),.up_paldata(8'd0),
 .int_start(),.fnt_a(11'd0),.fnt_d(8'd0),.fnt_wr(1'b0),.palcolor(),.fontrom_readback(),.contend());
 kg_osd_overlay #(.H_OFFSET(120)) overlay(.clk(clk),.rgb_i({{4{r}},{4{g}},{4{b}}}),.rgb_o(rgb),
 .hsync_i(hs),.vsync_i(vs),.v_offset(mode60?11'd34:11'd64),.osd_command(command));
 task cmd(input [15:0] value);begin @(negedge clk);command=value;repeat(4) @(negedge clk);end endtask
 integer i,j,frame,lines,active_lines,active_pixels,line_pixels,osd_lines;
 reg last_hs,last_vs,checking,line_osd;
 task check_raster(input sixty,input [2:0] video_mode);
 begin
  mode60=sixty;mode=video_mode;
  // Settle through two complete frames before measuring one frame.
  repeat(3) @(posedge vs); @(negedge clk);
  last_hs=hs;last_vs=vs;lines=0;active_lines=0;active_pixels=0;line_pixels=0;osd_lines=0;line_osd=0;
  checking=1;
  while(checking) begin
   @(negedge clk);
   if(!blank) begin
    active_pixels=active_pixels+1;line_pixels=line_pixels+1;
    if(hs||vs) $fatal(1,"Active video overlaps sync: mode=%0d raster=%0d hs=%b vs=%b hc=%d vc=%d ptr=%d linepix=%d",mode,mode60,hs,vs,dut.video_vga_sync_h.hcount,dut.video_sync_v.vcount,dut.video_vga_double.ptr_out,line_pixels);
   end
   if(rgb==24'he0e0e0) begin
    if(blank) $fatal(1,"OSD pixel outside HDMI DE: mode=%0d raster=%0d",mode,mode60);
    line_osd=1;
   end
   if(hs&&!last_hs) begin
    lines=lines+1;
    if(line_pixels) begin
     active_lines=active_lines+1;
     if(line_pixels!=720) $fatal(1,"Active line width=%0d expected 720",line_pixels);
    end
    if(line_osd) osd_lines=osd_lines+1;
    line_pixels=0;line_osd=0;
   end
   if(vs&&!last_vs) checking=0;
   last_hs=hs;last_vs=vs;
  end
  $display("Video mode=%0d raster=%0d lines=%0d active=%0d pixels=%0d OSD=%0d",mode,sixty?60:50,lines,active_lines,active_pixels,osd_lines);
  if(lines!=(sixty?524:640)) $fatal(1,"Wrong total frame height");
  if(active_lines!=(sixty?480:576)) $fatal(1,"Wrong active frame height");
  if(osd_lines!=416) $fatal(1,"OSD footer cropped");
 end endtask
 initial begin
  cmd(16'h2001);
  for(i=0;i<8;i=i+1) begin cmd(16'h21ff);cmd(16'h0000);end
  for(j=0;j<26;j=j+1) begin
   cmd(16'h1100+j);
   for(i=0;i<32;i=i+1) begin cmd(16'h1000+i);cmd(16'h1200);cmd(16'h13f0);end
  end
  cmd(16'h0101);
  check_raster(0,3);check_raster(1,3);
  check_raster(0,0);check_raster(1,0);
  check_raster(0,2);check_raster(1,2);
  check_raster(0,6);check_raster(1,6);
  $display("PASS mini video: blanking, 50/60 Hz, ZX/320/640/text, full OSD");$finish;
 end
 initial begin #300000000;$fatal(1,"Video timeout");end
endmodule
