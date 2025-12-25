`include "parameters.vh"

module rng_lfsr(
    input clk,
    input rst,
    input start_enable, 

    // UART 瑙ｇ爜鎺ュ彛 (鐢ㄤ簬鎺ユ敹 m, n, count)
    input decoder_valid,
    input [31:0] decoder_data,

    
    output reg alloc_req,
    output reg [3:0] alloc_m,
    output reg [3:0] alloc_n,
    input alloc_valid,
    input [6:0] alloc_id_in,

    
    output reg mem_we,
    output reg [6:0] mem_id,
    output reg [3:0] mem_row,
    output reg [3:0] mem_col,
    output reg [31:0] mem_data,
    output [31:0] random_out 
);

    
    // 1. LFSR 鏍稿績閫昏緫
    
    reg [31:0] lfsr_state;
    assign random_out = lfsr_state;
    wire lfsr_feedback = lfsr_state[31] ^ lfsr_state[21] ^ lfsr_state[2] ^ lfsr_state[1];

    
    wire [3:0] raw_nibble = lfsr_state[3:0];
    wire [3:0] mapped_digit = (raw_nibble >= 4'd10) ? (raw_nibble - 4'd10) : raw_nibble;

    
    // 2. 鐘舵€佹満閫昏緫
    
    localparam S_IDLE       = 4'd0;
    localparam S_GET_M      = 4'd1;
    localparam S_GET_N      = 4'd2;
    localparam S_GET_CNT    = 4'd3;
    localparam S_ALLOC_REQ  = 4'd4;
    localparam S_ALLOC_WAIT = 4'd5;
    localparam S_GEN_LOOP   = 4'd6;
    localparam S_DONE       = 4'd7;

    reg [3:0] state;
    reg [3:0] param_m, param_n, param_cnt;
    reg [3:0] current_mat_idx;
    reg [7:0] current_elem_cnt;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            lfsr_state <= 32'h89ABCDEF; 
            state <= S_IDLE;
            alloc_req <= 1'b0;
            mem_we <= 1'b0;
            alloc_m <= 4'd0; alloc_n <= 4'd0;
            mem_id <= 7'd0; mem_row <= 4'd0; mem_col <= 4'd0; mem_data <= 32'd0;
            param_m <= 4'd0; param_n <= 4'd0; param_cnt <= 4'd0;
            current_mat_idx <= 4'd0; current_elem_cnt <= 8'd0;
        end else begin
            
            alloc_req <= 1'b0;
            mem_we <= 1'b0;

            
            if (!start_enable) begin
                state <= S_IDLE;
            end else begin
                case (state)
                    S_IDLE: begin
                        
                        state <= S_GET_M;
                        current_mat_idx <= 4'd0;
                    end

                    S_GET_M: begin
                        if (decoder_valid) begin
                            param_m <= decoder_data[3:0];
                            state <= S_GET_N;
                        end
                    end

                    S_GET_N: begin
                        if (decoder_valid) begin
                            param_n <= decoder_data[3:0];
                            state <= S_GET_CNT;
                        end
                    end

                    S_GET_CNT: begin
                        if (decoder_valid) begin
                            
                            param_cnt <= (decoder_data > 32'd2) ? 4'd2 : decoder_data[3:0];
                            state <= S_ALLOC_REQ;
                        end
                    end

                    S_ALLOC_REQ: begin
                        alloc_req <= 1'b1;
                        alloc_m <= param_m;
                        alloc_n <= param_n;
                        state <= S_ALLOC_WAIT;
                    end

                    S_ALLOC_WAIT: begin
                        if (alloc_valid) begin
                            mem_id <= alloc_id_in;
                            current_elem_cnt <= 8'd0;
                            mem_row <= 4'd0;
                            mem_col <= 4'd0;
                            // 在进入生成循环前先步进一次LFSR，确保第一个随机数可用
                            lfsr_state <= {lfsr_state[30:0], lfsr_feedback};
                            state <= S_GEN_LOOP;
                        end
                    end

                    S_GEN_LOOP: begin
                        // 1. 步进 LFSR（为下一个周期产生随机数）
                        lfsr_state <= {lfsr_state[30:0], lfsr_feedback};

                        // 2. 写入当前随机数（使用当前LFSR状态，已在上一周期或S_ALLOC_WAIT中步进）
                        mem_we <= 1'b1;
                        mem_data <= {28'd0, mapped_digit};

                        // 3. 鏇存柊绱㈠紩
                        if (current_elem_cnt == (param_m * param_n) - 1) begin
                            
                            if (current_mat_idx == param_cnt - 1) begin
                                state <= S_DONE; 
                            end else begin
                                current_mat_idx <= current_mat_idx + 1;
                                state <= S_ALLOC_REQ; 
                            end
                        end else begin
                            current_elem_cnt <= current_elem_cnt + 1;
                            if (mem_col == param_n - 1) begin
                                mem_col <= 4'd0;
                                mem_row <= mem_row + 1;
                            end else begin
                                mem_col <= mem_col + 1;
                            end
                        end
                    end

                    S_DONE: begin
                        
                    end
                endcase
            end
        end
    end

endmodule
