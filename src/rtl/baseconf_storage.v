// SPDX-License-Identifier: GPL-3.0-or-later
// ROM and GS share SDRAM; main RAM remains entirely in the two SRAMs.
`default_nettype none
module baseconf_storage(
    input wire clk, input wire reset,
    input wire rom_req, input wire rom_wr, input wire [18:0] rom_addr,
    input wire [7:0] rom_din, output reg [7:0] rom_dout = 0,
    output wire rom_done,
    input wire gs_req, input wire gs_wr, input wire [20:0] gs_addr,
    input wire [7:0] gs_din, output reg [7:0] gs_dout = 0,
    output reg gs_done = 0,
    input wire loader_act, input wire loader_wr, input wire [31:0] loader_addr,
    input wire [7:0] loader_data,
    output wire busy, output reg fault = 0,
    output wire sdram_clk, output wire [12:0] sdram_a,
    output wire [1:0] sdram_ba, output wire [1:0] sdram_dqm,
    output wire sdram_ras_n, output wire sdram_cas_n, output wire sdram_we_n,
    inout wire [15:0] sdram_dq
);
    reg [32:0] fifo [0:15];
    reg [3:0] wp = 0, rp = 0;
    reg [4:0] count = 0;
    reg [1:0] state = 0, owner = 0;
    reg last_cpu = 0;
    reg rom_ack = 0;
    reg [18:0] rom_tag = 0;
    reg rom_write_tag = 0;
    reg request = 0, writing = 0;
    reg [24:0] address = 0;
    reg [7:0] data = 0;
    wire ready, done;
    wire [7:0] result;
    wire pop = state == 0 && ready && count != 0;
    // GS spends most playback time in its ROM and fixed workspace/sample
    // buffers. Keep the low 64 KiB in dual-port block RAM so those cycles
    // never queue behind main-ROM SDRAM traffic. The remaining GS address
    // space retains its original SDRAM addresses (no bank aliasing).
    reg [7:0] gs_local [0:65535];
    reg [7:0] local_data = 0;
    reg local_pending = 0;
    wire local_request = gs_req && gs_addr[20:16] == 0;
    wire [24:0] load_address = fifo[rp][32:8];
    wire local_load = pop && load_address[24:15] == 0;
    always @(posedge clk) begin
        if (local_request && !gs_done && !local_pending) begin
            local_data <= gs_local[gs_addr[15:0]];
            if (gs_wr) gs_local[gs_addr[15:0]] <= gs_din;
        end
    end
    always @(posedge clk)
        if (local_load) gs_local[load_address[15:0]] <= fifo[rp][7:0];
    reg loader_wr_seen = 0;
    wire push = loader_act && loader_wr && !loader_wr_seen;
    wire valid_loader = loader_addr[31] ? loader_addr[30:15] == 0 : loader_addr[30:19] == 0;
    // DOS entry can change the mapped ROM before an M1 read finishes.
    assign rom_done = rom_ack && rom_req && rom_addr == rom_tag && rom_wr == rom_write_tag;
    assign busy = !ready || count != 0 || (state != 0 && owner == 2) || fault;
    always @(posedge clk) begin
        loader_wr_seen <= loader_wr;
        if (!rom_req || rom_addr != rom_tag || rom_wr != rom_write_tag) rom_ack <= 0;
        if (!gs_req) begin gs_done <= 0; local_pending <= 0; end
        else if (local_pending) begin
            gs_dout <= local_data; gs_done <= 1; local_pending <= 0;
        end else if (local_request && !gs_done) local_pending <= 1;
        if (reset) begin
            wp <= 0; rp <= 0; count <= 0; state <= 0; loader_wr_seen <= 0;
            request <= 0; fault <= 0; rom_ack <= 0; gs_done <= 0;
            last_cpu <= 0; local_pending <= 0;
        end else begin
            if (push && (!valid_loader || (count == 16 && !pop))) fault <= 1;
            if (push && valid_loader && (count < 16 || pop)) begin
                fifo[wp] <= {loader_addr[31] ? {10'd0,loader_addr[14:0]} : {6'd4,loader_addr[18:0]},loader_data};
                wp <= wp + 1'b1;
            end
            if (pop) rp <= rp + 1'b1;
            case ({push && valid_loader && (count < 16 || pop),pop})
            2'b10: count <= count + 1'b1;
            2'b01: count <= count - 1'b1;
            default: ;
            endcase
            case (state)
            0: if (ready) begin
                if (pop) begin
                    if (!local_load) begin
                        {address,data} <= fifo[rp]; writing <= 1;
                        owner <= 2; request <= 1; state <= 1;
                    end
                end else if (!loader_act) begin
                    if (rom_req && !rom_done && (!(gs_req && !local_request && !gs_done) || !last_cpu)) begin
                        address <= {6'd4,rom_addr}; data <= rom_din; writing <= rom_wr;
                        rom_tag <= rom_addr; rom_write_tag <= rom_wr;
                        owner <= 0; last_cpu <= 1; request <= 1; state <= 1;
                    end else if (gs_req && !local_request && !gs_done) begin
                        address <= {4'd0,gs_addr}; data <= gs_din; writing <= gs_wr;
                        owner <= 1; last_cpu <= 0; request <= 1; state <= 1;
                    end
                end
            end
            1: if (done) begin
                if (owner == 0) begin
                    rom_dout <= result;
                    rom_ack <= rom_req && address == {6'd4,rom_addr} && writing == rom_wr;
                end
                if (owner == 1) begin gs_dout <= result; gs_done <= gs_req; end
                request <= 0; state <= 2;
            end
            2: if (!done) state <= 0;
            default: state <= 0;
            endcase
        end
    end
    baseconf_sdram memory(
        .clk(clk), .reset(reset), .req(request), .wr(writing), .addr(address),
        .din(data), .dout(result), .done(done), .ready(ready),
        .sdram_clk(sdram_clk), .sdram_a(sdram_a), .sdram_ba(sdram_ba),
        .sdram_dqm(sdram_dqm), .sdram_ras_n(sdram_ras_n),
        .sdram_cas_n(sdram_cas_n), .sdram_we_n(sdram_we_n), .sdram_dq(sdram_dq)
    );
endmodule
`default_nettype wire
