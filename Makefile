VC = iverilog

SOURCES = \
		  exmemory.v \
		  alu.v \
		  regfile.v \
		  mips.v
TEST_EXECUTIONS = $(SOURCES:%.v=%.test)

.SUFFIXES: _test.v .test 
.PHONY: test clean

test: $(TEST_EXECUTIONS)
	$(foreach EXE,$?,./$(EXE);)

_test.v.test: $(SOURCES)
	$(VC) -o $@ $(SOURCES) $<

clean:
	@rm -f $(TEST_EXECUTIONS)
