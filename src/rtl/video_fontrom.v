// SPDX-License-Identifier: GPL-3.0-or-later
// Portable replacement for the Altera-only wrapper. Same enabled read latency.
module video_fontrom(
    input wire clock, input wire [7:0] data,
    input wire [10:0] rdaddress, input wire rden,
    input wire [10:0] wraddress, input wire wren,
    output reg [7:0] q
);
    (* ram_style = "block" *) reg [7:0] font [0:2047];
    initial $readmemh("atm_font.hex", font);
    always @(posedge clock) begin
        if (wren) font[wraddress] <= data;
        if (rden) q <= font[rdaddress];
    end
endmodule
