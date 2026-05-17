// ============================================================================
// Amazon FPGA Hardware Development Kit
//
// Copyright 2024 Amazon.com, Inc. or its affiliates. All Rights Reserved.
//
// Licensed under the Amazon Software License (the "License"). You may not use
// this file except in compliance with the License. A copy of the License is
// located at
//
//    http://aws.amazon.com/asl/
//
// or in the "license" file accompanying this file. This file is distributed on
// an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, express or
// implied. See the License for the specific language governing permissions and
// limitations under the License.
// ============================================================================

#include <time.h>
#include <sys/time.h>
#include <stdio.h>
#include <fcntl.h>
#include <errno.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <poll.h>

#include "fpga_pci.h"
#include "fpga_mgmt.h"
#include "fpga_dma.h"
#include "utils/lcd.h"

#include "test_dram_dma_common.h"

#define MEM_16G (1ULL << 34)
#define USER_INTERRUPTS_MAX (16)

#define MIN(a, b) ((a) < (b) ? (a) : (b))
#define GB(x) ((size_t)((x) * 1024 * 1024 * 1024ull))
#define CHUNK_SIZE (64 * 1024)  // 64KB chunks
#define PROGRESS_INTERVAL GB(1) // Show progress every 1GB

/* use the standard out logger */
static const struct logger *logger = &logger_stdout;

/* Structure to hold command-line parameters */
typedef struct
{
    uint32_t slot_id;
    size_t buffer_size;
} test_parameters_t;

void usage(const char *program_name);
static int parse_arguments(int argc, char *argv[], test_parameters_t *params);
int dma_example(int slot_id, size_t buffer_size);
double get_throughput_gbps(struct timeval *start, struct timeval *end, size_t bytes);
void check_dma_queue_status(int fd, const char *queue_type);
void dump_buffer(const char *prefix, uint8_t *buffer, size_t size, size_t offset);
uint64_t buffer_compare_with_details(uint8_t *buf1, uint8_t *buf2, size_t size);
int interrupt_example(int slot_id, int interrupt_number);
int axi_mstr_example(int slot_id);
int axi_mstr_addr_access(int slot_id, pci_bar_handle_t pci_bar_handle, uint32_t addr_hi_addr, uint32_t addr_lo_addr, uint32_t addr_data);

static int parse_arguments(int argc, char *argv[], test_parameters_t *params)
{
    int i;

    for (i = 1; i < argc; i++)
    {
        if (strcmp(argv[i], "--slot") == 0)
        {
            i++;
            if (i >= argc)
            {
                usage(argv[0]);
                return 1;
            }
            sscanf(argv[i], "%x", &params->slot_id);
        }
        else if (strcmp(argv[i], "--size") == 0)
        {
            i++;
            if (i >= argc)
            {
                usage(argv[0]);
                return 1;
            }
            params->buffer_size = strtoul(argv[i], NULL, 0);
        }
        else if (strcmp(argv[i], "--gb") == 0)
        {
            i++;
            if (i >= argc)
            {
                usage(argv[0]);
                return 1;
            }
            params->buffer_size = GB(strtoul(argv[i], NULL, 0));
        }
        else
        {
            usage(argv[0]);
            return 1;
        }
    }

    return 0;
}

int main(int argc, char **argv)
{
    int rc;
    test_parameters_t params = {
        .slot_id = 0,
        .buffer_size = 1ULL << 24 // Default size (16MB)
    };

    rc = parse_arguments(argc, argv, &params);
    fail_on(rc, out, "%s", "Unable to parse command-line arguments.");

    /* setup logging to print to stdout */
    rc = log_init("test_dram_hbm_dma");
    fail_on(rc, out, "Unable to initialize the log.");
    rc = log_attach(logger, NULL, 0);
    fail_on(rc, out, "%s", "Unable to attach to the log.");

    log_info("Using buffer size: %zu bytes", params.buffer_size);

    /* initialize the fpga_plat library */
    rc = fpga_mgmt_init();
    fail_on(rc, out, "Unable to initialize the fpga_mgmt library");

    /* run the dma test example */
    rc = dma_example(params.slot_id, params.buffer_size);
    fail_on(rc, out, "DMA example failed");

    /* run axi master example */
    rc = axi_mstr_example(params.slot_id);
    fail_on(rc, out, "AXI Master example failed");

out:
    log_info("TEST %s", (rc == 0) ? "PASSED" : "FAILED");
    return rc;
}

