`default_nettype none
`timescale 1ns/1ns

import gpu_pkg::*;

// ============================================================
// INSTRUCTION FETCHER
//
// Retrieves instructions from program memory.
//
// Current Flow:
//
//   FETCH State
//        |
//        v
//   Memory Request
//        |
//        v
//   Instruction Returned
//        |
//        v
//   DECODE State
//
// Future Evolution:
// - Instruction Cache
// - Prefetch Buffer
// - Branch Prediction
// ============================================================

module fetch #(
    parameter int PROGRAM_MEM_ADDR_BITS = 8,
    parameter int PROGRAM_MEM_DATA_BITS = 16
)(
    input  logic clk,
    input  logic reset,

    // Execution State
    input  core_state_t core_state,
    input  logic [PROGRAM_MEM_ADDR_BITS-1:0] current_pc,

    // Program Memory Interface
    output logic mem_read_valid,
    output logic [PROGRAM_MEM_ADDR_BITS-1:0] mem_read_address,

    input  logic mem_read_ready,
    input  logic [PROGRAM_MEM_DATA_BITS-1:0] mem_read_data,

    // Fetch Output
    output fetcher_state_t fetcher_state,
    output logic [PROGRAM_MEM_DATA_BITS-1:0] instruction
);

    // --------------------------------------------------------
    // Fetch State Machine
    // --------------------------------------------------------

    always_ff @(posedge clk) begin

        if (reset) begin
            fetcher_state   <= FETCHER_IDLE;
            mem_read_valid  <= 1'b0;
            mem_read_address<= '0;
            instruction     <= '0;
        end
        else begin

            case (fetcher_state)

                FETCHER_IDLE: begin
                    if (core_state == CORE_FETCH) begin
                        fetcher_state   <= FETCHER_FETCHING;
                        mem_read_valid  <= 1'b1;
                        mem_read_address<= current_pc;
                    end
                end

                FETCHER_FETCHING: begin
                    if (mem_read_ready) begin
                        fetcher_state  <= FETCHER_FETCHED;
                        instruction    <= mem_read_data;
                        mem_read_valid <= 1'b0;
                    end
                end

                FETCHER_FETCHED: begin
                    if (core_state == CORE_DECODE) begin
                        fetcher_state <= FETCHER_IDLE;
                    end
                end

                default: begin
                    fetcher_state <= FETCHER_IDLE;
                end

            endcase
        end
    end
endmodule
`default_nettype wire

