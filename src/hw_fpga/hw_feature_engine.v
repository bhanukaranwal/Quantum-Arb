/*
 * QuantumArb 2.0 - FPGA Hardware Feature Engine
 *
 * File: src/hw_fpga/hw_feature_engine.v
 *
 * Description:
 * This module calculates market microstructure features in real-time from a
 * stream of market events. It is designed to feed the on-chip AI inference engine.
 *
 * Features Calculated:
 * - book_imbalance: The ratio of total bid volume to total volume at the top
 * levels of the book.
 * - trade_intensity: The number of trade events within a recent, sliding
 * time window.
 *
 * This module maintains state (registers) to track volumes and event counts.
 */

module hw_feature_engine (
    // System Signals
    input wire clk,
    input wire rst_n,

    // Market Event Input
    input wire        event_valid,
    input wire [31:0] event_price,
    input wire [31:0] event_size,
    input wire [1:0]  event_type, // 00=NewBid, 01=NewAsk, 10=Trade

    // Output Features
    output reg [15:0] book_imbalance_fixed,
    output reg [7:0]  trade_intensity
);

    // --- State Registers ---
    reg [63:0] total_bid_volume;
    reg [63:0] total_ask_volume;
    reg [7:0]  trade_count_window;

    // --- Logic for Trade Intensity (Sliding Window Counter) ---
    // This counter decrements over time and increments with each trade event.
    localparam COUNT_DECAY_RATE = 8'd1; // Decrement by 1 every N cycles
    localparam CYCLES_PER_DECAY = 1000; // N cycles for decay
    reg [15:0] decay_timer;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            trade_count_window <= 8'd0;
            decay_timer <= 0;
        end else begin
            // Increment count on a trade event
            if (event_valid && event_type == 2'b10) begin
                if (trade_count_window < 8'hFF) begin
                    trade_count_window <= trade_count_window + 1;
                end
            end

            // Decrement count based on the timer
            if (decay_timer == CYCLES_PER_DECAY - 1) begin
                if (trade_count_window > COUNT_DECAY_RATE) begin
                    trade_count_window <= trade_count_window - COUNT_DECAY_RATE;
                end else begin
                    trade_count_window <= 8'd0;
                end
                decay_timer <= 0;
            end else begin
                decay_timer <= decay_timer + 1;
            end
        end
    end

    // --- Logic for Book Imbalance ---
    // This logic updates total volumes based on new orders.
    // A real implementation would also handle order modifications and cancellations.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            total_bid_volume <= 64'd0;
            total_ask_volume <= 64'd0;
            book_imbalance_fixed <= 16'd0;
        end else begin
            if (event_valid) begin
                case (event_type)
                    2'b00: total_bid_volume <= total_bid_volume + event_size; // New Bid
                    2'b01: total_ask_volume <= total_ask_volume + event_size; // New Ask
                endcase
            end

            // Calculate imbalance: total_bid / (total_bid + total_ask)
            // This requires a hardware divider, which can be resource-intensive.
            // For FPGAs, it's often implemented as a multi-cycle operation.
            // Here, we'll represent it conceptually.
            if ((total_bid_volume + total_ask_volume) > 0) begin
                // Result is scaled by 2^10 (1024) to fit in a fixed-point format.
                book_imbalance_fixed <= (total_bid_volume * 1024) / (total_bid_volume + total_ask_volume);
            end else begin
                book_imbalance_fixed <= 16'd0;
            end
        end
    end

    // Assign the final output value for trade intensity
    always @* begin
        trade_intensity = trade_count_window;
    end

endmodule
