`timescale 1ns/1ps

//==============================================================================
// Testbench for Multi-Cycle RISC-V Processor
//==============================================================================
module riscv_testbench;

    //==========================================================================
    // Testbench Signals
    //==========================================================================
    reg clk;
    reg reset;

    wire [31:0] imem_addr;
    wire [31:0] imem_rdata;
    
    wire [31:0] dmem_addr;
    wire [31:0] dmem_wdata;
    wire [3:0]  dmem_wmask;
    wire [31:0] dmem_rdata;
    wire        dmem_rstrb;

    reg [31:0] memory [0:4095]; // 16KB memory

    integer     test_num = 0;
    integer     passed_tests = 0;
    integer     total_tests = 0;

    //==========================================================================
    // Instantiate RISC-V Processor
    //==========================================================================
    riscv_processor uut (
        .clk(clk),
        .reset(reset),
        .imem_addr(imem_addr),
        .imem_rdata(imem_rdata),
        .dmem_addr(dmem_addr),
        .dmem_wdata(dmem_wdata),
        .dmem_wmask(dmem_wmask),
        .dmem_rdata(dmem_rdata),
        .dmem_rstrb(dmem_rstrb)
    );

    //==========================================================================
    // Clock and Memory
    //==========================================================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz clock
    end

    // Memory Model: Separate instruction and data ports internally mapped to the
    // same physical memory array (Harvard interface over Von Neumann memory).
    assign imem_rdata = memory[imem_addr[31:2]];
    assign dmem_rdata = memory[dmem_addr[31:2]];
    
    always @(posedge clk) begin
        // Write operations remain synchronous
        // Read operations are now combinatorial
        if (dmem_wmask != 0) begin
            if (dmem_wmask[0]) memory[dmem_addr[31:2]][7:0]   <= dmem_wdata[7:0];
            if (dmem_wmask[1]) memory[dmem_addr[31:2]][15:8]  <= dmem_wdata[15:8];
            if (dmem_wmask[2]) memory[dmem_addr[31:2]][23:16] <= dmem_wdata[23:16];
            if (dmem_wmask[3]) memory[dmem_addr[31:2]][31:24] <= dmem_wdata[31:24];
        end
    end

    //==========================================================================
    // Helper Tasks
    //==========================================================================
    parameter HALT_ADDR = 32'hFFC;
    parameter HALT_VAL  = 32'hDEADBEEF;

    task reset_processor;
        begin
            reset = 1;
            @(posedge clk);
            @(posedge clk);
            reset = 0;
        end
    endtask

    task init_mem;
        integer i;
        begin
            for (i = 0; i < 4096; i = i + 1) begin
                memory[i] = 32'h00000013; // Fill with NOP
            end
        end
    endtask

    task run_test;
        input integer max_cycles;
        input [200*8:1] test_name;
        reg passed;
        integer k;
        begin
            test_num = test_num + 1;
            $display("\n-------------------------------------------");
            $display(">> Running Test %0d: %s", test_num, test_name);
            
            reset_processor();
            passed = 0;

            for (k = 0; k < max_cycles; k = k + 1) begin
                @(posedge clk);
                if (memory[HALT_ADDR[31:2]] == HALT_VAL) begin
                    passed = 1;
                    k = max_cycles; // exit loop
                end
            end

            if (passed) begin
                $display("[PASS] Test %0d: %s finished.", test_num, test_name);
            end else begin
                $display("[FAIL] Test %0d: %s timed out after %0d cycles.", test_num, test_name, max_cycles);
            end
        end
    endtask

    task check_result;
        input [31:0] addr;
        input [31:0] expected;
        input [200*8:1] check_name;
        begin
            total_tests = total_tests + 1;
            if (memory[addr[31:2]] === expected) begin
                $display("  [PASS] Check: %s", check_name);
                passed_tests = passed_tests + 1;
            end else begin
                $display("  [FAIL] Check: %s", check_name);
                $display("         - Expected: 0x%08h, Got: 0x%08h at addr 0x%h", expected, memory[addr[31:2]], addr);
            end
        end
    endtask

    //==========================================================================
    // Test Programs
    //==========================================================================

    task test_addi;
        integer idx;
    begin
        init_mem();
        // li a0, 5          (ADDI)
        memory[0] = 32'h00500513;
        // li a1, 8          (ADDI)
        memory[1] = 32'h00800593;
        // add a2, a0, a1    (a2 = 13)
        memory[2] = 32'h00b50633;
        // sw a2, 0(zero)
        memory[3] = 32'h00c02023;
        // Halt sequence
        idx = 4; // Start index for halt sequence
        memory[idx] = 32'hDEADC2B7; // LUI x5, 0xDEADC (t0 = 0xDEADBEEF)
        idx = idx + 1;
        memory[idx] = 32'hFEF28293; // ADDI x5, x5, 0xEEF
        idx = idx + 1;
        memory[idx] = 32'h00001337; // LUI x6, 0x00001 (t1 = 0x00000FFC)
        idx = idx + 1;
        memory[idx] = 32'hFFC30313; // ADDI x6, x6, 0xFFC
        idx = idx + 1;
        memory[idx] = 32'h00532023; // SW x5, 0(x6)
        idx = idx + 1;
        
        run_test(500, "ADDI and ADD");
        check_result(0, 13, "ADD result");
    end
    endtask
    
    task test_branches;
        integer idx;
    begin
        init_mem();
        idx = 0; // Start index for branch test instructions
        // li a0, 10
        memory[idx] = 32'h00A00513; idx = idx + 1; // ADDI x10, x0, 10
        // li a1, 10
        memory[idx] = 32'h00A00593; idx = idx + 1; // ADDI x11, x0, 10
        // li a2, 20
        memory[idx] = 32'h01400613; idx = idx + 1; // ADDI x12, x0, 20
        // beq a0, a1, label_A (should take)
        // PC=0x0C, Target=0x1C (label_A). Offset=0x10.
        memory[idx] = 32'h00B50563; idx = idx + 1; // BEQ x10, x11, 0x10
        // sw zero, 0(zero) (should be skipped)
        memory[idx] = 32'h00002023; idx = idx + 1; // SW x0, 0(x0)
        // blt a0, a2, label_B (should take)
        // PC=0x14, Target=0x24 (label_B). Offset=0x10.
        memory[idx] = 32'h01064563; idx = idx + 1; // BLT x10, x12, 0x10
        // sw zero, 4(zero) (should be skipped)
        memory[idx] = 32'h00002223; idx = idx + 1; // SW x0, 4(x0)
        // label_A: addi a3, zero, 42
        memory[idx] = 32'h02A00693; idx = idx + 1; // ADDI x13, x0, 42
        // sw a3, 8(zero)
        memory[idx] = 32'h00D02423; idx = idx + 1; // SW x13, 8(x0)
        // j label_C
        // PC=0x24, Target=0x2C (label_C). Offset=0x08.
        memory[idx] = 32'h0080006F; idx = idx + 1; // JAL x0, 0x08
        // label_B: addi a4, zero, 99 (skipped)
        memory[idx] = 32'h06300713; idx = idx + 1; // ADDI x14, x0, 99
        // label_C: sw a4, 12(zero)
        memory[idx] = 32'h00E02623; idx = idx + 1; // SW x14, 12(x0)
        // Halt sequence
        memory[idx] = 32'hDEADC2B7; idx = idx + 1; // LUI x5, 0xDEADC (t0 = 0xDEADBEEF)
        memory[idx] = 32'hFEF28293; idx = idx + 1; // ADDI x5, x5, 0xEEF
        memory[idx] = 32'h00001337; idx = idx + 1; // LUI x6, 0x00001 (t1 = 0x00000FFC)
        memory[idx] = 32'hFFC30313; idx = idx + 1; // ADDI x6, x6, 0xFFC
        memory[idx] = 32'h00532023; idx = idx + 1; // SW x5, 0(x6)
        
        run_test(1000, "Branches (BEQ, BLT, JAL)");
        check_result(8, 42, "BEQ branch taken");
        check_result(4, 0, "BLT branch taken (prev instruction skipped)");
        check_result(12, 0, "JAL jump taken");
    end
    endtask

    //==========================================================================
    // Main Test Sequence
    //==========================================================================
    initial begin
        $display("===========================================");
        $display("Starting RISC-V Multi-Cycle Processor Tests");
        $display("===========================================");

        test_addi();
        test_branches();

        $display("\n===========================================");
        $display("Test Summary: %0d / %0d checks passed.", passed_tests, total_tests);
        $display("===========================================");

        if (passed_tests == total_tests) $display("*** ALL TESTS PASSED ***");
        else $display("*** SOME TESTS FAILED ***");

        $finish;
    end

endmodule
