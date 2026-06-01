package gpu_pkg;

`include "gpu_params.svh"
`include "gpu_types.svh"

// ============================================================
// Tiny GPU Next
// GPU Package
// Central repository for:
// - ISA definitions
// - architectural constants
// - shared typedefs
// - utility functions
// ============================================================

// ------------------------------------------------------------
// ISA Opcodes
// ------------------------------------------------------------
// Current ISA follows original Tiny-GPU instruction set.
// Future ISA extensions:
// SHLD
// SHST
// BARRIER
// VADD
// VMUL
// ------------------------------------------------------------
typedef enum logic [3:0] {
    OP_NOP  = 4'h0,
    OP_ADD  = 4'h1,
    OP_SUB  = 4'h2,
    OP_MUL  = 4'h3,
    OP_DIV  = 4'h4,
    OP_LOAD = 4'h5,
    OP_STORE= 4'h6,
    OP_JMP  = 4'h7,
    OP_BEQ  = 4'h8,
    OP_HALT = 4'hF
} opcode_t;

// ------------------------------------------------------------
// Scheduler Configuration
// ------------------------------------------------------------
localparam int INVALID_WARP_ID = -1;

// ------------------------------------------------------------
// Memory Constants
// ------------------------------------------------------------
localparam logic [ADDR_WIDTH-1:0] RESET_PC = '0;

// ------------------------------------------------------------
// Utility Functions
// ------------------------------------------------------------
function automatic logic warp_active( input warp_context_t warp );
    warp_active = warp.valid && (warp.state != WARP_DONE);
endfunction

function automatic logic warp_schedulable( input warp_context_t warp );
    warp_schedulable = warp.valid && (warp.state == WARP_READY);
endfunction
endpackage