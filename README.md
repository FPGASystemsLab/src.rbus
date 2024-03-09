# RingNet: A NoC Architecture for FPGAs

## Overview

RingNet is a novel network-on-chip (NoC) architecture designed specifically for field-programmable gate arrays (FPGAs). This project encapsulates a comprehensive exploration of NoC design, emphasizing optimizations for FPGA characteristics offered by leading manufacturers. RingNet distinguishes itself by adopting a unique RingNet architecture and communication protocol, aiming to leverage FPGA potential to its fullest, particularly through its tree-of-rings topology, FPGA-optimized switches, and virtual cut-through switching.

## Features

- **FPGA-Optimized Design:** Tailored to exploit FPGA features such as distributed memory (LUTRAM) for buffering and optimized 3-port switches, ensuring efficient resource usage.
- **Tree-of-Rings Topology:** A unique structure that balances the load across the network, ensuring predictable latency and guaranteed throughput.
- **Virtual Cut-Through Switching:** Employs virtual cut-through switching for reduced latency and increased throughput, outperforming traditional crossbar interconnections like AXI4.
- **System Memory Communication:** Exclusive communication through system memory (SDRAM or block RAM), controlled by the processing elements to manage traffic load effectively.
- **Distributed Memory Utilization:** Leverages distributed memory within FPGA for small buffers in switches, enhancing the data handling efficiency.
- **Comprehensive Simulation Framework:** Includes a full suite of Verilog/SystemVerilog components for simulation, offering insights into network performance and scalability.

## Applications

RingNet is particularly suited for FPGA-based System-on-Chip (SoC) designs, with a special focus on high-volume data processing applications such as video processing. Its efficient implementation demonstrates superior performance metrics, including higher maximum clock frequencies and lower resource consumption, making it a compelling alternative to existing NoC solutions.

## Getting Started

This repository contains all necessary Verilog/SystemVerilog files for RingNet's implementation, along with simulation environments and examples. To get started:

1. Clone the repository to your local machine.
2. Navigate to the `simulation` directory for testbenches and simulation setups.
3. Follow the setup instructions in the `docs` directory for detailed guidance on compiling and running simulations.

## Contribution

Contributions are welcome! Whether it's feature enhancements, bug fixes, or documentation improvements, please feel free to fork the repository and submit a pull request. Check the `CONTRIBUTING.md` file for more details on how to contribute to this project.

## License

This project is licensed under the MIT License - see the `LICENSE` file for details.

## Acknowledgements

This project builds on years of research and development in FPGA-based NoC designs. We extend our gratitude to the academic and open-source communities for their invaluable contributions to this field.
