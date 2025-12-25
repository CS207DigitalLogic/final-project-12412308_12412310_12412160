`include "parameters.vh"

module bonus_controller(
    input clk,
    input rst,
    input [3:0] state,

    input decoder_valid,
    input [31:0] decoder_data,

    input bonus_done,
    input print_done,  // 新增：打印完成信号
    output reg start_run,
    output reg kernel_we,
    output reg [3:0] kernel_idx,
    output reg signed [31:0] kernel_data,

    output reg print_req
);

    reg bonus_collect;
    reg bonus_printed;
    reg [3:0] counter;
    reg conv_started;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            bonus_collect <= 1'b0;
            counter <= 4'd0;
            kernel_idx <= 4'd0;
            start_run <= 1'b0;
            kernel_we <= 1'b0;
            print_req <= 1'b0;
            bonus_printed <= 1'b0;
            kernel_data <= 32'd0;
            conv_started <= 1'b0;
        end else begin
            // start_run 淇濇寔楂樼洿鍒板嵎绉畬鎴?
            kernel_we <= 1'b0;
            // print_req 不再在这里清除，而是在状态改变时清除（见 else 分支）

            if (state == `BONUS) begin
                if (!bonus_collect && !conv_started && !bonus_done) begin
                    bonus_collect <= 1'b1;
                    counter <= 4'd0;
                    kernel_idx <= 4'd0;
                end

                if (bonus_collect && decoder_valid) begin
                    kernel_data <= $signed(decoder_data);
                    kernel_idx <= counter;
                    kernel_we <= 1'b1;

                    if (counter == 4'd8) begin
                        bonus_collect <= 1'b0;
                        start_run <= 1'b1;
                        counter <= 4'd0;
                        conv_started <= 1'b1;
                    end else begin
                        counter <= counter + 1;
                    end
                end

                // 当卷积完成时，先设置打印请求，然后再拉低start_run
                // 这样可以确保print_req在bonus_done变为低之前被设置
                if (bonus_done && !bonus_printed) begin
                    print_req <= 1'b1;
                    bonus_printed <= 1'b1;
                    start_run <= 1'b0;  // 在设置print_req的同时拉低start_run
                end else if (bonus_done && start_run) begin
                    start_run <= 1'b0;
                end

                // 当打印完成时，清除打印请求，避免重复打印
                if (print_done && print_req) begin
                    print_req <= 1'b0;
                end
            end else begin
                bonus_collect <= 1'b0;
                counter <= 4'd0;
                kernel_idx <= 4'd0;
                bonus_printed <= 1'b0;
                conv_started <= 1'b0;
                start_run <= 1'b0;
                print_req <= 1'b0;  // 离开 BONUS 状态时清除打印请求
            end
        end
    end

endmodule
