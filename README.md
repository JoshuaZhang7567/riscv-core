# riscv-core
A single-cycle RV32I RISC-V CPU core

Folder Structure:
- rtl/ (Register Transfer Level): This is where the synthesizer-ready SystemVerilog CPU code will live.

- tb/ (Testbench): This holds the simulation files used to test your CPU before putting it on real hardware.

- docs/: Holds any important documentation


## Prerequisites & Local Setup

This CPU is written in SystemVerilog and simulated using **Icarus Verilog**. 

### 1. Install the Simulation Toolchain (macOS)
You will need Homebrew to install the simulation engine and waveform viewer. Open your terminal and run:

```bash
# Install Icarus Verilog (The Compiler/Simulator)
brew install icarus-verilog

# Install GTKWave (The Waveform Viewer)
brew install --cask gtkwave