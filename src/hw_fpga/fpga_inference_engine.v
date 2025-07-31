/*
 * QuantumArb 2.0 - FPGA On-Chip Inference Engine
 *
 * File: src/hw_fpga/fpga_inference_engine.v
 *
 * Description:
 * This Verilog module implements the lightweight decision tree model trained
 * by 'train_fpga_model.py'. It performs inference directly in hardware to
 * generate a predictive signal with the lowest possible latency (single-digit
 * nanoseconds).
 *
 * The logic is a direct hardware translation of the rules from the
 * 'fpga_model_spec.txt' file.
 *
 * Implementation Notes:
 * - The inputs ('book_imbalance', 'trade_intensity') are assumed to be
 * fixed-point numbers. For example, a 'book_imbalance' of 0.60 in the spec
 * would be represented as an integer value here (e.g., 600 if scaled by 1000).
 * - The logic is purely combinatorial (`always @*`) to ensure the prediction
 * is available in the same clock cycle as the inputs.
 */

module fpga_inference_engine (
    // System Signals
    input wire clk,
    input wire rst_n,

    // Input Features (from a feature calculation engine on the FPGA)
    // Represents the ratio of bid volume to total volume, scaled.
    // E.g., a 16-bit fixed-point number with 10 fractional bits.
    input wire [15:0] book_imbalance_fixed,
    // Represents the number of trades in the last 100ms.
    input wire [7:0]  trade_intensity,

    // Output Signal
    // 1'b1 -> Predict price UP
    // 1'b0 -> Predict price DOWN/NEUTRAL
    output reg prediction
);

    // --- Thresholds from the fpga_model_spec.txt ---
    // These values are derived from the training script and hardcoded here.
    // 'book_imbalance <= 0.60' -> The threshold is 0.60.
    // Scaled by 2^10 (1024), 0.60 * 1024 = 614.
    localparam [15:0] IMBALANCE_THRESHOLD = 16'd614;

    // 'trade_intensity <= 25.50' -> The threshold is 25.
    localparam [7:0]  INTENSITY_THRESHOLD = 8'd25;


    // --- Combinatorial Inference Logic ---
    // This block directly implements the if-then-else structure of the decision tree.
    always @* begin
        // Default prediction is 0 (no trade)
        prediction = 1'b0;

        // if (book_imbalance > 0.60)
        if (book_imbalance_fixed > IMBALANCE_THRESHOLD) begin
            // if (trade_intensity > 25)
            if (trade_intensity > INTENSITY_THRESHOLD) begin
                // class: 1
                prediction = 1'b1;
            end else begin
                // class: 0
                prediction = 1'b0;
            end
        end else begin
            // class: 0
            prediction = 1'b0;
        end
    end

endmodule
