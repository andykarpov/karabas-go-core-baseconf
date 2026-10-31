`timescale 1ns/1ps
module tb_storage;
reg clk=0;always #6 clk=~clk;
reg reset=1,rom_req=0,rom_wr=0,gs_req=0,gs_wr=0;
reg [18:0] rom_addr=0;reg [20:0] gs_addr=0;
reg [7:0] rom_din=0,gs_din=0;
wire [7:0] rom_dout,gs_dout;wire rom_done,gs_done;
reg loader_act=0,loader_wr=0;reg [31:0] loader_addr=0;reg [7:0] loader_data=0;
wire busy,fault,sdram_clk;wire [12:0] sdram_a;wire [1:0] sdram_ba,sdram_dqm;
wire sdram_ras_n,sdram_cas_n,sdram_we_n;wire [15:0] sdram_dq;
baseconf_storage dut(.*);
sdram_model ram(sdram_clk,sdram_a,sdram_ba,sdram_dqm,sdram_ras_n,sdram_cas_n,sdram_we_n,sdram_dq);
task load(input [31:0] a,input [7:0] d);
reg [3:0] previous_wp;
begin previous_wp=dut.wp; @(negedge clk);loader_addr=a;loader_data=d;loader_wr=1;
 repeat(3) @(negedge clk);loader_wr=0;
 if((a[31] ? a[30:15]==0 : a[30:19]==0) && dut.wp!==((previous_wp+1)&15))
  $fatal(1,"loader pulse count: addr=%h previous=%d current=%d",a,previous_wp,dut.wp);
 repeat(24) @(negedge clk); end endtask
task romread(input [18:0] a,input [7:0] expected);
begin @(negedge clk);rom_addr=a;rom_req=1;
 wait(rom_done);#1;if(rom_dout!==expected) $fatal(1,"ROM %h got %h expected %h",a,rom_dout,expected);
 @(negedge clk);rom_req=0;repeat(4) @(negedge clk);end endtask
task gsaccess(input [20:0] a,input w,input [7:0] d);
begin @(negedge clk);gs_addr=a;gs_wr=w;gs_din=d;gs_req=1;
 wait(gs_done);#1;if(!w && gs_dout!==d) $fatal(1,"GS %h got %h expected %h",a,gs_dout,d);
 @(negedge clk);gs_req=0;repeat(4) @(negedge clk);end endtask
integer i,j;
initial begin
 repeat(4) @(negedge clk);reset=0;
 wait(!busy);loader_act=1;
 load(0,8'hc3);load(1,8'h12);load(32'h7ffff,8'hab);
 load(32'h80000000,8'hf3);load(32'h80007fff,8'hd4);
 loader_act=0;wait(!busy);
 romread(0,8'hc3);romread(1,8'h12);romread(19'h7ffff,8'hab);
 gsaccess(0,0,8'hf3);gsaccess(21'h7fff,0,8'hd4);
 gsaccess(21'h1fffff,1,8'h77);gsaccess(21'h1ffffe,1,8'h88);
 gsaccess(21'h1fffff,0,8'h77);gsaccess(21'h1ffffe,0,8'h88);
 gsaccess(21'h80000,1,8'h66);romread(0,8'hc3);
 // Every physical 32 KiB RAM page, eight marks 4 KiB apart, like Dune's
 // non-aliasing check. Also test the BRAM/SDRAM boundary and both byte lanes.
 for(i=1;i<64;i=i+1) for(j=0;j<8;j=j+1)
  gsaccess(i*32768+j*4096+16,1,(i*7+j*29)&255);
 for(i=1;i<64;i=i+1) for(j=0;j<8;j=j+1)
  gsaccess(i*32768+j*4096+16,0,(i*7+j*29)&255);
 gsaccess(21'hffff,1,8'h51);gsaccess(21'h10000,1,8'ha2);
 gsaccess(21'hffff,0,8'h51);gsaccess(21'h10000,0,8'ha2);
 // Both requesters remain asserted; neither may starve or be acknowledged twice.
 @(negedge clk);rom_addr=1;rom_req=1;gs_addr=21'h1fffff;gs_req=1;gs_wr=0;
 wait(rom_done&&gs_done);#1;
 if(rom_dout!==8'h12 || gs_dout!==8'h77) $fatal(1,"arbitration");
 repeat(300) @(negedge clk);
 if(!rom_done || !gs_done || ram.refreshes<3) $fatal(1,"held request/refresh");
 rom_req=0;gs_req=0;
 // Change ROM page while a physical SDRAM read is in flight (DOS M1 paging).
 repeat(4) @(negedge clk);rom_addr=0;rom_req=1;
 wait(dut.state==1);@(negedge clk);rom_addr=19'h7ffff;
 wait(rom_done);#1;if(rom_dout!==8'hab) $fatal(1,"stale page completion");
 @(negedge clk);rom_addr=1;#1;if(rom_done) $fatal(1,"stale completion still asserted");
 wait(rom_done);#1;if(rom_dout!==8'h12) $fatal(1,"page switch after completion");
 @(negedge clk);rom_req=0;
 if(fault) $fatal(1,"unexpected loader fault");
 // Illegal loader addresses fail closed instead of aliasing ROM/GS storage.
 loader_act=1;load(32'h00080000,8'hff);
 if(!fault || !busy) $fatal(1,"loader bounds guard");
 $display("PASS storage: ROM/GS isolation, byte lanes, highest pages, arbitration, refresh, loader guard");$finish;
end
initial begin #1000000;$fatal(1,"timeout");end
endmodule
