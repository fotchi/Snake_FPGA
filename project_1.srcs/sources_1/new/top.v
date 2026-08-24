//------------------------------------------------------------------------
// top.v  -  Snake on Nexys Video, output over HDMI via Digilent's
// official "rgb2dvi" IP core (handles TMDS encoding + serialization).
//
// Buttons : btnu/btnd/btnl/btnr -> direction, btnc -> new game / reset
// LEDs    : led[7] -> MMCM locked (debug), led[6:0] -> score (binary)
// HDMI OUT: hdmi_tx_p/n[2:0] (RGB channels), hdmi_tx_clk_p/n
//------------------------------------------------------------------------
module top (
    input  wire       sysclk,      // 100 MHz

    input  wire       btnc,        // center button = reset / new game
    input  wire       btnu,
    input  wire       btnd,
    input  wire       btnl,
    input  wire       btnr,

    output wire [7:0] led,

    output wire       hdmi_tx_clk_p,
    output wire       hdmi_tx_clk_n,
    output wire [2:0] hdmi_tx_p,
    output wire [2:0] hdmi_tx_n,
    output wire       hdmi_tx_hpd,
    output wire       hdmi_tx_cec
);

    assign hdmi_tx_hpd = 1'b1;
    assign hdmi_tx_cec = 1'b0;

    // ------------------------------------------------------------------
    // Clocking : only need the 25 MHz pixel clock now. rgb2dvi generates
    // its own internal serial clock (kGenerateSerialClk = true).
    // ------------------------------------------------------------------
    wire clk_pix, clk_serial, mmcm_locked;

    clk_dvi u_clk_dvi (
        .clk_100m   (sysclk),
        .reset      (1'b0),
        .clk_pix    (clk_pix),
        .clk_serial (clk_serial),
        .locked     (mmcm_locked)
    );

    wire sys_reset = ~mmcm_locked;

    // ------------------------------------------------------------------
    // Button debouncing (sysclk domain) + resync into clk_pix domain
    // ------------------------------------------------------------------
    wire rst_clean;
    wire up_clean;
    wire down_clean;
    wire left_clean;
    wire right_clean;

    debounce db_rst   (.clk(sysclk), .btn_in(btnc), .btn_clean(rst_clean));
    debounce db_up    (.clk(sysclk), .btn_in(btnu), .btn_clean(up_clean));
    debounce db_down  (.clk(sysclk), .btn_in(btnd), .btn_clean(down_clean));
    debounce db_left  (.clk(sysclk), .btn_in(btnl), .btn_clean(left_clean));
    debounce db_right (.clk(sysclk), .btn_in(btnr), .btn_clean(right_clean));

    // Resync the DEBOUNCED LEVEL (not a short pulse) into clk_pix domain,
    // then edge-detect there. A level held for ~2.5ms (debounce time) is
    // always safely caught by a 2-flop synchronizer, unlike a single
    // 100MHz-wide pulse which can be missed by the slower 25MHz clk_pix
    // domain (classic CDC bug - this was the "bizarre" button behavior).
    reg [1:0] rst_sync, up_sync, down_sync, left_sync, right_sync;
    reg       rst_prev, up_prev, down_prev, left_prev, right_prev;
    always @(posedge clk_pix) begin
        rst_sync   <= {rst_sync[0],   rst_clean};
        up_sync    <= {up_sync[0],    up_clean};
        down_sync  <= {down_sync[0],  down_clean};
        left_sync  <= {left_sync[0],  left_clean};
        right_sync <= {right_sync[0], right_clean};

        rst_prev   <= rst_sync[1];
        up_prev    <= up_sync[1];
        down_prev  <= down_sync[1];
        left_prev  <= left_sync[1];
        right_prev <= right_sync[1];
    end

    wire rst_pulse_pix   = rst_sync[1]   & ~rst_prev;
    wire up_pulse_pix    = up_sync[1]    & ~up_prev;
    wire down_pulse_pix  = down_sync[1]  & ~down_prev;
    wire left_pulse_pix  = left_sync[1]  & ~left_prev;
    wire right_pulse_pix = right_sync[1] & ~right_prev;

    wire game_reset = sys_reset | rst_pulse_pix;

    // ------------------------------------------------------------------
    // Video timing
    // ------------------------------------------------------------------
    wire [9:0] hcount, vcount;
    wire       hsync, vsync, de;

    vga_timing u_timing (
        .clk_pix (clk_pix),
        .reset   (sys_reset),
        .hcount  (hcount),
        .vcount  (vcount),
        .hsync   (hsync),
        .vsync   (vsync),
        .de      (de),
        .frame_tick ()
    );

    // ------------------------------------------------------------------
    // Game logic
    // ------------------------------------------------------------------
    wire [7:0] red, green, blue;
    wire [7:0] score;
    wire       game_over;
    wire       eat_pulse;

    snake_game u_game (
        .clk_pix  (clk_pix),
        .reset    (game_reset),
        .up       (up_pulse_pix),
        .down     (down_pulse_pix),
        .left     (left_pulse_pix),
        .right    (right_pulse_pix),
        .hcount   (hcount),
        .vcount   (vcount),
        .de       (de),
        .red      (red),
        .green    (green),
        .blue     (blue),
        .score    (score),
        .game_over(game_over),
        .eat_pulse(eat_pulse)
    );

    assign led = {mmcm_locked, score[6:0]};

    // ------------------------------------------------------------------
    // HDMI output via Digilent's rgb2dvi IP (Generate Output Products
    // must have been run in Vivado so rgb2dvi_0 exists as a source).
    // ------------------------------------------------------------------
    rgb2dvi_0 u_rgb2dvi (
        .TMDS_Clk_p  (hdmi_tx_clk_p),
        .TMDS_Clk_n  (hdmi_tx_clk_n),
        .TMDS_Data_p (hdmi_tx_p),
        .TMDS_Data_n (hdmi_tx_n),
        .aRst        (sys_reset),
        .vid_pData   ({red, green, blue}),
        .vid_pVDE    (de),
        .vid_pHSync  (hsync),
        .vid_pVSync  (vsync),
        .PixelClk    (clk_pix),
        .SerialClk   (clk_serial)
    );

endmodule