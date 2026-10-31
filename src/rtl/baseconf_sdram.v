// SPDX-License-Identifier: GPL-3.0-or-later
// 84.09 MHz byte SDRAM engine. Like TSConf's MVV controller: inverted
// forwarded clock, ACT -> two clocks -> CAS, CL2. Capture DQ on the next
// rising edge after CAS+2, allowing for the forwarded clock and input delays.
// Keeps explicit precharge, 200 us startup and autonomous refresh for shared ROM/GS.
// Address: bank[24:23], row[22:10], column[9:1], byte[0].
`default_nettype none
module baseconf_sdram #(
    parameter POWERUP_CYCLES = 18000,
    parameter REFRESH_CYCLES = 540
)(
    input wire clk, input wire reset,
    input wire req, input wire wr, input wire [24:0] addr,
    input wire [7:0] din, output wire [7:0] dout,
    output reg done = 0, output reg ready = 0,
    output wire sdram_clk, output reg [12:0] sdram_a = 0,
    output reg [1:0] sdram_ba = 0, output reg [1:0] sdram_dqm = 3,
    output reg sdram_ras_n = 1, output reg sdram_cas_n = 1,
    output reg sdram_we_n = 1, inout wire [15:0] sdram_dq
);
    localparam INIT=0, PRE=1, REF1=4, REF2=11, MODE=18, IDLE=21,
               ACT_WAIT=22, ACCESS=23, READ_WAIT=24, READ_WAIT2=25,
               COMPLETE=26, PRE_WAIT=27, PRE_WAIT2=28, REFRESH=30, RECOVER=36;
    reg [5:0] state = INIT;
    reg [15:0] timer = 0;
    reg [9:0] refresh_timer = 0;
    reg [24:0] address = 0;
    reg [7:0] data = 0;
    reg [15:0] captured = 0;
    reg write_cycle = 0, drive = 0;
    assign sdram_clk = ~clk;
    assign sdram_dq = drive ? {data,data} : 16'hzzzz;
    assign dout = address[0] ? captured[15:8] : captured[7:0];
    // CL2 data starts after CAS+1. The device sees the forwarded clock later
    // than this FPGA's clock; allow another half cycle for clock-to-DQ + input.
    // done and captured update together; the arbiter consumes both next cycle.
    always @(posedge clk)
        if (state == COMPLETE && !write_cycle)
            captured <= sdram_dq; // capture both lanes directly in I/O registers
    always @(posedge clk) begin
        {sdram_ras_n,sdram_cas_n,sdram_we_n} <= 3'b111;
        drive <= 0;
        if (!req) done <= 0;
        if (ready && refresh_timer < REFRESH_CYCLES)
            refresh_timer <= refresh_timer + 1'b1;
        if (reset) begin
            state <= INIT; timer <= 0; ready <= 0; done <= 0;
            sdram_dqm <= 3; refresh_timer <= 0;
        end else begin
            case (state)
            INIT: if (timer == POWERUP_CYCLES-1) state <= PRE;
                  else timer <= timer + 1'b1;
            PRE: begin
                {sdram_ras_n,sdram_cas_n,sdram_we_n} <= 3'b010;
                sdram_a <= 13'h400; state <= state + 1'b1;
            end
            REF1, REF2: begin
                {sdram_ras_n,sdram_cas_n,sdram_we_n} <= 3'b001;
                state <= state + 1'b1;
            end
            MODE: begin
                {sdram_ras_n,sdram_cas_n,sdram_we_n} <= 3'b000;
                sdram_ba <= 0; sdram_a <= 13'h020; // BL1, CL2
                state <= state + 1'b1;
            end
            IDLE: begin
                ready <= 1; sdram_dqm <= 0;
                if (refresh_timer >= REFRESH_CYCLES) state <= REFRESH;
                else if (req && !done) begin
                    address <= addr; data <= din; write_cycle <= wr;
                    {sdram_ras_n,sdram_cas_n,sdram_we_n} <= 3'b011;
                    sdram_a <= addr[22:10]; sdram_ba <= addr[24:23];
                    state <= ACT_WAIT;
                end
            end
            ACCESS: begin
                {sdram_ras_n,sdram_cas_n,sdram_we_n} <= write_cycle ? 3'b100 : 3'b101;
                sdram_a <= {4'b0000,address[9:1]};
                sdram_dqm <= write_cycle ? (address[0] ? 2'b01 : 2'b10) : 2'b00;
                drive <= write_cycle; state <= READ_WAIT;
            end
            COMPLETE: begin
                done <= 1; // release the client while precharge recovers
                {sdram_ras_n,sdram_cas_n,sdram_we_n} <= 3'b010;
                sdram_a <= 13'h400; state <= PRE_WAIT;
            end
            PRE_WAIT2: state <= IDLE;
            REFRESH: begin
                {sdram_ras_n,sdram_cas_n,sdram_we_n} <= 3'b001;
                refresh_timer <= 0; state <= state + 1'b1;
            end
            RECOVER: state <= IDLE;
            default: state <= state + 1'b1;
            endcase
        end
    end
endmodule
`default_nettype wire