void usage(const char *program_name)
{
    printf("usage: %s [--slot <slot>] [--size <size_in_bytes>] [--gb <size_in_gb>]\n", program_name);
}

double get_throughput_gbps(struct timeval *start, struct timeval *end, size_t bytes)
{
    double seconds = (end->tv_sec - start->tv_sec) + (end->tv_usec - start->tv_usec) / 1000000.0;
    return (bytes / (1024.0 * 1024.0 * 1024.0)) / seconds;
}

void check_dma_queue_status(int fd, const char *queue_type)
{
    // Since fpga_dma_queue_status is not available, we'll just log the fd status
    log_info("%s queue fd: %d", queue_type, fd);
}

void dump_buffer(const char *prefix, uint8_t *buffer, size_t size, size_t offset)
{
    printf("%s (offset %zu): ", prefix, offset);
    // Add boundary checking
    if (buffer == NULL)
    {
        printf("NULL BUFFER\n");
        return;
    }
    if (offset >= size)
    {
        printf("OFFSET OUT OF BOUNDS\n");
        return;
    }

    // Print up to 32 bytes in hex format
    for (size_t i = offset; i < offset + 32 && i < size; i++)
    {
        printf("%02x ", buffer[i]);
    }
    printf("\n");
}

uint64_t buffer_compare_with_details(uint8_t *buf1, uint8_t *buf2, size_t size)
{
    uint64_t diff_count = 0;
    size_t first_diff_pos = 0;
    bool first_diff_found = false;

    if (buf1 == NULL || buf2 == NULL)
    {
        log_error("NULL buffer detected in comparison");
        return size; // Return maximum difference
    }

    // Compare buffers
    for (size_t i = 0; i < size; i++)
    {
        if (buf1[i] != buf2[i])
        {
            diff_count++;
            if (!first_diff_found)
            {
                first_diff_pos = i;
                first_diff_found = true;

                // Log the first difference location and surrounding data
                log_error("First difference found at position %zu", first_diff_pos);
                log_error("Expected vs Actual at diff point: 0x%02x vs 0x%02x",
                          buf1[i], buf2[i]);

                // Dump some context around the difference
                dump_buffer("Written data", buf1, size, (first_diff_pos > 16) ? first_diff_pos - 16 : 0);
                dump_buffer("Read data", buf2, size, (first_diff_pos > 16) ? first_diff_pos - 16 : 0);
            }

            // Log periodic updates for large differences
            if (diff_count % 1000000 == 0)
            {
                log_info("Found %lu differences so far...", diff_count);
            }
        }
    }

    if (diff_count > 0)
    {
        log_error("Total number of differences: %lu (%0.2f%%)",
                  diff_count, (float)diff_count * 100.0 / size);
    }

    return diff_count;
}

static int dma_burst_transfer_chunked(int fd, uint8_t *buffer, size_t total_size, uint64_t addr, bool is_write)
{
    size_t transferred = 0;
    int rc = 0;
    struct timeval start_time, current_time;
    size_t last_progress = 0;
    const char *operation = is_write ? "Write" : "Read";

    gettimeofday(&start_time, NULL);

    while (transferred < total_size)
    {
        size_t chunk_size = MIN(CHUNK_SIZE, total_size - transferred);

        if (is_write)
        {
            rc = fpga_dma_burst_write(fd, buffer + transferred, chunk_size, addr + transferred);
        }
        else
        {
            rc = fpga_dma_burst_read(fd, buffer + transferred, chunk_size, addr + transferred);
        }

        if (rc != 0)
        {
            log_error("DMA %s failed at offset %zu with chunk size %zu (rc=%d)",
                      operation, transferred, chunk_size, rc);
            return rc;
        }

        transferred += chunk_size;

        // Show progress every PROGRESS_INTERVAL
        if (transferred - last_progress >= PROGRESS_INTERVAL)
        {
            gettimeofday(&current_time, NULL);
            double gbps = get_throughput_gbps(&start_time, &current_time, transferred);
            log_info("%s progress: %.2f GB / %.2f GB (%.2f GB/s)",
                     operation,
                     transferred / (double)GB(1),
                     total_size / (double)GB(1),
                     gbps);
            last_progress = transferred;
        }
    }

    gettimeofday(&current_time, NULL);
    double total_gbps = get_throughput_gbps(&start_time, &current_time, transferred);
    log_info("%s complete: %.2f GB transferred at %.2f GB/s",
             operation, transferred / (double)GB(1), total_gbps);

    return 0;
}

