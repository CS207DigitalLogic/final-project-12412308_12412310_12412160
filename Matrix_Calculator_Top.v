/**
 * 矩阵计算器顶层模块
 * 
 * 功能概述：
 * 这是一个完整的矩阵计算器系统，支持矩阵的输入、存储、运算（转置、加法、减法、乘法、标量运算）
 * 以及Bonus功能的卷积运算。系统通过UART进行数据输入输出，通过七段数码管和LED显示状态。
 * 
 * 主要子系统：
 * 1. IO子系统：处理UART通信、输入解码、打印输出
 * 2. 中央状态机：控制系统状态转换
 * 3. 计算控制器：处理矩阵运算命令
 * 4. Bonus控制器：处理卷积运算
 * 5. 矩阵存储：管理矩阵数据的存储和访问
 * 6. ALU：执行矩阵运算
 * 7. 显示控制：控制七段数码管和LED显示
 */

`include "parameters.vh"

module Matrix_Calculator_Top(
    input clk,              // 系统时钟
    input rst,              // 复位信号（低电平有效）
    input uart_rx,         // UART接收引脚
    output uart_tx,        // UART发送引脚
    input [7:0] sw,        // 拨码开关输入（用于配置和操作选择）
    input [3:0] btn,       // 按钮输入（用于触发操作）
    output [7:0] seg,      // 七段数码管段选信号
    output [3:0] an,       // 七段数码管位选信号
    output [7:0] led       // LED指示灯输出
);

// 系统复位信号：将外部复位信号取反（外部低电平有效，内部高电平有效）
wire sys_rst = ~rst; 

// ============================================================================
// 1. 时钟分频与输入消抖
// ============================================================================

// 时钟分频器：生成1Hz和1kHz时钟
// - clk_1hz: 用于倒计时显示等低频操作
// - clk_1khz: 用于需要较高频率的操作
wire clk_1hz, clk_1khz;
clk_divider u_clk_div (
    .clk(clk),
    .rst(sys_rst),
    .clk_1hz(clk_1hz),
    .clk_1khz(clk_1khz)
);

// 输入消抖：消除拨码开关和按钮的抖动
// - sw_clean: 消抖后的拨码开关信号
// - btn_clean: 消抖后的按钮信号
wire [7:0] sw_clean;
wire [3:0] btn_clean;
btn_debounce u_debounce (
    .clk(clk),
    .rst(sys_rst),
    .sw_raw(sw),
    .btn_raw(btn),
    .sw(sw_clean),
    .btn(btn_clean)
);

// 状态机复位信号：系统复位或按钮3（复位按钮）按下时复位状态机
wire fsm_rst;
assign fsm_rst = sys_rst | btn_clean[3];

// ============================================================================
// 2. IO子系统
// ============================================================================
// IO子系统负责处理UART通信、输入解码、矩阵数据打印等功能

// 状态机状态信号
wire [3:0] state;
// 存储器写使能信号（来自状态机）
wire mem_we;
// 输入计数器：记录已输入的数据个数
wire [7:0] input_count;
// 当前矩阵的维度（行数和列数）
wire [3:0] current_m, current_n;

// 计算总元素数：在输入维度/数据/填充零状态时使用分配维度，否则使用当前维度
wire [7:0] total_elems = ((state == `INPUT_DIM) || (state == `INPUT_DATA) || (state == `FILL_ZEROS)) ? 
                          (input_alloc_m * input_alloc_n) : (current_m * current_n);

// 输入解码器信号
wire decoder_valid;        // 解码器输出有效信号
wire [31:0] decoder_data;  // 解码器输出的32位数据
wire newline_rx;           // 接收到换行符信号

// 输入控制器信号：用于矩阵输入和分配
wire input_alloc_req;              // 输入分配请求
wire [3:0] input_alloc_m, input_alloc_n;  // 分配的矩阵维度
wire input_write_en;               // 输入写使能
wire [6:0] input_write_id;         // 输入写入的矩阵ID
wire [3:0] input_write_row, input_write_col;  // 输入写入的行列地址
wire [31:0] input_write_data;      // 输入写入的数据
wire [6:0] current_matrix_id;      // 当前操作的矩阵ID

