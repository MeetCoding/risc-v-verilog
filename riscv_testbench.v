`default_nettype none
`timescale 1ns/1ps

module riscv_testbench;

    reg clk;
    reg reset;

    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [3:0]  mem_wmask;
    wire        mem_rstrb;
    reg  [31:0] mem_rdata;

    // Instantiate the processor
    riscv_processor dut (
        .clk(clk),
        .reset(reset),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_wmask(mem_wmask),
        .mem_rstrb(mem_rstrb),
        .mem_rdata(mem_rdata)
    );

    // Clock generation
    always #5 clk = ~clk;

    // Simple memory model
    reg [31:0] memory[0:1023];

    always @(posedge clk) begin
        if (mem_rstrb) begin
            mem_rdata <= memory[mem_addr >> 2];
        end
        if (|mem_wmask) begin
            // Simplified write, does not handle mask
            memory[mem_addr >> 2] <= mem_wdata;
        end
    end

    // Test sequence
    initial begin
        clk = 0;
        reset = 1;
        #10;
        reset = 0;
        #100;
        $finish;
    end

    // Waveform dump
    initial begin
        $dumpfile("simulation.vcd");
        $dumpvars(0, riscv_testbench);
    end

endmodule