/**
 * This example fills a buffer with random data and then uses DMA to copy that
 * buffer into DDR and HBM.
 */
int dma_example(int slot_id, size_t buffer_size)
{
    int write_fd, read_fd, iter, rc;
    bool passed = true;
    write_fd = -1;
    read_fd = -1;

    log_info("Allocating buffers of size %zu bytes", buffer_size);

    uint8_t *write_buffer = malloc(buffer_size);
    uint8_t *read_buffer = malloc(buffer_size);
    if (write_buffer == NULL || read_buffer == NULL)
    {
        log_error("Failed to allocate buffers (write_buffer=%p, read_buffer=%p)",
                  (void *)write_buffer, (void *)read_buffer);
        rc = -ENOMEM;
        goto out;
    }

    // Initialize read buffer to a known pattern
    memset(read_buffer, 0xAA, buffer_size);

    read_fd = fpga_dma_open_queue(FPGA_DMA_XDMA, slot_id,
                                  /*channel*/ 0, /*is_read*/ true);
    fail_on((rc = (read_fd < 0) ? -1 : 0), out, "unable to open read dma queue");
    log_info("Successfully opened read DMA queue (fd=%d)", read_fd);

    write_fd = fpga_dma_open_queue(FPGA_DMA_XDMA, slot_id,
                                   /*channel*/ 0, /*is_read*/ false);
    fail_on((rc = (write_fd < 0) ? -1 : 0), out, "unable to open write dma queue");
    log_info("Successfully opened write DMA queue (fd=%d)", write_fd);

    rc = fill_buffer_urandom(write_buffer, buffer_size);
    fail_on(rc, out, "unable to initialize buffer");
    log_info("Successfully initialized buffer with random data");
    dump_buffer("Initial buffer content", write_buffer, buffer_size, 0);

    // The first 4 iters map to DDR and the fifth iter maps to HBM
    for (iter = 0; iter < 5; iter++)
    {
        uint64_t dma_addr = iter * MEM_16G;
        log_info("Starting chunked DMA write for iteration %d at address 0x%lx", iter, (unsigned long)dma_addr);

        rc = dma_burst_transfer_chunked(write_fd, write_buffer, buffer_size, dma_addr, true);
        if (rc != 0)
        {
            log_error("Chunked DMA write failed with error code %d (errno: %d - %s)", rc, errno, strerror(errno));
            goto out;
        }

        check_dma_queue_status(write_fd, "Write");
        log_info("DMA write completed for iteration %d", iter);

        // Clear read buffer before each read
        memset(read_buffer, 0x00, buffer_size);

        log_info("Starting chunked DMA read for iteration %d", iter);
        rc = dma_burst_transfer_chunked(read_fd, read_buffer, buffer_size, dma_addr, false);
        if (rc != 0)
        {
            log_error("Chunked DMA read failed with error code %d (errno: %d - %s)",
                      rc, errno, strerror(errno));
            goto out;
        }

        check_dma_queue_status(read_fd, "Read");
        log_info("DMA read completed for iteration %d", iter);

        uint64_t differ = buffer_compare_with_details(write_buffer, read_buffer, buffer_size);
        if (differ != 0)
        {
            log_error("iter %d failed with %lu bytes which differ", iter, differ);
            passed = false;
        }
        else
        {
            log_info("iter %d passed!", iter);
        }
    }
    rc = (passed) ? 0 : 1;

out:
    if (write_buffer != NULL)
    {
        free(write_buffer);
    }
    if (read_buffer != NULL)
    {
        free(read_buffer);
    }
    if (write_fd >= 0)
    {
        close(write_fd);
    }
    if (read_fd >= 0)
    {
        close(read_fd);
    }
    return (rc != 0 ? 1 : 0);
}

