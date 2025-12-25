`include "parameters.vh"

module display_ctrl(
    input clk,
    input rst,
    input [3:0] state,
    input [7:0] countdown,
    input [31:0] cycles,
    input [2:0] alu_op,
    input error_led,  // 新增：输入错误LED信号（维度或数据无效时点亮）
    output reg [7:0] seg,
    output reg [3:0] an,
    output reg [7:0] led
);

    reg [1:0] scan_cnt; 
    reg [19:0] refresh_cnt; 

    reg [4:0] digit_0, digit_1, digit_2, digit_3; 
    reg [4:0] current_digit;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            digit_0 <= 5'h0F;
            digit_1 <= 5'h0F;
            digit_2 <= 5'h0F;
            digit_3 <= 5'h0F;
        end
        else begin
            
            digit_3 <= 5'h0F; digit_2 <= 5'h0F; digit_1 <= 5'h0F; digit_0 <= 5'h0F;

            case (state)
                `IDLE: begin
                    digit_3 <= 5'h01;  // I
                    digit_2 <= 5'h0D;  // d
                    digit_1 <= 5'h12;  // L
                    digit_0 <= 5'h0E;  // E
                end

                `INPUT_DIM, `INPUT_DATA, `FILL_ZEROS: begin
                    digit_3 <= 5'h01;  // I
                    digit_2 <= 5'h05;  // n
                    digit_1 <= 5'h10;  // P
                    digit_0 <= 5'h11;  // t
                end

                `COMPUTE: begin
                    // 显示 "CAL" + 操作类型
                    digit_3 <= 5'h0C;  // C
                    digit_2 <= 5'h0A;  // A
                    digit_1 <= 5'h12;  // L
                    // digit_0 根据 alu_op 显示操作类型
                    // 根据图片要求：0=T(CALT), 1=A(CALA), 2=b(CALb), 3=C(CALC), 4=J(CALJ)
                    case (alu_op)
                        3'd0: digit_0 <= 5'h14; // T
                        3'd1: digit_0 <= 5'h0A; // A
                        3'd2: digit_0 <= 5'h0B; // b (小写)
                        3'd3: digit_0 <= 5'h0C; // C
                        3'd4: digit_0 <= 5'h15; // J
                        default: digit_0 <= 5'h0F; // F (无效操作)
                    endcase
                end

                `DISPLAY_MODE: begin
                    
                    digit_3 <= 5'h0D;  // d
                    digit_2 <= 5'h01;  // I
                    digit_1 <= 5'h05;  // n (S 鐨勮繎浼?
                    digit_0 <= 5'h10;  // P
                end

                `GEN_RANDOM: begin
                    
                    digit_3 <= 5'h01;  // I
                    digit_2 <= 5'h05;  // n
                    digit_1 <= 5'h10;  // P
                    digit_0 <= 5'h11;  // t
                end

                `ERROR: begin
                    // ERROR状态显示固定的"Err0"（与输入维度超出范围时相同）
                    // 无论是什么错误（输入维度错误、数据错误、运算维度不匹配），都显示相同的信息
                    digit_3 <= 5'h0E;  // E
                    digit_2 <= 5'h13;  // r
                    digit_1 <= 5'h13;  // r
                    digit_0 <= 5'h00;  // 0（表示错误）
                end

                `BONUS: begin 
                    // 在BONUS状态下显示时钟周期数（cycles）
                    // 提取每个十进制位：digit_3是千位，digit_2是百位，digit_1是十位，digit_0是个位
                    // 限制显示范围为0-9999（4位数字），如果超过则显示9999
                    if (cycles > 32'd9999) begin
                        digit_3 <= 4'd9;
                        digit_2 <= 4'd9;
                        digit_1 <= 4'd9;
                        digit_0 <= 4'd9;
                    end else begin
                        digit_3 <= (cycles / 32'd1000) % 10;
                        digit_2 <= (cycles / 32'd100) % 10;
                        digit_1 <= (cycles / 32'd10) % 10;
                        digit_0 <= cycles % 10;
                    end
                end

                `OUTPUT_RES: begin
                    digit_3 <= 5'h00;  // o
                    digit_2 <= 5'h01;  // U
                    digit_1 <= 5'h11;  // t
                    digit_0 <= 5'h10;  // P
                end


                default: begin
                    digit_3 <= 5'h0F;
                    digit_2 <= 5'h0F;
                    digit_1 <= 5'h0F;
                    digit_0 <= 5'h0F;
                end
            endcase
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            led <= 8'b0;
        end
        else begin
            led <= 8'b0; 
            
            // 错误LED优先级：如果检测到输入错误或处于ERROR状态，点亮led[7]
            if (error_led || (state == `ERROR)) begin
                if (state == `ERROR) 
                    led[7] <= refresh_cnt[19];  // ERROR状态时闪烁
                else
                    led[7] <= 1'b1;  // 输入错误时立即常亮点亮
            end
            // 如果不在错误状态，则根据状态显示对应的LED
            else begin
                case (state)
                    `IDLE:      led[0] <= 1'b1;
                    `INPUT_DIM: led[1] <= 1'b1;
                    `INPUT_DATA:led[2] <= 1'b1;
                    `FILL_ZEROS:led[2] <= 1'b1;
                    `COMPUTE:   led[3] <= 1'b1;
                    `BONUS:     led[4] <= 1'b1;
                    `OUTPUT_RES:led[5] <= 1'b1;
                    `DISPLAY_MODE: led[6] <= 1'b1;
                    `GEN_RANDOM: led[6] <= 1'b1;
                    default:    led <= 8'b0;
                endcase
            end
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            scan_cnt <= 2'd0;
            refresh_cnt <= 20'd0;
        end
        else begin
            refresh_cnt <= refresh_cnt + 1;
            if (refresh_cnt >= 20'd200_000) begin 
                refresh_cnt <= 0;
                scan_cnt <= scan_cnt + 1;
            end
        end
    end

    
    always @(*) begin
        an = 4'b0000;
        current_digit = 5'h00;

        case (scan_cnt)
            2'd0: begin
                an = 4'b0001;
                current_digit = digit_0;
            end
            2'd1: begin
                an = 4'b0010;
                current_digit = digit_1;
            end
            2'd2: begin
                an = 4'b0100;
                current_digit = digit_2;
            end
            2'd3: begin
                an = 4'b1000;
                current_digit = digit_3;
            end
            default: begin
                an = 4'b0000;
                current_digit = 5'h00;
            end
        endcase
    end

    
    always @(*) begin
        case (current_digit)
            5'h00: seg = 8'h3F; 
            5'h01: seg = 8'h06; 
            5'h02: seg = 8'h5B;
            5'h03: seg = 8'h4F;
            5'h04: seg = 8'h66;
            5'h05: seg = 8'h6D;
            5'h06: seg = 8'h7D;
            5'h07: seg = 8'h07;
            5'h08: seg = 8'h7F;
            5'h09: seg = 8'h6F;

            5'h0A: seg = 8'h77; //A
            5'h0B: seg = 8'h7C; //b
            5'h0C: seg = 8'h39; //C
            5'h0D: seg = 8'h5E; //d
            5'h0E: seg = 8'h79; //E
            5'h0F: seg = 8'h71; //F
            5'h10: seg = 8'h73; //P
            5'h11: seg = 8'h78; //t
            5'h12: seg = 8'h38; //L
            5'h13: seg = 8'h50; //r
            5'h14: seg = 8'h78; //T (same as t)
            5'h15: seg = 8'h1E; //J

            default: seg = 8'h00; //default榛樿鍏ㄧ伃
        endcase
    end

endmodule
