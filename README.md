# RISC-V Single-Cycle Processor in Verilog

This document serves as a Detailed Project Report (DPR) for the design and implementation of a 32-bit, single-cycle processor that executes the RISC-V (RV32I) base integer instruction set.

## 1. Processor Architecture: Single-Cycle Design

The core principle of a single-cycle processor is simplicity: **every instruction is executed in exactly one clock cycle.**

-   **Execution Flow:** The entire process for an instruction—fetching it from memory, decoding it, executing it in the ALU, accessing data memory, and writing the result back to a register—happens within a single, long clock cycle.
-   **Clock Period:** The clock's period is determined by the longest possible path an instruction can take through the datapath. This is typically the `LW` (Load Word) instruction, as it uses every major functional unit.
-   **Structure:** The datapath is a large block of combinatorial logic connecting the functional units. The state of the processor (the Program Counter and the Register File) is stored in sequential elements that are updated only on the rising edge of the clock.
-   **Memory Model:** This design assumes that both instruction and data memory can be accessed combinatorially or within a single clock cycle. The `mem_rbusy` and `mem_wbusy` inputs from the memory interface will be ignored, as a pure single-cycle design cannot handle wait states.

## 2. Top-Level Interface

The main processor module, `riscv_processor`, will have the following interface, connecting it to the memory system.

```verilog
module riscv_processor (
    input clk,
    input reset,

    // Memory Interface
    output [31:0] mem_addr,   // Address for both instruction and data memory
    output [31:0] mem_wdata,  // Data to be written for store instructions
    output [3:0]  mem_wmask,  // Write mask for SB, SH, SW (1 bit per byte)
    output        mem_rstrb,  // Read strobe (asserted for instruction fetch and loads)
    input  [31:0] mem_rdata,  // Data read from memory (can be an instruction or data)
    input         mem_rbusy,  // Ignored in single-cycle design
    input         mem_wbusy   // Ignored in single-cycle design
);
```

## 3. Supported Instruction Set (RV32I)

The processor will implement the base integer instruction set, including:

-   **R-Type:** `ADD`, `SUB`, `SLL`, `SLT`, `SLTU`, `XOR`, `SRL`, `SRA`, `OR`, `AND`
-   **I-Type:** `ADDI`, `SLTI`, `SLTIU`, `XORI`, `ORI`, `ANDI`, `SLLI`, `SRLI`, `SRAI`, `LW`, `LH`, `LB`, `LHU`, `LBU`, `JALR`
-   **S-Type:** `SW`, `SH`, `SB`
-   **B-Type:** `BEQ`, `BNE`, `BLT`, `BGE`, `BLTU`, `BGEU`
-   **U-Type:** `LUI`, `AUIPC`
-   **J-Type:** `JAL`

## 4. Core Components and Modules

The processor will be built from the following modular components.

### 4.1. Program Counter (`pc_logic.v`)

-   **Function:** A 32-bit register that holds the address of the current instruction.
-   **Implementation:** On each clock edge, it updates to the address of the *next* instruction. A multiplexer is required to select the source of the next PC value.
-   **Next PC Sources:**
    1.  `PC + 4` (Default sequential execution)
    2.  `Branch Target Address` (For taken branches)
    3.  `JAL Target Address`
    4.  `JALR Target Address`

### 4.2. Control Unit (`control_unit.v`)

-   **Function:** The "brain" of the processor. It decodes the instruction and generates all control signals.
-   **Implementation:** This is a purely combinatorial module. It takes the instruction's `opcode`, `funct3`, and `funct7` fields as input and uses a large `case` statement to generate the control signals.
-   **Key Output Signals:**
    -   `alu_op`: Tells the ALU which operation to perform.
    -   `alu_src_a_sel`, `alu_src_b_sel`: Control signals for multiplexers that select the ALU's operands.
    -   `reg_write_en`: Enables writing to the Register File.
    -   `mem_to_reg_sel`: Controls a multiplexer to select what data gets written back to a register (ALU result or data from memory).
    -   `mem_read_en`, `mem_write_en`: Control signals for data memory access.
    -   `branch_cond`: A signal to the PC logic indicating if a conditional branch should be taken.

### 4.3. Register File (`reg_file.v`)

-   **Function:** Stores the 32 general-purpose 32-bit registers (x0-x31).
-   **Implementation:** An array of 32 registers (`reg [31:0] registers[0:31]`).
    -   **Read Ports:** Two asynchronous (combinatorial) read ports that take `rs1` and `rs2` addresses and output the corresponding register values.
    -   **Write Port:** One synchronous write port that writes `write_data` to the `rd` address on the rising clock edge if `write_enable` is high.
    -   **x0 Logic:** Must ensure that reads from address 0 always return 0, and writes to address 0 are ignored.

