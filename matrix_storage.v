`include "parameters.vh"



module matrix_storage(
    input clk,
    input rst,

    // === 璇荤鍙 ===
    input [6:0] id_a,
    input [3:0] row_a,
    input [3:0] col_a,
    output reg [31:0] data_out_a,
    output reg [3:0] current_m,
    output reg [3:0] current_n,

    // === 璇荤鍙 ===
    input [6:0] id_b,
    input [3:0] row_b,
    input [3:0] col_b,
    output reg [31:0] data_out_b,
    output reg [3:0] current_m_b,
    output reg [3:0] current_n_b,

    // === 鍐欑鍙?===
    input [6:0] id_w,
    input [3:0] row_w,
    input [3:0] col_w,
    input [31:0] data_in,
    input write_en,

    // === 缁村害绠＄悊 ===
    input [6:0] dim_write_id,
    input [3:0] dim_write_m,
    input [3:0] dim_write_n,
    input dim_we,

    input [6:0] dim_read_id,
    input [6:0] dim_read_id_b,

    // === 鍒嗛厤鎺ュ彛 ===
    input alloc_req,
    input [3:0] alloc_m,
    input [3:0] alloc_n,
    output reg alloc_valid,
    output reg [6:0] alloc_id,

    // === 缁熻鏌ヨ ===
    input [4:0] size_idx_q,
    output reg [2:0] size_count_q,
    output reg [4:0] size_valid_mask_q,
    output reg [7:0] total_count,

    // === 閰嶇疆 ===
    input [2:0] cfg_x  
);

    // ========== 瀛樺偍缁撴瀯 ==========
    localparam MAX_MATRICES = 12;    
    localparam MAX_SIZE = 5;         

    
    reg [31:0] matrix_data [0:MAX_MATRICES-1][0:MAX_SIZE-1][0:MAX_SIZE-1];

    
    reg [3:0] matrix_m [0:MAX_MATRICES-1];
    reg [3:0] matrix_n [0:MAX_MATRICES-1];
    reg matrix_valid [0:MAX_MATRICES-1];  

    
    reg [3:0] next_alloc_id;
    
    integer i, j, k;
    // 统计查询用到的中间变量（必须在模块顶层声明，综合不允许在过程块内声明）
    integer count;
    integer mask_idx;
    reg [3:0] query_m, query_n;

    // ========== 澶嶄綅鍜屽垵濮嬪寲 ==========
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            next_alloc_id <= 0;
            total_count <= 0;
            alloc_valid <= 0;
            alloc_id <= 0;

            for (i = 0; i < MAX_MATRICES; i = i + 1) begin
                matrix_valid[i] <= 0;
                matrix_m[i] <= 0;
                matrix_n[i] <= 0;
                for (j = 0; j < MAX_SIZE; j = j + 1) begin
                    for (k = 0; k < MAX_SIZE; k = k + 1) begin
                        matrix_data[i][j][k] <= 0;
                    end
                end
            end
        end else begin
            alloc_valid <= 0;  

            // ========== 鍐欏叆鏁版嵁 ==========
            if (write_en && id_w < MAX_MATRICES) begin
                if (row_w < MAX_SIZE && col_w < MAX_SIZE) begin
                    matrix_data[id_w][row_w][col_w] <= data_in;
                end
            end

            // ========== 鍐欏叆缁村害 ==========
            if (dim_we && dim_write_id < MAX_MATRICES) begin
                matrix_m[dim_write_id] <= dim_write_m;
                matrix_n[dim_write_id] <= dim_write_n;
                if (!matrix_valid[dim_write_id]) begin
                    matrix_valid[dim_write_id] <= 1;
                    total_count <= total_count + 1;
                end
            end

            // ========== 鍒嗛厤鏂扮煩闃礗D ==========
            if (alloc_req) begin
                
                alloc_id <= next_alloc_id;
                alloc_valid <= 1;

                
                

                
                if (next_alloc_id >= MAX_MATRICES - 1)
                    next_alloc_id <= 0;
                else
                    next_alloc_id <= next_alloc_id + 1;
            end
        end
    end

    // ========== 璇荤鍙 (缁勫悎閫昏緫) ==========
    always @(*) begin
        if (id_a < MAX_MATRICES && matrix_valid[id_a]) begin
            if (row_a < MAX_SIZE && col_a < MAX_SIZE) begin
                data_out_a = matrix_data[id_a][row_a][col_a];
            end else begin
                data_out_a = 0;
            end
            current_m = matrix_m[id_a];
            current_n = matrix_n[id_a];
        end else begin
            data_out_a = 0;
            current_m = 0;
            current_n = 0;
        end
    end

    // ========== 璇荤鍙 (缁勫悎閫昏緫) ==========
    always @(*) begin
        if (id_b < MAX_MATRICES && matrix_valid[id_b]) begin
            if (row_b < MAX_SIZE && col_b < MAX_SIZE) begin
                data_out_b = matrix_data[id_b][row_b][col_b];
            end else begin
                data_out_b = 0;
            end
            current_m_b = matrix_m[id_b];
            current_n_b = matrix_n[id_b];
        end else begin
            data_out_b = 0;
            current_m_b = 0;
            current_n_b = 0;
        end
    end

    // ========== 灏哄缁熻鏌ヨ ==========
    // 使用 combinational 逻辑统计每种规格矩阵的数量和 valid mask
    always @(*) begin

        // size_idx = (m-1)*5 + (n-1)
        query_m = (size_idx_q / 5) + 1;
        query_n = (size_idx_q % 5) + 1;

        count = 0;
        size_valid_mask_q = 0;

        for (mask_idx = 0; mask_idx < MAX_MATRICES; mask_idx = mask_idx + 1) begin
            if (matrix_valid[mask_idx] && 
                matrix_m[mask_idx] == query_m && 
                matrix_n[mask_idx] == query_n) begin
                if (count < 5) begin
                    size_valid_mask_q[count] = 1;
                end
                count = count + 1;
            end
        end

        size_count_q = (count > 7) ? 7 : count[2:0];
    end

endmodule