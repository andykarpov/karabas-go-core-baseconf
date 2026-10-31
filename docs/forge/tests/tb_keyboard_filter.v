`timescale 1ns/1ps
module tb_keyboard_filter;
reg clk=0; always #5 clk=~clk;
reg reset=1; reg [7:0] status=0,scan=0; reg upd=0;
reg [47:0] keys=0;
wire [7:0] fs,fo; wire [47:0] fk; wire fu;
baseconf_keyboard_filter dut(clk,reset,status,keys,scan,upd,fs,fk,fo,fu);
reg prev=0; reg [7:0] captured[0:255]; integer count=0,consumed=0;
always @(posedge clk) begin
 prev<=fu;
 if(!reset && fu!=prev) begin captured[count]=fo;count=count+1;end
end
task send(input [7:0] v);
 begin @(negedge clk);scan=v;upd=~upd;repeat(24) @(negedge clk);end
endtask
task expect_byte(input [7:0] v);
 begin
  if(consumed>=count || captured[consumed]!==v)
   $fatal(1,"byte %0d expected %h got %h count %0d",consumed,v,captured[consumed],count);
  consumed=consumed+1;
 end
endtask
task empty;
 begin if(consumed!=count) $fatal(1,"Unexpected output: %0d bytes",count-consumed);end
endtask
reg [7:0] usages[0:7],codes[0:7]; integer i,j;
initial begin
 usages[0]='h29;codes[0]='h76;usages[1]='h0d;codes[1]='h3b;
 usages[2]='h15;codes[2]='h2d;usages[3]='h13;codes[3]='h4d;
 usages[4]='h3f;codes[4]='h0b;usages[5]='h40;codes[5]='h83;
 usages[6]='h41;codes[6]='h0a;usages[7]='h42;codes[7]='h01;
 #100;reset=0;
 for(i=0;i<8;i=i+1) begin
  // Both Win keys, every reserved key, every HID slot, Win-first release.
  for(j=0;j<6;j=j+1) begin
   status=(j%2) ? 8'h80 : 8'h08;keys=0;keys[j*8 +:8]=usages[i];#50;
   if(fk!==0 || fs!==0) $fatal(1,"Shortcut escaped slot %0d",j);
   status=0;#50;if(fk!==0) $fatal(1,"Shortcut escaped on modifier release");
   keys=0;#50;keys[j*8 +:8]=usages[i];#50;
   if(fk!==keys) $fatal(1,"Ordinary key blocked");keys=0;#50;
  end
  send('he0);send('h27);send(codes[i]);send(codes[i]);
  send('he0);send('hf0);send('h27);send(codes[i]);
  send('hf0);send(codes[i]);empty;
  send(codes[i]);send('hf0);send(codes[i]);
  expect_byte(codes[i]);expect_byte('hf0);expect_byte(codes[i]);empty;
 end
 // A key held before Win still needs its matching break, without a repeat.
 send('h3b);expect_byte('h3b);send('he0);send('h1f);send('h3b);
 send('hf0);send('h3b);expect_byte('hf0);expect_byte('h3b);
 send('he0);send('hf0);send('h1f);empty;
 // Key-first release with both Win keys held: one release does not unmask.
 send('he0);send('h1f);send('he0);send('h27);
 send('h3b);send('hf0);send('h3b);send('he0);send('hf0);send('h1f);
 send('h3b);send('hf0);send('h3b);send('he0);send('hf0);send('h27);empty;
 // Removed GS shortcut: Win+G is now an ordinary G on both paths.
 status=8'h08;keys=48'h0a;#50;
 if(fk!==keys || fs!==0) $fatal(1,"Removed Menu+G shortcut still blocked");
 status=0;keys=0;#50;
 send('he0);send('h1f);send('h34);send('hf0);send('h34);
 send('he0);send('hf0);send('h1f);
 expect_byte('h34);expect_byte('hf0);expect_byte('h34);empty;
 // Extended arrows and their complete break prefixes survive unchanged.
 send('he0);send('h75);send('he0);send('hf0);send('h75);
 expect_byte('he0);expect_byte('h75);expect_byte('he0);expect_byte('hf0);expect_byte('h75);empty;
 // Pause's embedded E1/F0 bytes must not affect the prefix decoder.
 send('he1);send('h14);send('h77);send('he1);send('hf0);send('h14);send('hf0);send('h77);
 expect_byte('he1);expect_byte('h14);expect_byte('h77);expect_byte('he1);
 expect_byte('hf0);expect_byte('h14);expect_byte('hf0);expect_byte('h77);
 send('h1c);send('hf0);send('h1c);
 expect_byte('h1c);expect_byte('hf0);expect_byte('h1c);empty;
 $display("PASS keyboard_filter: all eight shortcuts/six slots, both Meta keys, release order, typematic, normal keys, extended breaks and Pause");
 $finish;
end
initial begin #1000000;$fatal(1,"Filter timeout");end
endmodule
