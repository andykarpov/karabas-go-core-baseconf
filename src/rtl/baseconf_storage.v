// SPDX-License-Identifier: GPL-3.0-or-later
// ROM and GS share SDRAM; main RAM remains entirely in the two SRAMs.
// The SDRAM is sdram2p of TS-Conf (two ports, one access each in every cycle of 8 clk):
// port 1 (banks 0 / 1) = the main ROM and the ROM loader (the arbiter below): the main CPU waits for the
//   ROM, it has the port alone (a read in 10..17 clk: no wait state at 3.5 MHz);
// port 2 (banks 2 / 3) = the FL bytes (first), the GS above its 64 KiB of block RAM (bytes 0..1FFFFF
//   of the port), then the OPL4 sample memory (opl4_kg, 4 MB at 400000 of the port: the YRW801 ROM
//   0..1FFFFF from the FL item of core.json, the sample RAM 200000..3FFFFF), as gs_top.v of TS-Conf.
`default_nettype none
module baseconf_storage(
    input wire clk, input wire reset,
    input wire rom_req, input wire rom_wr, input wire [18:0] rom_addr,
    input wire [7:0] rom_din, output reg [7:0] rom_dout = 0,
    output wire rom_done,
    input wire gs_req, input wire gs_wr, input wire [20:0] gs_addr,
    input wire [7:0] gs_din, output wire [7:0] gs_dout,
    output wire gs_done,
    input wire loader_act, input wire loader_wr, input wire [31:0] loader_addr,
    input wire [7:0] loader_data,
    output wire busy, output reg fault = 0,
    // the YRW801 ROM of the OPL4 from the FL item (ld_wr of clk_bus): byte offset in the file
    input wire fl_wr, input wire [31:0] fl_a, input wire [7:0] fl_d,
    // the sample memory of the OPL4 (clk), see opl4_kg
    input wire [21:0] opl_addr, input wire opl_req, input wire opl_we, input wire [7:0] opl_wdata,
    output wire opl_ack, output wire [15:0] opl_rdata,
    input wire sdram_init_n, // the PLL lock only: sdram2p cannot abort an access
    output wire sdram_clk, output wire [12:0] sdram_a,
    output wire [1:0] sdram_ba, output wire [1:0] sdram_dqm,
    output wire sdram_ras_n, output wire sdram_cas_n, output wire sdram_we_n,
    inout wire [15:0] sdram_dq
);
    reg [32:0] fifo [0:15];
    reg [3:0] wp = 0, rp = 0;
    reg [4:0] count = 0;
    reg [1:0] state = 0, owner = 0;
    reg rom_ack = 0;
    reg [18:0] rom_tag = 0;
    reg rom_write_tag = 0;
    reg writing = 0;
    reg [24:0] address = 0;
    reg [7:0] data = 0;
    // port 1 of sdram2p: a toggle of p1_req starts an access, p1_ack follows it when it is done (a read:
    // p1_q valid in that clock). The toggle is never reset: after a reset the next access waits for the
    // ack of one still in the port (ready = p1_idle), sdram2p cannot abort it.
    reg p1_req = 0;
    wire p1_ack, sd_ready;
    wire [15:0] p1_q;
    wire p1_idle = p1_ack == p1_req;
    wire ready = sd_ready && p1_idle;
    wire [7:0] result = address[0] ? p1_q[15:8] : p1_q[7:0];
    wire pop = state == 0 && ready && count != 0;
    // GS spends most playback time in its ROM and fixed workspace/sample
    // buffers. Keep the low 64 KiB in dual-port block RAM so those cycles
    // never queue behind main-ROM SDRAM traffic. The remaining GS address
    // space retains its original SDRAM addresses (no bank aliasing).
    reg [7:0] gs_local [0:65535];
    reg [7:0] local_data = 0, gs_dout_l = 0, gs_dout_s = 0;
    reg local_pending = 0, gs_done_l = 0, gs_done_s = 0;
    assign gs_done = gs_done_l || gs_done_s;
    assign gs_dout = gs_done_s ? gs_dout_s : gs_dout_l;
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
    // busy holds the Z80 in reset (rst_req_n of baseconf.v): the SDRAM not initialised, loader bytes left,
    // not an access of the main CPU (ready = sd_ready && p1_idle falls in every ROM read)
    assign busy = !sd_ready || count != 0 || (state != 0 && owner == 2) || fault;
    always @(posedge clk) begin
        loader_wr_seen <= loader_wr;
        if (!rom_req || rom_addr != rom_tag || rom_wr != rom_write_tag) rom_ack <= 0;
        if (!gs_req) begin gs_done_l <= 0; local_pending <= 0; end
        else if (local_pending) begin
            gs_dout_l <= local_data; gs_done_l <= 1; local_pending <= 0;
        end else if (local_request && !gs_done) local_pending <= 1;
        if (reset) begin
            wp <= 0; rp <= 0; count <= 0; state <= 0; loader_wr_seen <= 0;
            fault <= 0; rom_ack <= 0; gs_done_l <= 0;
            local_pending <= 0;
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
                        owner <= 2; p1_req <= ~p1_req; state <= 1;
                    end
                end else if (!loader_act) begin
                    if (rom_req && !rom_done) begin
                        address <= {6'd4,rom_addr}; data <= rom_din; writing <= rom_wr;
                        rom_tag <= rom_addr; rom_write_tag <= rom_wr;
                        owner <= 0; p1_req <= ~p1_req; state <= 1;
                    end
                end
            end
            1: if (p1_idle) begin
                if (owner == 0) begin
                    rom_dout <= result;
                    rom_ack <= rom_req && address == {6'd4,rom_addr} && writing == rom_wr;
                end
                state <= 0;
            end
            default: state <= 0;
            endcase
        end
    end
    // ---------------------------------------------------------------- port 2: the FL bytes, then the GS, then the OPL4
    // (the FL / OPL4 part from gs_top.v of TS-Conf). The FL bytes: ld_wr of clk_bus is high for three clk; a
    // fifo of 4, as a port 2 write waits a cycle when port 1 reads and the bytes come every 250 ns (21 clk) at
    // most. A GS access left by a reset is let go: its ack comes, the port takes no new one before it.
    wire p2_ack;
    wire [15:0] p2_q;
    reg fl_wr_d = 1'b0;
    reg [28:0] fl_fifo [0:3];
    reg [2:0] fl_wp = 3'd0, fl_rp = 3'd0;
    wire fl_pend = (fl_wp != fl_rp);
    wire [28:0] fl_head = fl_fifo[fl_rp[1:0]];
    reg p2_req = 1'b0, p2_busy = 1'b0, p2_opl = 1'b0, p2_gs = 1'b0, p2_we = 1'b0;
    reg [22:0] p2_a = 23'd0;              // the byte address in the port: GS 0..1FFFFF, OPL4 400000..7FFFFF
    reg [7:0] p2_d = 8'd0;
    wire p2_done = p2_busy && (p2_ack == p2_req);
    wire gs_sd = gs_req && !local_request && !gs_done_s && !loader_act;
    always @(posedge clk) begin
        fl_wr_d <= fl_wr;
        if (fl_wr && !fl_wr_d && fl_a[31:21] == 11'd0) begin
            fl_fifo[fl_wp[1:0]] <= {fl_a[20:0], fl_d};
            fl_wp <= fl_wp + 1'd1;
        end
        if (!gs_req) gs_done_s <= 1'b0;
        if (p2_done) begin
            p2_busy <= 1'b0;
            if (p2_gs && gs_req && !reset) begin
                gs_done_s <= 1'b1;
                gs_dout_s <= p2_a[0] ? p2_q[15:8] : p2_q[7:0];
            end
        end else if (!p2_busy) begin
            // the FL bytes first: they come at the burst pace into a fifo of 4, a GS reading the SDRAM back
            // to back would let it overflow (only while the YRW801 loads; the GS waits one access then)
            if (fl_pend) begin
                fl_rp <= fl_rp + 1'd1;
                p2_busy <= 1'b1; p2_req <= ~p2_req; p2_opl <= 1'b0; p2_gs <= 1'b0; p2_we <= 1'b1;
                p2_a <= {2'b10, fl_head[28:8]}; p2_d <= fl_head[7:0];
            end else if (gs_sd && !reset) begin
                p2_busy <= 1'b1; p2_req <= ~p2_req; p2_opl <= 1'b0; p2_gs <= 1'b1; p2_we <= gs_wr;
                p2_a <= {2'b00, gs_addr}; p2_d <= gs_din;
            end else if (opl_req) begin
                p2_busy <= 1'b1; p2_req <= ~p2_req; p2_opl <= 1'b1; p2_gs <= 1'b0; p2_we <= opl_we;
                p2_a <= {1'b1, opl_addr}; p2_d <= opl_wdata;
            end
        end
        if (reset) gs_done_s <= 1'b0;
    end
    assign opl_ack = p2_done && p2_opl;
    assign opl_rdata = p2_q;

    sdram2p memory(
        .SDRAM_DQ(sdram_dq), .SDRAM_A(sdram_a), .SDRAM_DQML(sdram_dqm[0]), .SDRAM_DQMH(sdram_dqm[1]),
        .SDRAM_BA(sdram_ba), .SDRAM_nWE(sdram_we_n), .SDRAM_nRAS(sdram_ras_n), .SDRAM_nCAS(sdram_cas_n),
        .SDRAM_CLK(sdram_clk), .init_n(sdram_init_n), .clk(clk), .ready(sd_ready),
        .port1_req(p1_req), .port1_ack(p1_ack), .port1_we(writing), .port1_a(address[23:1]),
        .port1_ds(writing ? {address[0], ~address[0]} : 2'b11), .port1_d({data, data}), .port1_q(p1_q),
        .port2_req(p2_req), .port2_ack(p2_ack), .port2_we(p2_we), .port2_a({1'b0, p2_a[22:1]}),
        .port2_ds(p2_we ? {p2_a[0], ~p2_a[0]} : 2'b11), .port2_d({p2_d, p2_d}), .port2_q(p2_q)
    );
endmodule
`default_nettype wire
