

https://github.com/user-attachments/assets/c90e9a8a-424c-4950-bb78-24590325751c

# 🐍 Real-Time Snake Game on Artix-7 FPGA (Verilog & DVI/HDMI)

A hardware-based implementation of the classic **Snake Game** written in **Verilog HDL** and deployed on a **Xilinx Artix-7 FPGA** (`xc7a200tsbq484-1`). 

The project directly generates real-time DVI/HDMI video signals to display the game on a standard monitor, driven entirely by hardware logic without any soft-core CPU or microcontrollers.

---

##  Key Features

* **Pure Hardware Logic:** Fully written in Verilog HDL for low-latency, deterministic execution.
* **HDMI / DVI Video Output:** Custom VGA timing generator converted to DVI-D using Digilent's `rgb2dvi` IP core.
* **Pseudo-Random Food Generation:** Driven by a **17-bit Linear Feedback Shift Register (LFSR)** to ensure dynamic and non-repetitive food positions across spawns.
* **Input Debouncing:** Custom debouncing logic (`debounce.v`) filtering physical button presses for smooth control.
* **Real-time Collision Detection:** Hardware checks for snake self-collisions, border boundaries, and food consumption.

---

##  Architecture & Module Hierarchy

```text
top.v (Top-Level Wrapper)
 ├── clk_dvi.v       --> Generates pixel clock and high-speed DVI clocks
 ├── debounce.v      --> Button debouncers (Reset, Up, Down, Left, Right)
 ├── vga_timing.v    --> VGA timing generator (H-sync, V-sync, Active Area)
 ├── snake_game.v    --> Game logic, snake array, LFSR food spawner, collision checks
 └── rgb2dvi         --> Digilent RGB-to-DVI serializer for HDMI output
