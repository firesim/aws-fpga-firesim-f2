AXI Slave Timeouts (DMA_PCIS)
=============================

- The Shell provides a timeout mechanism which terminates any
  outstanding AXI transactions after 8 uS.

  - There is a separate timeout per interface.
  - Upon the first timeout, metrics registers are updated with the
    offending address and a counter is incremented.
  - Upon further timeouts the counter is incremented.
  - These metrics registers can be read via the
    `fpga-describe-local-image found in Amazon FPGA Image Management
    Tools <../../sdk/userspace/fpga-mgmt-tools/README.html>`__

- Timeouts can occur for three reasons:

  1. The CL doesn’t respond to the address (reserved address space)
  2. The CL has an AXI protocol violation which causes a hang on the bus
  3. The CL design’s latency exceeds the timeout threshold. For example
     if the cycle is going to DDR, accumulated DDR arbitration and
     access latencies may exceed the timeout threshold value.

- Best practice is to ensure addresses to reserved address space are
  fully decoded in the CL design.
- If accessing DDR, note DMA accesses to DDR will accumulate which can
  lead to timeouts if the transactions are not completed fast enough.
  This is especially true for CL designs operating at 125MHz or below.
  See `cl_dram_hbm_dma <https://github.com/aws/aws-fpga/tree/f2/hdk/cl/examples/cl_dram_hbm_dma>`__.This example
  illustrates best practice for DMA operations to DDR.
- CL designs which have multiple masters on the AXI “fabric” will also
  incur arbitration delays.
- If a timeout is suspected, debug by reading the metrics registers. The
  saved offending address should help narrow whether this is to DDR or
  registers/RAMs inside the FPGA. The developer should investigate if
  design parameters allow for long latency responses to the offending
  address. If not, then the developer should investigate protocol
  violations.
- ⚠️ Once a timeout happens, the DMA/PCIS interface may no longer be
  functional and the AFI/Shell must be re-loaded with
  `fpga-load-local-image <../../sdk/userspace/fpga-mgmt-tools/README.html>`__.

AXI Master Timeouts (PCIM)
--------------------------

- AXI Master transactions can timeout when the CL does not respond to
  the same channel within the 8us timeout. Possible causes for an AXI
  PCIM timeout include:

1. Does not complete Write Data
2. Does not assert BREADY when BVALID is asserted
3. Does not assert RREADY when RVALID is asserted

- Best practice is to have store and forward buffers for any slow
  masters (write), and to not issue read requests if the CL is not able
  to buffer the returned read data.

How to detect a shell timeout has occurred
------------------------------------------

- Shell-CL interface timeouts can be detected by checking for non-zero
  timeout counters. These metrics can be read using this command:

.. code-block:: bash

   ubuntu@ip-172-31-35-24:~$ sudo fpga-describe-local-image -S 0 --metrics
   AFI          0       agfi-0f0e045f919413242  loaded            0        ok               0       0x04151701
   AFIDEVICE    0       0x1d0f      0xf000      0000:34:00.0
   virtual-jtag-slave-timeout=0
   ocl-slave-timeout=0
   sda-slave-timeout=0
   dma-pcis-timeout=0
   pcim-range-error=0
   pcim-axi-protocol-error=0
   dma-range-error=0
   pcim-axi-protocol-4K-cross-error=0
   pcim-axi-protocol-bus-master-enable-error=0
   pcim-axi-protocol-request-size-error=0
   pcim-axi-protocol-write-incomplete-error=0
   pcim-axi-protocol-first-byte-enable-error=0
   pcim-axi-protocol-last-byte-enable-error=0
   pcim-axi-protocol-bready-error=0
   pcim-axi-protocol-rready-error=0
   pcim-axi-protocol-wchannel-error=0
   pcim-range-error-addr=0x0
   pcim-range-error-count=0
   pcim-axi-protocol-error-addr=0x0
   pcim-axi-protocol-error-count=0
   pcim-write-count=0
   pcim-read-count=0
   dma-pcis-timeout-addr=0x0
   dma-pcis-timeout-count=0
   ocl-slave-timeout-addr=0x0
   ocl-slave-timeout-count=0
   sda-slave-timeout-addr=0x0
   sda-slave-timeout-count=0
   virtual-jtag-slave-timeout-addr=0x0
   virtual-jtag-slave-timeout-count=0
   virtual-jtag-slave-write-count=0
   virtual-jtag-slave-read-count=0
   DDR0
      write-count=0
      read-count=0
   Power consumption (Vccint):
      Last measured: 9 watts
      Average: 9 watts
      Max measured: 10 watts
   Cached agfis:

- For detailed information on metrics, see `Amazon FPGA Image Management
  Tools README <../../sdk/userspace/fpga-mgmt-tools/README.html>`__

**NOTE**: The least significant 2 bits of the timeout address fields
(sdacl-slave-timeout-addr, virtual-jtag-slave-timeout-addr,
ocl-slave-timeout-addr, bar1-slave-timeout-addr and
dma-pcis-timeout-addr) in the metrics are used to report whether the
timeout occurred due to READ or WRITE transaction. The bits in timeout
address should be interpreted as follows:

- ``timeout-addr[1:0] == 2'b01`` - Interface timed out on READ
  transaction (Could be either on AR or R channels).
- ``timeout-addr[1:0] == 2'b10`` - Interface timed out on WRITE
  transaction (Could be on AW, W or B channels).
- True 32bit aligned address that triggered first timeout =
  {timeout-addr[1:0], 2’b00}.

`Back to Home <../../index.html>`__
