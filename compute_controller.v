`include "parameters.vh"

module compute_controller(
    input clk,
    input rst,
    input [3:0] state, 

    
    input [7:0] sw,
    input [3:0] btn,

    // UART 瑙ｇ爜鍣?
    input decoder_valid,
    input [31:0] decoder_data,

    // ALU 鎺ュ彛
    input alu_done,
    output reg alu_start,
    output reg [2:0] alu_op,
    output reg signed [31:0] scalar_val,

    
    output reg [6:0] id_a,
    output reg [6:0] id_b,

    
    output reg print_req,
    output reg [3:0] print_mode,

    // --- 鏂板锛氱敤浜庣淮搴︽鏌?---
    input [3:0] dim_a_m,
    input [3:0] dim_a_n,
    input [3:0] dim_b_m,
    input [3:0] dim_b_n,
    output reg error_flag, 

    
    input [4:0] valid_mask,
    input [31:0] random_val,
    output reg [3:0] query_dim_m,
    output reg [3:0] query_dim_n,

    
    output reg request_bonus
);

    localparam C_IDLE = 4'd0;
    localparam C_SELECT_OP = 4'd1;
    localparam C_SEL_ID_A = 4'd14;
    localparam C_SEL_ID_B = 4'd15;
    localparam C_EXEC = 4'd2;

    localparam C_GET_M_A = 4'd3;
    localparam C_GET_N_A = 4'd4;
    localparam C_LIST_A = 4'd5;
    localparam C_SELECT_A = 4'd6;

    // Operand B Flow
    localparam C_GET_M_B = 4'd7;
    localparam C_GET_N_B = 4'd8;
    localparam C_LIST_B = 4'd9;
    localparam C_SELECT_B = 4'd10;

    localparam C_INPUT_SCALAR = 4'd11;
    localparam C_CHECK_DIMS = 4'd12;
    localparam C_CALC = 4'd13;

    reg [3:0] c_state;
    reg [6:0] base_id;
    reg [2:0] rand_slot;
    reg print_req_keep;  // 用于保持print_req信号，直到被确认
    reg error_flag_keep; // 用于保持error_flag信号，确保FSM能够检测到

    function [2:0] find_valid_slot;
        input [2:0] start_slot;
        input [4:0] mask;
        begin
            if (mask[start_slot]) find_valid_slot = start_slot;
            else if (mask[(start_slot+1)%5]) find_valid_slot = (start_slot+1)%5;
            else if (mask[(start_slot+2)%5]) find_valid_slot = (start_slot+2)%5;
            else if (mask[(start_slot+3)%5]) find_valid_slot = (start_slot+3)%5;
            else if (mask[(start_slot+4)%5]) find_valid_slot = (start_slot+4)%5;
            else find_valid_slot = 3'd0;
        end
    endfunction

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            c_state <= C_IDLE;
            alu_op <= 3'd0;
            id_a <= 7'd0;
            id_b <= 7'd0;
            alu_start <= 1'b0;
            print_req <= 1'b0;
            print_mode <= 4'd0;
            scalar_val <= 32'd0;
            error_flag <= 1'b0;
            query_dim_m <= 4'd0;
            query_dim_n <= 4'd0;
            print_req_keep <= 1'b0;
            error_flag_keep <= 1'b0;
        end else begin
            alu_start <= 1'b0;      
            request_bonus <= 1'b0;  
            
            // print_req的清除逻辑：只有当print_req_keep为0时才清除
            // print_req_keep会在设置print_req时被设置为1，然后在下一个周期清除
            if (!print_req_keep) begin
                print_req <= 1'b0;
            end else begin
                print_req_keep <= 1'b0;  // 下一个周期清除保持标志
            end
            
            // error_flag的清除逻辑：只有当error_flag_keep为0时才清除
            // error_flag_keep会在设置error_flag时被设置为1，然后在下一个周期清除
            if (!error_flag_keep) begin
                error_flag <= 1'b0;
            end else begin
                error_flag_keep <= 1'b0;  // 下一个周期清除保持标志
            end
            
            // error_flag_keep和c_state的清除逻辑
            if (state != 4'd3) begin // state != COMPUTE
                error_flag_keep <= 1'b0;  // 不在COMPUTE状态时清除
                c_state <= C_IDLE;
                print_req_keep <= 1'b0;  // 不在COMPUTE状态时也清除
            end else begin
                case (c_state)
                    C_IDLE: begin
                        c_state <= C_SELECT_OP;
                    end

                    C_SELECT_OP: begin
                        // 方式一：通过 UART 输入一个数字(0~3)选择运算
                        if (decoder_valid) begin
                            if (decoder_data >= 0 && decoder_data <= 3) begin
                                alu_op <= decoder_data[2:0];
                                c_state <= C_SEL_ID_A;
                            end else begin
                                error_flag <= 1'b1;
                                error_flag_keep <= 1'b1;  // 保持error_flag信号
                                c_state <= C_IDLE;
                            end
                        end
                        // 方式二：通过板上开关+确认键选择运算
                        else if (btn[0]) begin
                            // sw[2:0] = 0~3: T / Add / Scalar / Mul
                            if (sw[2:0] <= 3'd3) begin
                                alu_op <= sw[2:0];
                                c_state <= C_SEL_ID_A;
                            end else begin
                                error_flag <= 1'b1;
                                error_flag_keep <= 1'b1;  // 保持error_flag信号
                                c_state <= C_IDLE;
                            end
                        end
                    end

                    
                    C_SEL_ID_A: begin
                        if (decoder_valid) begin
                            if (decoder_data >= 1 && decoder_data <= 12) begin
                                id_a <= decoder_data[6:0] - 1;  
                                
                                if (alu_op == 3'd0) begin
                                    c_state <= C_EXEC;
                                end else if (alu_op == 3'd2) begin
                                    c_state <= C_INPUT_SCALAR;
                                end else begin
                                    
                                    c_state <= C_SEL_ID_B;
                                end
                            end else begin
                                error_flag <= 1'b1;
                                error_flag_keep <= 1'b1;  // 保持error_flag信号
                                c_state <= C_IDLE;
                            end
                        end
                    end

                    
                    C_SEL_ID_B: begin
                        if (decoder_valid) begin
                            if (decoder_data >= 1 && decoder_data <= 12) begin
                                id_b <= decoder_data[6:0] - 1;  
                                // 选择矩阵B后，进入维度检查状态
                                c_state <= C_CHECK_DIMS;
                            end else begin
                                error_flag <= 1'b1;
                                error_flag_keep <= 1'b1;  // 保持error_flag信号
                                c_state <= C_IDLE;
                            end
                        end
                    end

                    // --- Operand A ---
                    C_GET_M_A: begin
                        if (decoder_valid) begin
                            query_dim_m <= decoder_data[3:0];
                            c_state <= C_GET_N_A;
                        end
                    end
                    C_GET_N_A: begin
                        if (decoder_valid) begin
                            query_dim_n <= decoder_data[3:0];
                            c_state <= C_LIST_A;
                        end
                    end
                    C_LIST_A: begin
                        // Trigger print of matrices with query_dim_m/n
                        id_a <= (query_dim_m - 1) * 5 + (query_dim_n - 1); // Pass size_idx via id_a
                        print_req <= 1'b1;
                        print_mode <= 4'd5; // MODE_LIST_DIM
                        c_state <= C_SELECT_A;
                    end
                    C_SELECT_A: begin
                        base_id = ((query_dim_m - 1) * 5 + (query_dim_n - 1)) * 5;

                        if (sw[7]) begin // Auto Mode
                            if (valid_mask == 0) begin
                                error_flag <= 1'b1; // No matrices available
                                error_flag_keep <= 1'b1;  // 保持error_flag信号
                            end else begin
                                // Pick random
                                rand_slot = find_valid_slot(random_val[2:0] % 5, valid_mask);
                                id_a <= base_id + rand_slot;
                                // Proceed
                                if (alu_op == 3'd0) c_state <= C_CALC;
                                else if (alu_op == 3'd2) c_state <= C_INPUT_SCALAR;
                                else c_state <= C_GET_M_B;
                            end
                        end else if (decoder_valid) begin // Manual Mode
                            id_a <= decoder_data[6:0];
                            if (alu_op == 3'd0) c_state <= C_CALC;
                            else if (alu_op == 3'd2) c_state <= C_INPUT_SCALAR;
                            else c_state <= C_GET_M_B;
                        end
                    end

                    // --- Operand B ---
                    C_GET_M_B: begin
                        if (decoder_valid) begin
                            query_dim_m <= decoder_data[3:0];
                            c_state <= C_GET_N_B;
                        end
                    end
                    C_GET_N_B: begin
                        if (decoder_valid) begin
                            query_dim_n <= decoder_data[3:0];
                            c_state <= C_LIST_B;
                        end
                    end
                    C_LIST_B: begin
                        id_a <= (query_dim_m - 1) * 5 + (query_dim_n - 1); // Pass size_idx via id_a
                        print_req <= 1'b1;
                        print_mode <= 4'd5;
                        c_state <= C_SELECT_B;
                    end
                    C_SELECT_B: begin
                        base_id = ((query_dim_m - 1) * 5 + (query_dim_n - 1)) * 5;

                        if (sw[7]) begin // Auto
                            if (valid_mask == 0) begin
                                error_flag <= 1'b1;
                                error_flag_keep <= 1'b1;  // 保持error_flag信号
                            end else begin
                                rand_slot = find_valid_slot(random_val[2:0] % 5, valid_mask);
                                id_b <= base_id + rand_slot;
                                c_state <= C_CHECK_DIMS;
                            end
                        end else if (decoder_valid) begin
                            id_b <= decoder_data[6:0];
                            c_state <= C_CHECK_DIMS;
                        end
                    end

                    C_CHECK_DIMS: begin
                        // 维度检查：根据操作类型检查维度是否匹配
                        if (alu_op == 3'd1) begin // Add: 要求两个矩阵维度完全相同
                            if (dim_a_m == dim_b_m && dim_a_n == dim_b_n) begin
                                c_state <= C_CALC;  // 维度匹配，继续计算
                            end else begin
                                error_flag <= 1'b1;  // 维度不匹配，报错
                                error_flag_keep <= 1'b1;  // 保持error_flag信号，确保FSM能够检测到
                                print_req <= 1'b1;   // 触发UART打印ERROR
                                print_req_keep <= 1'b1;  // 保持print_req信号
                                print_mode <= 4'd6;  // MODE_ERROR
                                c_state <= C_IDLE;   // 返回IDLE状态，等待FSM检测错误
                            end
                        end else if (alu_op == 3'd3) begin // Mul: 要求A的列数等于B的行数
                            if (dim_a_n == dim_b_m) begin
                                c_state <= C_CALC;  // 维度匹配，继续计算
                            end else begin
                                error_flag <= 1'b1;  // 维度不匹配，报错
                                error_flag_keep <= 1'b1;  // 保持error_flag信号，确保FSM能够检测到
                                print_req <= 1'b1;   // 触发UART打印ERROR
                                print_req_keep <= 1'b1;  // 保持print_req信号
                                print_mode <= 4'd6;  // MODE_ERROR
                                c_state <= C_IDLE;   // 返回IDLE状态，等待FSM检测错误
                            end
                        end else begin
                            // 其他操作（转置、标量乘）不需要检查第二个矩阵的维度
                            c_state <= C_CALC;
                        end
                    end

                    C_INPUT_SCALAR: begin
                        if (decoder_valid) begin
                            
                            scalar_val <= decoder_data;
                            c_state <= C_EXEC;
                        end
                    end

                    
                    C_EXEC: begin
                        alu_start <= 1'b1;
                        c_state <= C_CALC;
                    end

                    C_CALC: begin
                        alu_start <= 1'b1;  
                        if (alu_done) begin
                            alu_start <= 1'b0;  
                            print_req <= 1'b1;
                            print_mode <= 4'd3;  
                            c_state <= C_IDLE;
                        end
                    end

                    default: c_state <= C_IDLE;
                endcase
            end
        end
    end

endmodule
