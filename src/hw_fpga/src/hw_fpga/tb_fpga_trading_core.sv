/*
 * QuantumArb 2.0 - SystemVerilog Testbench for FPGA Trading Core
 *
 * File: src/hw_fpga/tb_fpga_trading_core.sv
 *
 * Description:
 * This testbench validates the functionality of the top-level 'fpga_trading_core'
 * module. It simulates a sequence of market data events and checks if the
 * 'send_order' signal is asserted correctly based on the internal logic
 * (spread condition and AI prediction).
 */

`timescale 1ns / 1ps

module tb_fpga_trading_core;

    // --- Testbench Signals ---
    logic clk;
    logic rst_n;
    logic market_data_valid;
    logic [31:0] market_data_price;
    logic [31:0] market_data_size;
    logic market_data_side;
    wire send_order;

    // --- Instantiate the Device Under Test (DUT) ---
    fpga_trading_core dut (
        .clk(clk),
        .rst_n(rst_n),
        .market_data_valid(market_data_valid),
        .market_data_price(market_data_price),
        .market_data_size(market_data_size),
        .market_data_side(market_data_side),
        .send_order(send_order)
    );

    // --- Clock and Reset Generation ---
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz clock
    end

    // --- Test Sequence ---
    initial begin
        // 1. Initialize and reset the DUT
        $display("TESTBENCH: Initializing and resetting the core...");
        rst_n = 1'b0;
        market_data_valid = 1'b0;
        market_data_price = 32'd0;
        market_data_size = 32'd0;
        market_data_side = 1'b0;
        repeat (2) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);

        // 2. Scenario 1: Establish an initial order book state (no profitable spread)
        $display("\nTESTBENCH: Scenario 1 - Establishing initial book state.");
        // Send a BID
        market_data_valid <= 1'b1;
        market_data_price <= 32'd1000;
        market_data_size  <= 32'd10;
        market_data_side  <= 1'b0; // BID
        @(posedge clk);
        // Send an ASK
        market_data_price <= 32'd1002; // Spread is 2, which is < SPREAD_THRESHOLD (5)
        market_data_side  <= 1'b1; // ASK
        @(posedge clk);
        market_data_valid <= 1'b0;
        @(posedge clk);
        $display("TESTBENCH: Book established. Best Bid: 1000, Best Ask: 1002. No trade expected.");
        
        // 3. Scenario 2: Create a profitable spread, AI should confirm
        $display("\nTESTBENCH: Scenario 2 - Creating profitable spread. Trade is expected.");
        // Send a new ASK that creates a wide spread
        market_data_valid <= 1'b1;
        market_data_price <= 32'd1010; // Spread is 10, which is > SPREAD_THRESHOLD (5)
        market_data_side  <= 1'b1; // ASK
        @(posedge clk);
        market_data_valid <= 1'b0;
        @(posedge clk);
        // The AI prediction is hardcoded to 1 in the DUT, so a trade should be triggered on this clock cycle.
        
        // 4. Scenario 3: Return to a non-profitable state
        $display("\nTESTBENCH: Scenario 3 - Spread narrows. No trade expected.");
        market_data_valid <= 1'b1;
        market_data_price <= 32'd1009; // New best bid, spread becomes 1
        market_data_side  <= 1'b0; // BID
        @(posedge clk);
        market_data_valid <= 1'b0;
        @(posedge clk);

        $display("\nTESTBENCH: Simulation finished.");
        $finish;
    end

    // --- Monitors and Assertions ---
    // This block continuously monitors the DUT's outputs.
    always @(posedge clk) begin
        if (send_order) begin
            $display("MONITOR: 'send_order' signal DETECTED at time %t", $time);
        end
    end

    // Formal-style assertion to check the trade condition
    property check_trade_logic;
        @(posedge clk)
        // If a trade signal is sent...
        send_order |->
        // ...then the spread must have been profitable AND the AI must have predicted UP on the previous cycle.
        ($past(dut.best_ask_price - dut.best_bid_price) > dut.SPREAD_THRESHOLD && $past(dut.ai_prediction) == 1);
    endproperty

    assert_trade_condition: assert property (check_trade_logic) else $error("Trade signal asserted without valid conditions!");

endmodule
