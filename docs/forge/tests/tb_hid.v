`timescale 1ns/1ps
module tb_hid;
reg clk=0;always #17.85 clk=~clk;
reg reset=1,sck=0,mosi=0,ss=1;
wire miso;wire [7:0] kb_status,kb0,kb1,kb2,kb3,kb4,kb5,scancode;
wire scancode_upd;wire [12:0] joy_l,joy_r;
wire [15:0] softcmd,osdcmd;wire [71:0] switches;
reg [7:0] rtc_a=0,rtc_di=0,kb_a=8'hff;
reg rtc_wr=0,rtc_rd=0;wire [7:0] rtc_do,mapped,joy_do;wire [5:0] kb_do;
wire [7:0] ms_x,ms_y,x,y;wire [3:0] ms_z,z;wire [2:0] ms_b,b;wire ms_upd;
kg_mcu #(.BURST_MAX_MHZ(1),.ENABLE_MATRIX(0),.ENABLE_DEBUG(0),.ENABLE_IMG(0),.ENABLE_FILE(0),
 .ENABLE_FT(0),.ENABLE_SD2(0),.ENABLE_UART(0),.RTC_SKIP_0D(0),.RTC_SEND_LIMIT(240)) mcu(
 .CLK(clk),.N_RESET(!reset),.MCU_SCK(sck),.MCU_MOSI(mosi),.MCU_MISO(miso),.MCU_SS(ss),
 .MCU_SPI_FT_SS(1'b1),.MCU_SPI_SD2_SS(1'b1),.MCU_BURST_CS_N(1'b1),
 .KB_STATUS(kb_status),.KB_DAT0(kb0),.KB_DAT1(kb1),.KB_DAT2(kb2),.KB_DAT3(kb3),.KB_DAT4(kb4),.KB_DAT5(kb5),
 .KB_SCANCODE(scancode),.KB_SCANCODE_UPD(scancode_upd),.JOY_L(joy_l),.JOY_R(joy_r),
 .MS_X(ms_x),.MS_Y(ms_y),.MS_Z(ms_z),.MS_B(ms_b),.MS_UPD(ms_upd),
 .RTC_A(rtc_a),.RTC_DI(rtc_di),.RTC_DO(rtc_do),.RTC_CS(1'b1),.RTC_WR_N(!rtc_wr),
 .SOFTSW_COMMAND(softcmd),.OSD_COMMAND(osdcmd),.UART_TX_DATA(8'd0),.UART_TX_WR(1'b0),
 .UART_TX_MODE(1'b0),.UART_DLM(8'd0),.UART_DLL(8'd0),.UART_DLM_WR(1'b0),.UART_DLL_WR(1'b0),
 .FT_MISO(1'b1),.SD2_MISO(1'b1),.MATRIX_CMD(24'd0),.MATRIX_CMD_WR(1'b0),
 .DEBUG_ADDR(16'd0),.DEBUG_DATA(16'd0),.IMG_Q_WR(1'b0),.IMG_Q_DI(24'd0));
kg_soft_switches #(.N(9),.INIT(72'h000000000100000101)) sw(.clk(clk),.command(softcmd),.regs(switches),.upd());
wire [7:0] filtered_status, filtered_scan;
wire [47:0] filtered_keys; wire filtered_upd;
baseconf_keyboard_filter filter(.clk(clk),.reset(reset),.status(kb_status),
 .keys({kb5,kb4,kb3,kb2,kb1,kb0}),.scancode(scancode),.scancode_upd(scancode_upd),
 .filtered_status(filtered_status),.filtered_keys(filtered_keys),
 .filtered_scancode(filtered_scan),.filtered_upd(filtered_upd));
hid_parser hid(.CLK(clk),.RESET(reset),.KB_STATUS(filtered_status),.KB_DAT0(filtered_keys[7:0]),.KB_DAT1(filtered_keys[15:8]),
 .KB_DAT2(filtered_keys[23:16]),.KB_DAT3(filtered_keys[31:24]),.KB_DAT4(filtered_keys[39:32]),.KB_DAT5(filtered_keys[47:40]),.KB_SCANCODE(filtered_scan),.KB_SCANCODE_UPD(filtered_upd),
 .JOY_TYPE_L(switches[26:24]),.JOY_TYPE_R(switches[34:32]),.JOY_L(joy_l),.JOY_R(joy_r),
 .KB_TYPE(1'b1),.A(kb_a),.JOY_DO(joy_do),.KB_DO(kb_do),.RTC_A(rtc_a),.RTC_WR(rtc_wr),.RTC_RD(rtc_rd),
 .RTC_DI(rtc_di),.RTC_DO_IN(rtc_do),.RTC_DO_OUT(mapped));
kg_cursor cursor(clk,ms_x,ms_y,ms_z,ms_b,ms_upd,x,y,z,b);
task frame(input [7:0] cmd,input [7:0] address,input [7:0] data);
reg [23:0] bits;integer i;
begin
 bits={cmd,address,data};ss=0;#100;
 for(i=23;i>=0;i=i-1) begin mosi=bits[i];#31.25;sck=1;#31.25;sck=0;end
 #50;ss=1;#500;
end endtask
task rtcwrite(input [7:0] a,input [7:0] d);
begin @(negedge clk);rtc_a=a;rtc_di=d;repeat(4) @(negedge clk);
 rtc_wr=1;repeat(8) @(negedge clk);rtc_wr=0;repeat(4) @(negedge clk);end endtask
task rtcread(input [7:0] a,input [7:0] expected);
begin @(negedge clk);rtc_a=a;repeat(4) @(negedge clk);
 rtc_rd=1;repeat(8) @(negedge clk);
 if(mapped!==expected) $fatal(1,"RTC %h got %h expected %h",a,mapped,expected);
 rtc_rd=0;repeat(4) @(negedge clk);end endtask
task joystick(input integer port, input [12:0] buttons);
begin frame(3,port*2,buttons[7:0]);frame(3,port*2+1,{3'd0,buttons[12:8]});end
endtask
// Expected physical Spectrum matrix: row A8 first, five key bits per row.
task matrix(input [39:0] pressed);
integer row;
begin
 for(row=0;row<8;row=row+1) begin
  kb_a=~(8'b1<<row);#1000;
  if(kb_do!=={1'b1,~pressed[row*5 +: 5]})
   $fatal(1,"Keyboard row %0d got %b expected pressed %b",row,kb_do,pressed[row*5 +: 5]);
 end
 kb_a=8'h00;#1000;
 if(kb_do[4:0]!==~(pressed[4:0]|pressed[9:5]|pressed[14:10]|pressed[19:15]|
  pressed[24:20]|pressed[29:25]|pressed[34:30]|pressed[39:35]))
  $fatal(1,"Combined keyboard row scan");
end
endtask
integer port,button;
integer key_bit[1:12];
reg [39:0] all_sega;
initial begin
 #1000;reset=0;#2000;
 rtcwrite(8'h0c,0);
 frame(8'h0b,0,8'h1c);frame(8'h0b,0,8'hf0);frame(8'h0b,0,8'h1c);
 rtcread(8'hf0,8'h1c);rtcread(8'hf0,8'hf0);rtcread(8'hf0,8'h1c);rtcread(8'hf0,0);
 frame(8'h0b,0,8'h29);rtcwrite(8'h0c,1);rtcread(8'hf0,0);
 frame(1,1,4);kb_a=8'hfd;#1000;if(kb_do[0]!==0) $fatal(1,"A key press");
 frame(1,1,0);#1000;if(kb_do[0]!==1) $fatal(1,"A key release");
 // Joystick shortcut is MCU-only through BOTH keyboard paths, even Win released first.
 frame(1,0,8'h08);frame(1,1,8'h0d);kb_a=8'hbf;#1000;
 if(kb_do[3]!==1) $fatal(1,"Menu+J leaked into Spectrum matrix");
 frame(8'h0b,0,8'he0);frame(8'h0b,0,8'h1f);frame(8'h0b,0,8'h3b);
 frame(1,0,0);#1000;if(kb_do[3]!==1) $fatal(1,"J leaked after Win release");
 frame(8'h0b,0,8'he0);frame(8'h0b,0,8'hf0);frame(8'h0b,0,8'h1f);
 frame(8'h0b,0,8'h3b); // typematic must stay suppressed until J is released
 frame(8'h0b,0,8'hf0);frame(8'h0b,0,8'h3b);frame(1,1,0);
 rtcread(8'hf0,0);
 frame(1,1,8'h0d);#1000;if(kb_do[3]!==0) $fatal(1,"Normal J blocked");
 frame(8'h0b,0,8'h3b);frame(8'h0b,0,8'hf0);frame(8'h0b,0,8'h3b);
 rtcread(8'hf0,8'h3b);rtcread(8'hf0,8'hf0);rtcread(8'hf0,8'h3b);rtcread(8'hf0,0);
 frame(1,1,0);
 // Menu+G is no longer consumed by the core's shortcut filter.
 frame(1,0,8'h08);frame(1,1,8'h0a);kb_a=8'hfd;#1000;
 if(kb_do[4]!==0) $fatal(1,"Menu+G should now reach normal G");
 frame(1,0,0);frame(1,1,0);
 // EVO boot selections: physical Spectrum matrix, including both shifts and multi-key.
 frame(1,0,8'h02);matrix(40'b1); // left Shift = Caps Shift
 frame(1,0,8'h20);matrix(40'b1); // right Shift
 frame(1,0,8'h01);matrix(40'b1<<36); // left Ctrl = Symbol Shift
 frame(1,0,8'h10);matrix(40'b1<<36); // right Ctrl
 frame(1,0,0);
 frame(1,1,8'h07);matrix(40'b1<<7); // D
 frame(1,1,8'h06);matrix(40'b1<<3); // C
 frame(1,1,8'h0b);matrix(40'b1<<34); // H
 frame(1,1,8'h16);matrix(40'b1<<6); // S
 frame(1,1,8'h27);matrix(40'b1<<20); // 0
 frame(1,1,8'h04);frame(1,2,8'h05);frame(1,6,8'h45);
 matrix((40'b1<<5)|(40'b1<<39)); // A+B+F12: F12 is not a third Spectrum key
 frame(1,1,0);frame(1,2,0);frame(1,6,0);
 // Two joystick inputs, changed through the same OSD register indexes as core.json.
 frame(3,0,8'h91);#1000;if(joy_do[4:0]!==5'h11) $fatal(1,"left Kempston");
 frame(5,3,4);frame(5,4,0);frame(3,2,8'h83);#1000;
 if(joy_do[4:0]!==5'h18) $fatal(1,"right Kempston after OSD mapping");
 kb_a=8'hdf;#1000;if(kb_do[0]!==0) $fatal(1,"left QAOP P key");
 // User mapping, indexed by MCU button bits: U D L R Start A B C X Y Z Mode.
 key_bit[1]=10;key_bit[2]=5;key_bit[3]=26;key_bit[4]=25;
 key_bit[5]=20;key_bit[6]=1;key_bit[7]=2;key_bit[8]=3;
 key_bit[9]=6;key_bit[10]=7;key_bit[11]=8;key_bit[12]=21;
 all_sega=0;
 for(button=1;button<=12;button=button+1) all_sega=all_sega|(40'b1<<key_bit[button]);
 joystick(0,0);joystick(1,0);frame(5,3,0);frame(5,4,0);
 for(port=0;port<2;port=port+1) begin
  frame(5,3+port,6); // actual OSD switch command selects SEGA
  joystick(port,1);matrix(0); // connected flag alone is not a key
  for(button=1;button<=12;button=button+1) begin
   joystick(port,13'b1|(13'b1<<button));matrix(40'b1<<key_bit[button]);
   joystick(port,1);matrix(0);
  end
  joystick(port,13'h1fff);matrix(all_sega);
  frame(5,3+port,0);matrix(0); // live mode switch clears all SEGA keys
  joystick(port,0);
 end
 // Both ports merge key presses; releasing one must not release the other.
 frame(5,3,6);frame(5,4,6);
 joystick(0,13'h1fff);joystick(1,13'h1fff);matrix(all_sega);
 joystick(0,0);matrix(all_sega);
 joystick(1,0);matrix(0);
 // Mixed modes and normal USB typing remain independent.
 frame(5,4,0);joystick(0,13'h0401);joystick(1,13'h0091);
 frame(1,1,8'h0a);matrix((40'b1<<7)|(40'b1<<9)); // Sega Y=D plus typed G
 if(joy_do[4:0]!==5'h11) $fatal(1,"SEGA left interfered with right Kempston");
 frame(1,1,0);joystick(0,0);joystick(1,0);matrix(0);
 $display("PASS SEGA: all 12 controls on both ports, releases, chords, combined rows, live mode switch, dual-port merge, keyboard and Kempston coexistence");
 frame(2,0,3);frame(2,1,8'hfe);frame(2,2,1);frame(2,3,5);#1000;
 if(x!==8'h82 || y!==8'h81 || z!==6 || b!==5) $fatal(1,"mouse deltas/buttons");
 frame(8'h20,8'h12,8'h34);#1000;if(osdcmd!==16'h1234) $fatal(1,"OSD command");
 $display("PASS hid: MCU SPI 16MHz, PS2 make/break FIFO/reset, reserved shortcuts isolated, USB matrix, two OSD-selectable joysticks, mouse, OSD command");$finish;
end
initial begin #2000000;$fatal(1,"HID timeout");end
endmodule
