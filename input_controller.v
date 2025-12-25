`include "parameters.vh"

module input_controller(
    input clk,
    input rst,
    input [3:0] state, 

    // UART 解码器
    input decoder_valid,
    input [31:0] decoder_data,

    // FSM 控制
    input mem_we_fsm,
    output reg [7:0] input_count,
    input [7:0] total_elems,

    // 错误检测信号
    input dim_invalid,
    input data_invalid,

    
    output reg alloc_req,
    output reg [3:0] alloc_m,
    output reg [3:0] alloc_n,
    input alloc_valid,
    input [6:0] alloc_id_in,

    
    output reg write_en,
    output reg [6:0] write_id,
    output reg [3:0] write_row,
    output reg [3:0] write_col,
    output reg [31:0] write_data,
    output [6:0] current_id_out
);

    reg top_dim_cnt;
    reg [6:0] current_matrix_id;
    assign current_id_out = current_matrix_id;
    reg [3:0] input_row;
    reg [3:0] input_col;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            top_dim_cnt <= 1'b0;
            alloc_m <= 4'd0;
            alloc_n <= 4'd0;
            alloc_req <= 1'b0;
            input_count <= 8'd0;
            input_row <= 4'd0;
            input_col <= 4'd0;
            current_matrix_id <= 7'd0;
        end else begin
            alloc_req <= 1'b0;

            if (state == `IDLE) top_dim_cnt <= 1'b0;

            if (state == `INPUT_DIM && decoder_valid) begin
                if (!top_dim_cnt) begin
                    alloc_m <= decoder_data[3:0];
                    top_dim_cnt <= 1'b1;
                end else begin
                    // 只有在维度有效时才发出分配请求
                    if (!dim_invalid) begin
                        alloc_n <= decoder_data[3:0];
                        alloc_req <= 1'b1;
                    end
                    top_dim_cnt <= 1'b0;
                end
            end

            if (alloc_valid) begin
                current_matrix_id <= alloc_id_in;
            end

            if (state == `IDLE || state == `INPUT_DIM) begin
                input_count <= 8'd0;
                input_row <= 4'd0;
                input_col <= 4'd0;
            end else if ((state == `INPUT_DATA || state == `FILL_ZEROS) && mem_we_fsm) begin
                if (input_count < total_elems) begin
                    input_count <= input_count + 1;

                    if (input_col == alloc_n - 1) begin
                        input_col <= 4'd0;
                        input_row <= input_row + 1;
                    end else begin
                        input_col <= input_col + 1;
                    end
                end
            end
        end
    end

    always @(*) begin
        write_en = 1'b0;
        write_id = current_matrix_id;
        write_row = input_row;
        write_col = input_col;
        write_data = 32'd0;

        // 只有在没有数据错误时才写入
        if (state == `INPUT_DATA && mem_we_fsm && input_count < total_elems && !data_invalid) begin
            write_data = decoder_data;
            write_en = 1'b1;
        end else if (state == `FILL_ZEROS && mem_we_fsm && input_count < total_elems) begin
            write_data = 32'd0;
            write_en = 1'b1;
        end
    end

endmodule
