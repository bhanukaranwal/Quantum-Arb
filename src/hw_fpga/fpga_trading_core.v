/*
 * QuantumArb 2.0 - FPGA Top-Level Trading Core
 *
 * File: src/hw_fpga/fpga_trading_core.v
 *
 * Description:
 * This module is the top-level trading core, integrating all critical hardware
 * components to create the complete tick-to-trade path on the FPGA.
 *
 * It instantiates:
 * 1. An order book to track the market.
 * 2. A feature engine to calculate microstructure features.
 * 3. The on-chip inference engine to get an AI prediction.
 * 4. Final decision logic to generate a trade signal.
 *
 * The output of this module is a single 'send_order' signal that would trigger
 * an IOC/FOK order router.
 */

module fpga_trading_core (
    // System Signals
    input wire clk,
    input wire rst_n,

    // Market Data Input (Simplified)
    // In reality, this would be a stream of raw ITCH/binary messages.
    input wire        market_data_valid,
    input wire [31:0] market_data_price,
    input wire [31:0] market_data_size,
    input wire        market_data_side, // 0 for BID, 1 for ASK

    // Output Trade Signal
    output reg send_order // Asserted high for one clock cycle to trigger a trade
);

    // --- Internal Wires and Registers ---

    // Outputs from the Order Book
    wire [31:0] best_bid_price;
    wire [31:0] best_ask_price;

    // Outputs from the Feature Engine
    wire [15:0] book_imbalance_fixed;
    wire [7:0]  trade_intensity;

    // Output from the Inference Engine
    wire ai_prediction;

    // --- 1. Instantiate the Order Book ---
    // This maintains the best bid and offer.
    order_book_poc order_book (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(market_data_valid),
        .price_in(market_data_price),
        .size_in(market_data_size),
        .side_in(market_data_side),
        .best_bid_price(best_bid_price),
        .best_ask_price(best_ask_price)
        // Other outputs like size are omitted for brevity
    );

    // --- 2. Instantiate the Feature Engine (Conceptual) ---
    // This block would calculate features based on the raw market data stream.
    // For this example, we'll use placeholder logic.
    // A real implementation would be a complex state machine.
    assign book_imbalance_fixed = 16'd716; // Mock value > 614
    assign trade_intensity = 8'd30;       // Mock value > 25

    // --- 3. Instantiate the On-Chip Inference Engine ---
    // This takes the features and produces a predictive signal.
    fpga_inference_engine inference_engine (
        .clk(clk),
        .rst_n(rst_n),
        .book_imbalance_fixed(book_imbalance_fixed),
        .trade_intensity(trade_intensity),
        .prediction(ai_prediction)
    );

    // --- 4. Final Trade Decision Logic ---
    // This combinatorial logic combines the market state (spread) with the
    // AI prediction to make the final trade decision.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            send_order <= 1'b0;
        end else begin
            // Default to no trade
            send_order <= 1'b0;

            // Define the arbitrage condition (e.g., spread > some threshold)
            // For simplicity, let's assume we are arbitraging this single instrument
            // against another venue with a fixed price, creating a simple threshold.
            localparam SPREAD_THRESHOLD = 32'd5; // e.g., 5 ticks
            
            if ((best_ask_price - best_bid_price) > SPREAD_THRESHOLD) begin
                // A profitable spread exists. Now, check the AI prediction for confirmation.
                // Only send the order if the AI predicts the market will move in our favor.
                if (ai_prediction == 1'b1) begin
                    // Both conditions met. Trigger the trade.
                    send_order <= 1'b1;
                    $display("TRADE TRIGGERED at time %t: Spread > %d AND AI Prediction = 1", $time, SPREAD_THRESHOLD);
                end
            end
        end
    end

endmodule
