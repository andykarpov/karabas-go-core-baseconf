`timescale 1ns/1ps
// Stock GS ROM, its real memory test/command protocol and MOD player.
module tb_gs_audio;
parameter integer REFERENCE=0;
reg fast=0; always #5.945946 fast=~fast;
reg clk=0; always #17.837838 clk=~clk;
reg ce=0; always @(posedge clk) ce<=~ce;
reg reset=1, run_reset=1;
reg [15:0] host_a=16'hbb;
reg [7:0] host_di=0;
reg host_rd=1,host_wr=1,host_io=1;
wire [7:0] host_do;
wire [20:0] addr;wire [7:0] di,dout;
wire rd_n,wr_n,done,busy,fault;
wire [14:0] left,right;
gs dut(.CLK(clk),.RESET(run_reset),.CE(ce),.MEM_WAIT_n(REFERENCE || (rd_n&&wr_n) || done),
 .A(host_a),.DI(host_di),.DO(host_do),.WR_n(host_wr),.RD_n(host_rd),.IORQ_n(host_io),.M1_n(1'b1),
 .MA(addr),.MDI(di),.MDO(dout),.MWE_n(wr_n),.MRD_n(rd_n),.OUT_L(left),.OUT_R(right));
reg [7:0] rom[0:32767];reg [7:0] mod_data[0:1048575];
reg [20:0] peek_addr=0;wire [7:0] peek_data;
generate if(REFERENCE) begin: ideal
 reg [7:0] mem[0:2097151];
 assign di=mem[addr];assign done=1;assign busy=0;assign fault=0;
 assign peek_data=mem[peek_addr];
 always @(posedge clk) if(!wr_n) mem[addr]<=dout;
 initial begin
  wait(loaded);for(integer k=0;k<32768;k=k+1) mem[k]=rom[k];
 end
end else begin: realmem
 wire sck;wire [12:0] a;wire [1:0] ba,dqm;wire ras,cas,we;wire [15:0] dq;
 baseconf_storage storage(.clk(fast),.reset(reset),.rom_req(1'b0),.rom_wr(1'b0),.rom_addr(19'd0),.rom_din(8'd0),
 .gs_req(!rd_n||!wr_n),.gs_wr(!wr_n),.gs_addr(addr),.gs_din(dout),.gs_dout(di),.gs_done(done),
 .loader_act(1'b0),.loader_wr(1'b0),.loader_addr(32'd0),.loader_data(8'd0),.busy(busy),.fault(fault),
 .sdram_clk(sck),.sdram_a(a),.sdram_ba(ba),.sdram_dqm(dqm),.sdram_ras_n(ras),.sdram_cas_n(cas),.sdram_we_n(we),.sdram_dq(dq));
 sdram_model #(.INPUT_DELAY(3.7)) ram(sck,a,ba,dqm,ras,cas,we,dq);
`ifdef GS_LOCALMEM
 begin: localmem
  assign peek_data=peek_addr<65536 ? storage.gs_local[peek_addr[15:0]] :
    (peek_addr[0] ? ram.mem[peek_addr>>1][15:8] : ram.mem[peek_addr>>1][7:0]);
  initial begin wait(loaded);for(integer k=0;k<32768;k=k+1) storage.gs_local[k]=rom[k];end
 end
