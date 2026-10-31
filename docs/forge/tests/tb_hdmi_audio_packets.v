`timescale 1ns/1ps
// Actual BaseConf raster + unmodified HDMI signaling/packet/audio logic.
// Core-mode pixel clock only; PLL/serializer electrical behavior is not modeled.
module tb_hdmi_audio_packets;
parameter RATE=48000,DECLARED_CLOCK=28030303;
localparam DIV=DECLARED_CLOCK/RATE;
localparam N=RATE==44100 ? 6272 : 6144;
reg clk=0;always #17.83784 clk=~clk;
reg [1:0] phase=0;always @(posedge clk) phase<=phase+1'b1;
reg mode60=0,reset=1;
wire [1:0] r,g,b;wire hs,vs,blank;
video_top video(.clk(clk),.vred(r),.vgrn(g),.vblu(b),.vhsync(hs),.vvsync(vs),.vcsync(),.vblank_out(blank),
 .zxborder(4'd0),.pent_vmode(2'd0),.atm_vmode(3'd3),.scr_page(1'b0),.vga_on(1'b1),
 .modes_raster({1'b0,mode60}),.mode_contend_type(1'b0),
 .cbeg(phase==0),.post_cbeg(phase==1),.pre_cend(phase==2),.cend(phase==3),
 .video_strobe(phase==3),.video_next(phase==2),.video_data(16'd0),.video_addr(),.video_bw(),.video_go(),
 .atm_palwr(1'b0),.atm_paldata(6'd0),.up_ena(1'b0),.up_palwr(1'b0),.up_paladdr(6'd0),.up_paldata(8'd0),
 .int_start(),.fnt_a(11'd0),.fnt_d(8'd0),.fnt_wr(1'b0),.palcolor(),.fontrom_readback(),.contend());
reg [15:0] ramp=0;reg [23:0] left=0,right=0;reg audio_clk=0;integer ticks=0;
always @(negedge clk) begin
 ramp<=ramp+16'h1357;
 audio_clk<=0;
 if(reset) ticks=0;
 else if(ticks==DIV-1) begin
  ticks=0;audio_clk<=1;left<={ramp,8'h00};right<={~ramp,8'h00};
 end else ticks=ticks+1;
end
wire [23:0] pixels;wire de,ae,vgb,dgb;
`HDMI_SIGNALING dut(.clk(clk),.reset(reset),.rgb({{8{r[0]}},{8{g[0]}},{8{b[0]}}}),
 .hsync(hs),.vsync(vs),.ide(!blank),.audio_en(1'b1),.audio_l(left),.audio_r(right),.audio_clk(audio_clk),
 .data(pixels),.de(de),.ae(ae),.vgb(vgb),.dgb(dgb));
reg [47:0] expected[0:16383];reg [7:0] packet[0:30];
integer pushed=0,popped=0,idx=0,packets=0,acrs=0,maxqueue=0,j,pos,cts,nfield;
reg [23:0] got_l,got_r;
reg previous_packet=0;
always @(posedge clk) begin
 if(reset) previous_packet<=0;
 else begin
  if(previous_packet && (!ae || de || dgb)) $fatal(1,"Data island clipped by active video");
  previous_packet<=dut.enc_packet;
 end
end
always @(posedge clk) begin
 if(reset) begin pushed=0;popped=0;idx=0;packets=0;acrs=0;maxqueue=0;end
 else begin
  if(audio_clk) begin
   if(pushed>=16384) $fatal(1,"test queue capacity");
   expected[pushed]={left,right};pushed=pushed+1;
   if((dut.pkgen.audio_packetizer.buf_end+3'd1)==dut.pkgen.audio_packetizer.buf_beg)
    $fatal(1,"HDMI audio buffer overflow");
  end
  if(pushed-popped>maxqueue) maxqueue=pushed-popped;
  if(dut.packet_ready && dut.packet_valid) begin
   packet[idx]=dut.packet_data;
   if(idx==30) begin
    if(packet[0]==2) begin
     packets=packets+1;
     for(j=0;j<4;j=j+1) if(packet[1][j]) begin
      pos=3+j*7;
      got_l={packet[pos+2],packet[pos+1],packet[pos]};
      got_r={packet[pos+5],packet[pos+4],packet[pos+3]};
      if(popped>=pushed || {got_l,got_r}!==expected[popped])
       $fatal(1,"Audio packet reordered/dropped/corrupt at sample %0d: got=%h/%h expected=%h",popped,got_l,got_r,expected[popped]);
      if((^got_l)^(^packet[pos+6][3:0]) || (^got_r)^(^packet[pos+6][7:4]))
       $fatal(1,"Audio parity error");
      popped=popped+1;
     end
    end else if(packet[0]==1) begin
     cts={packet[4][3:0],packet[5],packet[6]};nfield={packet[7][3:0],packet[8],packet[9]};
     if(nfield!=N) $fatal(1,"Wrong ACR N=%0d expected=%0d",nfield,N);
     // The first measurement starts with reset release, not a sample edge.
     if(acrs>0 && cts!=DIV*(N/128)) $fatal(1,"Wrong ACR CTS=%0d expected=%0d",cts,DIV*(N/128));
     acrs=acrs+1;
    end
    idx=0;
   end else idx=idx+1;
  end
 end
end
task check(input sixty);
begin
 @(negedge clk);reset=1;mode60=sixty;
 repeat(2) @(posedge vs);
 @(negedge clk);reset=0;
 repeat(3) @(posedge vs);
 @(negedge clk);
 if(popped<1000 || pushed-popped>7 || acrs<3) $fatal(1,"Insufficient/draining audio packets");
 $display("PASS HDMI packets: rate=%0d declared_clock=%0d raster=%0d accepted=%0d delivered=%0d packets=%0d ACR=%0d max_pending=%0d",RATE,DECLARED_CLOCK,sixty?60:50,pushed,popped,packets,acrs,maxqueue);
end
endtask
initial begin check(0);check(1);$finish;end
initial begin #300000000;$fatal(1,"Timeout");end
endmodule
