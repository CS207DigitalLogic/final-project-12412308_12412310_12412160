`include "parameters.vh"





// 0: 转置
// 1: 加法
// 2: 标量乘法 (A * scalar_k)
// 3: 矩阵乘法 (A(m*n) * B(n*p) => C(m*p))
module matrix_alu(
    input clk,
    input rst,

    input [31:0] data_a,
    input [31:0] data_b,

    input [2:0] op,
    input start,
    input [3:0] dim_m,
    input [3:0] dim_n,
    input [3:0] dim_p,
    input signed [31:0] scalar_k,

    output reg [31:0] result,
    output reg overflow,
    output reg done,

    output reg [3:0] row_read_a,
    output reg [3:0] col_read_a,
    output reg [3:0] row_read_b,
    output reg [3:0] col_read_b,

    output reg [3:0] row_write,
    output reg [3:0] col_write,
    output reg result_we
);

    localparam S_IDLE = 2'd0;
    localparam S_ADDR = 2'd1;
    localparam S_EXEC = 2'd2;
    localparam S_DONE = 2'd3;

    reg [1:0] state;
    reg [2:0] op_r;

    reg [3:0] i;
    reg [3:0] j;
    reg [3:0] k;
    reg signed [63:0] acc;

    wire signed [63:0] mul_prod;
    wire signed [63:0] acc_plus;
    assign mul_prod = $signed(data_a) * $signed(data_b);
    assign acc_plus = acc + mul_prod;

    wire signed [63:0] scalar_prod;
    assign scalar_prod = $signed(data_a) * $signed(scalar_k);

    wire dims_ok;
    assign dims_ok = (dim_m <= `MAX_ROWS) && (dim_n <= `MAX_COLS) && (dim_m > 0) && (dim_n > 0);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= S_IDLE;
            op_r <= 3'd0;
            done <= 1'b0;
            overflow <= 1'b0;
            result <= 32'd0;
            result_we <= 1'b0;

            row_read_a <= 4'd0;
            col_read_a <= 4'd0;
            row_read_b <= 4'd0;
            col_read_b <= 4'd0;
            row_write <= 4'd0;
            col_write <= 4'd0;

            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            acc <= 64'sd0;
        end else begin
            result_we <= 1'b0;
            overflow <= 1'b0;

            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        op_r <= op;
                        i <= 4'd0;
                        j <= 4'd0;
                        k <= 4'd0;
                        acc <= 64'sd0;
                        state <= S_ADDR;
                    end
                end

                S_ADDR: begin
                    
                    if (!dims_ok || dim_m == 0 || dim_n == 0 || ((op_r == 3'd3) && (dim_p == 0))) begin
                        state <= S_DONE;
                    end else begin
                        
                        if (op_r == 3'd3) begin
                            
                            row_read_a <= i;
                            col_read_a <= k;
                            row_read_b <= k;
                            col_read_b <= j;
                        end else begin
                            
                            row_read_a <= i;
                            col_read_a <= j;
                            row_read_b <= i;
                            col_read_b <= j;
                        end
                        state <= S_EXEC;
                    end
                end

                S_EXEC: begin
                    if (op_r == 3'd1) begin
                        
                        result <= data_a + data_b;
                        row_write <= i;
                        col_write <= j;
                        result_we <= 1'b1;

                        if (j + 1 < dim_n) begin
                            j <= j + 1;
                            state <= S_ADDR;
                        end else if (i + 1 < dim_m) begin
                            j <= 0;
                            i <= i + 1;
                            state <= S_ADDR;
                        end else begin
                            state <= S_DONE;
                        end
                    end else if (op_r == 3'd0) begin
                        
                        result <= data_a;
                        row_write <= j;
                        col_write <= i;
                        result_we <= 1'b1;

                        if (j + 1 < dim_n) begin
                            j <= j + 1;
                            state <= S_ADDR;
                        end else if (i + 1 < dim_m) begin
                            j <= 0;
                            i <= i + 1;
                            state <= S_ADDR;
                        end else begin
                            state <= S_DONE;
                        end
                    end else if (op_r == 3'd2) begin
                        
                        result <= scalar_prod[31:0];
                        row_write <= i;
                        col_write <= j;
                        result_we <= 1'b1;

                        if (j + 1 < dim_n) begin
                            j <= j + 1;
                            state <= S_ADDR;
                        end else if (i + 1 < dim_m) begin
                            j <= 0;
                            i <= i + 1;
                            state <= S_ADDR;
                        end else begin
                            state <= S_DONE;
                        end
                    end else begin
                        
                        acc <= acc_plus;

                        if (k + 1 < dim_n) begin
                            k <= k + 1;
                            state <= S_ADDR;
                        end else begin
                            
                            result <= acc_plus; 
                            row_write <= i;
                            col_write <= j;
                            result_we <= 1'b1;

                            acc <= 64'sd0;
                            k <= 4'd0;

                            if (j + 1 < dim_p) begin
                                j <= j + 1;
                                state <= S_ADDR;
                            end else if (i + 1 < dim_m) begin
                                j <= 0;
                                i <= i + 1;
                                state <= S_ADDR;
                            end else begin
                                state <= S_DONE;
                            end
                        end
                    end
                end

                S_DONE: begin
                    done <= 1'b1;
                    if (!start) begin
                        done <= 1'b0;
                        state <= S_IDLE;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
