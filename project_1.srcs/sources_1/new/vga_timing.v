//------------------------------------------------------------------------
// vga_timing.v
// 640x480 @ 60Hz timing generator, driven by a 25 MHz pixel clock.
//   H: 640 visible + 16 FP + 96 sync + 48 BP = 800 total
//   V: 480 visible + 10 FP + 2  sync + 33 BP = 525 total
//------------------------------------------------------------------------
module vga_timing (
    input  wire       clk_pix,
    input  wire       reset,
    output reg  [9:0] hcount,   // 0..799
    output reg  [9:0] vcount,   // 0..524
    output wire       hsync,
    output wire       vsync,
    output wire       de,       // data enable / visible area
    output wire       frame_tick // pulses once per frame (start of frame)
);

    localparam H_VISIBLE = 640;
    localparam H_FRONT   = 16;
    localparam H_SYNC    = 96;
    localparam H_BACK    = 48;
    localparam H_TOTAL   = H_VISIBLE + H_FRONT + H_SYNC + H_BACK; // 800

    localparam V_VISIBLE = 480;
    localparam V_FRONT   = 10;
    localparam V_SYNC    = 2;
    localparam V_BACK    = 33;
    localparam V_TOTAL   = V_VISIBLE + V_FRONT + V_SYNC + V_BACK; // 525

    always @(posedge clk_pix) begin
        if (reset) begin
            hcount <= 0;
            vcount <= 0;
        end else begin
            if (hcount == H_TOTAL - 1) begin
                hcount <= 0;
                vcount <= (vcount == V_TOTAL - 1) ? 10'd0 : vcount + 10'd1;
            end else begin
                hcount <= hcount + 10'd1;
            end
        end
    end

    assign hsync = ~((hcount >= H_VISIBLE + H_FRONT) &&
                      (hcount <  H_VISIBLE + H_FRONT + H_SYNC)); // active low
    assign vsync = ~((vcount >= V_VISIBLE + V_FRONT) &&
                      (vcount <  V_VISIBLE + V_FRONT + V_SYNC)); // active low

    assign de = (hcount < H_VISIBLE) && (vcount < V_VISIBLE);
    assign frame_tick = (hcount == 0) && (vcount == 0);

endmodule