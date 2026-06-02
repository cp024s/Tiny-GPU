`default_nettype none
`timescale 1ns/1ns
import gpu_pkg::*;

// ============================================================
// SCHEDULER
//
// Controls execution flow of a single compute core.
//
// Execution Pipeline:
//
//   FETCH
//      |
//      v
//   DECODE
//      |
//      v
//   REQUEST
//      |
//      v
//   WAIT
//      |
//      v
//   EXECUTE
//      |
//      v
//   UPDATE
//
// Future Evolution:
// - Instruction Cache Support
// - Pipeline Support
// - Branch Divergence
// - Warp Scheduling
// ============================================================

module scheduler #(
    parameter int THREADS_PER_BLOCK = 4
)(
    input  logic clk,
    input  logic reset,
    input  logic start,

    // Control Signals
    input  logic decoded_mem_read_enable,
    input  logic decoded_mem_write_enable,
    input  logic decoded_ret,

    // Memory Access State
    input  fetcher_state_t fetcher_state,
    input  logic [1:0] lsu_state [THREADS_PER_BLOCK-1:0],

    // Current & Next PC
    output logic [7:0] current_pc,
    input  logic [7:0] next_pc [THREADS_PER_BLOCK-1:0],

    // Execution State
    output core_state_t core_state,
    output logic done
);

    logic any_lsu_waiting;
    integer i;

    // --------------------------------------------------------
    // LSU Wait Detection
    // --------------------------------------------------------

    always_comb begin
        any_lsu_waiting = 1'b0;

        for (i = 0; i < THREADS_PER_BLOCK; i++) begin
            if ((lsu_state[i] == 2'b01) || (lsu_state[i] == 2'b10)) begin
                any_lsu_waiting = 1'b1;
            end
        end
    end

    // --------------------------------------------------------
    // Scheduler State Machine
    // --------------------------------------------------------
    always_ff @(posedge clk) begin
        if (reset) begin
            current_pc <= '0;
            core_state <= CORE_IDLE;
            done       <= 1'b0;
        end

        else begin

            case (core_state)
                CORE_IDLE: begin
                    if (start) begin
                        core_state <= CORE_FETCH;
                    end
                end

                CORE_FETCH: begin
                    if (fetcher_state == FETCHER_FETCHED) begin
                        core_state <= CORE_DECODE;
                    end
                end

                CORE_DECODE: begin
                    core_state <= CORE_REQUEST;
                end

                CORE_REQUEST: begin
                    core_state <= CORE_WAIT;
                end

                CORE_WAIT: begin
                    if (!any_lsu_waiting) begin
                        core_state <= CORE_EXECUTE;
                    end
                end

                CORE_EXECUTE: begin
                    core_state <= CORE_UPDATE;
                end

                CORE_UPDATE: begin
                    if (decoded_ret) begin
                        done <= 1'b1;
                        core_state <= CORE_DONE;
                    end
                    else begin
                        // TODO:
                        // Branch divergence support.
                        // Currently assumes all thread PCs converge.
                        current_pc <= next_pc[THREADS_PER_BLOCK-1];
                        core_state <= CORE_FETCH;
                    end
                end

                CORE_DONE: begin
                    // no-op
                end

                default: begin
                    core_state <= CORE_IDLE;
                end
            endcase
        end
    end
endmodule
`default_nettype wire

