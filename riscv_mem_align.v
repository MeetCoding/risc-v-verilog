`timescale 1ns / 1ps

module riscv_mem_align(
    input  wire [2:0]  funct3,
    input  wire [1:0]  addr_lsb,
    input  wire [31:0] rs2_data, mem_rdata,
    output reg  [31:0] store_wdata, load_data,
    output reg  [3:0]  store_wmask
);
    wire [7:0] b = (addr_lsb==2'b00)?mem_rdata[7:0] : (addr_lsb==2'b01)?mem_rdata[15:8] :
                   (addr_lsb==2'b10)?mem_rdata[23:16]:mem_rdata[31:24];
    wire [15:0] h = (addr_lsb[1]==0) ? mem_rdata[15:0] : mem_rdata[31:16];

    always @(*) begin
        store_wdata = 32'b0; store_wmask = 4'b0; load_data = mem_rdata;
        
        // Store Formatters
        case (funct3)
            3'b000: begin store_wdata={4{rs2_data[7:0]}}; store_wmask=(4'b0001<<addr_lsb); end
            3'b001: begin store_wdata={2{rs2_data[15:0]}}; store_wmask=addr_lsb[1]?4'b1100:4'b0011; end
            3'b010: begin store_wdata=rs2_data; store_wmask=4'b1111; end
        endcase
        
        // Load Formatters
        case (funct3)
            3'b000: load_data = {{24{b[7]}}, b};   // LB (Sign extend byte)
            3'b001: load_data = {{16{h[15]}}, h};  // LH (Sign extend half)
            3'b100: load_data = {24'b0, b};        // LBU
            3'b101: load_data = {16'b0, h};        // LHU
        endcase
    end
endmodule