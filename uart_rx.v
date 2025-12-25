`include "parameters.vh"

module uart_rx(
    input clk,
    input rst,
    input rx,
    output reg [7:0] data, // data 用于接收数据�?位）
    output reg rx_done 
);

localparam IDLE = 3'd0;
localparam START_BIT = 3'd1; 
localparam DATA_BITS = 3'd2; 
localparam STOP_BIT = 3'd3; 

reg [2:0] state;
reg [2:0] count;
reg [7:0] shift_reg;
reg [15:0] counter;
reg [15:0] half_count;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        state <= IDLE;
        data <= 8'd0;
        rx_done <= 1'b0;
        count <= 3'd0;
        shift_reg <= 8'd0;
        counter <= 16'd0;
        half_count <= 16'd0;
    end
    else begin
        rx_done <= 1'b0;
        case (state)
            IDLE: begin 
                if (rx == 1'b0) begin
                    state <= START_BIT;
                    counter <= 16'd0;
                    half_count <= `BIT_PERIOD / 2;
                end
            end

            START_BIT: begin
                if (counter >= half_count) begin
                    
                    if (rx == 1'b0) begin
                        state <= DATA_BITS;
                        count <= 3'd0;
                        counter <= 16'd0;
                    end
                    else begin
                    
                    
                        state <= IDLE;
                    end
                end
                else begin
                    counter <= counter + 16'd1;
                end
            end

            DATA_BITS: begin
                if (counter >= `BIT_PERIOD) begin
                    shift_reg <= {rx, shift_reg[7:1]};
                    counter <= 16'd0;

                    if (count == 3'd7) begin
                        state <= STOP_BIT;
                    end else begin
                        count <= count + 3'd1;
                    end
                end else begin
                    counter <= counter + 16'd1;
                end
            end

            STOP_BIT: begin
                
                if (counter >= `BIT_PERIOD) begin
                    if (rx == 1'b1) begin
                        data <= shift_reg; 
                        rx_done <= 1'b1; 
                    end
                    state <= IDLE;
                    counter <= 16'd0;
                end else begin
                    counter <= counter + 16'd1;
                end
            end

            default: state <= IDLE;
        endcase
    end
end

endmodule
