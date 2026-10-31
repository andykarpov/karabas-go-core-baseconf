`timescale 1ns/1ps
module tb_boot;
reg clk=0;always #17.83784 clk=~clk;
reg clk8=0;always #62.7027 clk8=~clk8;
reg locked=0,resetbtn_n=0,loader_act=0,loader_wr=0;
reg [31:0] loader_a=0;reg [7:0] loader_d=0;
wire [20:0] ma;wire [15:0] md;wire [1:0] mw,mr;
wire sclk;wire [12:0] sa;wire [1:0] ba,dqm;wire ras,cas,we;wire [15:0] dq;
wire [15:0] ide_d;wire [7:0] r,g,b;wire hs,vs;
wire [2:0] ide_a;wire ide_cs0,ide_cs1,ide_rd,ide_wr;
integer ide_reads=0,ide_writes=0;
reg [15:0] ide_write_sample;
// A small ATA register responder tests byte sequencing, not a CF card model.
assign ide_d=!ide_cs0 && !ide_rd ? (ide_a==0 ? (ide_reads==0 ? 16'hab34 : 16'hcd56) : 16'h0050) : 16'hzzzz;
always @(posedge ide_rd) if(!ide_cs0 && ide_a==0) ide_reads=ide_reads+1;
always @(negedge clk) if(!ide_cs0 && !ide_wr) ide_write_sample=ide_d;
always @(posedge ide_wr) if(!ide_cs0 && ide_a==0) begin
 if(ide_write_sample !== (ide_writes==0 ? 16'h1234 : 16'h5678))
  $fatal(1,"IDE word %0d wrong: %h",ide_writes,ide_write_sample);
 ide_writes=ide_writes+1;
end
wire [7:0] rtc_a,rtc_di,rtc_do;
wire rtc_wr,rtc_rd,rtc_tx;
integer rtc_writes=0;
time fdc_write_start;
always @(negedge dut.fdc.fdc_we_n) fdc_write_start=$time;
always @(posedge dut.fdc.fdc_we_n) if($test$plusargs("fdc_trace"))
 $display("FDC WR duration=%0t A=%h data=%h",$time-fdc_write_start,dut.a,dut.d);
kg_mcu_rtc #(.SKIP_0D(0),.SEND_LIMIT(240)) rtc(
 .clk(clk),.rx_stb(1'b0),.rx_cmd(8'd0),.rx_addr(8'd0),.rx_data(8'd0),.busy(1'b0),
 .rtc_a(rtc_a),.rtc_di(rtc_di),.rtc_do(rtc_do),.rtc_cs(1'b1),.rtc_wr_n(!rtc_wr),
 .tx_req(rtc_tx),.tx_data());
always @(posedge clk) if(rtc_tx) rtc_writes=rtc_writes+1;
reg fastclk=0;always #5.945946 fastclk=~fastclk;
baseconf dut(.clk(fastclk),.clk_bus(clk),.clk8(clk8),.ce(1'b1),.resetbtn_n(resetbtn_n),
 .resetgsbtn_n(1'b0),.locked(locked),.sram_addr(ma),.sram_data(md),.sram_we_n(mw),.sram_rd_n(mr),
 .VGA_R(r),.VGA_G(g),.VGA_B(b),.VGA_HS(hs),.VGA_VS(vs),.sddi(1'b1),
 .espcs_in(1'b1),.ftdi(1'b1),.ftint(1'b1),.joy_data(8'h00),.mouse_data(8'hff),
 .keyboard_data(5'b11111),.keyboard_scancode(8'd0),.rtc_do(rtc_do),.rtc_addr(rtc_a),
 .rtc_di(rtc_di),.rtc_wr(rtc_wr),.rtc_rd(rtc_rd),.uart_rx(1'b1),
 .ide_d(ide_d),.ide_a(ide_a),.ide_cs0_n(ide_cs0),.ide_cs1_n(ide_cs1),
 .ide_rd_n(ide_rd),.ide_wr_n(ide_wr),.ide_rdy(1'b1),.tape_in(1'b0),.covox_en(1'b1),.psg_mix(2'd1),
 .psg_type(1'b0),.vga_60hz(1'b0),.pause(1'b0),.nmi_button(1'b0),
 .fdc_rdata(1'b0),.fdc_wprt(1'b0),.fdc_tr00(1'b0),.fdc_index(1'b0),
 .loader_act(loader_act),.loader_a(loader_a),.loader_d(loader_d),.loader_wr(loader_wr),
 .sdram_clk(sclk),.sdram_dq(dq),.sdram_a(sa),.sdram_ba(ba),.sdram_dqm(dqm),
 .sdram_we_n(we),.sdram_ras_n(ras),.sdram_cas_n(cas),
 .usb_uart_rx_data(8'd0),.usb_uart_rx_idx(8'd0));
sdram_model ram(sclk,sa,ba,dqm,ras,cas,we,dq);
sram_model mainram(ma,md,mw,mr);
reg [7:0] program_bytes[0:511];integer i,p;
always @(posedge clk) if($test$plusargs("cpu_trace") && dut.rst_n && dut.zpos) begin
 if(dut.rom_req && dut.rom_done && dut.a<512 && dut.cpu_di!==program_bytes[dut.a])
  $display("BAD ROM %t a=%h di=%h expected=%h m1=%b rd=%b tag=%h data=%h state=%d",$time,dut.a,dut.cpu_di,program_bytes[dut.a],dut.m1_n,dut.rd_n,dut.storage.rom_tag,dut.rom_data,dut.storage.state);
 if(!dut.m1_n && !dut.rd_n && dut.rom_done) $display("FETCH %t %h %h",$time,dut.a,dut.cpu_di);
end
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
task fdcpoll(input [15:0] port,input [7:0] expected);
begin
 emit(8'h01);emit(port[7:0]);emit(port[15:8]);
 emit(8'hed);emit(8'h78);emit(8'hfe);emit(expected);
 emit(8'h20);emit(8'hfa); // retry IN: Firefly commits a write at its next microword
end endtask
initial begin
 p=0;
 emit(8'hf3); // DI
 // Hardware reset intentionally maps ROM31 in every window. Configure ATM pages
 // through CPU I/O, as the BaseConf BIOS does, before attempting RAM accesses.
 outport(16'h0ff7,8'h20); // ROM31 at 0000
 outport(16'h4ff7,8'h7a); // RAM5 at 4000
 outport(16'h8ff7,8'h7d); // RAM2 at 8000
 outport(16'hcff7,8'h7f); // RAM0 at C000
 outport(16'h0177,$test$plusargs("turbo14") ? 8'h0b : 8'h03);
 if($test$plusargs("slow35")) outport(16'heef7,8'h10);

 emit(8'h31);emit(8'h00);emit(8'h80); // LD SP,8000
 emit(8'h3e);emit(8'h5a); // LD A,5A
 emit(8'h32);emit(8'h00);emit(8'h80); // LD (8000),A
 emit(8'h3a);emit(8'h00);emit(8'h80); // LD A,(8000)
 emit(8'hfe);emit(8'h5a); // CP 5A
 emit(8'h20);emit(8'hfe); // JR NZ,$ (failure)
 emit(8'h3e);emit(8'ha5);
 emit(8'h32);emit(8'h01);emit(8'h80);
 // Select RAM255 at C000 through the full 4 MB mapper and exercise FFFF.
 outport(16'hc7f7,8'h00);
 emit(8'h3e);emit(8'h69);emit(8'h32);emit(8'hff);emit(8'hff);
 emit(8'h3a);emit(8'hff);emit(8'hff);emit(8'hfe);emit(8'h69);
 emit(8'h20);emit(8'hfe);
 // Shadow-mode CMOS ports: each CPU write must produce one MCU update.
 outport(16'hdef7,8'h42);
 outport(16'hbef7,8'h3c);
 outport(16'hbef7,8'ha6);
 emit(8'hed);emit(8'h78); // IN A,(C), BC still BEF7
 emit(8'hfe);emit(8'ha6);emit(8'h20);emit(8'hfe);
 // Current BIOS reads xxBD. Legacy xxBE reads remain an alias.
 incheck(16'h00bd,8'h3f,8'h20);incheck(16'h00be,8'h3f,8'h20);
 outport(16'h10bd,8'h34);outport(16'h11bd,8'h12);
 outport(16'h13bd,8'h00); // FDD mask must not corrupt the breakpoint address
 incheck(16'h10bd,8'hff,8'h34);incheck(16'h11bd,8'hff,8'h12);
 incheck(16'h90bd,8'hff,8'h34); // mirror of config read; must not select PSG
 incheck(16'h13bd,8'hff,8'h00); // physical drives, no AVR virtual-drive claims
 // Nemo (#10 low/#11 high) and divIDE-style (#10 twice) transfers.
 incheck(16'h00f0,8'hff,8'h50); // status access initializes byte-sequence state
 incheck(16'h0010,8'hff,8'h34);incheck(16'h0011,8'hff,8'hab);
 incheck(16'h0010,8'hff,8'h56);incheck(16'h0010,8'hff,8'hcd);
 outport(16'h0011,8'h12);outport(16'h0010,8'h34);
 outport(16'h0010,8'h78);outport(16'h0010,8'h56);
 // Real Firefly controller register bus; allow its microword write latency.
 outport(16'h00ff,8'h15); // release reset, drive B, side-select bit set
 for(integer k=0;k<8;k=k+1) emit(8'h00);
 outport(16'h001f,8'hd0); // force interrupt, stop a previous command
 for(integer k=0;k<8;k=k+1) emit(8'h00);
 emit(8'h01);emit(8'h1f);emit(8'h00); // LD BC,001F
 emit(8'hed);emit(8'h78);emit(8'he6);emit(8'h01);
 emit(8'h20);emit(8'hfa); // poll controller BUSY until command stops
 outport(16'h003f,8'h12);
 for(integer k=0;k<8;k=k+1) emit(8'h00);
 fdcpoll(16'h003f,8'h12);
 outport(16'h005f,8'h07);
 for(integer k=0;k<8;k=k+1) emit(8'h00);
 fdcpoll(16'h005f,8'h07);
 incheck(16'h00ff,8'h3f,8'h3f); // controller system-port read path
 emit(8'h3e);emit(8'h02);emit(8'hd3);emit(8'hfe); // red border
 emit(8'h76);emit(8'h18);emit(8'hfd); // HALT loop
 if(p>512) $fatal(1,"Diagnostic exceeds image buffer");
 repeat(20) @(negedge clk);locked=1;
 wait(!dut.storage_busy);
 // Fast memory image deposit: storage/loader is tested separately. No CPU force.
 for(i=0;i<32;i=i+1) begin
  for(integer j=0;j<p;j=j+1) begin
   if(j%2) ram.mem[(25'h200000+i*16384+j)>>1][15:8]=program_bytes[j];
   else ram.mem[(25'h200000+i*16384+j)>>1][7:0]=program_bytes[j];
  end
 end
 @(negedge clk);resetbtn_n=1;
 wait(dut.border==2);
 if(mainram.hi[21'h4000]!==8'h5a || mainram.lo[21'h4000]!==8'ha5 || mainram.lo[21'h1fffff]!==8'h69)
   $fatal(1,"CPU memory writes wrong: %h %h",mainram.lo[21'h4000],mainram.hi[21'h4000]);
 if(rtc_writes!=2) $fatal(1,"Two CPU CMOS writes produced %0d MCU updates",rtc_writes);
 if(ide_reads!=2 || ide_writes!=2) $fatal(1,"IDE physical counts read=%0d write=%0d",ide_reads,ide_writes);
 if(dut.fdc.port_ff_reg!==8'h15 || dut.fdc_side!==0) $fatal(1,"FDC system latch/side select");
 $display("PASS boot: ROM31, ATM RAM255/FFFF, CMOS single updates, BD config/breakpoints, Nemo/divIDE bytes, Firefly registers/system latch, branch/border");$finish;
end
initial begin #2000000;
 $display("CPU a=%h data=%h reset=%b zpos=%b zneg=%b mreq=%b rompg=%h ram=%h border=%h stall=%b",
 dut.a,dut.cpu_di,dut.rst_n,dut.zpos,dut.zneg,dut.mreq_n,dut.rompg,dut.cpu_addr,dut.border,dut.cpu_stall);
 $display("clock phase cbeg=%b preend=%b cend=%b stall=%b pstall=%b clkout=%b turbo=%b prepos=%b preneg=%b intturbo=%b",dut.cbeg,dut.pre_cend,dut.cend,dut.zclock.stall,dut.zclk_stall,dut.clkz_out,dut.zclock.turbo,dut.zclock.pre_zpos,dut.zclock.pre_zneg,dut.zclock.int_turbo);
 $display("FDC clock=%b divider=%h track=%h sector=%h cmd=%h status=%h",dut.fdc.fdc_clk,dut.fdc.f,dut.fdc.vg93_top.track_seen,dut.fdc.vg93_top.sector_seen,dut.fdc.vg93_top.cmd_reg,dut.fdc.vg93_top.status_byte);
 $fatal(1,"boot timeout");end
endmodule
