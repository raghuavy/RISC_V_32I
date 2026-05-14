`timescale 1ns / 1ps
import risc_pkg::*;

module alu (
    input  logic [63:0] a,
    input  logic [63:0] b,
    input  logic [63:0] pc,       // needed for AUIPC
    input  alu_op_t     alu_op,
    output logic [63:0] result,
    output logic        zero      // for branch comparisons
);

logic [31:0] word_tmp;

always_comb begin
    result   = 64'd0;
    word_tmp = 32'd0;
    case (alu_op)
        ALU_ADD:  result = a + b;
        ALU_SUB:  result = a - b;
        ALU_AND:  result = a & b;
        ALU_OR:   result = a | b;
        ALU_XOR:  result = a ^ b;
        ALU_SLL:  result = a << b[5:0];
        ALU_SRL:  result = a >> b[5:0];
        ALU_SRA:  result = $signed(a) >>> b[5:0];
        ALU_SLT:  result = ($signed(a) < $signed(b)) ? 64'd1 : 64'd0;
        ALU_SLTU: result = (a < b)                   ? 64'd1 : 64'd0;
        ALU_LUI:  result = b;
        ALU_AUIPC:result = pc + b;

        // RV64 word ops - compute into 32-bit tmp, then sign-extend to 64
        ALU_ADDW: begin word_tmp = a[31:0] + b[31:0];           result = {{32{word_tmp[31]}}, word_tmp}; end
        ALU_SUBW: begin word_tmp = a[31:0] - b[31:0];           result = {{32{word_tmp[31]}}, word_tmp}; end
        ALU_SLLW: begin word_tmp = a[31:0] << b[4:0];           result = {{32{word_tmp[31]}}, word_tmp}; end
        ALU_SRLW: begin word_tmp = a[31:0] >> b[4:0];           result = {{32{word_tmp[31]}}, word_tmp}; end
        ALU_SRAW: begin word_tmp = $signed(a[31:0]) >>> b[4:0]; result = {{32{word_tmp[31]}}, word_tmp}; end

        default:  result = 64'd0;
    endcase
end

assign zero = (result == 64'd0);

endmodule