// 矩阵分配信号
wire alloc_valid;    // 分配有效信号
wire [6:0] alloc_id; // 分配的矩阵ID

// 打印控制信号
wire final_print_req;              // 最终打印请求（经过系统互联选择后）
wire [3:0] final_print_mode;       // 打印模式
wire [6:0] final_print_target_id;  // 打印目标矩阵ID
wire print_done_sig;               // 打印完成信号
wire printer_busy;                 // 打印机忙信号

// 矩阵大小统计信号
wire [7:0] total_count;        // 矩阵总数
wire [2:0] size_count_q;       // 当前大小的矩阵数量
wire [4:0] size_valid_mask_q;  // 大小有效掩码
wire [4:0] p_size_idx;         // 打印时的大小索引

// 打印机读取信号
wire [6:0] p_mat_id;           // 打印的矩阵ID
wire [3:0] p_mat_r, p_mat_c;   // 打印的行列地址
wire [31:0] data_out_a;        // 存储器端口A输出数据

// Bonus卷积输出读取信号
wire [6:0] conv_out_rd_addr;           // 卷积输出读取地址
wire signed [31:0] conv_out_rd_data;   // 卷积输出读取数据

// IO子系统实例化：处理UART通信、输入解码、矩阵数据打印
io_subsystem u_io (
    .clk(clk),
    .rst(sys_rst),
    .uart_rx_pin(uart_rx),
    .uart_tx_pin(uart_tx),
    .state(state),
    .mem_we_fsm(mem_we),
    .total_elems(total_elems),
    .dim_invalid(dim_invalid),
    .data_invalid(data_invalid),
    .decoder_valid(decoder_valid),
    .decoder_data(decoder_data),
    .newline_rx(newline_rx),
    .input_count(input_count),
    .input_alloc_req(input_alloc_req),
    .input_alloc_m(input_alloc_m),
    .input_alloc_n(input_alloc_n),
    .alloc_valid(alloc_valid),
    .alloc_id_in(alloc_id),
    .input_write_en(input_write_en),
    .input_write_id(input_write_id),
    .input_write_row(input_write_row),
    .input_write_col(input_write_col),
    .input_write_data(input_write_data),
    .current_matrix_id(current_matrix_id),
    .print_req(final_print_req),
    .print_mode(final_print_mode),
    .print_target_id(final_print_target_id),
    .print_done(print_done_sig),
    .printer_busy(printer_busy),
    .total_count(total_count),
    .size_count_in(size_count_q),
    .size_valid_mask_in(size_valid_mask_q),
    .p_size_idx(p_size_idx),
    .p_mat_id(p_mat_id),
    .p_mat_r(p_mat_r),
    .p_mat_c(p_mat_c),
    .mat_data(data_out_a),
    .mat_m(current_m),
    .mat_n(current_n),
    .conv_addr(conv_out_rd_addr),
    .conv_data(conv_out_rd_data)
);

// ============================================================================
// 3. 中央状态机
// ============================================================================
// 中央状态机控制系统的主要状态转换，协调各个子模块的工作

// 状态机控制信号
wire enable_alu;        // ALU使能信号
wire error_timeout;     // 错误超时信号
wire countdown_done;    // 倒计时完成信号
wire alu_done;          // ALU运算完成信号

// 输入验证信号：检查输入的维度和数据是否有效
// 维度无效：维度必须在1-5之间
wire dim_invalid = (state == `INPUT_DIM) && decoder_valid &&
                   ((decoder_data < 32'd1) || (decoder_data > 32'd5));
// 数据无效：数据必须在0-9之间（有符号数）
wire data_invalid = (state == `INPUT_DATA) && decoder_valid &&
                    (($signed(decoder_data) < 32'sd0) || ($signed(decoder_data) > 32'sd9));

