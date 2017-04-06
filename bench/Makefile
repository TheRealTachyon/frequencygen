TARGET=serial_decode
.PHONY: $(TARGET)

all: $(TARGET)

$(TARGET): edge.o 
	verilator -O3 -Wno-fatal -I../rtl/ --cc $(@).v --trace --exe  ../$(@).cpp  -Mdir $(@) -LDFLAGS "../edge.o" 
	make -C $(@) -f V$(TARGET).mk
edge.o: edge.cpp
tinycon.o: tinycon.cpp
clean:
	rm -rf *.o $(TARGET) 
distclean: clean
	rm -rf *~ *.mif *.lu *.ul *.vcd *.txt