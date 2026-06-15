/*
 * Copyright 2025 Amazon.com, Inc. or its affiliates. All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License"). You may
 * not use this file except in compliance with the License. A copy of the
 * License is located at
 *
 *     http://aws.amazon.com/apache2.0/
 *
 * or in the "license" file accompanying this file. This file is distributed
 * on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
 * express or implied. See the License for the specific language governing
 * permissions and limitations under the License.
 */

/**
 * The sde_utility library contains various utility functions.
 */

#pragma once

#include <sde_enums.h>
#include <stdint.h>
#include <stddef.h>

#define SDE_PUBLIC __attribute__((visibility("default")))

//============================================================================================================
//
// sde_fill_pkt_data() : Fill a buffer of uint8_t with patterned data for the entire size of the buffer.
// arguments:
// -----------
// uint8_t* data_ptr           : The pointer of the buffer.
// size_t size                 : The number of bytes in the buffer.
// uint32_t start_dw           : The start of the pattern to write to the buffer.
//
//=============================================================================================================
SDE_PUBLIC int sde_fill_pkt_data (uint8_t* data_ptr, size_t size, uint32_t start_dw);

//============================================================================================================
//
// sde_aligned_size() : Return the size of the buffer that is aligned to the bit_alignment.
// arguments:
// -----------
// size_t size                 : The number of bytes in the buffer.
// size_t bit_alignment        : The bit alignment of the buffer.
//
//=============================================================================================================
SDE_PUBLIC size_t sde_aligned_size(size_t size, size_t bit_alignment);

//============================================================================================================
//
// sde_mgmt_strerror() : Return the string representation for the sde_mgmt error.
// arguments:
// -----------
// int err                     : Error returned from an sde function.
//
//=============================================================================================================
SDE_PUBLIC const char *sde_mgmt_strerror(int err);

//============================================================================================================
//
// sde_mgmt_strerror_long() : Return the long string representatino for the sde_mgmt error.
// arguments:
// -----------
// int err                     : Error returned from an sde function.
//
//=============================================================================================================
SDE_PUBLIC const char *sde_mgmt_strerror_long(int err);

//============================================================================================================
//
// sde_print_payload() : Print the contents of the uint8_t buffer.
// arguments:
// -----------
// uint8_t* payload            : The uint8_t buffer to print the contents of.
// int pkt_size                : The number of bytes from the buffer that will be printed.
//
//=============================================================================================================
SDE_PUBLIC void sde_print_payload(uint8_t* payload, int pkt_size);

SDE_PUBLIC void sde_print_help(const char* example_name);

struct sde_parameters {
  size_t pkt_cnt;
  size_t pkt_size;
  int slot_id;
};

//============================================================================================================
//
// sde_parse_args() : Parse commandline arguments where three arguments are expected to be provided.
// argv[1] : number of packets
// argv[2] : packet size in bytes
// argv[3] : slot id of the FPGA card
// arguments:
// -----------
// int argc                    : The argc as it was passed to main.
// char **argv                 : The argv as it was passed to main.
// struct sde_parameters* params : struct that contains the detected commandline parameters.
// const char* example         : The name of the example.
//
//=============================================================================================================
SDE_PUBLIC int sde_parse_args(int argc, char **argv, struct sde_parameters* params, const char* example);

//============================================================================================================
//
// sde_get_curr_time() : Returns time of day in seconds.
//
//=============================================================================================================
SDE_PUBLIC double sde_get_curr_time(void);

//============================================================================================================
//
// print_timing() : Prints the elapsed time and bandwidth in MPPS and GB/s.
// double start_time : The beginning of the test after configuration is complete.
// double end_time : The end of the test after transfers are complete.
// int pkt_size : The number of bytes transferred with each packet.
// size_t num_packets : The number of packets transferred.
// enum SDE_EXAMPLE_DIR direction : The direction of the example (c2h, h2c, loopback).
//
//=============================================================================================================
SDE_PUBLIC void print_timing(double start_time, double end_time, int pkt_size, size_t num_packets, enum SDE_EXAMPLE_DIR direction);