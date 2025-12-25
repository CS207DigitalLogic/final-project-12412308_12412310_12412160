`include "parameters.vh"

module uart_tx(
    input clk,
    input rst,
    output reg tx,
    input [7:0] data, // data 用于发��数据（8位）
    input tx_start, 
    output reg tx_done 
);

localparam IDLE = 3'd0;
localparam START_BIT = 3'd1; 
localparam DATA_BITS = 3'd2; 
localparam STOP_BIT = 3'd3;  

reg [2:0] state;
reg [2:0] count;
reg [7:0] shift_reg;
reg [15:0] counter;
reg [7:0] data_backup;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        state <= IDLE;
        tx <= 1'b1;
        tx_done <= 1'b0;
        count <= 3'd0;
        shift_reg <= 8'd0;
        counter <= 16'd0;
        data_backup <= 8'd0;
    end
    else begin
        tx_done <= 1'b0;
        case (state)
            IDLE: begin 
                tx <= 1'b1;
                if (tx_start) begin
                    state <= START_BIT;
                    shift_reg <= data;
                    data_backup <= data;
                    counter <= 16'd0;
                    count <= 3'd0;
                end
            end

            START_BIT: begin
                tx <= 1'b0;
                if (counter >= `BIT_PERIOD) begin
                    state <= DATA_BITS;
                    counter <= 16'd0;
                end
                else begin
                    counter <= counter + 16'd1;
                end
            end

            DATA_BITS: begin
                
                tx <= shift_reg[0];
                if (counter >= `BIT_PERIOD) begin
                    shift_reg <= {1'b0, shift_reg[7:1]};
                    counter <= 16'd0;

                    if (count == 3'd7) begin
                        state <= STOP_BIT;
                    end
                    else begin
                        count <= count + 3'd1;
                    end
                end
                else begin
                    counter <= counter + 16'd1;
                end
            end

            STOP_BIT: begin
                
                tx <= 1'b1;
                if (counter >= `BIT_PERIOD) begin
                    state <= IDLE;
                    tx_done <= 1'b1; 
                    counter <= 16'd0;
                end
                else begin
                    counter <= counter + 16'd1;
                end
            end

            default: state <= IDLE;
        endcase
    end
end

endmodule
