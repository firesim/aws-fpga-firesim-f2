# =============================================================================
# Amazon FPGA Hardware Development Kit
#
# Copyright 2026 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Amazon Software License (the "License"). You may not use
# this file except in compliance with the License. A copy of the License is
# located at
#
#    http://aws.amazon.com/asl/
#
# or in the "license" file accompanying this file. This file is distributed on
# an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, express or
# implied. See the License for the specific language governing permissions and
# limitations under the License.
# =============================================================================

SDK_USERSPACE_DIR := $(SDK_DIR)/userspace

AXIL_SRC_DIR := ../src
SW_INC_DIR := ../include

INCLUDES := -I$(SW_INC_DIR) -I$(SDK_USERSPACE_DIR)/include
LDFLAGS := -L$(SDK_USERSPACE_DIR)/lib/so
LDLIBS := -lfpga_mgmt

CC = gcc
CFLAGS = -DCONFIG_LOGLEVEL=4 -std=gnu11 -g -Wall -Werror $(INCLUDES)

# Utility library sources
UTIL_SRCS := $(AXIL_SRC_DIR)/cl_axil_reg_access_utils.c
UTIL_OBJS := $(UTIL_SRCS:.c=.o)

AXIL_EXAMPLES := test_sum test_carry test_random test_misalignment

.PHONY: all clean check_env help

all: axil_examples

help:
	@echo "Available targets:"
	@echo "  all              - Build everything"
	@echo "  clean            - Remove built files"
	@echo "  axil_examples    - Build AXIL examples"
	@echo "  help             - Display this help message"

axil_examples: check_env $(AXIL_EXAMPLES)

clean:
	$(RM) $(AXIL_EXAMPLES) $(UTIL_OBJS)

check_env:
ifndef SDK_DIR
    $(error SDK_DIR is undefined. Try "source sdk_setup.sh" to set the software environment)
endif

# Build utility library objects
$(AXIL_SRC_DIR)/%.o: $(AXIL_SRC_DIR)/%.c
	$(CC) $(CFLAGS) -c $< -o $@

# Build test executables with utility library
%: $(AXIL_SRC_DIR)/%.c $(UTIL_OBJS) check_env
	$(CC) -o $@ $< $(UTIL_OBJS) $(CFLAGS) $(LDFLAGS) $(LDLIBS)
