/*
 * QuantumArb 2.0 - High-Level Synthesis (HLS) Proof-of-Concept
 *
 * File: src/hw_fpga/hls_sma_poc.cpp
 *
 * Description:
 * This HLS module calculates a Simple Moving Average (SMA) over a stream of
 * incoming price data. It is designed to be synthesized into a hardware kernel
 * for an FPGA.
 *
 * The code uses HLS pragmas to guide the compiler to create an optimal hardware
 * implementation. Specifically, it uses a pipelined architecture to process one
 * new price point per clock cycle after an initial warm-up period.
 *
 * This kind of hardware block could be used to generate real-time technical
 * indicators that feed into the FPGA's own decision-making logic or the
 * main strategy engine.
 *
 * Synthesis:
 * This C++ function would be the top-level function for the HLS compiler
 * (e.g., Xilinx Vitis HLS). The compiler would generate Verilog/VHDL from it.
 */

#include <cstdint>

// Define a constant for the SMA window size.
// This must be a compile-time constant for HLS to create hardware of a fixed size.
const int WINDOW_SIZE = 10;

// Use a typedef for clarity. In a real HLS project, you'd use fixed-point
// types from an HLS library (e.g., ap_fixed) for more precision.
typedef uint64_t price_t;
typedef uint64_t sum_t;

/**
 * @brief Top-level HLS function for a streaming SMA calculation.
 *
 * @param price_in      Input stream of new prices.
 * @param sma_out       Output stream for the calculated SMA.
 */
void hls_sma_poc(
    price_t price_in,
    price_t& sma_out
) {
    // HLS PRAGMAS: These are directives for the synthesis tool.
    // INTERFACE: Defines how the function arguments map to hardware ports (e.g., AXI-Stream, ap_vld).
    // 'ap_vld' creates a data input with a valid signal. 'ap_ovld' for output.
    #pragma HLS INTERFACE ap_vld port=price_in
    #pragma HLS INTERFACE ap_ovld port=sma_out
    // 'ap_ctrl_none' removes standard block-level control signals (start, done, idle)
    // for a purely streaming, combinatorial-like interface.
    #pragma HLS INTERFACE ap_ctrl_none port=return

    // Use 'static' to ensure these variables are synthesized as registers
    // that persist their state across function calls (i.e., across clock cycles).
    static price_t price_history[WINDOW_SIZE] = {0};
    static sum_t current_sum = 0;
    static uint8_t current_idx = 0;

    // HLS PRAGMA: Array Partition
    // This directive splits the array into individual registers instead of a single
    // block RAM. This allows all elements to be accessed simultaneously, which is
    // crucial for the pipelined logic below.
    #pragma HLS ARRAY_PARTITION variable=price_history complete dim=1

    // --- Core Streaming Logic ---

    // 1. Subtract the oldest price from the sum.
    // The oldest price is the one at the current index, which is about to be replaced.
    sum_t old_sum = current_sum;
    price_t oldest_price = price_history[current_idx];
    sum_t new_sum = old_sum - oldest_price + price_in;

    // 2. Update the history buffer with the new price.
    price_history[current_idx] = price_in;

    // 3. Update the rolling sum.
    current_sum = new_sum;

    // 4. Update the index for the next cycle, wrapping around the buffer.
    if (current_idx == WINDOW_SIZE - 1) {
        current_idx = 0;
    } else {
        current_idx++;
    }

    // 5. Calculate and output the new SMA.
    sma_out = new_sum / WINDOW_SIZE;
}
