`timescale 1ns/1ps
// Deliberately only a sink for machine/BIOS simulations. No HDMI behavior is
// certified by these runs; forge hdmi-test separately runs the actual transmitter
// and Xilinx clock/serializer primitives in ISim.
module hdmi_top #(parameter SAMPLERATE=48000, CLKRATE=28000000)(
 input clk,clk_ref,clk_ref_pll,clk_8,reset,
 input [23:0] vga_rgb,input vga_hs,vga_vs,vga_de,
 input [23:0] ft_rgb,input ft_hs,ft_vs,ft_de,ft_sel,
 input audio_en,input [15:0] audio_l,audio_r,
 output [3:0] tmds_p,tmds_n,output [7:0] freq);
 assign tmds_p=0;assign tmds_n=15;assign freq=0;
endmodule
