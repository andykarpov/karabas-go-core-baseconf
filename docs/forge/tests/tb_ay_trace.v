`timescale 1ns/1ps
// Replay CPU bus writes captured from Fuse. Compare the BaseConf and TSConf
// port decoders and CE phases, using their shared, source-identical PSG logic.
module tb_ay_trace;
reg clk=0;always #1 clk=~clk;
reg reset=1,write=0;reg [15:0] port=0;reg [7:0] data=0;
reg [2:0] div=0;reg ref_ce=0;
always @(posedge clk) begin div<=div+1'b1;ref_ce<=div==0;end
wire signed [15:0] left[0:1],right[0:1];
genvar k;
generate for(k=0;k<2;k=k+1) begin: paths
 wire [7:0] a,b,c,d,e,f;wire [15:0] fm0,fm1;wire fm_ena;
 turbosound sound(.RESET(reset),.CLK(clk),.CE(k==0 ? div==0 : ref_ce),
  .BDIR(write && port[15] && (k==0 ? port[7:0]==8'hfd : port[3:0]==4'hd)),
  .BC(port[14]),.DI(data),.AY_MODE(1'b1),
  .SSG0_AUDIO_A(a),.SSG0_AUDIO_B(b),.SSG0_AUDIO_C(c),
  .SSG1_AUDIO_A(d),.SSG1_AUDIO_B(e),.SSG1_AUDIO_C(f),
  .SSG0_AUDIO_FM(fm0),.SSG1_AUDIO_FM(fm1),.SSG_FM_ENA(fm_ena));
 audio_mixer mix(.clk(clk),.mute(1'b0),.mode(2'd1),.speaker(1'b0),.tape_in(1'b0),
  .ssg0_a(a),.ssg0_b(b),.ssg0_c(c),.ssg1_a(d),.ssg1_b(e),.ssg1_c(f),
  .covox_a(8'd0),.covox_b(8'd0),.covox_c(8'd0),.covox_d(8'd0),.covox_fb(8'd0),
  .saa_l(8'd0),.saa_r(8'd0),.gs_l(15'd0),.gs_r(15'd0),.fm_l(fm0),.fm_r(fm1),
  .fm_ena(fm_ena),.opl3_l(16'd0),.opl3_r(16'd0),.audio_l(left[k]),.audio_r(right[k]));
end endgenerate
integer input_fd,output_fd,n,cycle=0,next_cycle,bus_port,bus_data,end_cycle;
integer sum0l=0,sum0r=0,sum1l=0,sum1r=0,samples=0,writes=0;
integer s0l,s0r,s1l,s1r;
reg [4095:0] tracefile,pcmfile;
task next_write;
 begin n=$fscanf(input_fd,"%d %h %h\n",next_cycle,bus_port,bus_data);if(n!=3) next_cycle=32'h7fffffff;end
endtask
initial begin
 if(!$value$plusargs("trace=%s",tracefile) || !$value$plusargs("pcm=%s",pcmfile) || !$value$plusargs("cycles=%d",end_cycle)) $fatal(1,"missing arguments");
 input_fd=$fopen(tracefile,"r");output_fd=$fopen(pcmfile,"wb");
 if(!input_fd || !output_fd) $fatal(1,"cannot open files");
 repeat(32) @(negedge clk);reset=0;next_write;
 for(cycle=0;cycle<end_cycle;cycle=cycle+1) begin
  @(negedge clk);
  if(cycle==next_cycle) begin port=bus_port;data=bus_data;write=1;writes=writes+1;end
  if(write && cycle==next_cycle+16) begin write=0;next_write;end
  sum0l=sum0l+left[0];sum0r=sum0r+right[0];sum1l=sum1l+left[1];sum1r=sum1r+right[1];
  // Boxcar anti-alias integration: bus clock / 636, about 44.073 kHz.
  if(cycle%636==635) begin
   s0l=sum0l/636;s0r=sum0r/636;s1l=sum1l/636;s1r=sum1r/636;
   $fwrite(output_fd,"%c%c%c%c%c%c%c%c",s0l[7:0],s0l[15:8],s0r[7:0],s0r[15:8],s1l[7:0],s1l[15:8],s1r[7:0],s1r[15:8]);
   sum0l=0;sum0r=0;sum1l=0;sum1r=0;samples=samples+1;
  end
 end
 if(next_cycle!=32'h7fffffff) $fatal(1,"trace not consumed");
 $display("PASS trace consumed %0d writes, rendered %0d stereo sample pairs",writes,samples);
 $fclose(input_fd);$fclose(output_fd);$finish;
end
endmodule
