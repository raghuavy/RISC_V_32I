`timescale 1ns / 1ps
import risc_pkg::*;

module cpu_top (
    input  logic clk,
    input  logic reset_n
);

// -------------------------------------------------------
// Pipeline registers
// -------------------------------------------------------
if_id_t  if_id;
id_ex_t  id_ex;
ex_mem_t ex_mem;
mem_wb_t mem_wb;

// -------------------------------------------------------
// Hazard / forwarding signals
// -------------------------------------------------------
logic        stall;
logic [1:0]  fwd_sel_a, fwd_sel_b;

// -------------------------------------------------------
// Branch redirect
// -------------------------------------------------------
logic        branch_taken;
logic [63:0] branch_target;
assign branch_taken = ex_mem.branch_taken | ex_mem.jump;
assign branch_target = ex_mem.pc_target;

// -------------------------------------------------------
// Instruction memory signals
// -------------------------------------------------------
logic        imem_req;
logic [63:0] imem_addr;
logic [31:0] imem_data;

// -------------------------------------------------------
// Register file signals
// -------------------------------------------------------
logic [4:0]  rs1_addr, rs2_addr;
logic [63:0] rs1_data, rs2_data;
logic        reg_write;
logic [4:0]  rd_addr;
logic [63:0] rd_data;

// Writeback mux
always_comb begin
    case (mem_wb.wb_src)
        WB_MEM:  rd_data = mem_wb.mem_data;
        WB_PC4:  rd_data = mem_wb.alu_result; // PC+4 was computed in ALU as AUIPC-like
        default: rd_data = mem_wb.alu_result;
    endcase
end
assign reg_write = mem_wb.reg_write & mem_wb.valid;
assign rd_addr   = mem_wb.rd_addr;

// -------------------------------------------------------
// Data memory signals
// -------------------------------------------------------
logic        dmem_read, dmem_write;
logic [63:0] dmem_addr, dmem_wdata, dmem_rdata;
logic [2:0]  dmem_func3;

// -------------------------------------------------------
// Forwarding data buses
// -------------------------------------------------------
logic [63:0] fwd_ex_mem, fwd_mem_wb;
assign fwd_ex_mem = ex_mem.alu_result;
assign fwd_mem_wb = rd_data;

// -------------------------------------------------------
// Module instantiations
// -------------------------------------------------------

instruction_memory u_imem (
    .imem_req  (imem_req),
    .imem_addr (imem_addr),
    .imem_data (imem_data)
);

fetch u_fetch (
    .clk           (clk),
    .reset_n       (reset_n),
    .branch_taken  (branch_taken),
    .branch_target (branch_target),
    .stall         (stall),
    .imem_req      (imem_req),
    .imem_addr     (imem_addr),
    .imem_data     (imem_data),
    .if_id         (if_id)
);

register_file u_rf (
    .clk       (clk),
    .reset_n   (reset_n),
    .rs1_addr  (rs1_addr),
    .rs2_addr  (rs2_addr),
    .rs1_data  (rs1_data),
    .rs2_data  (rs2_data),
    .reg_write (reg_write),
    .rd_addr   (rd_addr),
    .rd_data   (rd_data)
);

decode u_decode (
    .clk       (clk),
    .reset_n   (reset_n),
    .if_id     (if_id),
    .rs1_addr  (rs1_addr),
    .rs2_addr  (rs2_addr),
    .rs1_data  (rs1_data),
    .rs2_data  (rs2_data),
    .stall     (stall),
    .flush     (branch_taken),
    .id_ex     (id_ex)
);

hazard_unit u_hazard (
    .id_rs1_addr  (rs1_addr),
    .id_rs2_addr  (rs2_addr),
    .ex_rd_addr   (id_ex.rd_addr),
    .ex_mem_read  (id_ex.mem_read),
    .ex_reg_write (id_ex.reg_write),
    .mem_rd_addr  (ex_mem.rd_addr),
    .mem_reg_write(ex_mem.reg_write),
    .stall        (stall),
    .flush        (),
    .fwd_sel_a    (fwd_sel_a),
    .fwd_sel_b    (fwd_sel_b)
);

execute u_execute (
    .clk        (clk),
    .reset_n    (reset_n),
    .id_ex      (id_ex),
    .fwd_ex_mem (fwd_ex_mem),
    .fwd_mem_wb (fwd_mem_wb),
    .fwd_sel_a  (fwd_sel_a),
    .fwd_sel_b  (fwd_sel_b),
    .ex_mem     (ex_mem)
);

mem_stage u_mem (
    .clk       (clk),
    .reset_n   (reset_n),
    .ex_mem    (ex_mem),
    .mem_read  (dmem_read),
    .mem_write (dmem_write),
    .mem_addr  (dmem_addr),
    .mem_wdata (dmem_wdata),
    .mem_func3 (dmem_func3),
    .mem_rdata (dmem_rdata),
    .mem_wb    (mem_wb)
);

data_memory u_dmem (
    .clk        (clk),
    .mem_read   (dmem_read),
    .mem_write  (dmem_write),
    .addr       (dmem_addr),
    .write_data (dmem_wdata),
    .func3      (dmem_func3),
    .read_data  (dmem_rdata)
);

endmodule
