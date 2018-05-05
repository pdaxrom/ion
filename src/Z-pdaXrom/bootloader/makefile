#-- Bring toolchain config parameters from the common makefile
include ../common/makefile

# Link script to be used: run from BRAM
LINK_SCRIPT = $(SRC_DIR)/common/bram.lds

#-- Configure the application --------------------------------------------------

# Simulation length in cycles; long enough to let the program run to completion.
SIM_LENGTH = 90000

# FPGA Block RAM parameters
BRAM_START = 0xbfc00000
CODE_BRAM_SIZE = 2048
# External RAM parameters (size in words)
XRAM_SIZE = 1024
XRAM_START = 0x00000000


# 1.- Put the code in internal BRAM and the data in external SRAM.
# 2.- Do not use any of the standard libraries and use libsoc instead.

LFLAGS = -T$(LINK_SCRIPT) -L $(LIB_PATH) \
         -Ttext $(BRAM_START) -Tdata $(XRAM_START) \
         -nodefaultlibs -nostdlib -ereset -I elf32-big
CFLAGS = -O2 -Wall -c -s -fno-builtin -nodefaultlibs -nostdlib \
         -msoft-float -mips1 -G0 -I ../common
AFLAGS = --defsym XRAM_BASE=$(XRAM_START)


OBJS = bootstrap.o opcode_emu.o c_startup.o bootloader.o


#-- Targets & rules ------------------------------------------------------------

bootloader: bootloader.code bootloader.data
	@# This comment prevents use of implicit rule so our rules are used instead.
	@# This will save us a few harmless linker warnings.

bootloader.axf: $(OBJS)
	$(LD) $(LFLAGS) -Map bootloader.map -s -N -o bootloader.axf $(OBJS) -lsoc
	-@$(DUMP) -m mips --disassemble bootloader.axf > bootloader.lst

bootloader.code: bootloader.axf
# Extract object code to be placed in code space
	$(COPY) -I elf32-big -O binary bootloader.axf bootloader.code

bootloader.data: bootloader.axf
# Extract object code to be placed in data space
	$(COPY) -I elf32-big -j.data -j.bss -O binary bootloader.axf bootloader.data



bootstrap.o: $(SRC_DIR)/common/bootstrap.s
	$(AS) $(AFLAGS) -o bootstrap.o $(SRC_DIR)/common/bootstrap.s

c_startup.o: $(SRC_DIR)/common/c_startup.s
	$(AS) $(AFLAGS) -o c_startup.o $(SRC_DIR)/common/c_startup.s

opcode_emu.o: $(SRC_DIR)/common/opcode_emu.s
	$(AS) $(AFLAGS) -o opcode_emu.o $(SRC_DIR)/common/opcode_emu.s

bootloader.o: bootloader.c
	$(CC) $(CFLAGS) -o bootloader.o bootloader.c

#-- Create VHDL package with data and parameters for simulation and syntesis
demo: bootloader
	$(VHDL_OBJ_PKG) --project="bootloader" \
		--package obj_code_pkg \
		--bin bootloader.code --name obj_code --bram_size $(CODE_BRAM_SIZE) \
		--output ../../../lattice/Z-pdaXrom/bootstrap_code_pkg.vhdl
		sed -i -e 's/^constant CLOCK_RATE/--constant CLOCK_RATE/g' ../../../lattice/Z-pdaXrom/bootstrap_code_pkg.vhdl
		sed -i -e 's/^constant T/--constant CLOCK_RATE/g' ../../../lattice/Z-pdaXrom/bootstrap_code_pkg.vhdl


#-- And now the usual housekeeping stuff ---------------------------------------

.PHONY: clean

clean:
	-$(RM) *.o *.obj *.map *.lst *.hex *.exe *.axf *.code *.data *.bin
