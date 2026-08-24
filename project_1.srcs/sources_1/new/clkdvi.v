//------------------------------------------------------------------------
// clk_dvi.v
// Generates:
//   clk_pix    : 25 MHz  pixel clock      (640x480 @ 60Hz timing)
//   clk_serial : 125 MHz TMDS serial clock (5x clk_pix, fed to rgb2dvi's
//                SerialClk input since kGenerateSerialClk = false)
// from the 100 MHz Nexys Video system clock, using a native MMCME2_BASE.
//------------------------------------------------------------------------
module clk_dvi (
    input  wire clk_100m,
    input  wire reset,
    output wire clk_pix,
    output wire clk_serial,
    output wire locked
);

    wire clkfb;
    wire clk_pix_unbuf, clk_serial_unbuf, clkfb_unbuf;

    MMCME2_BASE #(
        .BANDWIDTH        ("OPTIMIZED"),
        .CLKIN1_PERIOD    (10.0),        // 100 MHz input
        .DIVCLK_DIVIDE    (1),
        .CLKFBOUT_MULT_F  (10.0),        // VCO = 100 * 10 / 1 = 1000 MHz
        .CLKOUT0_DIVIDE_F (8.0),         // 1000 / 8  = 125 MHz (serial, 5x)
        .CLKOUT1_DIVIDE   (40),          // 1000 / 40 = 25  MHz (pixel)
        .CLKOUT0_PHASE    (0.0),
        .CLKOUT1_PHASE    (0.0),
        .CLKOUT0_DUTY_CYCLE(0.5),
        .CLKOUT1_DUTY_CYCLE(0.5),
        .REF_JITTER1      (0.010),
        .STARTUP_WAIT     ("FALSE")
    ) mmcm_inst (
        .CLKIN1   (clk_100m),
        .CLKFBIN  (clkfb),
        .CLKFBOUT (clkfb_unbuf),
        .CLKOUT0  (clk_serial_unbuf),
        .CLKOUT1  (clk_pix_unbuf),
        .LOCKED   (locked),
        .PWRDWN   (1'b0),
        .RST      (reset)
    );

    BUFG bufg_fb     (.I(clkfb_unbuf),      .O(clkfb));
    BUFG bufg_pix    (.I(clk_pix_unbuf),    .O(clk_pix));
    BUFG bufg_serial (.I(clk_serial_unbuf), .O(clk_serial));

endmodule