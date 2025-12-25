`include "parameters.vh"

module input_decoder(
    input clk,
    input rst,
    input [7:0] uart_data,
    input uart_done,
    output reg [31:0] decoded_int,
    output reg is_space,
    output reg is_newline,
    output reg is_dimension,
    output reg is_data
);
    localparam WAIT_CHAR   = 2'd0;
    localparam DECODE_NUM  = 2'd1;
    localparam DECODE_SIGN = 2'd2;

    reg [1:0] state;
    reg [3:0] digit_cnt;
    reg negative_flag;
    reg [31:0] temp_val;

    wire is_digit;
    wire is_sign;
    wire is_whiteSpace;
    wire is_end;
    wire [3:0] ascii_val;

    assign is_digit = (uart_data >= `ASCII_0) && (uart_data <= `ASCII_9);
    assign is_sign = (uart_data == `ASCII_MINUS);

    
    assign is_whiteSpace = (uart_data == `ASCII_SPACE); 

    
    assign is_end = (uart_data == `ASCII_NEWLINE) || (uart_data == `ASCII_CR);

    assign ascii_val = uart_data - `ASCII_0;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= WAIT_CHAR;
            decoded_int <= 32'd0;
            is_space <= 1'b0;
            is_newline <= 1'b0; 
            is_dimension <= 1'b0;
            is_data <= 1'b0;
            digit_cnt <= 4'd0;
            negative_flag <= 1'b0;
            temp_val <= 32'd0;
        end
        else begin
            
            is_space <= 1'b0;
            is_newline <= 1'b0; 
            is_dimension <= 1'b0;
            is_data <= 1'b0;

            if (uart_done) begin
                case (state)
                    WAIT_CHAR: begin
                        if (is_whiteSpace) begin
                            is_space <= 1'b1;
                        end 
                        else if (is_end) begin
                            is_newline <= 1'b1; 
                        end 
                        else if (is_sign) begin
                            state <= DECODE_SIGN;
                            negative_flag <= 1'b1;
                            temp_val <= 32'd0;
                            digit_cnt <= 4'd0;
                        end 
                        else if (is_digit) begin
                            state <= DECODE_NUM;
                            negative_flag <= 1'b0;
                            temp_val <= ascii_val;
                            digit_cnt <= 4'd1;
                        end
                    end

                    DECODE_SIGN: begin
                        if (is_digit) begin
                            state <= DECODE_NUM;
                            temp_val <= ascii_val;
                            digit_cnt <= 4'd1;
                        end else begin
                            state <= WAIT_CHAR;
                            negative_flag <= 1'b0;
                        end
                    end

                    DECODE_NUM: begin
                        if (is_digit) begin
                            temp_val <= temp_val * 10 + ascii_val;
                            digit_cnt <= digit_cnt + 4'd1;
                            if (digit_cnt >= 4'd5) begin
                                state <= WAIT_CHAR;
                                decoded_int <= (negative_flag) ? -temp_val : temp_val;
                                is_data <= 1'b1;
                            end
                        end
                        else begin
                            
                            state <= WAIT_CHAR;
                            decoded_int <= (negative_flag) ? -temp_val : temp_val;
                            is_data <= 1'b1; 

                            
                            if (is_whiteSpace) begin
                                is_space <= 1'b1;
                            end
                            else if (is_end) begin
                                is_newline <= 1'b1; 
                                
                                // FSM 会先写入数据，再根据 newline 跳转
                            end
                        end
                    end
                    default: state <= WAIT_CHAR;
                endcase
            end
        end
    end
endmodule
