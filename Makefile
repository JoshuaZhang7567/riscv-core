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
PKG       = rtl/riscv_pkg.sv

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
# System Test — Full CPU (test_basic.hex)
# ===========================================================================
RTL_SRC   = $(PKG) \
            rtl/lib/adder.sv rtl/lib/mux2.sv rtl/lib/mux3.sv \
            rtl/lib/flopr.sv rtl/lib/flopenr.sv \
            $(CORE_DIR)/pc.sv $(CORE_DIR)/alu.sv $(CORE_DIR)/regfile.sv \
            $(CORE_DIR)/immgen.sv $(CORE_DIR)/control.sv \
            $(MEM_DIR)/imem.sv $(MEM_DIR)/dmem.sv \
            $(TOP_DIR)/riscv_top.sv

SYS_SRC   = $(RTL_SRC) $(TB_SYS)/tb_riscv_top.sv
SYS_OUT   = $(WAVE_DIR)/tb_riscv_top.out
SYS_VCD   = $(WAVE_DIR)/riscv_top.vcd

test_cpu: test_cpu_compile test_cpu_run

test_cpu_compile:
	mkdir -p $(WAVE_DIR)
	$(CC) $(CFLAGS) -o $(SYS_OUT) $(SYS_SRC)

test_cpu_run:
	vvp $(SYS_OUT)

test_cpu_wave:
	gtkwave $(SYS_VCD) &

# ===========================================================================
# Helpers
# ===========================================================================
clean:
	rm -rf $(WAVE_DIR)/*.out $(WAVE_DIR)/*.vcd

.PHONY: alu alu_compile alu_run alu_wave test_cpu test_cpu_compile test_cpu_run test_cpu_wave clean
