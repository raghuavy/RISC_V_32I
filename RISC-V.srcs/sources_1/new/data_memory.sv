`timescale 1ns / 1ps
import risc_pkg::*;

module data_memory #(
    parameter ADDR_WIDTH = 12  // 4KB data memory
)(
    input  logic        clk,
    input  logic        mem_read,
    input  logic        mem_write,
    input  logic [63:0] addr,
    input  logic [63:0] write_data,
    input  logic [2:0]  func3,       // controls access size
    output logic [63:0] read_data
);

logic [7:0] mem [0:(2**ADDR_WIDTH)-1];

// Read (combinational)
always_comb begin
    read_data = 64'd0;
    if (mem_read) begin
        case (func3)
            3'h0: read_data = {{56{mem[addr[ADDR_WIDTH-1:0]][7]}},  mem[addr[ADDR_WIDTH-1:0]]};          // LB
            3'h1: read_data = {{48{mem[addr[ADDR_WIDTH-1:0]+1][7]}}, mem[addr[ADDR_WIDTH-1:0]+1], mem[addr[ADDR_WIDTH-1:0]]}; // LH
            3'h2: read_data = {{32{mem[addr[ADDR_WIDTH-1:0]+3][7]}}, mem[addr[ADDR_WIDTH-1:0]+3], mem[addr[ADDR_WIDTH-1:0]+2], mem[addr[ADDR_WIDTH-1:0]+1], mem[addr[ADDR_WIDTH-1:0]]}; // LW
            3'h3: read_data = {mem[addr[ADDR_WIDTH-1:0]+7], mem[addr[ADDR_WIDTH-1:0]+6], mem[addr[ADDR_WIDTH-1:0]+5], mem[addr[ADDR_WIDTH-1:0]+4],
                               mem[addr[ADDR_WIDTH-1:0]+3], mem[addr[ADDR_WIDTH-1:0]+2], mem[addr[ADDR_WIDTH-1:0]+1], mem[addr[ADDR_WIDTH-1:0]]};  // LD
            3'h4: read_data = {56'b0, mem[addr[ADDR_WIDTH-1:0]]};                                        // LBU
            3'h5: read_data = {48'b0, mem[addr[ADDR_WIDTH-1:0]+1], mem[addr[ADDR_WIDTH-1:0]]};           // LHU
            3'h6: read_data = {32'b0, mem[addr[ADDR_WIDTH-1:0]+3], mem[addr[ADDR_WIDTH-1:0]+2], mem[addr[ADDR_WIDTH-1:0]+1], mem[addr[ADDR_WIDTH-1:0]]}; // LWU
            default: read_data = 64'd0;
        endcase
    end
end

// Write (synchronous)
always_ff @(posedge clk) begin
    if (mem_write) begin
        case (func3)
            3'h0: mem[addr[ADDR_WIDTH-1:0]] <= write_data[7:0];  // SB
            3'h1: begin  // SH
                mem[addr[ADDR_WIDTH-1:0]]   <= write_data[7:0];
                mem[addr[ADDR_WIDTH-1:0]+1] <= write_data[15:8];
            end
            3'h2: begin  // SW
                mem[addr[ADDR_WIDTH-1:0]]   <= write_data[7:0];
                mem[addr[ADDR_WIDTH-1:0]+1] <= write_data[15:8];
                mem[addr[ADDR_WIDTH-1:0]+2] <= write_data[23:16];
                mem[addr[ADDR_WIDTH-1:0]+3] <= write_data[31:24];
            end
            3'h3: begin  // SD
                mem[addr[ADDR_WIDTH-1:0]]   <= write_data[7:0];
                mem[addr[ADDR_WIDTH-1:0]+1] <= write_data[15:8];
                mem[addr[ADDR_WIDTH-1:0]+2] <= write_data[23:16];
                mem[addr[ADDR_WIDTH-1:0]+3] <= write_data[31:24];
                mem[addr[ADDR_WIDTH-1:0]+4] <= write_data[39:32];
                mem[addr[ADDR_WIDTH-1:0]+5] <= write_data[47:40];
                mem[addr[ADDR_WIDTH-1:0]+6] <= write_data[55:48];
                mem[addr[ADDR_WIDTH-1:0]+7] <= write_data[63:56];
            end
            default:;
        endcase
    end
end

endmodule
