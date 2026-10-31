// SPDX-License-Identifier: GPL-3.0-or-later
// Four 28 MHz clocks per word, matching BaseConf dram.v/arbiter.v.
// Both physical chips are 2M x 8 and share the 21-bit word address.
`default_nettype none
module baseconf_sram(
    input wire clk, input wire rst_n,
    input wire [20:0] addr, input wire req, input wire rnw,
    input wire [15:0] wrdata, input wire [1:0] bsel,
    output wire cbeg, output reg rrdy = 0,
    output reg [15:0] rddata = 0,
    output reg [20:0] ma = 0, inout wire [15:0] md,
    output reg [1:0] we_n = 3, output reg [1:0] oe_n = 3
);
    reg [1:0] phase = 0;
    reg active = 0, reading = 0;
    reg [1:0] mask = 0;
    reg [15:0] data = 0;
    assign cbeg = phase == 0;
    assign md = active && !reading ? data : 16'hzzzz;
    always @(posedge clk) begin
        phase <= phase + 1'b1;
        rrdy <= 0;
        case (phase)
        3: begin
            ma <= addr;
            data <= wrdata;
            mask <= bsel;
            active <= req && rst_n;
            reading <= rnw;
            oe_n <= req && rst_n && rnw ? 2'b00 : 2'b11;
            we_n <= 3;
        end
        0: if (active && !reading) we_n <= ~mask;
        1: we_n <= 3; // data/address remain stable for a full hold clock
        2: begin
            if (active && reading) begin
                rddata <= md;
                rrdy <= 1;
            end
            oe_n <= 3;
            active <= 0;
        end
        endcase
    end
endmodule
`default_nettype wire
