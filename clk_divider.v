`include "parameters.vh"

module clk_divider(
    input clk,
    input rst,
    output reg clk_1hz,
    output reg clk_1khz
);




reg [25:0] counter_1hz;
reg [15:0] counter_1khz;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        counter_1hz <= 0;
        counter_1khz <= 0;
        clk_1hz <= 0;
        clk_1khz <= 0;
    end else begin
        if (counter_1hz == 50000000 - 1) begin
            counter_1hz <= 0;
            clk_1hz <= ~clk_1hz;
        end else begin
            counter_1hz <= counter_1hz + 1;
        end
        if (counter_1khz == 50000 - 1) begin
            counter_1khz <= 0;
            clk_1khz <= ~clk_1khz;
        end else begin
            counter_1khz <= counter_1khz + 1;
        end
    end
end

endmodule
