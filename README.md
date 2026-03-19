# 1. Objective and Scope
The objective of this project is to design and implement a RISC-V processor in Verilog that fully supports the RV32I Base Integer Instruction Set (excluding system instructions ecall and ebreak).

Note on Architecture: While the project brief mentions a "single-cycle" design, the provided testbench interface uses a unified memory port (mem_addr, mem_rdata, mem_wdata). In a strictly single-cycle architecture, fetching an instruction and reading/writing data must happen simultaneously, requiring two separate memory ports (Harvard architecture). To successfully pass the testbench using the unified memory interface provided, this design implements a highly efficient Finite State Machine (FSM)-driven multi-cycle architecture.

# 2. System Architecture
To ensure clean design logic and high modularity, the processor is divided into a robust Datapath and an embedded Control Unit governed by an FSM.

The architecture contains:

Instruction Decoder & Immediate Generator: Combinatorially extracts operation codes, register addresses, and sign-extends five different immediate types (I, S, B, U, J).

Register File (RegFile): Contains 32x32-bit registers with asynchronous read and synchronous write capabilities.

Arithmetic Logic Unit (ALU): Sub-module executing arithmetic, logical, and shift operations, as well as providing branch condition flags (zero, lt, ltu).

Memory Alignment Logic: Correctly multiplexes and formats load and store data depending on the funct3 width specifier (Byte, Halfword, Word).

# 3. FSM State Design
The core of the execution runs on a 5-state machine that guarantees memory stability and resolves the unified memory bottleneck.

S_FETCH (0): Asserts the Program Counter (PC) onto mem_addr and sets mem_rstrb = 1 to initiate the instruction read. Transitions to S_DECODE.

S_DECODE (1): The fetched instruction is available on mem_rdata. The processor combinatorially evaluates the instruction:

For ALU, Branch, and Jump operations: The instruction executes fully. The ALU updates the result, the Register File writes the data, and the PC updates immediately. The state transitions directly back to S_FETCH (Effectively executing these instructions in 2 cycles).

For Load operations: Computes the memory address, latches it to alu_out_reg, and transitions to S_MEM_READ.

For Store operations: Computes the target address and formats the store data, transitioning to S_MEM_WRITE.

S_MEM_READ (2): Puts alu_out_reg on the memory bus and triggers mem_rstrb. Transitions to S_MEM_WB.

S_MEM_WB (3): Formats the incoming mem_rdata (handling sign-extensions for LB/LH), writes to the Register File, increments PC, and transitions to S_FETCH.

S_MEM_WRITE (4): Triggers the data write to memory using the appropriate mem_wmask (byte, half, word enables). Updates PC and transitions to S_FETCH.