# RingNet Network EndPoint

The EndPoint in the RingNet network is a terminal point that enables communication between devices and the network. It consists of several key components that together form an interface between devices and communication rings.

## EndPoint Components

The RingNet network EndPoint consists of the following main components:

1. **Device-to-Ring Extractor (rsbus_d2r_extractor):**
   - Extracts packets from the device to the ring
   - Checks packet address space (optional)
   - Forwards packets to the ring injector

2. **Device-to-Ring Injector (rsbus_d2r_injector):**
   - Injects packets from the device to the ring
   - Handles device identifiers (BASE_ID to LAST_ID)
   - Manages data flow and error control

3. **Ring-to-Device Extractor (rsbus_r2d_extractor):**
   - Extracts packets from the ring to the device
   - Filters packets based on device identifiers
   - Optionally forwards write acknowledgments

4. **Ring-to-Device Injector (rsbus_r2d_injector):**
   - Injects packets from the ring to the device
   - Manages data flow and error control

5. **Device-to-Ring Manager (rsbus_d2r_mgr):**
   - Buffers requests from devices
   - Grants ring access according to priorities
   - Manages ring initialization and "owned" packet detection

6. **Frame Generator (rsbus_frame_generator):**
   - Generates communication frames
   - Handles packet formatting

## Packet Structure

The RingNet network uses two types of packets: long and short, which differ in structure and application.

### Table 1: Packet Structure

| Packet Type | Structure | Application |
|-------------|-----------|-------------|
| **Long** | Header + Payload | Data write operations (MEM_WRITE, MEM_UPDATE) |
| **Short** | Header only | Read operations (MEM_READ_1, MEM_READ_8) |

### Table 2: Header Structure - 72 bits

| Field | Bits | Description |
|-------|------|-------------|
| frm_used | 1 | Used packet flag |
| frm_owned | 1 | "Owned" packet flag |
| frm_priority | 2 | Packet priority (0-3, where 3 is highest) |
| net_addr | 20 | Network address (5 LID fields, 4 bits each) |
| frm_sid | 4 | Source ID |
| frm_rid | 4 | Receiver ID |
| frm_len | 1 | Packet length (0 = short, 1 = long) |
| mem_addr | 36 | Memory address |
| mem_space | 1 | Memory space (0 = physical, 1 = virtual) |
| mem_op | 2 | Memory operation type |

### Table 3: Payload Structure - 72 bits

| Field | Bits | Description |
|-------|------|-------------|
| ben | 8 | Byte Enable markers |
| data | 64 | Data |

### Table 4: Memory Operation Types (mem_op)

| Value | Type | Description |
|-------|------|-------------|
| 2'b00 | MEM_READ_1 | Single word read |
| 2'b01 | MEM_READ_8 | 8-word read |
| 2'b10 | MEM_WRITE | Data write |
| 2'b11 | MEM_UPDATE | Data update |

## Control Word Structure

The control word (rbus_ctrl_t) is used to control packet flow in the network.

### Table 5: Control Word Structure - 12 bits

| Field | Bits | Description |
|-------|------|-------------|
| valid | 1 | Packet validity flag |
| len | 1 | Packet length (0 = short, 1 = long) |
| pp | 2 | Packet priority (0-3) |
| did | 4 | Destination device ID |
| rid | 4 | Ring ID |

## Data Flow in EndPoint

1. **Device-to-Ring Path:**
   - Device generates a request
   - rsbus_d2r_mgr buffers the request and grants ring access
   - rsbus_d2r_extractor extracts the packet from the device
   - rsbus_d2r_injector injects the packet into the ring

2. **Ring-to-Device Path:**
   - Packet circulates in the ring
   - rsbus_r2d_extractor extracts the packet from the ring based on ID
   - rsbus_r2d_injector injects the packet to the device

## Flow Control Mechanisms

1. **Priority-based Buffering:**
   - Separate FIFO buffers for different priorities
   - Separate buffers for long and short packets

2. **Overflow Control:**
   - Parameters FF_NEVER_OVERFLOW and FF_CAN_OVERFLOW_JUST_FOR_PP3 control behavior in case of overflow risk
   - Possibility to skip the request and leave it on the ring

3. **"Owned" Packet Detection:**
   - Stopping access grants until all "owned" packets are extracted
   - Automatic initialization and determination of the number of packets in the ring

The RingNet network EndPoint provides efficient and reliable communication between devices and the network, with advanced flow control and traffic prioritization mechanisms. 