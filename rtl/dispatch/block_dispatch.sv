`default_nettype none
`timescale 1ns/1ns

module block_dispatch #(
    parameter int NUM_CORES         = 2,
    parameter int THREADS_PER_BLOCK = 4,
    parameter int NUM_WARPS         = 4
)(
    input  logic clk,
    input  logic reset,
    input  logic start,

    // Kernel Metadata
    input  logic [7:0] thread_count,

    // Core States
    input  logic [NUM_CORES-1:0] core_done,
    output logic [NUM_CORES-1:0] core_start,
    output logic [NUM_CORES-1:0] core_reset,
    output logic [7:0] core_block_id [NUM_CORES-1:0],

    output logic [$clog2(THREADS_PER_BLOCK):0] core_thread_count [NUM_CORES-1:0],

    // Warp Allocation Interface
    output logic alloc_valid,
    output logic [$clog2(NUM_WARPS)-1:0] alloc_warp_id,
    output logic [31:0] alloc_pc,

    // Kernel Execution
    output logic done
);

    import gpu_pkg::*;
    logic [7:0] total_blocks;
    logic [7:0] blocks_dispatched;
    logic [7:0] blocks_done;
    logic start_execution;
    logic [$clog2(NUM_WARPS)-1:0] next_warp_id;

    assign total_blocks = (thread_count + THREADS_PER_BLOCK - 1) / THREADS_PER_BLOCK;

    always_ff @(posedge clk) begin

        if (reset) begin
            done <= 1'b0;
            blocks_dispatched <= '0;
            blocks_done       <= '0;
            start_execution <= 1'b0;
            next_warp_id <= '0;
            alloc_valid   <= 1'b0;
            alloc_warp_id <= '0;
            alloc_pc      <= '0;

            for (int i = 0; i < NUM_CORES; i++) begin
                core_start[i]        <= 1'b0;
                core_reset[i]        <= 1'b1;
                core_block_id[i]     <= '0;
                core_thread_count[i] <= THREADS_PER_BLOCK;
            end
        end
        else if (start) begin
            alloc_valid <= 1'b0;
            if (!start_execution) begin
                start_execution <= 1'b1;
                for (int i = 0; i < NUM_CORES; i++) begin
                    core_reset[i] <= 1'b1;
                end
            end

            if (blocks_done >= total_blocks) begin
                done <= 1'b1;
            end

            for (int i = 0; i < NUM_CORES; i++) begin
                if (core_reset[i]) begin
                    core_reset[i] <= 1'b0;
                    if (blocks_dispatched < total_blocks) begin
                        core_start[i] <= 1'b1;
                        core_block_id[i] <= blocks_dispatched;
                        core_thread_count[i] <= (blocks_dispatched == total_blocks - 1) ? thread_count - (blocks_dispatched * THREADS_PER_BLOCK) : THREADS_PER_BLOCK;
                        blocks_dispatched <= blocks_dispatched + 1'b1;
                        alloc_valid   <= 1'b1;
                        alloc_warp_id <= next_warp_id;
                        alloc_pc      <= RESET_PC;
                        next_warp_id <= next_warp_id + 1'b1;
                    end
                end
            end

            for (int i = 0; i < NUM_CORES; i++) begin
                if (core_start[i] && core_done[i]) begin
                    core_reset[i] <= 1'b1;
                    core_start[i] <= 1'b0;
                    blocks_done <= blocks_done + 1'b1;
                end
            end
        end
    end
endmodule

`default_nettype wire
