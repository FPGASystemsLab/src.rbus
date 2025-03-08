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

## System Architecture

RingNet consists of several key components that together form an efficient network-on-chip:

### Main Components

1. **Communication Rings:**
   - Basic communication structure in the topology
   - Implemented as bidirectional channels with FIFO buffers
   - Support different traffic priorities for Quality of Service (QoS)

2. **Routers (Slice Router Boxes):**
   - The `rsbus_slice_rt_box.sv` module implements routing functionality
   - Handles packet routing between different rings in the tree topology
   - Supports adaptive routing algorithms for optimized data flow

3. **Switches (Switch Boxes):**
   - The `rsbus_slice_sw_box*.sv` modules implement various switch configurations
   - Optimized for FPGA resource utilization
   - Support virtual cut-through switching for latency minimization

4. **Communication Managers:**
   - The `rsbus_d2r_mgr.sv` module manages device-to-ring communication
   - Buffers requests from devices and grants ring access according to priorities
   - Handles ring initialization and "owned" packet detection

5. **Extractors and Injectors:**
   - Modules `rsbus_d2r_extractor.sv`, `rsbus_d2r_injector.sv`, `rsbus_r2d_extractor.sv`, `rsbus_r2d_injector.sv`
   - Responsible for injecting and extracting packets from rings
   - Implement flow control and buffering mechanisms

### Communication Protocol

RingNet uses a dedicated packet-based communication protocol defined in `rbus_defs.sv`:

- **Packet Structure:**
  - Header containing address information, priority, memory operation
  - Payload containing data and byte enable markers
  - Support for different memory operation types: read, write, update

- **Addressing:**
  - Hierarchical network addressing using local identifiers (LID)
  - Support for physical and virtual address spaces

- **Priorities:**
  - Four priority levels (0-3) for different traffic classes
  - Mechanisms to prevent deadlocks and ensure fair access

## Project Directory Structure

The RingNet project is organized into the following directories:

- **`core/`**: Contains core network components such as communication managers, frame generators, extractors, and injectors
- **`slice/`**: Contains components related to network segments, including routers and switches in various configurations
- **`devring/`**: Contains components related to the device ring, including interfaces for UART, VGA, and other peripheral devices
- **`sim/`**: Contains simulation components, traffic generators, and test environment
- **`root/`**: Contains configuration files and main system components

## Implementation and Optimizations

RingNet includes several FPGA-specific optimizations:

1. **Buffer Optimization:**
   - Utilization of distributed LUTRAM memory for small FIFO buffers
   - Balanced use of Block RAM resources for larger buffers

2. **Switch Optimization:**
   - 3-port switches optimized for FPGA architecture
   - Minimization of latency and logic resources

3. **Flow Control Mechanisms:**
   - Advanced mechanisms to prevent buffer overflow
   - Handling of different traffic priorities for quality of service

4. **Scalability:**
   - Parameterized components allowing easy network scaling
   - Support for different tree-of-rings topology configurations

## Applications

RingNet is particularly suited for FPGA-based System-on-Chip (SoC) designs, with a special focus on high-volume data processing applications such as video processing. Its efficient implementation demonstrates superior performance metrics, including higher maximum clock frequencies and lower resource consumption, making it a compelling alternative to existing NoC solutions.

## Getting Started

This repository contains all necessary Verilog/SystemVerilog files for RingNet's implementation, along with simulation environments and examples. To get started:

1. Clone the repository to your local machine.
2. Navigate to the `sim` directory for testbenches and simulation setups.
3. Follow the setup instructions in the `docs` directory for detailed guidance on compiling and running simulations.

### Example Usage

To build and simulate a basic RingNet configuration:

```bash
# Compile components
iverilog -f files_for_sim.lst -o ringnet_sim

# Run simulation
vvp ringnet_sim

# Visualize results (requires GTKWave)
gtkwave sim_results.vcd
```

## Contribution

Contributions are welcome! Whether it's feature enhancements, bug fixes, or documentation improvements, please feel free to fork the repository and submit a pull request. Check the `CONTRIBUTING.md` file for more details on how to contribute to this project.

## License

This project is licensed under a custom license that allows for unrestricted use, modification, and distribution of the project provided that the original work is properly cited as specified below:

J. Siast, A. Łuczak and M. Domański, "RingNet: A Memory-Oriented Network-On-Chip Designed for FPGA," in IEEE Transactions on Very Large Scale Integration (VLSI) Systems, vol. 27, no. 6, pp. 1284-1297, June 2019, doi: 10.1109/TVLSI.2019.2899575.


## Acknowledgements

This project builds on years of research and development in FPGA-based NoC designs. We extend our gratitude to the academic and open-source communities for their invaluable contributions to this field.

## Citing RingNet

If you use RingNet in your research or wish to refer to the benchmark results, please consider citing our IEEE Transactions on Very Large Scale Integration (VLSI) Systems article:

```
J. Siast, A. Łuczak and M. Domański, "RingNet: A Memory-Oriented Network-On-Chip Designed for FPGA," in IEEE Transactions on Very Large Scale Integration (VLSI) Systems, vol. 27, no. 6, pp. 1284-1297, June 2019, doi: 10.1109/TVLSI.2019.2899575.
```

Additionally, you can use the following BibTeX entry for LaTeX users:

```bibtex
@ARTICLE{8663289,
  author={Siast, Jakub and Łuczak, Adam and Domański, Marek},
  journal={IEEE Transactions on Very Large Scale Integration (VLSI) Systems}, 
  title={RingNet: A Memory-Oriented Network-On-Chip Designed for FPGA}, 
  year={2019},
  volume={27},
  number={6},
  pages={1284-1297},
  keywords={Field programmable gate arrays;Table lookup;Random access memory;Throughput;Routing;Switches;Lattices;Distributed memory;lookup table RAM (LUTRAM);fairness;field-programmable gate array (FPGA);network-on-chip (NoC);virtual cut-through},
  doi={10.1109/TVLSI.2019.2899575}
}
```

For more information and access to the full paper, visit:

- [IEEE Xplore](https://ieeexplore.ieee.org/document/8663289)
- [Chair of Multimedia Telecommunications and Microelectronics, PDF](http://multimedia.edu.pl/publications/RingNet-A-Memory-Oriented-Network-On-Chip-Designed-for-FPGA.pdf)