### 4.4. ALU (`alu.v`)

-   **Function:** Performs all arithmetic and logical computations.
-   **Implementation:** A combinatorial module that takes two 32-bit operands and an `alu_op` control signal. A `case` statement selects the operation to perform.
-   **Outputs:**
    -   `result`: The 32-bit result of the operation.
    -   `zero_flag`: A 1-bit signal that is asserted if the result is zero. This is used by the Control Unit for `BEQ` and `BNE` instructions.

### 4.5. Immediate Generator (`imm_gen.v`)

-   **Function:** Parses the 32-bit instruction and constructs the correct sign-extended immediate value based on the instruction type (I, S, B, U, J).
-   **Implementation:** A purely combinatorial module that uses wire slicing and concatenation to assemble the immediate value from different bits of the instruction word.

## 5. Datapath and Control Flow

The datapath wires these components together. In a single cycle, data flows through the system as follows:

1.  **Instruction Fetch (IF):**
    -   The current `PC` value is sent to `mem_addr`.
    -   `mem_rstrb` is asserted. The instruction is returned on `mem_rdata`.

2.  **Instruction Decode (ID):**
    -   The instruction on `mem_rdata` is fed into the `Control Unit`, the `Register File` (for read addresses `rs1` and `rs2`), and the `Immediate Generator`.
    -   The `Register File` outputs the values of `rs1` and `rs2`.
    -   The `Control Unit` generates all control signals for the rest of the datapath.

3.  **Execute (EX):**
    -   A multiplexer, controlled by `alu_src_a_sel`, selects the first ALU operand (either the PC or the `rs1` value).
    -   A second multiplexer, controlled by `alu_src_b_sel`, selects the second ALU operand (either the `rs2` value or the sign-extended immediate).
    -   The `ALU` performs the operation specified by `alu_op`.

4.  **Memory (MEM):**
    -   For `LW` and `SW` instructions, the `ALU result` is used as the data memory address and is sent to `mem_addr`.
    -   For `SW`, the `rs2` value is sent to `mem_wdata`, and `mem_wmask` is set.
    -   For `LW`, `mem_rstrb` is asserted.

5.  **Write Back (WB):**
    -   A final multiplexer, controlled by `mem_to_reg_sel`, selects the data to be written back into the `Register File`. The choices are typically:
        1.  The `ALU result`.
        2.  The data returned from memory on `mem_rdata`.
        3.  The value of `PC + 4` (for `JAL` and `JALR`).
    -   If `reg_write_en` is asserted, this data is written into the register file at the `rd` address on the next clock edge.

## 6. Implementation Guide

Follow these steps to build the processor:

1.  **Create Module Files:** Create separate Verilog files for each component described in Section 4 (e.g., `alu.v`, `reg_file.v`, `control_unit.v`, etc.).

2.  **Implement Core Datapath Modules:** Start by implementing and testing the `ALU`, `Register File`, and `Immediate Generator`. These can be unit-tested individually.

3.  **Implement the Control Unit:** This is the most complex combinatorial part. Carefully map each instruction to its required control signals.

4.  **Create the Top-Level Module:** In `riscv_processor.v`, instantiate all the sub-modules.

5.  **Wire the Datapath:** Connect the modules according to the data flow described in Section 5. This will involve adding the necessary multiplexers to select data sources for the ALU, the register file write-back port, and the PC.

6.  **Connect the PC Logic:** Implement the PC register and the logic to select its next value based on branches and jumps.

7.  **Verify with Testbench:** Use the provided `riscv_testbench.v` and your `Makefile` to compile and run a full simulation. The testbench is comprehensive and will help you debug issues.

8.  **Debug:** Use a waveform viewer (like GTKWave) to analyze the `simulation.vcd` file. If a test fails, trace the signals through the datapath for the failing instruction cycle by cycle to find the source of the error.

---

## Build and Run

This project uses `iverilog` for compilation and simulation.

1.  **Installation (Arch Linux):**
    ```sh
    sudo pacman -S iverilog
    ```

2.  **Compilation & Simulation:**
    Run the `make` command, which will execute the following:
    ```makefile
    # 1. Compile all .v files into a simulation executable
    iverilog -o dsgn.out $(wildcard *.v)

    # 2. Run the simulation, which generates a waveform file
    vvp dsgn.out
    ```

3.  **Viewing Results:**
    Open the generated `simulation.vcd` file in a waveform viewer like GTKWave to visualize the processor's signals and debug its behavior.