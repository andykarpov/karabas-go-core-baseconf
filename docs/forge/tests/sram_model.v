`timescale 1ns/1ps
module sram_model(input [20:0] a,inout [15:0] d,input [1:0] we_n,oe_n);
reg [7:0] lo[0:2097151],hi[0:2097151];
`ifdef VERILATOR
// The compiled simulator cannot delay a tristate assignment. Keep address-to-data
// delay, with ideal OE switching; Icarus retains the delayed pin driver below.
wire [7:0] lo_data,hi_data;
assign #10 lo_data=lo[a];
assign #10 hi_data=hi[a];
assign d[7:0]=!oe_n[0]?lo_data:8'hzz;
assign d[15:8]=!oe_n[1]?hi_data:8'hzz;
`else
assign #10 d[7:0]=!oe_n[0]?lo[a]:8'hzz;
assign #10 d[15:8]=!oe_n[1]?hi[a]:8'hzz;
`endif
always @(posedge we_n[0]) lo[a]=d[7:0];
always @(posedge we_n[1]) hi[a]=d[15:8];
endmodule
