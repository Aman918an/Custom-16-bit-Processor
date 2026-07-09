// Comprehensive Self-Checking Testbench for Custom Processor
// Debug wires exposed for waveform viewing in Vivado

`timescale 1ns / 1ps

module tb;

    //=========================================================================
    // DUT Signals
    //=========================================================================
    reg         clk, sys_rst;
    reg  [15:0] din;
    wire [15:0] dout;

    // Instantiate DUT with named connections
    top dut (
        .clk(clk),
        .sys_rst(sys_rst),
        .din(din),
        .dout(dout)
    );

    //=========================================================================
    // Clock Generation: 100 MHz (10 ns period)
    //=========================================================================
    initial clk = 0;
    always #5 clk = ~clk;

    //=========================================================================
    // Debug Wires — visible in Vivado waveform under "tb" scope
    //=========================================================================

    // Control path
    wire [2:0]  dbg_state    = dut.state;
    wire [2:0]  dbg_nxtstate = dut.next_state;
    wire [3:0]  dbg_PC       = dut.PC;
    wire [31:0] dbg_IR       = dut.IR;
    wire [2:0]  dbg_count    = dut.count;
    wire        dbg_jmp_flag = dut.jmp_flag;
    wire        dbg_stop     = dut.stop;

    // Condition flags
    wire        dbg_sign     = dut.sign;
    wire        dbg_zero     = dut.zero;
    wire        dbg_carry    = dut.carry;
    wire        dbg_overflow = dut.overflow;

    // Key registers (used in test program)
    wire [15:0] dbg_R0       = dut.GPR[0];
    wire [15:0] dbg_R1       = dut.GPR[1];
    wire [15:0] dbg_R2       = dut.GPR[2];
    wire [15:0] dbg_R3       = dut.GPR[3];
    wire [15:0] dbg_R4       = dut.GPR[4];
    wire [15:0] dbg_R5       = dut.GPR[5];
    wire [15:0] dbg_R6       = dut.GPR[6];
    wire [15:0] dbg_R7       = dut.GPR[7];
    wire [15:0] dbg_R8       = dut.GPR[8];
    wire [15:0] dbg_R9       = dut.GPR[9];
    wire [15:0] dbg_R10      = dut.GPR[10];
    wire [15:0] dbg_R11      = dut.GPR[11];
    wire [15:0] dbg_SGPR     = dut.SGPR;

    // Data memory (first 4 locations used in test)
    wire [15:0] dbg_dmem0    = dut.data_mem[0];
    wire [15:0] dbg_dmem1    = dut.data_mem[1];

    // FSM state names for console log
    reg [12*8-1:0] state_name;
    always @(*) begin
        case (dut.state)
            3'd0: state_name = "IDLE        ";
            3'd1: state_name = "FETCH       ";
            3'd2: state_name = "DECODE_EXE  ";
            3'd3: state_name = "DELAY       ";
            3'd4: state_name = "NEXT_INST   ";
            3'd5: state_name = "SENSE_HALT  ";
            default: state_name = "UNKNOWN     ";
        endcase
    end

    // Opcode name for console log
    reg [8*8-1:0] opcode_name;
    always @(*) begin
        case (dut.IR[31:27])
            5'b00000: opcode_name = "MOVSGPR ";
            5'b00001: opcode_name = "MOV     ";
            5'b00010: opcode_name = "ADD     ";
            5'b00011: opcode_name = "SUB     ";
            5'b00100: opcode_name = "MUL     ";
            5'b00101: opcode_name = "OR      ";
            5'b00110: opcode_name = "AND     ";
            5'b00111: opcode_name = "XOR     ";
            5'b01000: opcode_name = "XNOR    ";
            5'b01001: opcode_name = "NAND    ";
            5'b01010: opcode_name = "NOR     ";
            5'b01011: opcode_name = "NOT     ";
            5'b01101: opcode_name = "STOREREG";
            5'b01110: opcode_name = "STOREDIN";
            5'b01111: opcode_name = "SENDDOUT";
            5'b10001: opcode_name = "SENDREG ";
            5'b10010: opcode_name = "JUMP    ";
            5'b10011: opcode_name = "JCARRY  ";
            5'b10100: opcode_name = "JNOCARRY";
            5'b10101: opcode_name = "JSIGN   ";
            5'b10110: opcode_name = "JNOSIGN ";
            5'b10111: opcode_name = "JZERO   ";
            5'b11000: opcode_name = "JNOZERO ";
            5'b11001: opcode_name = "JOVERFLW";
            5'b11010: opcode_name = "JNOOVFLW";
            5'b11011: opcode_name = "HALT    ";
            default:  opcode_name = "NOP     ";
        endcase
    end

    //=========================================================================
    // Execution Trace — prints every instruction as it executes
    //=========================================================================
    always @(posedge clk) begin
        if (dut.state == 3'd2) begin // DEC_EXE_INST
            $display("[%0t ns] PC=%0d  %0s  IR=%b  rdst=R%0d  rsrc1=R%0d  imm=%0b  isrc=%0d",
                     $time, dut.PC, opcode_name, dut.IR,
                     dut.IR[26:22], dut.IR[21:17], dut.IR[16], dut.IR[15:0]);
        end
    end

    //=========================================================================
    // Test Tracking
    //=========================================================================
    integer pass_count = 0;
    integer fail_count = 0;
    integer test_num   = 0;

    //=========================================================================
    // Verification Tasks
    //=========================================================================

    task check_reg;
        input [4:0]   reg_num;
        input [15:0]  expected;
        input [255:0] description;
    begin
        test_num = test_num + 1;
        if (dut.GPR[reg_num] === expected) begin
            $display("  [PASS] Test %2d: GPR[%2d] = 0x%04h  (%0s)",
                     test_num, reg_num, dut.GPR[reg_num], description);
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] Test %2d: GPR[%2d] = 0x%04h, expected 0x%04h  (%0s)",
                     test_num, reg_num, dut.GPR[reg_num], expected, description);
            fail_count = fail_count + 1;
        end
    end
    endtask

    task check_flag;
        input         actual;
        input         expected;
        input [255:0] name;
    begin
        test_num = test_num + 1;
        if (actual === expected) begin
            $display("  [PASS] Test %2d: %0s = %0b", test_num, name, actual);
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] Test %2d: %0s = %0b, expected %0b", test_num, name, actual, expected);
            fail_count = fail_count + 1;
        end
    end
    endtask

    task check_dmem;
        input [3:0]   addr;
        input [15:0]  expected;
        input [255:0] description;
    begin
        test_num = test_num + 1;
        if (dut.data_mem[addr] === expected) begin
            $display("  [PASS] Test %2d: data_mem[%2d] = 0x%04h  (%0s)",
                     test_num, addr, dut.data_mem[addr], description);
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] Test %2d: data_mem[%2d] = 0x%04h, expected 0x%04h  (%0s)",
                     test_num, addr, dut.data_mem[addr], expected, description);
            fail_count = fail_count + 1;
        end
    end
    endtask

    //=========================================================================
    // Main Test Sequence
    //=========================================================================

    initial begin
        $display("");
        $display("=======================================================");
        $display("  Custom Processor - Verification Testbench");
        $display("=======================================================");
        $display("");

        // Initialize inputs
        sys_rst = 1'b1;
        din     = 16'h0000;

        // Assert reset for 5 clock cycles
        repeat(5) @(posedge clk);
        #1;
        sys_rst = 1'b0;
        $display("[%0t ns] Reset deasserted - program execution begins", $time);
        $display("");
        $display("--- Instruction Execution Trace ---");
        $display("");

        // Wait for processor to halt
        // Monitor the stop signal instead of fixed delay
        wait(dut.stop == 1'b1);
        repeat(5) @(posedge clk);  // Let final state settle

        $display("");
        $display("--- Processor halted at time %0t ns ---", $time);
        $display("");

        // =====================================================================
        // Verify Results
        // =====================================================================

        $display("--- Register File Verification ---");
        $display("");

        // Arithmetic operations
        check_reg(5'd0,  16'h0002, "MOV R0, #2");
        check_reg(5'd1,  16'h0003, "MOV R1, #3");
        check_reg(5'd2,  16'h0005, "ADD R2, R0, R1 = 2+3");
        check_reg(5'd3,  16'h0002, "SUB R3, R2, R1 = 5-3");
        check_reg(5'd4,  16'h0006, "MUL R4, R0, R1 = 2*3");

        // Logical operations
        check_reg(5'd5,  16'h0003, "OR  R5, R0, R1 = 2|3");
        check_reg(5'd6,  16'h0002, "AND R6, R0, R1 = 2&3");
        check_reg(5'd7,  16'h0001, "XOR R7, R0, R1 = 2^3");
        check_reg(5'd8,  16'hFFFD, "NOT R8, R0 = ~2");

        // Memory operations
        check_reg(5'd9,  16'h0005, "SENDREG R9 from data_mem[0]");

        // Zero-producing MOV
        check_reg(5'd10, 16'h0000, "MOV R10, #0");

        // JZERO test: R11 should be 0 (inst 14 was skipped)
        check_reg(5'd11, 16'h0000, "R11=0 proves JZERO skipped inst 14");

        $display("");
        $display("--- Data Memory Verification ---");
        $display("");

        check_dmem(4'd0, 16'h0005, "STOREREG dm[0] = R2 = 5");
        check_dmem(4'd1, 16'h0006, "STOREREG dm[1] = R4 = 6");

        $display("");
        $display("--- Condition Flag Verification ---");
        $display("");

        check_flag(dut.zero,     1'b1, "zero flag (after MOV R10,#0)");
        check_flag(dut.sign,     1'b0, "sign flag (after MOV R10,#0)");
        check_flag(dut.carry,    1'b0, "carry flag");
        check_flag(dut.overflow, 1'b0, "overflow flag");

        $display("");
        $display("--- Control Signal Verification ---");
        $display("");

        check_flag(dut.stop, 1'b1, "stop (HALT executed)");

        test_num = test_num + 1;
        if (dut.SGPR === 16'h0000) begin
            $display("  [PASS] Test %2d: SGPR = 0x%04h  (MUL upper = 0)", test_num, dut.SGPR);
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] Test %2d: SGPR = 0x%04h, expected 0x0000", test_num, dut.SGPR);
            fail_count = fail_count + 1;
        end

        // =====================================================================
        // Reset Verification
        // =====================================================================

        $display("");
        $display("--- Reset Behavior Verification ---");
        $display("");

        sys_rst = 1'b1;
        repeat(3) @(posedge clk);
        #1;

        test_num = test_num + 1;
        if (dut.PC === 4'd0) begin
            $display("  [PASS] Test %2d: PC = %0d after reset", test_num, dut.PC);
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] Test %2d: PC = %0d, expected 0", test_num, dut.PC);
            fail_count = fail_count + 1;
        end

        test_num = test_num + 1;
        if (dut.stop === 1'b0) begin
            $display("  [PASS] Test %2d: stop cleared by reset", test_num);
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] Test %2d: stop = %0b, expected 0 after reset", test_num, dut.stop);
            fail_count = fail_count + 1;
        end

        test_num = test_num + 1;
        if (dut.jmp_flag === 1'b0) begin
            $display("  [PASS] Test %2d: jmp_flag cleared by reset", test_num);
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] Test %2d: jmp_flag = %0b, expected 0 after reset", test_num, dut.jmp_flag);
            fail_count = fail_count + 1;
        end

        sys_rst = 1'b0;

        // =====================================================================
        // Summary
        // =====================================================================

        $display("");
        $display("=======================================================");
        $display("  RESULTS: %0d PASSED, %0d FAILED (out of %0d tests)",
                 pass_count, fail_count, test_num);
        if (fail_count == 0)
            $display("  *** ALL TESTS PASSED ***");
        else
            $display("  *** %0d TEST(S) FAILED ***", fail_count);
        $display("=======================================================");
        $display("");

        #100;
        $finish;
    end

endmodule
