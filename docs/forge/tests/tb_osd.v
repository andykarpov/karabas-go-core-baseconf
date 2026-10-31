`timescale 1ns/1ps
// BaseConf doubles 320/262 source lines to 640/524 VGA lines. Check the
// actual overlay pixels against its visible window, including the footer.
module tb_osd;
reg clk=0;always #5 clk=~clk;
reg hs=0,vs=0,mode60=0;reg [15:0] command=0;
wire [23:0] rgb;
kg_osd_overlay #(.H_OFFSET(120)) dut(.clk(clk),.rgb_i(24'd0),.rgb_o(rgb),
 .hsync_i(hs),.vsync_i(vs),.v_offset(mode60 ? 11'd34 : 11'd64),.osd_command(command));
task cmd(input [15:0] v);begin @(negedge clk);command=v;repeat(4) @(negedge clk);end endtask
integer i,x,y,f,line,pixels,rows,first,last,total,start_visible,end_visible;
reg row_lit;
task raster(input m);
begin
 mode60=m;total=m?524:640;start_visible=m?36:48;end_visible=m?516:624;
 rows=0;first=-1;last=-1;
 for(f=0;f<3;f=f+1) begin
  for(line=0;line<total;line=line+1) begin
   row_lit=0;
   for(x=0;x<896;x=x+1) begin
    @(negedge clk);hs=x<64;vs=line<6;
    if(rgb==24'he0e0e0) row_lit=1;
   end
   if(f==2&&row_lit) begin
    rows=rows+1;if(first<0) first=line;last=line;
    if(line<start_visible||line>=end_visible) $fatal(1,"OSD cropped in %0d Hz: row=%0d visible=[%0d,%0d)",m?60:50,line,start_visible,end_visible);
   end
  end
 end
 if(rows!=416) $fatal(1,"OSD incomplete: %0d rows instead of 416",rows);
 $display("OSD %0d Hz: all 26 character rows visible, VGA lines %0d..%0d",m?60:50,first,last);
end endtask
initial begin
 cmd(16'h2001);
 for(i=0;i<8;i=i+1) begin cmd(16'h21ff);cmd(16'h0000);end
 for(y=0;y<26;y=y+1) begin
  cmd(16'h1100+y);
  for(i=0;i<32;i=i+1) begin cmd(16'h1000+i);cmd(16'h1200);cmd(16'h13f0);end
 end
 cmd(16'h0101);raster(0);raster(1);raster(0);
 $display("PASS osd: complete menu and footer inside both raster windows, including live switches");$finish;
end
initial begin #100000000;$fatal(1,"OSD timeout");end
endmodule
