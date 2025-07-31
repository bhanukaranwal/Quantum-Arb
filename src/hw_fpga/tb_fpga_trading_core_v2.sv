/*
 * QuantumArb 2.0 - SystemVerilog Testbench for Integrated FPGA Trading Core
 *
 * File: src/hw_fpga/tb_fpga_trading_core_v2.sv
 *
 * Description:
 * This updated testbench validates the 'fpga_trading_core' with the integrated
 * 'hw_feature_engine'. It simulates a more realistic scenario including
 * order book building and trade events to test the stateful feature calculation
 * and the final AI-augmented trade decision logic.
 */

`timescale 1ns / 1ps

module tb_fpga_trading_core_v2;

    // --- Testbench Signals ---
    logic clk;
    logic rst_n;
    logic market_data_valid;
    logic [31:0] market_data_price;
    logic [31:0] market_data_size;
    logic [1:0]  market_data_type; // 00=NewBid, 01=NewAsk, 10=Trade
    wire send_order;

    // --- Instantiate the Device Under Test (DUT) ---
    fpga_trading_core dut (
        .clk(clk),
        .rst_n(rst_n),
        .market_data_valid(market_data_valid),
        .market_data_price(market_data_price),
        .market_data_size(market_data_size),
        .market_data_type(market_data_type),
        .send_order(send_order)
    );

    // --- Clock and Reset Generation ---
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz clock
    end

    // --- Test Sequence Task ---
    task drive_market_event(input [1:0] type, input [31:0] price, input [31:0] size);
        @(posedge clk);
        market_data_valid <= 1'b1;
        market_data_type  <= type;
        market_data_price <= price;
        market_data_size  <= size;
        @(posedge clk);
        market_data_valid <= 1'b0;
    endtask

    // --- Main Test Sequence ---
    initial begin
        // 1. Initialize and reset the DUT
        $display("TESTBENCH: Initializing and resetting the core...");
        rst_n <= 1'b0;
        market_data_valid <= 1'b0;
        repeat (2) @(posedge clk);
        rst_n <= 1'b1;

        // 2. Scenario 1: Build up book imbalance to favor a BUY signal
        $display("\nTESTBENCH: Scenario 1 - Building high book imbalance.");
        drive_market_event(2'b00, 1000, 800); // High Bid Volume
        drive_market_event(2'b00, 999,  700);
        drive_market_event(2'b01, 1002, 200); // Low Ask Volume
        drive_market_event(2'b01, 1003, 100);
        $display("TESTBENCH: Book imbalance feature should now be high. No trade expected yet.");
        
        // 3. Scenario 2: Create high trade intensity
        $display("\nTESTBENCH: Scenario 2 - Simulating high trade intensity.");
        repeat (30) begin // Simulate 30 trade events
            drive_market_event(2'b10, 1001, 5); // Trade event
        end
        $display("TESTBENCH: Trade intensity feature should now be high. No trade expected yet.");

        // 4. Scenario 3: Create a profitable spread
        $display("\nTESTBENCH: Scenario 3 - Creating profitable spread. TRADE EXPECTED.");
        // At this point, both book_imbalance and trade_intensity should be above the
        // thresholds in the fpga_inference_engine, causing ai_prediction to be 1.
        // Now, we create a spread that is wider than the SPREAD_THRESHOLD (5).
        drive_market_event(2'b01, 1015, 50); // New ask at 1015. Best bid is 1000. Spread = 15.
        
        // Wait a few cycles to observe the result
        repeat (5) @(posedge clk);

        $display("\nTESTBENCH: Simulation finished.");
        $finish;
    end

    // --- Monitors ---
    always @(posedge clk) begin
        if (send_order) begin
            $display("MONITOR @ %t: 'send_order' signal DETECTED! BBO was [%d, %d]. AI Prediction was %b.",
                $time, dut.best_bid_price, dut.best_ask_price, dut.ai_prediction);
        end
    end

endmodule
