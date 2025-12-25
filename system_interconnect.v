`include "parameters.vh"

module system_interconnect(
    input [3:0] state,

    // 1. 输入控制器接�?
    input input_alloc_req,
    input [3:0] input_alloc_m,
    input [3:0] input_alloc_n,
    input input_write_en,
    input [6:0] input_write_id,
    input [3:0] input_write_row,
    input [3:0] input_write_col,
    input [31:0] input_write_data,
    input [6:0] current_matrix_id, 

    // 2. 随机数生成器接口
    input rng_alloc_req,
    input [3:0] rng_alloc_m,
    input [3:0] rng_alloc_n,
    input rng_mem_we,
    input [6:0] rng_mem_id,
    input [3:0] rng_mem_row,
    input [3:0] rng_mem_col,
    input [31:0] rng_mem_data,

    // 3. ALU 接口（写回和读地坢��?
    input result_we,
    input [3:0] alu_row_write,
    input [3:0] alu_col_write,
    input [31:0] alu_result,
    input [3:0] alu_row_read_a,
    input [3:0] alu_col_read_a,

    
    input [6:0] compute_id_a,
    input [6:0] compute_id_b,
    input compute_print_req,
    input [3:0] compute_print_mode,

    input bonus_print_req,

    input [6:0] printer_id,
    input [3:0] printer_row,
    input [3:0] printer_col,
    input printer_active,

    input display_print_req,

    
    output reg [6:0] mem_id_w,
    output reg [3:0] mem_row_w,
    output reg [3:0] mem_col_w,
    output reg [31:0] mem_data_w,
    output reg mem_we,

    output reg mem_alloc_req,
    output reg [3:0] mem_alloc_m,
    output reg [3:0] mem_alloc_n,

    output [6:0] mem_id_a,
    output [3:0] mem_row_a,
    output [3:0] mem_col_a,

    output [6:0] mem_id_b,

    
    output reg final_print_req,
    output reg [3:0] final_print_mode,
    output reg [6:0] final_print_target_id
);

    
    // ============================================================================
    // 存储器分配请求仲裁：根据系统状态选择分配来源
    // - GEN_RANDOM状态：使用随机数生成器的分配请求
    // - 其他状态：使用输入控制器的分配请求
    // ============================================================================
    always @(*) begin
        if (state == `GEN_RANDOM) begin
            mem_alloc_req = rng_alloc_req;
            mem_alloc_m = rng_alloc_m;
            mem_alloc_n = rng_alloc_n;
        end else begin
            mem_alloc_req = input_alloc_req;
            mem_alloc_m = input_alloc_m;
            mem_alloc_n = input_alloc_n;
        end
    end

    
    // ============================================================================
    // 存储器写入仲裁：根据优先级选择写入数据来源
    // 优先级：输入控制器 > 随机数生成器 > ALU结果
    // 确保只有一个模块同时写入，避免数据冲突
    // ============================================================================
    always @(*) begin
        mem_id_w = 7'd0;
        mem_row_w = 4'd0;
        mem_col_w = 4'd0;
        mem_data_w = 32'd0;
        mem_we = 1'b0;

        if (input_write_en) begin
            mem_id_w = input_write_id;
            mem_row_w = input_write_row;
            mem_col_w = input_write_col;
            mem_data_w = input_write_data;
            mem_we = 1'b1;
        end else if (rng_mem_we) begin
            mem_id_w = rng_mem_id;
            mem_row_w = rng_mem_row;
            mem_col_w = rng_mem_col;
            mem_data_w = rng_mem_data;
            mem_we = 1'b1;
        end else if (result_we) begin
            mem_id_w = 7'd11;
            mem_row_w = alu_row_write;
            mem_col_w = alu_col_write;
            mem_data_w = alu_result;
            mem_we = 1'b1;
        end
    end

    
    // ============================================================================
    // 打印请求仲裁：根据不同模块的打印请求选择最终输出
    // - 计算控制器：根据模式选择矩阵ID (A/B/结果)
    // - Bonus控制器：固定模式4，ID=0
    // - 显示模块：模式0，ID=0（统计信息）
    // 确保只有一个打印请求生效
    // ============================================================================
    always @(*) begin
        final_print_req = 1'b0;
        final_print_mode = 4'd0;
        final_print_target_id = 7'd0;

        if (compute_print_req) begin
            final_print_req = 1'b1;
            final_print_mode = compute_print_mode;
            case (compute_print_mode)
                4'd1: final_print_target_id = compute_id_a;
                4'd2: final_print_target_id = compute_id_b;
                4'd3: final_print_target_id = 7'd11;
                4'd5: final_print_target_id = compute_id_a;
                default: final_print_target_id = 7'd0;
            endcase
        end else if (bonus_print_req) begin
            final_print_req = 1'b1;
            final_print_mode = 4'd4;
            final_print_target_id = 7'd0;
        end else if (display_print_req) begin
            final_print_req = 1'b1;
            final_print_mode = 4'd0;
            final_print_target_id = 7'd0;
        end
    end

    
    // ============================================================================
    // 存储器读取端口A地址选择：根据状态和打印活动动态选择
    // - 打印机活动或DISPLAY_MODE：使用打印机地址
    // - COMPUTE状态：使用ALU读取地址
    // - 其他：使用当前矩阵ID
    // ============================================================================
    assign mem_id_a = (printer_active || state == `DISPLAY_MODE) ? printer_id : 
                      (state == `COMPUTE) ? compute_id_a :
                      current_matrix_id;

    assign mem_row_a = (printer_active || state == `DISPLAY_MODE) ? printer_row :
                       (state == `COMPUTE) ? alu_row_read_a :
                       4'd0;

    assign mem_col_a = (printer_active || state == `DISPLAY_MODE) ? printer_col :
                       (state == `COMPUTE) ? alu_col_read_a :
                       4'd0;

    assign mem_id_b = compute_id_b;

endmodule
