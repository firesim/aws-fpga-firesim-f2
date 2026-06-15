#
# Copyright 2015-2016 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"). You may
# not use this file except in compliance with the License. A copy of the
# License is located at
#
#     http://aws.amazon.com/apache2.0/
#
# or in the "license" file accompanying this file. This file is distributed
# on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
# express or implied. See the License for the specific language governing
# permissions and limitations under the License.
#

TOP = ../..
TOPINC_PATH = $(TOP)/include
FPGAHALINC_PATH = $(TOPINC_PATH)/hal
LIB_PATH = $(TOP)/lib

# Build output directory
BUILD_DIR = build

INCLUDES = -I$(FPGAHALINC_PATH) -I$(TOPINC_PATH) -I../. -I.

OPT=-DFPGA_ALLOW_NON_ROOT -DCONFIG_LOGLEVEL=1
CFLAGS=$(OPT) -g -Wall -Werror -W -Wno-parentheses -Wstrict-prototypes -Wmissing-prototypes $(INCLUDES)

LDFLAGS = -L$(LIB_PATH)/so
LDLIBS = -lfpga_mgmt

# flags for compiling a statically linked version
LDFLAGS_STATIC = -L$(LIB_PATH)
LDLIBS_STATIC = -lfpga_mgmt -lrt -lpthread

UTILLCDLIB = $(LIB_PATH)/libutils.a
LIBS=$(UTILLCDLIB)

OBJ = $(SRC:.c=.o)

BINS = clear_single_fpga clear_multiple_fpga load_single_fpga load_multiple_fpga prefetch_multiple_afi
STATIC_BINS = clear_single_fpga clear_multiple_fpga load_single_fpga load_multiple_fpga prefetch_multiple_afi

all: $(BUILD_DIR) $(addprefix $(BUILD_DIR)/,$(BINS)) $(addprefix $(BUILD_DIR)/static_,$(STATIC_BINS))

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/%: %.c | $(BUILD_DIR)
	$(CC) -o $@ $^ $(LDFLAGS) $(LDLIBS) $(CFLAGS)

$(BUILD_DIR)/static_%: %.c | $(BUILD_DIR)
	$(CC) -o $@ $^ $(LDFLAGS_STATIC) $(LDLIBS_STATIC) $(CFLAGS)

clean:
	rm -rf $(BUILD_DIR) *.o *.a
