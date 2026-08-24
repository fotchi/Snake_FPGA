//------------------------------------------------------------------------
// debounce.v
// Simple counter-based debouncer. Outputs a clean, stable level (no
// short pulse) - edge detection for driving the game happens later, in
// the clk_pix domain, to avoid cross-clock pulse-loss (see top.v).
//------------------------------------------------------------------------
module debounce #(
    parameter DELAY = 250_000   // ~2.5 ms @ 100MHz
) (
    input  wire clk,
    input  wire btn_in,
    output reg  btn_clean
);

    reg [17:0] cnt = 0;
    reg sync0 = 0, sync1 = 0;

    always @(posedge clk) begin
        sync0 <= btn_in;
        sync1 <= sync0;

        if (sync1 != btn_clean) begin
            cnt <= cnt + 1;
            if (cnt >= DELAY) begin
                btn_clean <= sync1;
                cnt <= 0;
            end
        end else begin
            cnt <= 0;
        end
    end

endmodule