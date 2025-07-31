/*
 * QuantumArb 2.0 - FPGA Formal Verification Testbench
 *
 * File: src/hw_fpga/tb_order_book_formal.sv
 *
 * Description:
 * This SystemVerilog testbench is used to formally verify the correctness
 * of the `order_book_poc` Verilog module. It drives inputs to the module
 * and uses concurrent assertions to check that the outputs always adhere
 * to the specified properties.
 *
 * This is a more rigorous approach than simple simulation, as it explores
 * the entire state space to find any possible violations of the rules.
 *
 * Tools:
 * This would be run using a formal verification tool like Synopsys VC Formal,
 * Cadence JasperGold, or an open-source alternative.
 */

`timescale 1ns / 1ps

module tb_order_book_formal;

    // --- Signals to connect to the DUT (Device Under Test) ---
    logic clk;
    logic rst_n;
    logic valid_in;
    logic [31:0] price_in;
    logic [31:0] size_in;
    logic side_in; // 0 for BID, 1 for ASK

    logic [31:0] best_bid_price;
    logic [31:0] best_bid_size;
    logic [31:0] best_ask_price;
    logic [31:0] best_ask_size;

    // --- Instantiate the Device Under Test ---
    order_book_poc dut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .price_in(price_in),
        .size_in(size_in),
        .side_in(side_in),
        .best_bid_price(best_bid_price),
        .best_bid_size(best_bid_size),
        .best_ask_price(best_ask_price),
        .best_ask_size(best_ask_size)
    );

    // --- Clock and Reset Generation ---
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz clock
    end

    initial begin
        rst_n = 0;
        valid_in = 0;
        price_in = 0;
        size_in = 0;
        side_in = 0;
        #20 rst_n = 1; // Release reset
        // Test sequence would go here in a simulation testbench.
        // For formal verification, we focus on properties.
    end

    // --- Formal Properties and Assertions ---
    // These properties define the "rules" that the DUT must always follow.
    // The formal tool will try to mathematically prove that these assertions
    // can never be violated.

    property p_reset_state;
        @(posedge clk) disable iff (!rst_n)
            (best_bid_price == 0 && best_ask_price == 32'hFFFFFFFF);
    endproperty
    a_reset_state: assert property (p_reset_state) else $error("Reset state is incorrect.");

    property p_bid_is_always_less_than_ask;
        @(posedge clk) disable iff (!rst_n)
            // If both bid and ask are valid (i.e., not at their initial reset state)
            (best_bid_price != 0 && best_ask_price != 32'hFFFFFFFF) |-> (best_bid_price < best_ask_price);
    endproperty
    a_bid_ask_spread: assert property (p_bid_is_always_less_than_ask) else $error("CRITICAL: Bid price crossed ask price!");

    property p_bid_only_increases;
        @(posedge clk) disable iff (!rst_n)
            // If a valid new bid arrives that is higher than the previous best bid...
            (valid_in && side_in == 0 && price_in > $past(best_bid_price)) |=>
            // ...then the new best bid price must be equal to the input price.
            (best_bid_price == price_in);
    endproperty
    a_bid_updates_correctly: assert property (p_bid_only_increases) else $error("Best bid did not update correctly.");

    property p_ask_only_decreases;
        @(posedge clk) disable iff (!rst_n)
            // If a valid new ask arrives that is lower than the previous best ask...
            (valid_in && side_in == 1 && price_in < $past(best_ask_price)) |=>
            // ...then the new best ask price must be equal to the input price.
            (best_ask_price == price_in);
    endproperty
    a_ask_updates_correctly: assert property (p_ask_only_decreases) else $error("Best ask did not update correctly.");


    // In a full formal testbench, you would add many more properties covering
    // corner cases, size updates, order modifications, and deletions.

endmodule