int interrupt_example(int slot_id, int interrupt_number)
{
    pci_bar_handle_t pci_bar_handle = PCI_BAR_HANDLE_INIT;
    struct pollfd fds[1];
    int fd = -1;
    uint32_t rd, read_data;
    char event_file_name[256];
    int rc = 0;
    int poll_timeout = 1000;
    int num_fds = 1;
    int pf_id = 0;
    int bar_id = 0;
    int fpga_attach_flags = 0;
    int poll_limit = 20;
    uint32_t interrupt_reg_offset = 0xd00;

    int device_num = 0;
    rc = fpga_pci_get_dma_device_num(FPGA_DMA_XDMA, slot_id, &device_num);
    fail_on((rc = (rc != 0) ? 1 : 0), out, "Unable to get xdma device number.");

    rc = sprintf(event_file_name, "/dev/xdma%i_events_%i", device_num, interrupt_number);
    fail_on((rc = (rc < 0) ? 1 : 0), out, "Unable to format event file name.");

    log_info("Starting MSI-X Interrupt test");
    rc = fpga_pci_attach(slot_id, pf_id, bar_id, fpga_attach_flags, &pci_bar_handle);
    fail_on(rc, out, "Unable to attach to the AFI on slot id %d", slot_id);

    log_info("Polling device file: %s for interrupt events", event_file_name);
    fd = open(event_file_name, O_RDONLY);
    if (fd == -1)
    {
        log_error("Error - invalid device\n");
        fail_on((rc = 1), out, "Unable to open event device");
    }
    fds[0].fd = fd;
    fds[0].events = POLLIN;

    log_info("Triggering MSI-X Interrupt %d", interrupt_number);
    rc = fpga_pci_poke(pci_bar_handle, interrupt_reg_offset, 1 << interrupt_number);
    fail_on(rc, out, "Unable to write to the fpga !");

    // Poll checks whether an interrupt was generated.
    rd = poll(fds, num_fds, poll_timeout);
    if ((rd > 0) && (fds[0].revents & POLLIN))
    {
        uint32_t events_user;

        // Check how many interrupts were generated, and clear the interrupt so we can detect
        // future interrupts.
        rc = pread(fd, &events_user, sizeof(events_user), 0);
        fail_on((rc = (rc < 0) ? 1 : 0), out, "call to pread failed.");

        log_info("Interrupt present for Interrupt %i, events %i. It worked!",
                 interrupt_number, events_user);

        // Clear the interrupt register
        rc = fpga_pci_poke(pci_bar_handle, interrupt_reg_offset, 0x1 << (16 + interrupt_number));
        fail_on(rc, out, "Unable to write to the fpga !");
    }
    else
    {
        log_error("No interrupt generated- something went wrong.");
        fail_on((rc = 1), out, "Interrupt generation failed");
    }

    // Clear the interrupt register
    do
    {
        // In this CL, a successful interrupt is indicated by the CL setting bit <interrupt_number + 16>
        // of the interrupt register. Here we check that bit is set and write 1 to it to clear.
        rc = fpga_pci_peek(pci_bar_handle, interrupt_reg_offset, &read_data);
        fail_on(rc, out, "Unable to read from the fpga !");
        read_data = read_data & (1 << (interrupt_number + 16));

        rc = fpga_pci_poke(pci_bar_handle, interrupt_reg_offset, read_data);
        fail_on(rc, out, "Unable to write to the fpga !");

        poll_limit--;
    } while (!read_data && poll_limit > 0);

out:
    if (fd >= 0)
    {
        close(fd);
    }
    if (pci_bar_handle != PCI_BAR_HANDLE_INIT)
    {
        fpga_pci_detach(pci_bar_handle);
    }
    return rc;
}