// 输入错误锁存器：锁存输入错误状态，直到状态离开INPUT_DIM/INPUT_DATA或进入ERROR状态
// 用于在状态转换过程中保持错误信号，确保错误能被正确检测和处理
reg input_error_latched;
always @(posedge clk or posedge sys_rst) begin
    if (sys_rst) begin
        input_error_latched <= 1'b0;
    end else begin
        // 检测到输入错误时，锁存错误状态
        if (dim_invalid || data_invalid) begin
            input_error_latched <= 1'b1;
        end
        // 当状态离开INPUT_DIM/INPUT_DATA或进入ERROR时，清除锁存
        else if ((state != `INPUT_DIM && state != `INPUT_DATA) || (state == `ERROR)) begin
            input_error_latched <= 1'b0;
        end
    end
end

// 填充控制信号
wire need_fill = (state == `INPUT_DATA) && newline_rx && (input_count < total_elems);  // 需要填充零
wire fill_done = (input_count >= total_elems);  // 填充完成

// Bonus和显示控制信号
wire bonus_done;           // Bonus运算完成信号
wire enable_decoder;       // 解码器使能信号
wire display_req_wire;     // 显示请求信号（来自状态机）

// 中央状态机实例化：控制系统的主要状态转换
central_fsm u_fsm (
    .clk(clk),
    .rst(fsm_rst),
    .uart_data(8'd0), // Unused in FSM now, handled by decoder
    .uart_done(1'b0), // Unused
    .newline_rx(newline_rx),
    .need_fill(need_fill),
    .fill_done(fill_done),
    .sw(sw_clean),
    .btn(btn_clean),
    .alu_done(alu_done),
    .decoder_valid(decoder_valid),
    .decoder_data(decoder_data),
    .mem_we(mem_we),
    .bonus_done(bonus_done),
    .request_bonus(request_bonus),
    .state(state),
    .enable_decoder(enable_decoder),
    .enable_alu(enable_alu),
    .countdown_done(countdown_done),
    .dim_invalid(dim_invalid),
    .data_invalid(data_invalid),
    .compute_error(compute_error_sig),
    .error_timeout(error_timeout),
    .display_req(display_req_wire) // Connected
);


// ============================================================================
// 4. 控制器实例化
// ============================================================================

// 4.1 计算控制器信号
wire alu_start_run;              // ALU启动运行信号
wire [2:0] selected_op;          // 选择的运算操作（0=转置, 1=加法, 2=减法, 3=乘法, 4=标量）
wire signed [31:0] selected_scalar;  // 选择的标量值
wire [6:0] selected_id_a, selected_id_b;  // 选择的矩阵A和B的ID
wire compute_print_req;          // 计算打印请求
wire [3:0] compute_print_mode;   // 计算打印模式
wire request_bonus;              // 请求Bonus功能
wire alu_overflow;               // ALU溢出标志
wire [31:0] alu_result;          // ALU运算结果
wire compute_error_sig;           // 计算错误信号

// 计算控制器使用的信号
wire [31:0] random_val;          // 随机数值（用于查询）
wire [3:0] query_dim_m, query_dim_n;  // 查询的矩阵维度

// 计算控制器实例化：处理矩阵运算命令，控制ALU执行运算
compute_controller u_compute_ctrl (
    .clk(clk),
    .rst(fsm_rst),
    .state(state),
    .sw(sw_clean),
    .btn(btn_clean),
    .decoder_valid(decoder_valid),
    .decoder_data(decoder_data),
    .alu_done(alu_done),
    .alu_start(alu_start_run),
    .alu_op(selected_op),
    .scalar_val(selected_scalar),
    .id_a(selected_id_a),
    .id_b(selected_id_b),
    .print_req(compute_print_req),
    .dim_a_m(current_m),
    .dim_a_n(current_n),
    .dim_b_m(current_m_b),
    .dim_b_n(current_n_b),
    .error_flag(compute_error_sig),
    .print_mode(compute_print_mode),
    .request_bonus(request_bonus),
    .valid_mask(size_valid_mask_q), // Connected
    .random_val(random_val),        // Connected
    .query_dim_m(query_dim_m),      // Connected
    .query_dim_n(query_dim_n)       // Connected
);

// 4.2 Bonus控制器信号
wire bonus_start_run;            // Bonus卷积启动信号
wire bonus_kernel_we;            // Bonus卷积核写使能
wire [3:0] bonus_kernel_idx;     // Bonus卷积核索引
wire signed [31:0] bonus_kernel_data;  // Bonus卷积核数据
wire bonus_print_req;            // Bonus打印请求

// Bonus控制器实例化：处理卷积运算命令
bonus_controller u_bonus_ctrl (
    .clk(clk),
    .rst(fsm_rst),
    .state(state),
    .decoder_valid(decoder_valid),
    .decoder_data(decoder_data),
    .bonus_done(bonus_done),
    .print_done(print_done_sig),  // 连接打印完成信号
    .start_run(bonus_start_run),
    .kernel_we(bonus_kernel_we),
    .kernel_idx(bonus_kernel_idx),
    .kernel_data(bonus_kernel_data),
    .print_req(bonus_print_req)
);

// 4.3 随机数生成器信号
// 随机数生成器用于生成随机矩阵，使用LFSR（线性反馈移位寄存器）实现
wire rng_alloc_req;              // 随机数生成器分配请求
wire [3:0] rng_alloc_m, rng_alloc_n;  // 随机矩阵的维度
wire rng_mem_we;                 // 随机数生成器存储器写使能
wire [6:0] rng_mem_id;           // 随机数生成器存储器ID
wire [3:0] rng_mem_row, rng_mem_col;  // 随机数生成器存储器行列地址
wire [31:0] rng_mem_data;        // 随机数生成器存储器数据

// 随机数生成器实例化：使用LFSR生成随机数并填充到矩阵中
rng_lfsr u_rng (
    .clk(clk),
    .rst(sys_rst),
    .start_enable(state == `GEN_RANDOM),
    .decoder_valid(decoder_valid),
    .decoder_data(decoder_data),
    .alloc_req(rng_alloc_req),
    .alloc_m(rng_alloc_m),
    .alloc_n(rng_alloc_n),
    .alloc_valid(alloc_valid),
    .alloc_id_in(alloc_id),
    .mem_we(rng_mem_we),
    .mem_id(rng_mem_id),
    .mem_row(rng_mem_row),
    .mem_col(rng_mem_col),
    .mem_data(rng_mem_data),
    .random_out(random_val) // Connected
);


// ============================================================================
// 5. 系统互联 - 多路选择器逻辑
// ============================================================================
// 系统互联模块负责协调多个数据源（输入控制器、RNG、ALU、计算控制器、Bonus控制器等）
// 并将它们的选择结果路由到矩阵存储器和打印机

// 显示打印请求生成逻辑：在进入DISPLAY_MODE时生成一个脉冲
reg display_printed;      // 显示已打印标志
reg display_print_req;    // 显示打印请求

always @(posedge clk or posedge fsm_rst) begin
    if (fsm_rst) begin
        display_printed <= 1'b0;
        display_print_req <= 1'b0;
    end else begin
        // 当进入DISPLAY_MODE时生成打印请求脉冲
        if (display_req_wire && !display_printed) begin
            display_print_req <= 1'b1;
            display_printed <= 1'b1;
        end else begin
            display_print_req <= 1'b0;
        end

        // 当退出DISPLAY_MODE时复位标志
        if (!display_req_wire) begin
            display_printed <= 1'b0;
        end
    end
end


// 系统互联输出信号：经过多路选择后的存储器控制信号
wire [6:0] mem_id_w;              // 写入矩阵ID
wire [3:0] mem_row_w, mem_col_w;  // 写入行列地址
wire [31:0] mem_data_w;           // 写入数据
wire mem_we_mux;                  // 存储器写使能（多路选择后）
wire mem_alloc_req_mux;           // 存储器分配请求（多路选择后）
wire [3:0] mem_alloc_m_mux, mem_alloc_n_mux;  // 分配维度（多路选择后）
wire [6:0] mem_id_a_mux, mem_id_b_mux;        // 读取矩阵ID（多路选择后）
wire [3:0] mem_row_a_mux, mem_col_a_mux;      // 读取行列地址（多路选择后）

// ALU信号（前向声明）
wire result_we;                   // 结果写使能
wire [3:0] alu_row_write, alu_col_write;  // ALU写入行列地址
wire [3:0] row_read_a, col_read_a;        // ALU读取行列地址（端口A）

// 系统互联实例化：协调多个数据源，将选择结果路由到矩阵存储器和打印机
system_interconnect u_interconnect (
    .state(state),

    // Input Controller (From IO Subsystem)
    .input_alloc_req(input_alloc_req),
    .input_alloc_m(input_alloc_m),
    .input_alloc_n(input_alloc_n),
    .input_write_en(input_write_en),
    .input_write_id(input_write_id),
    .input_write_row(input_write_row),
    .input_write_col(input_write_col),
    .input_write_data(input_write_data),
    .current_matrix_id(current_matrix_id),

    // RNG
    .rng_alloc_req(rng_alloc_req),
    .rng_alloc_m(rng_alloc_m),
    .rng_alloc_n(rng_alloc_n),
    .rng_mem_we(rng_mem_we),
    .rng_mem_id(rng_mem_id),
    .rng_mem_row(rng_mem_row),
    .rng_mem_col(rng_mem_col),
    .rng_mem_data(rng_mem_data),

    // ALU
    .result_we(result_we),
    .alu_row_write(alu_row_write),
    .alu_col_write(alu_col_write),
    .alu_result(alu_result),
    .alu_row_read_a(row_read_a),
    .alu_col_read_a(col_read_a),

    // Compute Controller
    .compute_id_a(selected_id_a),
    .compute_id_b(selected_id_b),
    .compute_print_req(compute_print_req),
    .compute_print_mode(compute_print_mode),

    // Bonus Controller
    .bonus_print_req(bonus_print_req),

    // Printer (From IO Subsystem)
    .printer_id(p_mat_id),
    .printer_row(p_mat_r),
    .printer_col(p_mat_c),
    .printer_active(printer_busy),

    // Display Logic
    .display_print_req(display_print_req),

    // Outputs
    .mem_id_w(mem_id_w),
    .mem_row_w(mem_row_w),
    .mem_col_w(mem_col_w),
    .mem_data_w(mem_data_w),
    .mem_we(mem_we_mux),
    .mem_alloc_req(mem_alloc_req_mux),
    .mem_alloc_m(mem_alloc_m_mux),
    .mem_alloc_n(mem_alloc_n_mux),
    .mem_id_a(mem_id_a_mux),
    .mem_row_a(mem_row_a_mux),
    .mem_col_a(mem_col_a_mux),
    .mem_id_b(mem_id_b_mux),
    .final_print_req(final_print_req),
    .final_print_mode(final_print_mode),
    .final_print_target_id(final_print_target_id)
);

// ============================================================================
// 6. 矩阵存储
// ============================================================================
// 矩阵存储模块管理所有矩阵数据的存储和访问，支持双端口读取和单端口写入

// 矩阵存储输出信号
wire [31:0] data_out_b;           // 存储器端口B输出数据
wire [3:0] current_m_b, current_n_b;  // 矩阵B的当前维度
wire [4:0] size_idx_q;            // 大小索引（用于统计）

// ALU端口B读取信号
wire [3:0] row_read_b, col_read_b;  // ALU读取行列地址（端口B）


// 配置寄存器：在IDLE状态下通过拨码开关配置系统参数
reg [2:0] cfg_matrix_limit;      // 矩阵数量限制（sw[2:0]）
reg [7:0] cfg_countdown_start;   // 倒计时初始值（sw[7:4]）

always @(posedge clk or posedge sys_rst) begin
    if (sys_rst) begin
        cfg_matrix_limit <= 3'd2;      // 默认限制2个矩阵
        cfg_countdown_start <= 8'd10;  // 默认倒计时10秒
    end else if (state == 4'd0) begin // IDLE状态时允许配置
        // 配置矩阵数量限制：sw[2:0]，如果为0则使用默认值2
        if (sw_clean[2:0] != 0) 
            cfg_matrix_limit <= sw_clean[2:0];
        else 
            cfg_matrix_limit <= 3'd2;

        // 配置倒计时初始值：sw[7:4]
        // 如果为0则使用默认值10，如果小于5则设为5，否则使用sw[7:4]的值
        if (sw_clean[7:4] == 4'd0)
            cfg_countdown_start <= 8'd10;
        else if (sw_clean[7:4] < 4'd5)
            cfg_countdown_start <= 8'd5;
        else
            cfg_countdown_start <= {4'd0, sw_clean[7:4]};
    end
end

// 结果矩阵（固定ID=11）的维度写入逻辑
// 当ALU完成运算时，根据运算类型更新结果矩阵的维度
reg        result_dim_we;        // 结果维度写使能
reg [6:0]  result_dim_id;        // 结果矩阵ID（固定为11）
reg [3:0]  result_dim_m, result_dim_n;  // 结果矩阵的维度

always @(posedge clk or posedge sys_rst) begin
    if (sys_rst) begin
        result_dim_we <= 1'b0;
        result_dim_id <= 7'd0;
        result_dim_m  <= 4'd0;
        result_dim_n  <= 4'd0;
    end else begin
        // 默认关闭写使能，只在计算完成时写一次
        result_dim_we <= 1'b0;

        // 在COMPUTE状态下，ALU完成一次运算时，记录结果矩阵（ID=11）的维度
        if (state == `COMPUTE && alu_done) begin
            result_dim_we <= 1'b1;
            result_dim_id <= 7'd11;

            // 根据运算类型选择结果矩阵的维度
            // op=0: 转置 => 维度 (n, m)
            // op=1: 加法 => 维度 (m, n)
            // op=2: 减法 => 维度 (m, n)
            // op=3: 乘法 => 维度 (m_a, n_b)
            case (selected_op)
                3'd0: begin
                    result_dim_m <= current_n;
                    result_dim_n <= current_m;
                end
                3'd3: begin
                    result_dim_m <= current_m;
                    result_dim_n <= current_n_b;
                end
                default: begin
                    result_dim_m <= current_m;
                    result_dim_n <= current_n;
                end
            endcase
        end
    end
end

// 维度写入端口多路选择：合并结果矩阵（ID=11）的维度写入和alloc的维度写入
wire       dim_we_mux;
wire [6:0] dim_write_id_mux;
wire [3:0] dim_write_m_mux, dim_write_n_mux;

assign dim_we_mux        = alloc_valid | result_dim_we;
assign dim_write_id_mux  = result_dim_we ? result_dim_id : alloc_id;
assign dim_write_m_mux   = result_dim_we ? result_dim_m  : mem_alloc_m_mux;
assign dim_write_n_mux   = result_dim_we ? result_dim_n  : mem_alloc_n_mux;

// 矩阵存储实例化：管理所有矩阵数据的存储和访问
matrix_storage u_storage (
    .clk(clk),
    .rst(sys_rst),
    .row_a(mem_row_a_mux), .col_a(mem_col_a_mux), .id_a(mem_id_a_mux),
    .row_b(row_read_b), .col_b(col_read_b), .id_b(mem_id_b_mux), // Port B connected to ALU
    .id_w(mem_id_w), .row_w(mem_row_w), .col_w(mem_col_w), .data_in(mem_data_w), .write_en(mem_we_mux),
    .dim_write_id(dim_write_id_mux), .dim_write_m(dim_write_m_mux), .dim_write_n(dim_write_n_mux), .dim_we(dim_we_mux),
    .dim_read_id(mem_id_a_mux), .dim_read_id_b(mem_id_b_mux),
    .cfg_x(cfg_matrix_limit),
    .alloc_req(mem_alloc_req_mux), .alloc_m(mem_alloc_m_mux), .alloc_n(mem_alloc_n_mux), .alloc_valid(alloc_valid), .alloc_id(alloc_id),
    .size_idx_q(size_idx_q), .size_count_q(size_count_q), .size_valid_mask_q(size_valid_mask_q), .total_count(total_count),
    .data_out_a(data_out_a), .data_out_b(data_out_b),
    .current_m(current_m), .current_n(current_n),
    .current_m_b(current_m_b), .current_n_b(current_n_b)
);

// 根据当前模式选择用于size统计的索引
// - COMPUTE状态：使用compute_controller查询(query_dim_m/n -> controller_size_idx)
// - 其他状态：使用UART打印系统查询(p_size_idx)
wire [4:0] controller_size_idx;
wire [4:0] size_idx_sel;

assign controller_size_idx = ((query_dim_m > 0) && (query_dim_n > 0)) ? 
                             ((query_dim_m - 1) * 5 + (query_dim_n - 1)) : 5'd0;
assign size_idx_sel = (state == `COMPUTE) ? controller_size_idx : p_size_idx;
assign size_idx_q   = size_idx_sel;


// ============================================================================
// 7. ALU实例
// ============================================================================
// 矩阵运算单元：执行矩阵转置、加法、减法、乘法、标量运算等操作

matrix_alu u_alu (
    .clk(clk),
    .rst(sys_rst),
    .data_a(data_out_a),
    .data_b(data_out_b),
    .op(selected_op),
    .start(alu_start_run),
    .dim_m(current_m), 
    .dim_n(current_n), 
    .dim_p(current_n_b), 
    .scalar_k(selected_scalar),
    .result(alu_result),
    .overflow(alu_overflow),
    .done(alu_done),
    .row_read_a(row_read_a), .col_read_a(col_read_a),
    .row_read_b(row_read_b), .col_read_b(col_read_b),
    .row_write(alu_row_write), .col_write(alu_col_write),
    .result_we(result_we)
);

// ============================================================================
// 8. Bonus卷积
// ============================================================================
// Bonus功能：对输入图像进行卷积运算

// Bonus卷积信号
wire [31:0] cycles;       // 卷积运算周期数
wire [7:0] rom_addr;      // ROM读取地址
wire [31:0] rom_data;     // ROM读取数据

bonus_conv u_bonus (
    .clk(clk),
    .rst(sys_rst),
    .start_conv(bonus_start_run),
    .kernel_we(bonus_kernel_we),
    .kernel_idx(bonus_kernel_idx),
    .kernel_data(bonus_kernel_data),
    .rom_data(rom_data),
    .rom_addr(rom_addr),
    .out_rd_addr(conv_out_rd_addr),
    .out_rd_data(conv_out_rd_data),
    .cycles(cycles),
    .done(bonus_done)
);

// ROM数据扩展：将4位ROM数据扩展为32位
wire [3:0] rom_data_raw;
assign rom_data = {28'd0, rom_data_raw};

// ROM地址解码：将线性地址转换为(x,y)坐标（12x12图像）
wire [31:0] rom_x_full = rom_addr / 12;  // x坐标
wire [31:0] rom_y_full = rom_addr % 12;  // y坐标

// 输入图像ROM实例化：存储12x12的输入图像数据
input_image_rom u_rom (
    .clk(clk),
    .x(rom_x_full[3:0]), 
    .y(rom_y_full[3:0]),
    .data_out(rom_data_raw)
);

// ============================================================================
// 9. 显示控制
// ============================================================================
// 显示控制模块负责控制七段数码管和LED的显示，显示系统状态、倒计时、运算信息等

// 倒计时寄存器：在ERROR状态下进行倒计时
reg [7:0] countdown_reg;
always @(posedge clk_1hz or posedge sys_rst) begin
    if (sys_rst) countdown_reg <= 8'd10;  // 复位时设为默认值10
    else if (state == `ERROR && countdown_reg > 0) countdown_reg <= countdown_reg - 1;  // ERROR状态下递减
    else if (state != `ERROR) countdown_reg <= cfg_countdown_start;  // 非ERROR状态时恢复配置值
end

assign countdown_done = (countdown_reg == 0);  // 倒计时完成信号

// 输入错误LED信号：综合输入错误锁存、维度无效和数据无效信号
// 用于在检测到维度或数据无效时，使LED保持错误状态
wire input_error_led = input_error_latched || dim_invalid || data_invalid;

// 显示控制实例化：控制七段数码管和LED显示
display_ctrl u_display (
    .clk(clk),
    .rst(sys_rst),
    .state(state),
    .countdown(countdown_reg),
    .cycles(cycles),
    .alu_op(selected_op),
    .error_led(input_error_led),  // 连接错误LED信号
    .seg(seg),
    .an(an),
    .led(led)
);

endmodule
