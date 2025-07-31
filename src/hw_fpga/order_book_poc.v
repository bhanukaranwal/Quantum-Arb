/*
 * QuantumArb 2.0 - FPGA Order Book Proof-of-Concept
 *
 * File: src/hw_fpga/order_book_poc.v
 *
 * Description:
 * This is a conceptual Verilog module representing a simplified, single-level
 * order book for one financial instrument. In a real-world scenario, this would be
 * far more complex, likely using BRAMs (Block RAMs) to store many price levels
 * and supporting multiple instruments.
 *
 * This POC demonstrates the core principle: market data comes in, and the
 * best bid and offer (BBO) are updated in hardware with minimal, deterministic latency.
 *
 * The module accepts a stream of order book updates and maintains the top-of-book.
 *
 * Synthesis:
 * This code is intended for synthesis on an FPGA (e.g., Xilinx or Intel).
 * The logic is primarily combinatorial to ensure that outputs are updated
 * in the same clock cycle as the inputs, minimizing latency.
 */

module order_book_poc (
    // System Signals
    input wire clk,         // System clock
    input wire rst_n,       // Asynchronous reset (active low)

    // Input Market Data (simplified 'Add Order' message)
    input wire        valid_in,     // Indicates a new order update is present
    input wire [31:0] price_in,     // Price of the new order
    input wire [31:0] size_in,      // Size/quantity of the new order
    input wire        side_in,      // 0 for BID, 1 for ASK

    // Output: Best Bid and Offer (BBO)
    output reg [31:0] best_bid_price, // Current best bid price
    output reg [31:0] best_bid_size,  // Current best bid size
    output reg [31:0] best_ask_price, // Current best ask price
    output reg [31:0] best_ask_size   // Current best ask size
);

    // Internal registers to hold the current BBO state.
    // In a real implementation, this would be a more complex data structure
    // like a priority queue or a sorted list stored in BRAM.
    reg [31:0] internal_best_bid_price;
    reg [31:0] internal_best_bid_size;
    reg [31:0] internal_best_ask_price;
    reg [31:0] internal_best_ask_size;

    // Combinatorial logic to update BBO outputs directly
    // This ensures the output reflects the most up-to-date state immediately.
    always @* begin
        best_bid_price = internal_best_bid_price;
        best_bid_size  = internal_best_bid_size;
        best_ask_price = internal_best_ask_price;
        best_ask_size  = internal_best_ask_size;
    end

    // Sequential logic to process incoming order updates
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset state: clear the order book
            internal_best_bid_price <= 32'd0;
            internal_best_bid_size  <= 32'd0;
            // Initialize ask price high to ensure the first valid ask is accepted
            internal_best_ask_price <= 32'hFFFFFFFF;
            internal_best_ask_size  <= 32'd0;
        end else begin
            // If a valid new order arrives, update the book
            if (valid_in) begin
                if (side_in == 0) begin // This is a BID
                    // If the new bid is higher than the current best bid, it becomes the new best bid.
                    // A real book would handle modifications and deletions.
                    if (price_in > internal_best_bid_price) begin
                        internal_best_bid_price <= price_in;
                        internal_best_bid_size  <= size_in;
                    end
                end else begin // This is an ASK
                    // If the new ask is lower than the current best ask, it becomes the new best ask.
                    if (price_in < internal_best_ask_price) begin
                        internal_best_ask_price <= price_in;
                        internal_best_ask_size  <= size_in;
                    end
                end
            end
        end
    end

endmodule
