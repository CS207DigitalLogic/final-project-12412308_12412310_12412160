`include "parameters.vh"


module btn_debounce#(
    parameter CNT_MAX=21'd 1_999_999,
    parameter CNT_WIDTH = 21
)
(
    input clk,
    input rst,
    input [7:0] sw_raw,
    input [3:0] btn_raw,
    output reg [7:0] sw,
    output reg [3:0] btn
);



    reg [CNT_WIDTH-1:0] counter; 
    reg [11:0] last_sample; 
    wire [11:0] current_input; 

    reg [7:0] sw_stable; 
    reg [3:0] btn_stable; 
    reg [3:0] btn_stable_d1; 

    
    assign current_input = {sw_raw, btn_raw};

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sw_stable <= 8'b0;
            btn_stable <= 4'b0;
            btn_stable_d1 <= 4'b0;
            sw <= 8'b0;
            btn <= 4'b0;
            counter <= {CNT_WIDTH{1'b0}};
            last_sample <= 12'b0;
        end else begin
            
            if (current_input != last_sample) begin
                counter <= {CNT_WIDTH{1'b0}};
                last_sample <= current_input;
            end else begin
                
                if (counter < CNT_MAX) begin
                    counter <= counter + 1'b1;
                end else begin
                    sw_stable <= last_sample[11:4];
                    btn_stable <= last_sample[3:0];
                end
            end
            
            sw <= sw_stable;

            
            btn_stable_d1 <= btn_stable;
            btn <= btn_stable & ~btn_stable_d1; 
        end
    end

endmodule