int axi_mstr_example(int slot_id)
{
    int rc;
    pci_bar_handle_t pci_bar_handle = PCI_BAR_HANDLE_INIT;
    int pf_id = 0;
    int bar_id = 0;
    int fpga_attach_flags = 0;
    uint32_t addr_hi_addr, addr_lo_addr, addr_data;

    rc = fpga_pci_attach(slot_id, pf_id, bar_id, fpga_attach_flags, &pci_bar_handle);
    fail_on(rc, out, "Unable to attach to the AFI on slot id %d", slot_id);

    log_info("Starting AXI Master to ADDR test");

    /* DDR ADDR Access */
    addr_hi_addr = 0x00000001;
    addr_lo_addr = 0xA021F700;
    addr_data = 0xA5A61A2A;

    rc = axi_mstr_addr_access(slot_id, pci_bar_handle, addr_hi_addr, addr_lo_addr, addr_data);
    fail_on(rc, out, "Unable to access DDR ADDR");

    /* HBM  Access */
    addr_hi_addr = 0x00000008;
    addr_lo_addr = 0x2078BC00;
    addr_data = 0x8BD18801;

    rc = axi_mstr_addr_access(slot_id, pci_bar_handle, addr_hi_addr, addr_lo_addr, addr_data);
    fail_on(rc, out, "Unable to access HBM.");

out:
    return rc;
}

/* Helper function for accessing DDR controllers via AXI Master block */
int axi_mstr_addr_access(int slot_id, pci_bar_handle_t pci_bar_handle, uint32_t addr_hi_addr, uint32_t addr_lo_addr, uint32_t addr_data)
{
    int rc;
    static uint32_t ccr_offset = 0x500;
    static uint32_t cahr_offset = 0x504;
    static uint32_t calr_offset = 0x508;
    static uint32_t cwdr_offset = 0x50C;
    static uint32_t crdr_offset = 0x510;
    uint32_t read_data;
    int poll_limit = 20;

    /* Issue AXI Master Write Command */
    rc = fpga_pci_poke(pci_bar_handle, cahr_offset, addr_hi_addr);
    fail_on(rc, out, "Unable to write to AXI Master CAHR register!");
    rc = fpga_pci_poke(pci_bar_handle, calr_offset, addr_lo_addr);
    fail_on(rc, out, "Unable to write to AXI Master CALR register!");
    rc = fpga_pci_poke(pci_bar_handle, cwdr_offset, addr_data);
    fail_on(rc, out, "Unable to write to AXI Master CWDR register!");
    rc = fpga_pci_poke(pci_bar_handle, ccr_offset, 0x1);
    fail_on(rc, out, "Unable to write to AXI Master CCR register!");

    /* Poll for done */
    do
    {
        // Read the CCR until the done bit is set
        rc = fpga_pci_peek(pci_bar_handle, ccr_offset, &read_data);
        fail_on(rc, out, "Unable to read AXI Master CCR from the fpga !");
        read_data = read_data & (0x2);
        poll_limit--;
    } while (!read_data && poll_limit > 0);
    fail_on((rc = !read_data), out, "AXI Master write to DDR did not complete. Done bit not set in CCR.");

    /* Issue AXI Master Read Command */
    rc = fpga_pci_poke(pci_bar_handle, ccr_offset, 0x5);
    fail_on(rc, out, "Unable to write to AXI Master CCR register!");

    /* Poll for done */
    poll_limit = 20;
    do
    {
        // Read the CCR until the done bit is set
        rc = fpga_pci_peek(pci_bar_handle, ccr_offset, &read_data);
        fail_on(rc, out, "Unable to read AXI Master CCR from the fpga !");
        read_data = read_data & (0x2);
        poll_limit--;
    } while (!read_data && poll_limit > 0);
    fail_on((rc = !read_data), out, "AXI Master read from DDR did not complete. Done bit not set in CCR.");

    /* Compare Read/Write Data */
    // Read the CRDR for read data
    rc = fpga_pci_peek(pci_bar_handle, crdr_offset, &read_data);
    fail_on(rc, out, "Unable to read AXI Master CRDR from the fpga !");
    if (read_data == addr_data)
    {
        rc = 0;
        log_info("Resulting value at address 0x%x%x matched expected value 0x%x. It worked!", addr_hi_addr, addr_lo_addr, addr_data);
    }
    else
    {
        rc = 1;
        fail_on(rc, out, "Resulting value, 0x%x did not match expected value 0x%x at address 0x%x%x. Something didn't work.\n", read_data, addr_data, addr_hi_addr, addr_lo_addr);
    }

out:
    return rc;
}
