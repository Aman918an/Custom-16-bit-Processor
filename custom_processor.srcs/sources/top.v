// Custom Processor — Harvard Architecture, FSM-controlled
// RTL corrected: all register updates in sequential block,
// clean combinational/sequential separation

`timescale 1ns / 1ps
`include "define.vh"

module top(
    input clk, sys_rst,
    input [15:0] din,
    output reg [15:0] dout
);

    // Instruction Register
    reg [31:0] IR;

    // Register File: 32 x 16-bit General Purpose Registers
    reg [15:0] GPR [31:0];

    // Special General Purpose Register (multiply upper result)
    reg [15:0] SGPR;

    // Condition Flags
    reg sign, zero, carry, overflow;

    // Program Memory (Instruction) — 16 x 32-bit (Harvard architecture)
    reg [31:0] inst_mem [15:0];

    // Data Memory — 16 x 16-bit (matches GPR width)
    reg [15:0] data_mem [15:0];

    // Control Signals
    reg jmp_flag;
    reg stop;

    // Program Counter — 4-bit for 16 locations
    reg [3:0] PC;

    // Delay Counter
    reg [2:0] count;

    // Intermediate Computation (blocking, used within sequential block only)
    reg [31:0] mul_res;
    reg [16:0] temp_sum;
    reg [15:0] alu_result;

    // Load program from file into instruction memory
    initial begin
        $readmemb("data.mem", inst_mem);
    end

    // FSM State Encoding
    localparam IDLE            = 3'd0;
    localparam FETCH_INST      = 3'd1;
    localparam DEC_EXE_INST    = 3'd2;
    localparam DELAY_NEXT_INST = 3'd3;
    localparam NEXT_INST       = 3'd4;
    localparam SENSE_HALT      = 3'd5;

    reg [2:0] state, next_state;

    //=========================================================================
    // Combinational Block: Next-State Logic ONLY
    //=========================================================================
    always @(*) begin
        case (state)
            IDLE:            next_state = FETCH_INST;
            FETCH_INST:      next_state = DEC_EXE_INST;
            DEC_EXE_INST:    next_state = DELAY_NEXT_INST;
            DELAY_NEXT_INST: next_state = (count < 3'd4) ? DELAY_NEXT_INST : NEXT_INST;
            NEXT_INST:       next_state = SENSE_HALT;
            SENSE_HALT: begin
                if (stop == 1'b0)
                    next_state = FETCH_INST;
                else if (sys_rst == 1'b1)
                    next_state = IDLE;
                else
                    next_state = SENSE_HALT;
            end
            default: next_state = IDLE;
        endcase
    end

    //=========================================================================
    // Sequential Block: State Register + All Datapath Register Updates
    //=========================================================================
    integer i;
    always @(posedge clk) begin
        if (sys_rst) begin
            // Synchronous reset — initialize all registers
            state    <= IDLE;
            PC       <= 4'd0;
            IR       <= 32'd0;
            count    <= 3'd0;
            jmp_flag <= 1'b0;
            stop     <= 1'b0;
            sign     <= 1'b0;
            zero     <= 1'b0;
            carry    <= 1'b0;
            overflow <= 1'b0;
            dout     <= 16'd0;
            SGPR     <= 16'd0;
            for (i = 0; i < 32; i = i + 1)
                GPR[i] <= 16'd0;
            for (i = 0; i < 16; i = i + 1)
                data_mem[i] <= 16'd0;
        end
        else begin
            // State transition
            state <= next_state;

            case (state)
                //-------------------------------------------------------------
                // IDLE: Reset internal state, prepare for first fetch
                //-------------------------------------------------------------
                IDLE: begin
                    PC       <= 4'd0;
                    IR       <= 32'd0;
                    count    <= 3'd0;
                    jmp_flag <= 1'b0;
                    stop     <= 1'b0;
                end

                //-------------------------------------------------------------
                // FETCH: Load instruction from program memory
                //-------------------------------------------------------------
                FETCH_INST: begin
                    IR    <= inst_mem[PC];
                    count <= 3'd0;
                end

                //-------------------------------------------------------------
                // DECODE & EXECUTE: Decode opcode, perform operation,
                //                   update condition flags
                //-------------------------------------------------------------
                DEC_EXE_INST: begin
                    count    <= 3'd0;
                    jmp_flag <= 1'b0;  // Default: no jump

                    // Initialize intermediates (blocking — for flag computation)
                    alu_result = 16'd0;
                    mul_res    = 32'd0;

                    // ==================== Decode & Execute ====================
                    case (`oper_type)

                        //--- Arithmetic Operations ---

                        `movsgpr: begin
                            alu_result  = SGPR;
                            GPR[`rdst] <= alu_result;
                        end

                        `mov: begin
                            if (`imm_mode)
                                alu_result = `isrc;
                            else
                                alu_result = GPR[`rsrc1];
                            GPR[`rdst] <= alu_result;
                        end

                        `add: begin
                            if (`imm_mode)
                                alu_result = GPR[`rsrc1] + `isrc;
                            else
                                alu_result = GPR[`rsrc1] + GPR[`rsrc2];
                            GPR[`rdst] <= alu_result;
                        end

                        `sub: begin
                            if (`imm_mode)
                                alu_result = GPR[`rsrc1] - `isrc;
                            else
                                alu_result = GPR[`rsrc1] - GPR[`rsrc2];
                            GPR[`rdst] <= alu_result;
                        end

                        `mul: begin
                            if (`imm_mode)
                                mul_res = GPR[`rsrc1] * `isrc;
                            else
                                mul_res = GPR[`rsrc1] * GPR[`rsrc2];
                            alu_result  = mul_res[15:0];
                            GPR[`rdst] <= mul_res[15:0];
                            SGPR       <= mul_res[31:16];
                        end

                        //--- Logical Operations ---

                        `ror: begin
                            if (`imm_mode)
                                alu_result = GPR[`rsrc1] | `isrc;
                            else
                                alu_result = GPR[`rsrc1] | GPR[`rsrc2];
                            GPR[`rdst] <= alu_result;
                        end

                        `rand: begin
                            if (`imm_mode)
                                alu_result = GPR[`rsrc1] & `isrc;
                            else
                                alu_result = GPR[`rsrc1] & GPR[`rsrc2];
                            GPR[`rdst] <= alu_result;
                        end

                        `rxor: begin
                            if (`imm_mode)
                                alu_result = GPR[`rsrc1] ^ `isrc;
                            else
                                alu_result = GPR[`rsrc1] ^ GPR[`rsrc2];
                            GPR[`rdst] <= alu_result;
                        end

                        `rxnor: begin
                            if (`imm_mode)
                                alu_result = GPR[`rsrc1] ~^ `isrc;
                            else
                                alu_result = GPR[`rsrc1] ~^ GPR[`rsrc2];
                            GPR[`rdst] <= alu_result;
                        end

                        `rnand: begin
                            if (`imm_mode)
                                alu_result = ~(GPR[`rsrc1] & `isrc);
                            else
                                alu_result = ~(GPR[`rsrc1] & GPR[`rsrc2]);
                            GPR[`rdst] <= alu_result;
                        end

                        `rnor: begin
                            if (`imm_mode)
                                alu_result = ~(GPR[`rsrc1] | `isrc);
                            else
                                alu_result = ~(GPR[`rsrc1] | GPR[`rsrc2]);
                            GPR[`rdst] <= alu_result;
                        end

                        `rnot: begin
                            if (`imm_mode)
                                alu_result = ~(`isrc);
                            else
                                alu_result = ~(GPR[`rsrc1]);
                            GPR[`rdst] <= alu_result;
                        end

                        //--- Memory Operations ---

                        `storedin: begin
                            data_mem[IR[3:0]] <= din;
                        end

                        `storereg: begin
                            data_mem[IR[3:0]] <= GPR[`rsrc1];
                        end

                        `senddout: begin
                            dout <= data_mem[IR[3:0]];
                        end

                        `sendreg: begin
                            GPR[`rdst] <= data_mem[IR[3:0]];
                        end

                        //--- Jump & Branch ---

                        `jump:        jmp_flag <= 1'b1;
                        `jcarry:      jmp_flag <= carry;
                        `jnocarry:    jmp_flag <= ~carry;
                        `jsign:       jmp_flag <= sign;
                        `jnosign:     jmp_flag <= ~sign;
                        `jzero:       jmp_flag <= zero;
                        `jnozero:     jmp_flag <= ~zero;
                        `joverflow:   jmp_flag <= overflow;
                        `jnooverflow: jmp_flag <= ~overflow;

                        //--- Halt ---

                        `halt: begin
                            stop <= 1'b1;
                        end

                        //--- Default (undefined opcodes) ---
                        default: begin
                            // No operation
                        end
                    endcase

                    // ============ Update Condition Flags ============
                    // Only for arithmetic/logical operations (opcodes 00000–01011)
                    if (`oper_type <= `rnot) begin

                        // Sign flag
                        if (`oper_type == `mul)
                            sign <= mul_res[31];
                        else
                            sign <= alu_result[15];

                        // Zero flag
                        if (`oper_type == `mul)
                            zero <= ~(|mul_res);
                        else
                            zero <= ~(|alu_result);

                        // Carry flag (ADD and SUB only)
                        if (`oper_type == `add) begin
                            if (`imm_mode)
                                temp_sum = GPR[`rsrc1] + `isrc;
                            else
                                temp_sum = GPR[`rsrc1] + GPR[`rsrc2];
                            carry <= temp_sum[16];
                        end
                        else if (`oper_type == `sub) begin
                            if (`imm_mode)
                                temp_sum = GPR[`rsrc1] - `isrc;
                            else
                                temp_sum = GPR[`rsrc1] - GPR[`rsrc2];
                            carry <= temp_sum[16];
                        end
                        else begin
                            carry <= 1'b0;
                        end

                        // Overflow flag (ADD and SUB only)
                        if (`oper_type == `add) begin
                            if (`imm_mode)
                                overflow <= (~GPR[`rsrc1][15] & ~IR[15] & alu_result[15]) |
                                            ( GPR[`rsrc1][15] &  IR[15] & ~alu_result[15]);
                            else
                                overflow <= (~GPR[`rsrc1][15] & ~GPR[`rsrc2][15] &  alu_result[15]) |
                                            ( GPR[`rsrc1][15] &  GPR[`rsrc2][15] & ~alu_result[15]);
                        end
                        else if (`oper_type == `sub) begin
                            if (`imm_mode)
                                overflow <= (~GPR[`rsrc1][15] &  IR[15]          &  alu_result[15]) |
                                            ( GPR[`rsrc1][15] & ~IR[15]          & ~alu_result[15]);
                            else
                                overflow <= (~GPR[`rsrc1][15] &  GPR[`rsrc2][15] &  alu_result[15]) |
                                            ( GPR[`rsrc1][15] & ~GPR[`rsrc2][15] & ~alu_result[15]);
                        end
                        else begin
                            overflow <= 1'b0;
                        end

                    end // if oper_type <= rnot
                end // DEC_EXE_INST

                //-------------------------------------------------------------
                // DELAY: Wait cycles before advancing to next instruction
                //-------------------------------------------------------------
                DELAY_NEXT_INST: begin
                    count <= count + 1;
                end

                //-------------------------------------------------------------
                // NEXT_INST: Update Program Counter
                //-------------------------------------------------------------
                NEXT_INST: begin
                    count <= 3'd0;
                    if (jmp_flag == 1'b1)
                        PC <= IR[3:0];   // Jump target (lower 4 bits of isrc)
                    else
                        PC <= PC + 1;    // Sequential execution
                end

                //-------------------------------------------------------------
                // SENSE_HALT: Check if processor should continue or halt
                //-------------------------------------------------------------
                SENSE_HALT: begin
                    count <= 3'd0;
                end

                //-------------------------------------------------------------
                default: begin
                    count <= 3'd0;
                end
            endcase
        end
    end

endmodule
