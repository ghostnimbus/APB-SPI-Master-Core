# APB SPI Master Core

A modular **Verilog RTL implementation of an APB-controlled SPI Master peripheral**, designed to bridge an AMBA APB interface with SPI serial communication.

The design provides programmable SPI control through APB-accessible registers and separates the core functionality into dedicated modules for **APB register/control handling, baud-rate generation, SPI clock generation, serial data shifting, slave-select control, and transfer status**.

The project also includes a simulation testbench that exercises APB register transactions and models an SPI slave response for functional verification.

---

## ✨ Features

* APB slave interface for configuration and data access
* SPI Master functionality
* Configurable **CPOL** and **CPHA**
* Support for all four standard SPI modes

  * Mode 0 — CPOL=0, CPHA=0
  * Mode 1 — CPOL=0, CPHA=1
  * Mode 2 — CPOL=1, CPHA=0
  * Mode 3 — CPOL=1, CPHA=1
* Configurable **MSB-first / LSB-first** data transfer
* Programmable SPI baud-rate divisor
* SPI clock generation
* MOSI transmit shifting
* MISO receive shifting
* Automatic Slave Select (`SS`) control
* Transfer-in-progress (`TIP`) indication
* SPI status reporting
* SPI interrupt-request generation
* APB read/write transaction handling
* Simulation testbench with APB read/write tasks
* SPI slave-response modeling in the testbench
* VCD waveform generation for simulation/debugging

---

## 🏗️ Architecture

The design is organized into a top-level SPI Master core and dedicated functional blocks.

```text
                         APB BUS
                            │
             ┌──────────────┴──────────────┐
             │                              │
             │      APB SPI Master Core     │
             │                              │
             │  ┌────────────────────────┐  │
             │  │ APB Slave Interface    │  │
             │  │                        │  │
             │  │ CR1 / CR2 / BR / SR /  │  │
             │  │ DR Registers           │  │
             │  └───────────┬────────────┘  │
             │              │               │
             │       Control / Status       │
             │              │               │
             │      ┌───────┴────────┐      │
             │      │                │      │
             │      ▼                ▼      │
             │  Baud Generator   Slave      │
             │      │            Control    │
             │      │                │      │
             │      ▼                ▼      │
             │   SPI Clock       SS / TIP   │
             │      │                │      │
             │      └───────┬────────┘      │
             │              │               │
             │              ▼               │
             │       Shift Register         │
             │          │       │            │
             └──────────┼───────┼────────────┘
                        │       │
                       MOSI    MISO
```

---

## 📁 Project Structure

```text
APB-SPI-Master-Core/
│
├── apb_spi_master_core.v
├── apb_slave_interface.v
├── baud_generator.v
├── shift_register.v
├── slave_control_select.v
├── tb.v
├── files.f
├── output.PNG
└── README.md
```
---

## 🔧 RTL Modules

### `apb_spi_master_core.v`

Top-level integration module.

It connects the APB interface with the SPI control, baud-rate generation, shift-register, and slave-select logic.

### `apb_slave_interface.v`

Implements the APB-side control and register logic.

The module handles:

* APB setup and enable phases
* Register read/write operations
* SPI configuration
* Data register access
* Status generation
* Interrupt-request generation
* SPI operating-state control

### `baud_generator.v`

Generates the SPI serial clock from the APB clock.

The baud-rate divisor is calculated from the programmable `SPPR` and `SPR` fields:

```text
BaudRateDivisor = (SPPR + 1) × 2^(SPR + 1)
```

The module also generates timing pulses used by the shift-register logic for MOSI and MISO operations.

### `shift_register.v`

Implements serial data transmission and reception.

Responsibilities include:

* Loading transmit data
* Generating MOSI data
* Sampling MISO data
* MSB-first transfers
* LSB-first transfers
* CPOL/CPHA-dependent shifting and sampling

### `slave_control_select.v`

Controls SPI transfer activity and Slave Select.

It generates:

* `SS`
* `TIP`
* Receive-data timing

The module uses the programmed baud-rate divisor to determine the transfer duration.

### `tb.v`

Simulation testbench for functional verification.

