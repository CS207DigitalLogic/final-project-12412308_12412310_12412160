/**
 * 中央状态机模块
 * 
 * 功能概述：
 * 这是矩阵计算器系统的核心状态机，负责控制系统的主要状态转换。
 * 状态机协调各个子模块的工作，根据用户输入和系统状态进行状态转换。
 * 
 * 主要状态：
 * - IDLE: 空闲状态，等待用户操作
 * - INPUT_DIM: 输入矩阵维度
 * - INPUT_DATA: 输入矩阵数据
 * - FILL_ZEROS: 填充零（当输入数据不足时）
 * - COMPUTE: 执行矩阵运算
 * - ERROR: 错误状态
 * - BONUS: Bonus卷积运算
 * - GEN_RANDOM: 生成随机矩阵
 * - DISPLAY_MODE: 显示模式
 */

`include "parameters.vh"

module central_fsm(
    // 时钟和复位
    input clk,              // 系统时钟
    input rst,              // 复位信号（高电平有效）
    
    // 输入控制信号
    input newline_rx,       // 接收到换行符
    input need_fill,        // 需要填充零
    input fill_done,        // 填充完成
    input [7:0] sw,         // 拨码开关（用于选择操作模式）
    input [3:0] btn,         // 按钮输入
    
    // ALU相关
    input alu_done,         // ALU运算完成信号
    
    // 输入解码器相关
    input decoder_valid,    // 解码器输出有效
    input [31:0] decoder_data,  // 解码器输出的32位数据
    
    // 存储器控制
    output reg mem_we,      // 存储器写使能
    
    // Bonus相关
    input bonus_done,       // Bonus运算完成
    input request_bonus,    // 请求Bonus功能
    
    // 状态机输出
    output reg [3:0] state, // 当前状态
    output reg enable_decoder,  // 解码器使能
    output reg enable_alu,      // ALU使能
    
    // 错误和超时控制
    input countdown_done,   // 倒计时完成
    input dim_invalid,      // 维度无效
    input data_invalid,     // 数据无效
    input compute_error,    // 计算错误
    output reg error_timeout,   // 错误超时信号
    
    // 显示控制
    output reg display_req  // 显示请求信号
);

// ============================================================================
// 状态定义
// ============================================================================
localparam IDLE = 4'd0;          // 空闲状态：等待用户操作
localparam INPUT_DIM = 4'd1;    // 输入维度：等待输入矩阵的行数和列数
localparam INPUT_DATA = 4'd2;   // 输入数据：等待输入矩阵的元素值
localparam FILL_ZEROS = 4'd7;   // 填充零：当输入数据不足时自动填充0
localparam COMPUTE = 4'd3;      // 计算状态：执行矩阵运算
localparam ERROR = 4'd5;        // 错误状态：处理各种错误情况
localparam BONUS = 4'd6;        // Bonus状态：执行卷积运算
localparam GEN_RANDOM = 4'd8;   // 生成随机矩阵：生成随机数并填充矩阵
localparam DISPLAY_MODE = 4'd9; // 显示模式：显示矩阵统计信息

// ============================================================================
// 内部寄存器
// ============================================================================
reg [3:0] next_state;      // 下一状态
reg [3:0] error_cnt;        // 错误计数器（未使用）
reg dim_cnt;                // 维度计数器：用于计数已输入的维度（行/列）
reg display_exit_req;       // 显示退出请求：记录在DISPLAY_MODE中是否按下退出按钮

// ============================================================================
// 状态寄存器更新逻辑（时序逻辑）
// ============================================================================
always @(posedge clk or posedge rst) begin
    if (rst) begin
        // 复位：回到IDLE状态，清除所有计数器
        state <= IDLE;
        dim_cnt <= 1'b0;
        display_exit_req <= 1'b0;
    end else begin
        // 状态更新
        state <= next_state;

        // 维度计数器逻辑：在INPUT_DIM状态下，每次收到有效数据时翻转
        // dim_cnt=0表示已输入行数，dim_cnt=1表示已输入列数
        if (state != INPUT_DIM) begin
            dim_cnt <= 1'b0;  // 不在INPUT_DIM状态时清零
        end else if (decoder_valid) begin
            dim_cnt <= ~dim_cnt;  // 在INPUT_DIM状态且收到有效数据时翻转
        end

        // 显示退出请求逻辑：在DISPLAY_MODE中按下btn[1]时记录退出请求
        // 这样可以确保即使按钮释放，退出请求仍然有效
        if (state != DISPLAY_MODE)
            display_exit_req <= 1'b0;
        else if (btn[1])
            display_exit_req <= 1'b1;
    end
end

// ============================================================================
// 状态转换逻辑（组合逻辑）
// ============================================================================
always @(*) begin
    // 默认值：保持当前状态，所有控制信号为0
    next_state = state; 

    mem_we = 0;           // 默认不写存储器
    enable_decoder = 0;  // 默认不解码器使能
    enable_alu = 0;       // 默认不ALU使能
    error_timeout = 0;    // 默认无错误超时
    display_req = 0;      // 默认无显示请求

    case (state)
        IDLE: begin
            // 空闲状态：等待用户按下btn[0]并选择操作模式
            // sw[7:5]用于选择操作模式：000=输入, 001=生成随机矩阵, 010=显示, 011=计算, 100=Bonus
            if (btn[0]) begin
                if (sw[7:5] == 3'b000) next_state = INPUT_DIM;
                else if (sw[7:5] == 3'b001) next_state = GEN_RANDOM;
                else if (sw[7:5] == 3'b010) next_state = DISPLAY_MODE;
                else if (sw[7:5] == 3'b011) next_state = COMPUTE;
                else if (sw[7:5] == 3'b100) next_state = BONUS;
                else next_state = IDLE;  // 无效模式，保持IDLE
            end
        end

        INPUT_DIM: begin
            // 输入维度状态：等待输入矩阵的行数和列数
            enable_decoder = 1;  // 使能解码器接收数据
            
            if (decoder_valid) begin
                // 首先检查维度是否有效，如果无效则转到ERROR状态
                if (dim_invalid) begin
                    next_state = ERROR;
                end
                // 只有当维度有效时才根据dim_cnt判断是否进入下一状态
                // dim_cnt=0: 已输入行数，继续等待列数
                // dim_cnt=1: 已输入列数，转到INPUT_DATA状态
                else if (dim_cnt) begin
                    next_state = INPUT_DATA;  // 两个维度都已输入，进入数据输入
                end else begin
                    next_state = INPUT_DIM;   // 只输入了一个维度，继续等待
                end
            end
        end

        INPUT_DATA: begin
            // 输入数据状态：等待输入矩阵的元素值
            enable_decoder = 1;  // 使能解码器接收数据
            
            // 数据有效性检查
            if (decoder_valid && data_invalid) begin
                mem_we = 1'b0;      // 数据无效，不写存储器
                next_state = ERROR; // 转到错误状态
            end else begin
                mem_we = decoder_valid;  // 数据有效时，解码器有效则写存储器
            end
            
            // 接收到换行符时，判断是否需要填充零
            if (newline_rx) begin
                if (need_fill) 
                    next_state = FILL_ZEROS;  // 需要填充零，转到填充状态
                else 
                    next_state = IDLE;        // 不需要填充，返回空闲状态
            end
        end

        FILL_ZEROS: begin
            // 填充零状态：当输入数据不足时，自动用0填充剩余元素
            mem_we = 1'b1;  // 持续写使能，写入0值
            
            if (fill_done) begin
                next_state = IDLE;  // 填充完成，返回空闲状态
            end
        end

        COMPUTE: begin
            // 计算状态：执行矩阵运算
            enable_alu = 1;        // 使能ALU
            enable_decoder = 1;    // 使能解码器（用于接收运算命令）
            // 注意：alu_start现在由顶层compute_controller控制，不直接在这里控制
            
            // 状态转换条件
            if (request_bonus) begin
                next_state = BONUS;      // 请求Bonus功能，转到BONUS状态
            end else if (compute_error) begin 
                next_state = ERROR;      // 计算错误，转到ERROR状态
            end else if (btn[1]) begin 
                next_state = IDLE;       // 按下btn[1]，返回空闲状态
            end
        end

        // OUTPUT_RES 状态已移除，由顶层处理

        ERROR: begin
            // 错误状态：处理各种错误情况（维度无效、数据无效、计算错误等）
            error_timeout = 1;  // 启动错误超时计时
            
            // 退出错误状态的条件：倒计时完成或按下btn[0]
            if (countdown_done || btn[0]) begin 
                if (compute_error) 
                    next_state = COMPUTE;  // 如果是计算错误，返回COMPUTE状态
                else 
                    next_state = IDLE;     // 其他错误，返回空闲状态
            end
        end

        BONUS: begin
            // Bonus状态：执行卷积运算
            // 注意：Bonus流程（卷积核输入/运行/UART输出）在顶层bonus_controller协调
            
            enable_decoder = 1;  // 使能解码器（用于接收卷积核数据）
            
            if (btn[1]) begin 
                next_state = IDLE;  // 按下btn[1]，返回空闲状态
            end
        end

        GEN_RANDOM: begin
            // 生成随机矩阵状态：使用LFSR生成随机数并填充矩阵
            enable_decoder = 1;  // 使能解码器（用于接收矩阵维度）
            
            if (btn[1]) 
                next_state = IDLE;  // 按下btn[1]，返回空闲状态
        end

        DISPLAY_MODE: begin
            // 显示模式：显示矩阵统计信息（矩阵总数、各尺寸矩阵数量等）
            display_req = 1;  // 发出显示请求信号
            
            // 退出条件：在DISPLAY_MODE期间任何时候按下btn[1]都会返回IDLE
            // display_exit_req确保即使按钮释放，退出请求仍然有效
            if (btn[1] | display_exit_req) next_state = IDLE; 
        end

        default: next_state = IDLE;
    endcase
end

endmodule
