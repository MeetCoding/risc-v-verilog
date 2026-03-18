# Requirements: iverilog
SRCS = $(wildcard *.v)
all:
	iverilog -o dsgn.out $(SRCS)
	vvp dsgn.out