`include "parameters.vh"

module uart_printer(
    input clk,
    input rst,
    input start,
    input [3:0] mode,
    input [6:0] target_id,

    
    input [7:0] total_count,
    input [4:0] size_idx_in,
    input [2:0] size_count_in,
    input [4:0] size_valid_mask_in,

    
    output reg [6:0] mat_id,
    output reg [3:0] mat_r,
    output reg [3:0] mat_c,
    input [31:0] mat_data,
    input [3:0] mat_m,
    input [3:0] mat_n,

    
    output reg [6:0] conv_addr,
    input signed [31:0] conv_data,

    // UART 鎺ュ彛
    output reg [7:0] tx_data,
    output reg tx_start,
    input tx_done,

    output reg done,
    output wire busy,
    output reg [4:0] size_idx_out,
    output reg [2:0] slot_out
);

    localparam MODE_DUMP = 4'd0;
    localparam MODE_MAT_A = 4'd1;
    localparam MODE_MAT_B = 4'd2;
    localparam MODE_RES = 4'd3;
    localparam MODE_CONV = 4'd4;
    localparam MODE_LIST_DIM = 4'd5;
    localparam MODE_ERROR = 4'd6;  // 新增：打印ERROR消息

    localparam S_IDLE = 6'd0;
    localparam S_WAIT_TX = 6'd1;

    assign busy = (state != S_IDLE);

    localparam S_DUMP_TOTAL = 6'd2;
    localparam S_DUMP_SIZE_LOOP = 6'd3;
    localparam S_DUMP_SIZE_CHECK = 6'd4;
    localparam S_DUMP_SIZE_PRINT = 6'd5;
    localparam S_DUMP_MAT_LOOP = 6'd6;
    localparam S_DUMP_MAT_CHECK = 6'd7;
    localparam S_DUMP_MAT_PRINT = 6'd8;
    localparam S_PRINT_ID = 6'd9;

    localparam S_MAT_ROW_LOOP = 6'd10;
    localparam S_MAT_COL_LOOP = 6'd11;
    localparam S_MAT_PRINT_ELEM = 6'd12;
    localparam S_MAT_NEXT_ELEM = 6'd13;
    localparam S_MAT_CALC_PAD = 6'd14;
    localparam S_MAT_PRINT_PAD = 6'd15;

    localparam S_NUM_PREP = 6'd20;
    localparam S_NUM_SIGN = 6'd21;
    localparam S_NUM_DIGIT = 6'd22;
    
    // ERROR模式状态
    localparam S_ERROR_E = 6'd30;  // 打印'E'
    localparam S_ERROR_R1 = 6'd31; // 打印第一个'R'
    localparam S_ERROR_R2 = 6'd32; // 打印第二个'R'
    localparam S_ERROR_O = 6'd33;  // 打印'O'
    localparam S_ERROR_R3 = 6'd34; // 打印第三个'R'
    localparam S_ERROR_DONE = 6'd35; // 完成，发送换行

    reg [5:0] state;
    reg [5:0] return_state;
    reg [5:0] next_state_after_num;

    reg signed [31:0] num_val;
    reg [31:0] num_abs;
    reg [3:0] num_len;
    reg [3:0] num_pos;
    reg [7:0] num_buf [0:10];
    reg num_neg;
    reg [31:0] divisor;
    reg [3:0] digit_val;

    reg [4:0] chars_printed;
    reg [4:0] spaces_needed;
    reg [4:0] space_cnt;
    localparam COLUMN_WIDTH = 5'd10;

    reg [4:0] s_idx;
    reg [2:0] s_slot;
    reg [3:0] r_cnt;
    reg [3:0] c_cnt;
    reg first_mat;

    
    function [6:0] make_id;
        input [4:0] sidx;
        input [2:0] slot;
        begin
            make_id = (sidx * 5) + slot;
        end
    endfunction

    wire [3:0] lim_m;
    wire [3:0] lim_n;
    assign lim_m = (mode == MODE_CONV) ? 4'd8 : mat_m;
    assign lim_n = (mode == MODE_CONV) ? 4'd10 : mat_n;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= S_IDLE;
            tx_start <= 1'b0;
            done <= 1'b0;
            size_idx_out <= 5'd0;
            slot_out <= 3'd0;
            mat_id <= 7'd0;
            mat_r <= 4'd0;
            mat_c <= 4'd0;
            conv_addr <= 7'd0;
        end else begin
            tx_start <= 1'b0;
            done <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (start) begin
                        $display("UART Printer Started: Mode=%d, Target=%d, Total=%d", mode, target_id, total_count);
                        case (mode)
                            MODE_DUMP: begin
                                num_val <= $signed({24'd0, total_count});
                                next_state_after_num <= S_DUMP_TOTAL;
                                state <= S_NUM_PREP;
                                mat_id <= 7'd0;  
                                first_mat <= 1'b1;
                            end
                            MODE_MAT_A, MODE_MAT_B, MODE_RES: begin
                                mat_id <= target_id;
                                r_cnt <= 4'd0;
                                c_cnt <= 4'd0;
                                state <= S_MAT_ROW_LOOP;
                            end
                            MODE_CONV: begin
                                r_cnt <= 4'd0; 
                                c_cnt <= 4'd0; 
                                state <= S_MAT_ROW_LOOP; 
                            end
                            MODE_LIST_DIM: begin // MODE_LIST_DIM
                                s_idx <= target_id[4:0];
                                s_slot <= 3'd0;
                                state <= S_DUMP_MAT_LOOP;
                            end
                            MODE_ERROR: begin  // 打印"ERROR"
                                state <= S_ERROR_E;
                            end
                            default: state <= S_IDLE;
                        endcase
                    end
                end

                S_WAIT_TX: begin
                    if (tx_done) state <= return_state;
                end

                // --- DUMP MODE ---
                S_DUMP_TOTAL: begin
                    tx_data <= `ASCII_NEWLINE;
                    tx_start <= 1'b1;
                    return_state <= S_DUMP_MAT_LOOP;  
                    state <= S_WAIT_TX;
                end

                S_DUMP_SIZE_LOOP: begin
                    
                    state <= S_DUMP_MAT_LOOP;
                end

                S_DUMP_SIZE_CHECK: begin
                    
                    
                    
                    if (s_idx >= 25) begin
                        tx_data <= `ASCII_NEWLINE;
                        tx_start <= 1'b1;
                        return_state <= S_DUMP_MAT_LOOP;
                        state <= S_WAIT_TX;
                        s_idx <= 5'd0;
                        s_slot <= 3'd0;
                    end else if (size_count_in == 0) begin
                        s_idx <= s_idx + 1;
                        state <= S_DUMP_SIZE_LOOP;
                    end else begin
                        
                        tx_data <= `ASCII_SPACE;
                        tx_start <= 1'b1;
                        return_state <= S_DUMP_SIZE_PRINT;
                        state <= S_WAIT_TX;
                    end
                end

                S_DUMP_SIZE_PRINT: begin
                    
                    num_val <= (s_idx / 5) + 1;
                    next_state_after_num <= 6'd40; 
                    state <= S_NUM_PREP;
                end

                6'd40: begin // m 涔嬪悗
                    tx_data <= 8'h2A; // '*'
                    tx_start <= 1'b1;
                    return_state <= 6'd41;
                    state <= S_WAIT_TX;
                end

                6'd41: begin 
                    num_val <= (s_idx % 5) + 1;
                    next_state_after_num <= 6'd42;
                    state <= S_NUM_PREP;
                end

                6'd42: begin // n 涔嬪悗
                    tx_data <= 8'h2A; // '*'
                    tx_start <= 1'b1;
                    return_state <= 6'd43;
                    state <= S_WAIT_TX;
                end

                6'd43: begin 
                    num_val <= size_count_in;
                    next_state_after_num <= 6'd44;
                    state <= S_NUM_PREP;
                end

                6'd44: begin 
                    s_idx <= s_idx + 1;
                    state <= S_DUMP_SIZE_LOOP;
                end

                // --- DUMP MATRICES (鏂扮畝鍖栫増) ---
                S_DUMP_MAT_LOOP: begin
                    
                    state <= S_DUMP_MAT_CHECK;
                end

                S_DUMP_MAT_CHECK: begin
                    // mat_id鏄綋鍓嶈妫€鏌ョ殑ID锛堜粠0寮€濮嬶級
                    if (mat_id >= 12) begin
                        done <= 1'b1;
                        state <= S_IDLE;
                    end else if (mat_m == 0 || mat_n == 0) begin
                        
                        mat_id <= mat_id + 1;
                        state <= S_DUMP_MAT_LOOP;
                    end else begin
                        
                        if (!first_mat) begin
                            tx_data <= `ASCII_NEWLINE;
                            tx_start <= 1'b1;
                            return_state <= S_DUMP_MAT_PRINT;
                            state <= S_WAIT_TX;
                        end else begin
                            first_mat <= 1'b0;
                            state <= S_DUMP_MAT_PRINT;
                        end
                    end
                end

                S_PRINT_ID: begin
                    tx_data <= `ASCII_NEWLINE;
                    tx_start <= 1'b1;
                    return_state <= S_DUMP_MAT_PRINT;
                    state <= S_WAIT_TX;
                end

                S_DUMP_MAT_PRINT: begin
                    
                    r_cnt <= 0;
                    c_cnt <= 0;
                    
                    // m = s_idx/5 + 1, n = s_idx%5 + 1
                    state <= S_MAT_ROW_LOOP;
                end

                // --- SHARED MATRIX PRINT LOOP ---
                S_MAT_ROW_LOOP: begin
                    if (r_cnt >= lim_m) begin
                        if (mode == MODE_DUMP) begin
                            mat_id <= mat_id + 1;  
                            state <= S_DUMP_MAT_LOOP;
                        end else begin
                            done <= 1'b1;
                            state <= S_IDLE;
                        end
                    end else begin
                        state <= S_MAT_COL_LOOP;
                    end
                end

                S_MAT_COL_LOOP: begin
                    if (c_cnt >= lim_n) begin
                        tx_data <= `ASCII_NEWLINE;
                        tx_start <= 1'b1;
                        return_state <= 6'd50; 
                        state <= S_WAIT_TX;
                    end else begin
                        
                        mat_r <= r_cnt;
                        mat_c <= c_cnt;
                        if (mode == MODE_CONV) begin
                            conv_addr <= (r_cnt * 10) + c_cnt;
                        end
                        state <= S_MAT_PRINT_ELEM;
                    end
                end

                6'd50: begin 
                    c_cnt <= 0;
                    r_cnt <= r_cnt + 1;
                    state <= S_MAT_ROW_LOOP;
                end

                S_MAT_PRINT_ELEM: begin
                    
                    if (mode == MODE_CONV) num_val <= conv_data;
                    else num_val <= mat_data;

                    next_state_after_num <= S_MAT_CALC_PAD;
                    state <= S_NUM_PREP;
                end

                S_MAT_CALC_PAD: begin
                    if (chars_printed < COLUMN_WIDTH) begin
                        spaces_needed <= COLUMN_WIDTH - chars_printed;
                    end else begin
                        spaces_needed <= 5'd1; 
                    end
                    space_cnt <= 5'd0;
                    state <= S_MAT_PRINT_PAD;
                end

                S_MAT_PRINT_PAD: begin
                    if (space_cnt < spaces_needed) begin
                        tx_data <= `ASCII_SPACE;
                        tx_start <= 1'b1;
                        space_cnt <= space_cnt + 1;
                        return_state <= S_MAT_PRINT_PAD;
                        state <= S_WAIT_TX;
                    end else begin
                        c_cnt <= c_cnt + 1;
                        state <= S_MAT_COL_LOOP;
                    end
                end

                // --- NUMBER PRINTING SUBROUTINE (Robust) ---
                S_NUM_PREP: begin
                    if (num_val < 0) begin
                        num_neg <= 1'b1;
                        num_abs <= -num_val;
                    end else begin
                        num_neg <= 1'b0;
                        num_abs <= num_val;
                    end
                    num_pos <= 0; 
                    divisor <= 32'd1000000000; 
                    state <= 6'd60; 
                end

                6'd60: begin // Skip leading zeros
                    if (divisor > 1 && num_abs < divisor) begin
                        case (divisor)
                            32'd1000000000: divisor <= 32'd100000000;
                            32'd100000000:  divisor <= 32'd10000000;
                            32'd10000000:   divisor <= 32'd1000000;
                            32'd1000000:    divisor <= 32'd100000;
                            32'd100000:     divisor <= 32'd10000;
                            32'd10000:      divisor <= 32'd1000;
                            32'd1000:       divisor <= 32'd100;
                            32'd100:        divisor <= 32'd10;
                            32'd10:         divisor <= 32'd1;
                            default:        divisor <= 32'd1;
                        endcase
                        state <= 6'd60;
                    end else begin
                        digit_val <= 0;
                        state <= 6'd62;
                    end
                end

                6'd62: begin // Subtraction loop
                    if (num_abs >= divisor) begin
                        num_abs <= num_abs - divisor;
                        digit_val <= digit_val + 1;
                        state <= 6'd62;
                    end else begin
                        num_buf[num_pos] <= digit_val + `ASCII_0;
                        num_pos <= num_pos + 1;

                        if (divisor > 1) begin
                            case (divisor)
                                32'd1000000000: divisor <= 32'd100000000;
                                32'd100000000:  divisor <= 32'd10000000;
                                32'd10000000:   divisor <= 32'd1000000;
                                32'd1000000:    divisor <= 32'd100000;
                                32'd100000:     divisor <= 32'd10000;
                                32'd10000:      divisor <= 32'd1000;
                                32'd1000:       divisor <= 32'd100;
                                32'd100:        divisor <= 32'd10;
                                32'd10:         divisor <= 32'd1;
                                default:        divisor <= 32'd0;
                            endcase
                            digit_val <= 0;
                            state <= 6'd62;
                        end else begin
                            state <= S_NUM_SIGN;
                        end
                    end
                end

                S_NUM_SIGN: begin
                    num_len <= num_pos; // Total digits
                    num_pos <= 0; // Reset for printing

                    if (num_neg) begin
                        chars_printed <= num_pos + 1;
                        tx_data <= `ASCII_MINUS;
                        tx_start <= 1'b1;
                        return_state <= S_NUM_DIGIT;
                        state <= S_WAIT_TX;
                    end else begin
                        chars_printed <= num_pos;
                        state <= S_NUM_DIGIT;
                    end
                end

                S_NUM_DIGIT: begin
                    tx_data <= num_buf[num_pos];
                    tx_start <= 1'b1;

                    if (num_pos == num_len - 1) begin
                        return_state <= next_state_after_num;
                    end else begin
                        num_pos <= num_pos + 1;
                        return_state <= S_NUM_DIGIT;
                    end
                    state <= S_WAIT_TX;
                end

                6'd61: begin
                    // Unused now
                    state <= S_IDLE;
                end

                // --- ERROR MODE: Print "ERROR" ---
                S_ERROR_E: begin
                    tx_data <= `ASCII_E;  // 'E'
                    tx_start <= 1'b1;
                    return_state <= S_ERROR_R1;
                    state <= S_WAIT_TX;
                end

                S_ERROR_R1: begin
                    tx_data <= `ASCII_R;  // 'R'
                    tx_start <= 1'b1;
                    return_state <= S_ERROR_R2;
                    state <= S_WAIT_TX;
                end

                S_ERROR_R2: begin
                    tx_data <= `ASCII_R;  // 'R'
                    tx_start <= 1'b1;
                    return_state <= S_ERROR_O;
                    state <= S_WAIT_TX;
                end

                S_ERROR_O: begin
                    tx_data <= `ASCII_O;  // 'O'
                    tx_start <= 1'b1;
                    return_state <= S_ERROR_R3;
                    state <= S_WAIT_TX;
                end

                S_ERROR_R3: begin
                    tx_data <= `ASCII_R;  // 'R'
                    tx_start <= 1'b1;
                    return_state <= S_ERROR_DONE;
                    state <= S_WAIT_TX;
                end

                S_ERROR_DONE: begin
                    tx_data <= `ASCII_NEWLINE;  // 换行
                    tx_start <= 1'b1;
                    return_state <= S_IDLE;
                    state <= S_WAIT_TX;
                end

            endcase
        end
    end

endmodule
