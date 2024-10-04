TOP = soc_top
GTKWAVE = gtkwave

V_SRC = ../core/soc/soc_top.v
V_SRC += ../core/vsrc/coretop.v
V_SRC += $(wildcard ../core/device/*.v)
V_SRC += $(wildcard ../core/vsrc/ctrl/*.v)
V_SRC += $(wildcard ../core/vsrc/ctx_module/*.v)
V_SRC += $(wildcard ../core/vsrc/exe/*.v)
V_SRC += $(wildcard ../core/vsrc/heap_module/*.v)
V_SRC += $(wildcard ../core/vsrc/id/*.v)
V_SRC += $(wildcard ../core/vsrc/if/*.v)
V_SRC += $(wildcard ../core/vsrc/include/*.v)
V_SRC += $(wildcard ../core/vsrc/mem/*.v)
V_SRC += $(wildcard ../core/vsrc/wb/*.v)
V_SRC += $(wildcard ../core/vsrc/id/*.v)
V_SRC += $(wildcard ../core/vsrc/id/*.v)


TESTBENCH_SRC = $(wildcard ./tb/*.cpp)
VTOP = ../core/soc/${TOP}.v
INC = -I../core/vsrc/include
PROG = test
PROG_S = $(wildcard ./test_src/*.S)

.DEFAULT_GOAL :=all

all:vhdl

obj_dir/V${TOP}.mk: ${V_SRC} ${TESTBENCH_SRC}
	verilator --cc --trace -Wall --exe --build ${TESTBENCH_SRC} ${INC} ${V_SRC} --trace --trace-max-array 256

obj_dir/V${TOP} : obj_dir/V${TOP}.mk
	$(MAKE) -C obj_dir -f V$(TOP).mk

test_src/${PROG}.bin: ${PROG_S}
	$(MAKE) -C test_src

.PHONY : vhdl
vhdl: obj_dir/V${TOP}.mk

.PHONY : run
run: test_src/${PROG}.bin obj_dir/V${TOP}
	obj_dir/V${TOP} test_src/${PROG}.bin

.PHONY : testc
testc: ctest/${PROG}.bin obj_dir/V${TOP}
	obj_dir/V${TOP} ctest/${PROG}.bin

.PHONY : wave
wave : run
	${GTKWAVE} wave.vcd

.PHONY : clean
clean: 
	rm -rf obj_dir wave.vcd
	rm -rf test_src/*.elf test_src/*.bin