`else
 begin: oldmem
  assign peek_data=peek_addr[0] ? ram.mem[peek_addr>>1][15:8] : ram.mem[peek_addr>>1][7:0];
  initial begin wait(loaded);for(integer k=0;k<16384;k=k+1) ram.mem[k]={rom[2*k+1],rom[2*k]};end
 end
`endif
end endgenerate
reg loaded=0,recording=0,old_m1=1,old_ack=0;
integer underruns=0,irqs=0,waits=0,fetches=0;
always @(posedge clk) if(!run_reset) begin
 old_m1<=dut.cpu_m1_n;old_ack<=!dut.cpu_iorq_n&&!dut.cpu_m1_n;
 if(recording) begin
  if(!dut.cpu_m1_n&&old_m1) begin
   fetches=fetches+1;if(dut.cpu_a_bus==16'h13b9) underruns=underruns+1;
  end
  if(!dut.cpu_iorq_n&&!dut.cpu_m1_n&&!old_ack) irqs=irqs+1;
  if(ce&&(!rd_n||!wr_n)&&!done&&dut.z80_unit.tstate==2) waits=waits+1;
 end
end
task write_port(input [15:0] a,input [7:0] value);
begin
 @(negedge clk);host_a=a;host_di=value;host_io=0;host_wr=0;
 repeat(6) @(negedge clk);host_io=1;host_wr=1;host_a=16'hbb;
 repeat(6) @(negedge clk);
end endtask
task read_data(output [7:0] value);
begin
 repeat(24) @(negedge clk);
 @(negedge clk);host_a=16'hb3;host_io=0;host_rd=0;
 repeat(6) @(negedge clk);value=host_do;host_io=1;host_rd=1;host_a=16'hbb;
 repeat(6) @(negedge clk);
end endtask
task command(input [7:0] value);
begin wait(!host_do[0]);repeat(24) @(negedge clk);write_port(16'hbb,value);wait(!host_do[0]);end endtask
task send_data(input [7:0] value);
// A real 14 MHz host executes polling/branch/OUT instructions after a flag
// changes. Do not overwrite its latch while the GS IN cycle is still active.
begin wait(!host_do[7]);repeat(24) @(negedge clk);write_port(16'hb3,value);end endtask
string rom_file,mod_file,pcm_file;
integer mod_size,seconds=30,fd,i;
reg [7:0] pages,handle,physical_page;
reg signed [15:0] sample_l,sample_r;
initial begin
 if(!$value$plusargs("rom=%s",rom_file)||!$value$plusargs("module=%s",mod_file)||
    !$value$plusargs("size=%d",mod_size)||!$value$plusargs("pcm=%s",pcm_file)) $fatal(1,"missing audio arguments");
 if($value$plusargs("seconds=%d",seconds)) begin end
 $readmemh(rom_file,rom);$readmemh(mod_file,mod_data,0,mod_size-1);loaded=1;
 repeat(8) @(negedge clk);reset=0;wait(!busy);repeat(8) @(negedge clk);run_reset=0;
 // Wait for the unmodified ROM to finish testing every RAM page.
 wait(!dut.cpu_m1_n&&dut.cpu_a_bus==16'h026e);
 $display("GS boot ready at %0t reference=%0d",$time,REFERENCE);$fflush();
 read_data(pages);command(8'h23);read_data(pages);
 $display("GS stock ROM reports %0d RAM pages",pages);$fflush();
 if(pages!=62) $fatal(1,"GS full 2MB memory check failed");
 send_data(0);command(8'h12);command(8'hf3);
 wait(!dut.cpu_m1_n&&dut.cpu_a_bus==16'h026e);
 command(8'h23);read_data(pages);
 if(pages!=62) $fatal(1,"GS page count lost after warm reset");
 command(8'h30);read_data(handle);
 $display("GS module handle=%0d, uploading %0d bytes",handle,mod_size);$fflush();
 for(i=0;i<mod_size;i=i+1) send_data(mod_data[i]);
 wait(!host_do[7]);repeat(30) @(negedge clk);
 // Check transport before the ROM changes signed samples into unsigned ones.
 for(i=0;i<mod_size;i=i+1) begin
  peek_addr=21'h8000+(i>>15);#1;physical_page=peek_data;
  peek_addr={physical_page[5:0],15'd0}+(i&32767);#1;
  if(peek_data!==mod_data[i]) $fatal(1,"MOD upload mismatch at %0d: %h expected %h",i,peek_data,mod_data[i]);
 end
 $display("GS MOD upload verified byte-for-byte; warm reset retained 62 pages");$fflush();
 command(8'hd2);
 // Parsing/unsigned conversion is performed by the original ROM.
 wait(!dut.cpu_m1_n&&dut.cpu_a_bus==16'h026e);
 send_data(handle);command(8'h31);read_data(pages);
 $display("GS playing at %0t",$time);$fflush();
 fd=$fopen(pcm_file,"wb");if(!fd) $fatal(1,"cannot open PCM");recording=1;
 repeat(seconds*44100) begin
  #22675.737;sample_l=$signed(left)*2;sample_r=$signed(right)*2;
  $fwrite(fd,"%c%c%c%c",sample_l[7:0],sample_l[15:8],sample_r[7:0],sample_r[15:8]);
 end
 recording=0;$fclose(fd);
 $display("PASS GS audio: seconds=%0d underruns=%0d IRQs=%0d T2-waits=%0d fetches=%0d",seconds,underruns,irqs,waits,fetches);$finish;
end
initial begin
 forever begin #1000000000;$display("GS progress t=%0t bus=%h page=%d recording=%b underruns=%0d",$time,dut.cpu_a_bus,dut.port_xx00_reg,recording,underruns);$fflush();end
end
initial begin #120000000000;$fatal(1,"GS audio timeout");end
endmodule
