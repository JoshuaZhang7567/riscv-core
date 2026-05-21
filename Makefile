# ===========================================================================
# RISC-V RV32I CPU — Project Makefile
# ===========================================================================

CC        = iverilog
CFLAGS    = -g2012    # SystemVerilog 2012

# --- Directories ---
CORE_DIR  = rtl/core
MEM_DIR   = rtl/mem
PERIPH_DIR= rtl/periph
TOP_DIR   = rtl/top
TB_UNIT   = tb/unit
TB_SYS    = tb/system
WAVE_DIR  = sim/waveforms

# --- Package (must be compiled first) ---
PKG       = $(CORE_DIR)/riscv_pkg.sv

# ===========================================================================
# ALU
# ===========================================================================
ALU_SRC   = $(PKG) $(CORE_DIR)/alu.sv $(TB_UNIT)/tb_alu.sv
ALU_OUT   = $(WAVE_DIR)/tb_alu.out
ALU_VCD   = $(WAVE_DIR)/alu_waves.vcd

alu: alu_compile alu_run

alu_compile:
	mkdir -p $(WAVE_DIR)
	$(CC) $(CFLAGS) -o $(ALU_OUT) $(ALU_SRC)

alu_run:
	vvp $(ALU_OUT)

alu_wave:
	gtkwave $(ALU_VCD) &

# ===========================================================================
# Helpers
# ===========================================================================
clean:
	rm -rf $(WAVE_DIR)/*.out $(WAVE_DIR)/*.vcd

.PHONY: alu alu_compile alu_run alu_wave clean
