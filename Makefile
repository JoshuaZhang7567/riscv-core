CC = iverilog	#compiler

CFLAGS = -g2012		# -g2012 tells the compiler to use the SystemVerilog 2012 standard

# Directories
RTL_DIR = rtl
TB_DIR  = tb
BUILD_DIR = build

SRC = $(RTL_DIR)/riscv_pkg.sv $(RTL_DIR)/alu.sv $(TB_DIR)/alu_tb.sv		# The list of files. riscv_pkg.sv must be first because the others depend on it!

OUT = $(BUILD_DIR)/sim.out
VCD = $(BUILD_DIR)/alu_waves.vcd

all: compile run

prep:
	mkdir -p $(BUILD_DIR)

compile: prep	#prep is a dependency
	$(CC) $(CFLAGS) -o $(OUT) $(SRC)

run:
	vvp $(OUT)

wave:
	gtkwave $(VCD) &