// Reserve the core's Win/Menu shortcuts for the MCU. Some MCU firmware also
// forwards them to the FPGA. Filter both HID matrix reports and PS/2 set-2
// events, including releases after Win is released first.
module baseconf_keyboard_filter(
    input wire clk, reset,
    input wire [7:0] status,
    input wire [47:0] keys,
    input wire [7:0] scancode,
    input wire scancode_upd,
    output wire [7:0] filtered_status,
    output reg [47:0] filtered_keys,
    output reg [7:0] filtered_scancode = 0,
    output reg filtered_upd = 0
);
    // Indexes match config/core.json: Escape, J, R, P, F6..F9. G is no longer reserved.
    function [3:0] hid_index(input [7:0] key);
        case (key)
            8'h29: hid_index=0;
            8'h0d: hid_index=2; 8'h15: hid_index=3;
            8'h13: hid_index=4; 8'h3f: hid_index=5;
            8'h40: hid_index=6; 8'h41: hid_index=7;
            8'h42: hid_index=8; default: hid_index=15;
        endcase
    endfunction
    function [3:0] ps2_index(input [7:0] key);
        case (key)
            8'h76: ps2_index=0;
            8'h3b: ps2_index=2; 8'h2d: ps2_index=3;
            8'h4d: ps2_index=4; 8'h0b: ps2_index=5;
            8'h83: ps2_index=6; 8'h0a: ps2_index=7;
            8'h01: ps2_index=8; default: ps2_index=15;
        endcase
    endfunction
    wire meta = status[3] | status[7];
    reg [8:0] held, blocked = 0;
    integer slot;
    reg [3:0] index;
    always @* begin
        held=0; filtered_keys=keys;
        for (slot=0; slot<6; slot=slot+1) begin
            index=hid_index(keys[slot*8 +: 8]);
            if (index<9) begin
                held[index]=1;
                if (meta || blocked[index]) filtered_keys[slot*8 +: 8]=0;
            end
        end
    end
    assign filtered_status = status & 8'h77;
    always @(posedge clk)
        if (reset) blocked<=0;
        else blocked<=(blocked | (meta ? held : 9'd0)) & held;

    reg previous_upd=0, extended=0, breaking=0;
    reg [1:0] win_down=0;
    reg [8:0] suppressed=0, forwarded=0;
    reg [2:0] pause_left=0;
    reg [23:0] pending=0;
    reg [1:0] pending_count=0, spacing=0;
    wire [3:0] scan_index=ps2_index(scancode);
    wire reserved_key=!extended && scan_index<9;
    wire win_key=extended && (scancode==8'h1f || scancode==8'h27);
    wire allow_key = !reserved_key ||
        (breaking ? forwarded[scan_index] :
         (win_down==0 && !suppressed[scan_index]));

    // Complete tokens are queued before emission: dropping a shortcut cannot
    // leave an E0/F0 prefix attached to the next ordinary key. A 24-bit MCU SPI
    // frame takes much longer than the <=12 bus clocks used to drain a token.
    always @(posedge clk) begin
        previous_upd<=scancode_upd;
        if (reset) begin
            extended<=0; breaking<=0; win_down<=0;
            suppressed<=0; forwarded<=0; pause_left<=0;
            pending_count<=0; spacing<=0;
            filtered_scancode<=0; filtered_upd<=0;
        end else begin
            if (spacing!=0) spacing<=spacing-1'b1;
            else if (pending_count!=0) begin
                filtered_scancode<=pending[7:0];
                filtered_upd<=~filtered_upd;
                pending<=pending>>8;
                pending_count<=pending_count-1'b1;
                spacing<=3;
            end
            if (scancode_upd!=previous_upd) begin
                if (pause_left!=0 || scancode==8'he1) begin
                    // Pause's eight-byte sequence contains embedded prefixes.
                    pending<={16'd0,scancode}; pending_count<=1;
                    if (pause_left!=0) pause_left<=pause_left-1'b1;
                    else pause_left<=7;
                end else if (scancode==8'he0) extended<=1;
                else if (scancode==8'hf0) breaking<=1;
                else begin
                    extended<=0; breaking<=0;
                    if (win_key) begin
                        if (scancode==8'h1f) win_down[0]<=!breaking;
                        else win_down[1]<=!breaking;
                    end else begin
                        if (reserved_key) begin
                            if (breaking) begin
                                suppressed[scan_index]<=0;
                                forwarded[scan_index]<=0;
                            end else if (win_down!=0) suppressed[scan_index]<=1;
                            else if (!suppressed[scan_index]) forwarded[scan_index]<=1;
                        end
                        if (allow_key) begin
                            if (extended && breaking) begin
                                pending<={scancode,8'hf0,8'he0}; pending_count<=3;
                            end else if (extended || breaking) begin
                                pending<={8'd0,scancode,(extended ? 8'he0 : 8'hf0)};
                                pending_count<=2;
                            end else begin
                                pending<={16'd0,scancode}; pending_count<=1;
                            end
                        end
                    end
                end
            end
        end
    end
endmodule
