/*
 * QuantumArb 2.0 - FPGA Top-Level Trading Core (Feature Engine Integrated)
 *
 * File: src/hw_fpga/fpga_trading_core.v
 *
 * Description:
 * This is the updated version of the trading core. It now instantiates and uses
 * the 'hw_feature_engine' to generate real-time features from the market data
 * stream, replacing the previous conceptual/mock implementation.
 */

module fpga_trading_core (
    // System Signals
    input wire clk,
    input wire rst_n,

    // Market Data Input (now with event_type)
    input wire        market_data_valid,
    input wire [31:0] market_data_price,
    input wire [31:0] market_data_size,
    input wire [1:0]  market_data_type, // 00=NewBid, 01=NewAsk, 10=Trade

    // Output Trade Signal
    output reg send_order
);

    // --- Internal Wires and Registers ---
    wire [31:0] best_bid_price;
    wire [31:0] best_ask_price;
    wire [15:0] book_imbalance_fixed;
    wire [7:0]  trade_intensity;
    wire ai_prediction;

    // --- 1. Instantiate the Order Book ---
    order_book_poc order_book (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(market_data_valid && (market_data_type == 2'b00 || market_data_type == 2'b01)),
        .price_in(market_data_price),
        .size_in(market_data_size),
        .side_in(market_data_type[0]), // 0 for Bid, 1 for Ask
        .best_bid_price(best_bid_price),
        .best_ask_price(best_ask_price)
    );

    // --- 2. NEW: Instantiate the Hardware Feature Engine ---
    hw_feature_engine feature_engine (
        .clk(clk),
        .rst_n(rst_n),
        .event_valid(market_data_valid),
        .event_price(market_data_price),
        .event_size(market_data_size),
        .event_type(market_data_type),
        .book_imbalance_fixed(book_imbalance_fixed),
        .trade_intensity(trade_intensity)
    );

    // --- 3. Instantiate the On-Chip Inference Engine ---
    fpga_inference_engine inference_engine (
        .clk(clk),
        .rst_n(rst_n),
        .book_imbalance_fixed(book_imbalance_fixed),
        .trade_intensity(trade_intensity),
        .prediction(ai_prediction)
    );

    // --- 4. Final Trade Decision Logic (Unchanged) ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            send_order <= 1'b0;
        end else begin
            send_order <= 1'b0;
            localparam SPREAD_THRESHOLD = 32'd5;
            
            if ((best_ask_price - best_bid_price) > SPREAD_THRESHOLD) begin
                if (ai_prediction == 1'b1) begin
                    send_order <= 1'b1;
                    $display("TRADE TRIGGERED at time %t: Spread > %d AND AI Prediction = 1", $time, SPREAD_THRESHOLD);
                end
            end
        end
    end

endmodule
