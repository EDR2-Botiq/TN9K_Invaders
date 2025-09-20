// HDMI Encoder with Audio Support - SystemVerilog Wrapper
// Wraps the new HDMI implementation to maintain compatibility with existing VHDL code
// Supports HDMI with embedded audio from Space Invaders game

module hdmi_encoder (
    // Clocks
    input  logic clk_pixel,     // 25.2 MHz pixel clock
    input  logic clk_tmds,      // 126 MHz TMDS clock (5x pixel clock)
    input  logic reset_n,       // Active low reset

    // Video inputs
    input  logic [23:0] rgb_data,  // RGB data (8:8:8)
    input  logic hsync,            // Horizontal sync
    input  logic vsync,            // Vertical sync
    input  logic de,               // Data enable

    // Audio inputs (optional - can be tied to zero if no audio)
    input  logic [15:0] audio_sample_left,   // Left channel audio
    input  logic [15:0] audio_sample_right,  // Right channel audio

    // HDMI differential outputs
    output logic hdmi_tx_clk_p,   // TMDS clock positive
    output logic hdmi_tx_clk_n,   // TMDS clock negative
    output logic [2:0] hdmi_tx_p, // TMDS data positive [2:0] = [R:G:B]
    output logic [2:0] hdmi_tx_n  // TMDS data negative [2:0] = [R:G:B]
);

// Internal signals
logic reset;
logic [2:0] tmds;
logic tmds_clock;
logic clk_audio;

// Convert active-low reset to active-high
assign reset = ~reset_n;

// Generate audio clock (simple approximation from pixel clock)
// For proper audio, this should be derived from a proper audio PLL
logic [9:0] audio_clk_counter = 10'd0;
always_ff @(posedge clk_pixel) begin
    if (reset) begin
        audio_clk_counter <= 10'd0;
        clk_audio <= 1'b0;
    end else begin
        // Approximate: 25.2MHz / 525 ≈ 48kHz
        if (audio_clk_counter == 10'd524) begin
            audio_clk_counter <= 10'd0;
            clk_audio <= ~clk_audio;
        end else begin
            audio_clk_counter <= audio_clk_counter + 1'b1;
        end
    end
end

// Audio sample word array for HDMI module
logic [15:0] audio_sample_word [1:0];
assign audio_sample_word[0] = audio_sample_left;
assign audio_sample_word[1] = audio_sample_right;

// Instantiate the main HDMI module with audio support
hdmi #(
    .VIDEO_ID_CODE(1),           // 640x480@60Hz
    .IT_CONTENT(1'b1),           // IT content (full range RGB)
    .DVI_OUTPUT(1'b0),           // True HDMI with audio
    .VIDEO_REFRESH_RATE(59.94),  // 60Hz refresh rate
    .AUDIO_RATE(48000),          // 48 kHz audio
    .AUDIO_BIT_WIDTH(16),        // 16-bit audio
    .VENDOR_NAME("FPGA SI\0\0"),   // 8-byte vendor name
    .PRODUCT_DESCRIPTION("Space Invaders\0\0\0"), // 16-byte product description
    .SOURCE_DEVICE_INFORMATION(8'h00)
) hdmi_inst (
    .clk_pixel_x5(clk_tmds),
    .clk_pixel(clk_pixel),
    .clk_audio(clk_audio),
    .reset(reset),
    .rgb(rgb_data),
    .audio_sample_word(audio_sample_word),
    .tmds(tmds),
    .tmds_clock(tmds_clock),
    .cx(),      // Not used in this wrapper
    .cy(),      // Not used in this wrapper
    .frame_width(),
    .frame_height(),
    .screen_width(),
    .screen_height()
);

// Convert single-ended TMDS to differential using Gowin primitives
// TMDS Clock differential output
ELVDS_OBUF tmds_clk_obuf (
    .I(tmds_clock),
    .O(hdmi_tx_clk_p),
    .OB(hdmi_tx_clk_n)
);

// TMDS Data differential outputs
genvar i;
generate
    for (i = 0; i < 3; i++) begin : tmds_obuf_gen
        ELVDS_OBUF tmds_data_obuf (
            .I(tmds[i]),
            .O(hdmi_tx_p[i]),
            .OB(hdmi_tx_n[i])
        );
    end
endgenerate

endmodule