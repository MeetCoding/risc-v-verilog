# RISC V Verilog
This project aims at building a RISC-V processor using Verilog hardware description language.

## Get Started

Requirements: `iverilog`
For arch users, run `sudo pacman -S iverilog`
After installation, run `make` to build the 

Makefile:
```
SRCS = $(wildcard *.v)  # Fetches all verilog files
all:
	iverilog -o dsgn.out $(SRCS)  # Compiles them to dsgn.out
	vvp dsgn.out  # Creates .vcd simulation file
```

Use `gtkwave`, Surfers extension on VSCode or any other waveform viewer that suppoers VCD files to see the testbench results.

Make sure to mention the following in the initial block of your testbench:
```
$dumpfile("simulation.vcd"); # or any other prefered name
$dumpvars(0, main_tb); # replace with name of your testbench file
```