The testbench provides reusable tasks for:

* APB writes
* APB reads
* SPI data transmission
* SPI slave response generation

It also probes the configured CPOL, CPHA, and LSB-first settings from the DUT to model the SPI slave response accordingly.

---

## 🗃️ APB Register Map

The APB interface uses a 3-bit address bus.

|  Address | Register | Description               |
| :------: | :------: | ------------------------- |
| `3'b000` |   `CR1`  | SPI control/configuration |
| `3'b001` |   `CR2`  | Additional SPI control    |
| `3'b010` |   `BR`   | Baud-rate configuration   |
| `3'b011` |   `SR`   | SPI status                |
| `3'b101` |   `DR`   | SPI data register         |

Addresses `3'b100`, `3'b110`, and `3'b111` are treated as invalid/reserved by the current APB register logic.

---

## ⚙️ SPI Configuration

### CR1

The current RTL uses the following CR1 fields:

| Bit | Signal  | Function                      |
| :-: | ------- | ----------------------------- |
| `7` | `SPIE`  | SPI interrupt enable          |
| `6` | `SPE`   | SPI enable                    |
| `5` | `SPTIE` | SPI transmit interrupt enable |
| `4` | `MSTR`  | Master mode                   |
| `3` | `CPOL`  | Clock polarity                |
| `2` | `CPHA`  | Clock phase                   |
| `1` | `SSOE`  | Slave-select output enable    |
| `0` | `LSBFE` | LSB-first enable              |

### CR2

The implemented control logic uses fields including:

* `SPISWAI`
* `MODFEN`

### BR

The baud-rate register contains:

* `SPPR[2:0]`
* `SPR[2:0]`

These fields determine the SPI clock divisor.

---

## 🔄 SPI Operating Modes

The implementation supports the four standard SPI clock configurations:

| SPI Mode | CPOL | CPHA |
| :------: | :--: | :--: |
|  Mode 0  |   0  |   0  |
|  Mode 1  |   0  |   1  |
|  Mode 2  |   1  |   0  |
|  Mode 3  |   1  |   1  |

The shift-register and baud-generator logic select the appropriate transmit and receive timing based on the configured `CPOL` and `CPHA` values.

---
## 🧪 Verification

The included testbench configures the SPI Master through APB transactions and performs an SPI transfer.

The current test sequence:

1. Apply reset.
2. Configure `CR1`.
3. Configure `CR2`.
4. Configure the baud-rate register.
5. Write transmit data to the SPI data register.
6. Start an SPI transfer.
7. Generate an SPI slave response on MISO.
8. Wait for the transfer to complete.
9. Read the received data through the APB data register.

Example transmit/receive transaction in the testbench:

```text
Master TX : B1
Slave  TX : 56
```

The testbench generates a VCD waveform during simulation for signal-level debugging.

---

## 🖥️ Simulation

The project uses the source list provided in `files.f`.

For an Icarus Verilog-based simulation flow, the project can be compiled using:

```bash
iverilog -o out.vvp -c files.f
```

Run the simulation with:

```bash
vvp out.vvp
```

The testbench contains:

```verilog
$dumpfile("spi_tb.vcd");
$dumpvars(0, tb);
```

which can be used to generate a VCD waveform for viewing in a waveform viewer such as GTKWave.

---

## 📊 Verification Waveform

The repository includes a captured waveform image:

`output.PNG`

---

## 🛠️ Tools & Technologies

* **Verilog HDL**
* **AMBA APB**
* **SPI**
* **RTL Design**
* **Finite State Machines**
* **Digital Design**
* **Simulation & Verification**
* **VCD Waveform Analysis**
* **Icarus Verilog / compatible Verilog simulators**
* **GTKWave / compatible waveform viewers**

---

## 🎯 Design Objectives

This project demonstrates the implementation of a configurable SPI Master peripheral integrated with an APB register interface.

The primary design objectives are:

* Modular RTL architecture
* Configurable SPI timing
* Programmable baud-rate generation
* Support for standard SPI clock modes
* Bidirectional serial data transfer
* APB-based register control
* Hardware status and interrupt signaling
* Simulation-driven verification
---
