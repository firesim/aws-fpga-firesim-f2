CL_AXIL_REG_ACCESS Example Simulation
=====================================

Table of Contents
-----------------

- `Overview <#overview>`__
- `Dump Waves <#dump-waves>`__
- `SystemVerilog Tests <#systemverilog-tests>`__
- `FSM Coverage <#fsm-coverage>`__

Overview
--------

This readme provides information about the simulation environment for
the ``cl_axil_reg_access`` example. For more details about overall HDK
simulation environment and CL bringup in simulation please refer to the
`RTL Simulation Guide for HDK Design
Flow <https://github.com/aws/aws-fpga/blob/f2/hdk/docs/RTL_Simulation_Guide_for_HDK_Design_Flow.md>`__

SystemVerilog (SV) simulations can be run from the
``$CL_DIR/verif/scripts/`` directory with all supported simulators. You
can run tests by calling the make target for that test located in
``$CL_DIR/verif/scripts/Makefile.tests``:

.. code-block:: bash

   make test_null                                # Runs with XSIM by default
   make test_adder VCS=1
   make test_arithmetic_operations QUESTA=1

   make TEST=test_adder                          # Runs with XSIM by default
   make TEST=test_adder VCS=1
   make TEST=test_adder QUESTA=1

``test_random.sv`` supports ``plusargs`` for runtime configuration.
Users can set ``+num_iterations=<N>`` (default: ``100``) to control how
many random addition operations to run, and ``+seed=<N>`` (default:
``0``) to set the random number generator seed for reproducing a
specific test case for debugging:

.. code-block:: bash

   make test_random PLUSARGS="+num_iterations=500"   # Run 500 random operations
   make test_random PLUSARGS="+seed=12345"           # Use fixed seed to reproduce specific test case

To run all tests (regression):

.. code-block:: bash

   make regression                             # Runs with XSIM by default
   make regression VCS=1
   make regression QUESTA=1

Note that the appropriate simulators must be installed.

Dump Waves
----------

For information about how to dump waves with XSIM or VCS, please refer
to `Debugging Custom Logic using the AWS
HDK <https://github.com/aws/aws-fpga/blob/f2/hdk/docs/RTL_Simulation_Guide_for_HDK_Design_Flow.md#debugging-custom-logic-using-the-aws-hdk>`__

SystemVerilog Tests
-------------------

The SystemVerilog test cases are located at ``verif/tests/``. All tests
include ``test_base.inc`` which includes common signals and tasks used
across tests (such as ``write_operand_a``, ``read_sum``,
``perform_addition``). Information about each test can be found below.

test_null.sv
~~~~~~~~~~~~

This test verifies the design loads, powers up, and resets cleanly
without performing any register operations.

test_adder.sv
~~~~~~~~~~~~~

This test demonstrates register-based AXI-Lite communication. It writes
two operands via OCL AXI-Lite, triggers the addition by setting the
start bit in the control register, then reads back the sum and carry
results. This validates write to the input registers, triggers
computation, and read from output registers.

test_arithmetic_operations.sv
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

This test validates arithmetic correctness across a range of input
conditions including simple addition, larger numbers, addition with
carry generation (overflow conditions), maximum values (``0xFFFFFFFF`` +
``0xFFFFFFFF``), both operands zero, one operand zero, and random value
combinations.

test_axil_registers.sv
~~~~~~~~~~~~~~~~~~~~~~

This test validates register access patterns and read-only protection.
It verifies all registers initialize to zero on reset, tests write and
read transactions on ``RW`` registers (``operand_a``, ``operand_b``),
validates read-only protection by attempting writes to ``RO`` registers
(``sum``, ``carry``), tests various write-then-read data patterns, and
verifies register stability.

test_control_bits.sv
~~~~~~~~~~~~~~~~~~~~

This test verifies the control and status register handshake between
host and CL. Tests that the start bit (bit ``0``) triggers the addition
operation, the ready bit (bit ``1``) asserts when computation completes,
and the ready bit clears after both ``sum`` and ``carry`` registers are
read.

test_error_handling.sv
~~~~~~~~~~~~~~~~~~~~~~

This test validates that the design handles invalid operations
gracefully. It tests write/read to out-of-range addresses, tests
misaligned address accesses, and verifies the system continues to
function normally after encountering invalid operations.

test_reset.sv
~~~~~~~~~~~~~

This test validates reset behavior during various operational states.
Tests power-on reset (initializes all registers to zero), mid-operation
reset (aborts computation and clears registers), and FSM return to
``IDLE`` state after reset.

test_random.sv
~~~~~~~~~~~~~~

This test generates randomized inputs for ``operand_a`` and
``operand_b``, and compares the DUT results against a software golden
model. It tests various control flow scenarios and targets boundary
cases including large numbers, small numbers, and powers of 2.

test_stress_axil.sv
~~~~~~~~~~~~~~~~~~~

This test performs stress testing of the AXI-Lite interface by
validating rapid consecutive write transactions, alternating write
operations between different registers, rapid consecutive read
transactions, alternating read operations from different registers,
mixed write and read transactions, and multiple sequential operations.

FSM Coverage
------------

The ``cl_axil_fsm_coverage.sv`` bind module provides functional coverage
and assertions for the AXI-Lite FSM. The coverage report is
automatically printed at the end of each simulation. The module tracks:

**State Coverage:** All 5 FSM states (``IDLE``, ``WRITE_WAIT``,
``WRITE``, ``WRITE_RESP``, ``READ``)

**Transition Coverage:** All valid state-to-state transitions (11
transitions total)

**SVA Assertions:** Validates legal FSM transitions and catches illegal
states

`Back to Home <../../../../../../index.html>`__
