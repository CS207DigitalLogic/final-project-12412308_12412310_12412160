`include "parameters.vh"

module io_subsystem(
    input clk,
    input rst,
    input uart_rx_pin,
    output uart_tx_pin,
    input [3:0] state,
    input mem_we_fsm,
    input [7:0] total_elems,
    input dim_invalid,
    input data_invalid,
    output decoder_valid,
    output [31:0] decoder_data,
    output newline_rx,     
    output [7:0] input_count,
    output input_alloc_req,
    output [3:0] input_alloc_m,
    output [3:0] input_alloc_n,
    input alloc_valid,
    input [6:0] alloc_id_in,
    output input_write_en,
    output [6:0] input_write_id,
    output [3:0] input_write_row,
    output [3:0] input_write_col,
    output [31:0] input_write_data,
    output [6:0] current_matrix_id,
    input print_req,
    input [3:0] print_mode,
    input [6:0] print_target_id,
    output print_done,
    output printer_busy,
    input [7:0] total_count,
    input [2:0] size_count_in,
    input [4:0] size_valid_mask_in,
    output [4:0] p_size_idx,
    output [6:0] p_mat_id,
    output [3:0] p_mat_r,
    output [3:0] p_mat_c,
    input [31:0] mat_data,
    input [3:0] mat_m,
    input [3:0] mat_n,
    output [6:0] conv_addr,
    input signed [31:0] conv_data
);

    // 1.1 UART 接收�?
    wire [7:0] rx_data;
    wire rx_done;

    uart_rx u_rx (
        .clk(clk),
        .rst(rst),
        .rx(uart_rx_pin),
        .data(rx_data),
        .rx_done(rx_done)
    );

    // 1.2 输入解码�?
    wire is_space, is_newline_from_decoder, is_dimension, is_data;
    input_decoder u_decoder (
        .clk(clk),
        .rst(rst),
        .uart_data(rx_data),
        .uart_done(rx_done),
        .decoded_int(decoder_data),
        .is_space(is_space),
        .is_newline(is_newline_from_decoder), 
        .is_dimension(is_dimension),
        .is_data(is_data)
    );

    assign decoder_valid = is_data;

    
    
    assign newline_rx = is_newline_from_decoder; 

    // 1.3 输入控制�?
    input_controller u_input_ctrl (
        .clk(clk),
        .rst(rst),
        .state(state),
        .decoder_valid(decoder_valid),
        .decoder_data(decoder_data),
        .mem_we_fsm(mem_we_fsm),
        .input_count(input_count),
        .total_elems(total_elems),
        .dim_invalid(dim_invalid),
        .data_invalid(data_invalid),
        .alloc_req(input_alloc_req),
        .alloc_m(input_alloc_m),
        .alloc_n(input_alloc_n),
        .alloc_valid(alloc_valid),
        .alloc_id_in(alloc_id_in),
        .write_en(input_write_en),
        .write_id(input_write_id),
        .write_row(input_write_row),
        .write_col(input_write_col),
        .write_data(input_write_data),
        .current_id_out(current_matrix_id)
    );

    // 2.1 UART 发��器
    wire [7:0] tx_data;
    wire tx_start;
    wire tx_done_sig;

    uart_tx u_tx (
        .clk(clk),
        .rst(rst),
        .data(tx_data),
        .tx_start(tx_start),
        .tx(uart_tx_pin),
        .tx_done(tx_done_sig)
    );

    // 2.2 UART 打印�?
    uart_printer u_printer (
        .clk(clk),
        .rst(rst),
        .start(print_req),
        .mode(print_mode),
        .target_id(print_target_id),
        .total_count(total_count),
        .size_idx_in(p_size_idx),
        .size_count_in(size_count_in),
        .size_valid_mask_in(size_valid_mask_in),
        .mat_id(p_mat_id),
        .mat_r(p_mat_r),
        .mat_c(p_mat_c),
        .mat_data(mat_data),
        .mat_m(mat_m),
        .mat_n(mat_n),
        .conv_addr(conv_addr),
        .conv_data(conv_data),
        .tx_data(tx_data),
        .tx_start(tx_start),
        .tx_done(tx_done_sig),
        .done(print_done),
        .busy(printer_busy),
        .size_idx_out(p_size_idx),
        .slot_out()
    );

endmodule
