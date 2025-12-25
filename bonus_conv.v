`include "parameters.vh"


module bonus_conv(
    input clk,
    input rst,

    input start_conv,

    
    input kernel_we,
    input [3:0] kernel_idx,
    input signed [31:0] kernel_data,

    input [31:0] rom_data,
    output reg [7:0] rom_addr,

    input [6:0] out_rd_addr,
    output reg signed [31:0] out_rd_data,

    output reg [31:0] cycles,
    output reg done
);

    localparam IMG_R = 10;
    localparam IMG_C = 12;
    localparam K_R = 3;
    localparam K_C = 3;
    localparam OUT_R = IMG_R - K_R + 1;
    localparam OUT_C = IMG_C - K_C + 1;
    localparam OUT_N = OUT_R * OUT_C;

    localparam S_IDLE = 2'd0;
    localparam S_RUN  = 2'd1;
    localparam S_DONE = 2'd2;

    reg [1:0] state;

    reg signed [31:0] kernel [0:8];
    reg signed [31:0] out_mem [0:OUT_N-1];

    reg [3:0] out_r;
    reg [3:0] out_c;
    reg [3:0] k_idx;
    reg signed [63:0] acc;

    wire [3:0] k_r;
    wire [3:0] k_c;
    assign k_r = k_idx / K_C;
    assign k_c = k_idx - (k_r * K_C);

    wire [3:0] img_r;
    wire [3:0] img_c;
    assign img_r = out_r + k_r;
    assign img_c = out_c + k_c;

    wire [7:0] img_addr;
    assign img_addr = (img_r * IMG_C) + img_c;

    wire signed [31:0] img_val;
    assign img_val = $signed({28'd0, rom_data[3:0]});

    wire signed [63:0] prod;
    assign prod = $signed(kernel[k_idx]) * $signed(img_val);

    reg [3:0] next_k_idx;
    reg [3:0] next_out_r;
    reg [3:0] next_out_c;

    always @(*) begin
        next_k_idx = k_idx + 1;
        next_out_r = out_r;
        next_out_c = out_c;

        if (k_idx == 4'd8) begin
            next_k_idx = 4'd0;
            if (out_c + 1 < OUT_C) begin
                next_out_c = out_c + 1;
            end else if (out_r + 1 < OUT_R) begin
                next_out_c = 4'd0;
                next_out_r = out_r + 1;
            end else begin
                next_out_c = 4'd0;
                next_out_r = 4'd0;
            end
        end
    end

    wire [3:0] next_k_r = next_k_idx / K_C;
    wire [3:0] next_k_c = next_k_idx - (next_k_r * K_C);
    wire [3:0] next_img_r = next_out_r + next_k_r;
    wire [3:0] next_img_c = next_out_c + next_k_c;
    wire [7:0] next_img_addr = (next_img_r * IMG_C) + next_img_c;

    integer ii;

    always @(*) begin
        if (out_rd_addr < OUT_N) out_rd_data = out_mem[out_rd_addr];
        else out_rd_data = 32'sd0;
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= S_IDLE;
            rom_addr <= 8'd0;
            cycles <= 32'd0;
            done <= 1'b0;

            out_r <= 4'd0;
            out_c <= 4'd0;
            k_idx <= 4'd0;
            acc <= 64'sd0;

            for (ii = 0; ii < 9; ii = ii + 1) begin
                kernel[ii] <= 32'sd0;
            end
            for (ii = 0; ii < OUT_N; ii = ii + 1) begin
                out_mem[ii] <= 32'sd0;
            end
        end else begin
            done <= 1'b0;

            if (kernel_we && (kernel_idx < 4'd9)) begin
                kernel[kernel_idx] <= kernel_data;
            end

            case (state)
                S_IDLE: begin
                    // 只有在start_conv为高时才开始新的计算并重置cycles
                    if (start_conv) begin
                        cycles <= 32'd0;  // 新计算开始时重置cycles
                        out_r <= 4'd0;
                        out_c <= 4'd0;
                        k_idx <= 4'd0;
                        acc <= 64'sd0;
                        rom_addr <= img_addr;
                        state <= S_RUN;
                    end
                    // 否则保持cycles不变（显示上一次计算的最终值）
                end

                S_RUN: begin
                    cycles <= cycles + 1;
                    rom_addr <= next_img_addr;
                    acc <= acc + prod;

                    if (k_idx == 4'd8) begin
                        out_mem[(out_r * OUT_C) + out_c] <= acc + prod;
                        acc <= 64'sd0;
                        k_idx <= 4'd0;

                        if (out_c + 1 < OUT_C) begin
                            out_c <= out_c + 1;
                        end else if (out_r + 1 < OUT_R) begin
                            out_c <= 4'd0;
                            out_r <= out_r + 1;
                        end else begin
                            state <= S_DONE;
                        end
                    end else begin
                        k_idx <= k_idx + 1;
                    end
                end

                S_DONE: begin
                    // 在S_DONE状态下保持cycles不变，以便在数码管上显示最终值
                    done <= 1'b1;  // 保持done为高，直到start_conv被拉低后的下一个周期
                    if (!start_conv) begin
                        // 延迟一个周期再清除done和返回IDLE，确保controller有足够时间捕获done信号
                        done <= 1'b0;
                        state <= S_IDLE;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
