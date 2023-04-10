`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/04/10 15:41:46
// Design Name: 
// Module Name: temp
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module temp(

    );
endmodule

module input_data(
    input clk,
    input reset,
    input data_valid,
    input [DATA_WIDTH-1:0] data_in,
    output input_ready
);

module output_data(
    input clk,
    input reset,
    output reg data_valid,
    output [DATA_WIDTH-1:0] data_out,
    input output_ready
);

module data_flow(
    input clk,
    input reset,
    input [DATA_WIDTH-1:0] input_data,
    output [DATA_WIDTH-1:0] output_data
);

module multi_head_attention(
    input clk,
    input reset,
    input [DATA_WIDTH-1:0] input_data,
    output [DATA_WIDTH-1:0] output_data,
    input [DATA_WIDTH-1:0] weight_q,
    input [DATA_WIDTH-1:0] weight_k,
    input [DATA_WIDTH-1:0] weight_v,
    input [DATA_WIDTH-1:0] weight_o,
    input [DATA_WIDTH-1:0] bias_q,
    input [DATA_WIDTH-1:0] bias_k,
    input [DATA_WIDTH-1:0] bias_v,
    input [DATA_WIDTH-1:0] bias_o
);

    parameter NUM_HEADS = 8;
    parameter HIDDEN_DIM = 512;

    reg [DATA_WIDTH-1:0] q;
    reg [DATA_WIDTH-1:0] k;
    reg [DATA_WIDTH-1:0] v;
    reg [DATA_WIDTH-1:0] scaled_dot_product;
    reg [DATA_WIDTH-1:0] softmax_output;
    reg [DATA_WIDTH-1:0] output_data_reg;

    always @(posedge clk) begin
        // 计算Q、K、V
        q = input_data * weight_q + bias_q;
        k = input_data * weight_k + bias_k;
        v = input_data * weight_v + bias_v;
        
                // 分头计算
        reg [HIDDEN_DIM/NUM_HEADS-1:0] q_head [NUM_HEADS-1:0];
        reg [HIDDEN_DIM/NUM_HEADS-1:0] k_head [NUM_HEADS-1:0];
        reg [HIDDEN_DIM/NUM_HEADS-1:0] v_head [NUM_HEADS-1:0];
        for (int i = 0; i < NUM_HEADS; i++) begin
            q_head[i] = q[(i+1)*HIDDEN_DIM/NUM_HEADS-1:i*HIDDEN_DIM/NUM_HEADS];
            k_head[i] = k[(i+1)*HIDDEN_DIM/NUM_HEADS-1:i*HIDDEN_DIM/NUM_HEADS];
            v_head[i] = v[(i+1)*HIDDEN_DIM/NUM_HEADS-1:i*HIDDEN_DIM/NUM_HEADS];
        end

        // 计算注意力分值
        reg [HIDDEN_DIM/NUM_HEADS-1:0] dot_product [NUM_HEADS-1:0];
        for (int i = 0; i < NUM_HEADS; i++) begin
            dot_product[i] = q_head[i] * k_head[i];
        end

        // 缩放点积
        reg [DATA_WIDTH-1:0] scale_factor = (DATA_WIDTH-1)'d(HIDDEN_DIM/NUM_HEADS);
        scaled_dot_product = {dot_product} >> scale_factor;

        // 计算softmax
        reg [DATA_WIDTH-1:0] exp_sum = 0;
        for (int i = 0; i < HIDDEN_DIM/NUM_HEADS; i++) begin
            exp_sum += #(1) exp(scaled_dot_product[(i+1)*DATA_WIDTH-1:i*DATA_WIDTH] - max_value);
        end
        softmax_output = 0;
        for (int i = 0; i < HIDDEN_DIM/NUM_HEADS; i++) begin
            softmax_output[(i+1)*DATA_WIDTH-1:i*DATA_WIDTH] = #(1) exp(scaled_dot_product[(i+1)*DATA_WIDTH-1:i*DATA_WIDTH] - max_value) / exp_sum;
        end

        // 计算加权和
        reg [HIDDEN_DIM/NUM_HEADS-1:0] weighted_sum [NUM_HEADS-1:0];
        for (int i = 0; i < NUM_HEADS; i++) begin
            weighted_sum[i] = softmax_output[(i+1)*HIDDEN_DIM/NUM_HEADS-1:i*HIDDEN_DIM/NUM_HEADS] * v_head[i];
        end
        reg [DATA_WIDTH-1:0] concat_output = {weighted_sum};
        output_data_reg = concat_output * weight_o + bias_o;
    end

    assign output_data = output_data_reg;

endmodule


module feed_forward(
    input clk,
    input reset,
    input [DATA_WIDTH-1:0] input_data,
    output [DATA_WIDTH-1:0] output_data,
    input [DATA_WIDTH-1:0] weight,
    input [DATA_WIDTH-1:0] bias
);

    reg [DATA_WIDTH-1:0] linear_output;
    reg [DATA_WIDTH-1:0] relu_output;
    reg [DATA_WIDTH-1:0] output_data_reg;

    always @(posedge clk) begin
        linear_output = input_data * weight + bias;
        relu_output = (linear_output > 0) ? linear_output : 0;
        output_data_reg = relu_output;
    end

    assign output_data = output_data_reg;

endmodule


module transformer(
    input clk,
    input reset,
    input [DATA_WIDTH-1:0] input_data,
    output [DATA_WIDTH-1:0] output_data,
    input [DATA_WIDTH-1:0] enc_weight,
    input [DATA_WIDTH-1:0] enc_bias,
    input [DATA_WIDTH-1:0] dec_weight,
    input [DATA_WIDTH-1:0] dec_bias
);

    parameter NUM_LAYERS = 6;
    parameter HIDDEN_DIM = 512;

    reg [DATA_WIDTH-1:0] enc_output;
    reg [DATA_WIDTH-1:0] dec_output;

    // 输入层
    input_data input_layer(
        .clk(clk),
        .reset(reset),
        .data_valid(1'b1),
        .data_in(input_data),
        .input_ready(enc_input_ready)
    );
    // 编码器
    for (int i = 0; i < NUM_LAYERS; i++) begin
        multi_head_attention enc_self_attention(
            .clk(clk),
            .reset(reset),
            .input_data(enc_input),
            .output_data(enc_output_1),
            .weight_q(enc_weight[i*6+0]),
            .weight_k(enc_weight[i*6+1]),
            .weight_v(enc_weight[i*6+2]),
            .weight_o(enc_weight[i*6+3]),
            .bias_q(enc_bias[i*6+0]),
            .bias_k(enc_bias[i*6+1]),
            .bias_v(enc_bias[i*6+2]),
            .bias_o(enc_bias[i*6+3])
        );
        residual_connection enc_residual_1(
            .clk(clk),
            .reset(reset),
            .input_data(enc_input),
            .output_data(enc_output_1),
            .weight(enc_weight[i*6+4]),
            .bias(enc_bias[i*6+4])
        );
        feed_forward enc_feed_forward(
            .clk(clk),
            .reset(reset),
            .input_data(enc_output_1),
            .output_data(enc_output_2),
            .weight(enc_weight[i*6+5]),
            .bias(enc_bias[i*6+5])
        );
        residual_connection enc_residual_2(
            .clk(clk),
            .reset(reset),
            .input_data(enc_output_1),
            .output_data(enc_output_2),
            .weight(enc_weight[i*6+4]),
            .bias(enc_bias[i*6+4])
        );
        assign enc_input_ready = 1'b0;
        assign enc_input = enc_output_2;
    end
    
        // 解码器
    for (int i = 0; i < NUM_LAYERS; i++) begin
        multi_head_attention dec_self_attention(
            .clk(clk),
            .reset(reset),
            .input_data(dec_input),
            .output_data(dec_output_1),
            .weight_q(dec_weight[i*9+0]),
            .weight_k(dec_weight[i*9+1]),
            .weight_v(dec_weight[i*9+2]),
            .weight_o(dec_weight[i*9+3]),
            .bias_q(dec_bias[i*9+0]),
            .bias_k(dec_bias[i*9+1]),
            .bias_v(dec_bias[i*9+2]),
            .bias_o(dec_bias[i*9+3])
        );
        residual_connection dec_residual_1(
            .clk(clk),
            .reset(reset),
            .input_data(dec_input),
            .output_data(dec_output_1),
            .weight(dec_weight[i*9+4]),
            .bias(dec_bias[i*9+4])
        );
        multi_head_attention dec_enc_attention(
            .clk(clk),
            .reset(reset),
            .input_data(dec_output_1),
            .output_data(dec_output_2),
            .weight_q(dec_weight[i*9+5]),
            .weight_k(dec_weight[i*9+6]),
            .weight_v(dec_weight[i*9+7]),
            .weight_o(dec_weight[i*9+8]),
            .bias_q(dec_bias[i*9+5]),
            .bias_k(dec_bias[i*9+6]),
            .bias_v(dec_bias[i*9+7]),
            .bias_o(dec_bias[i*9+8])
        );
        residual_connection dec_residual_2(
            .clk(clk),
            .reset(reset),
            .input_data(dec_output_1),
            .output_data(dec_output_2),
            .weight(dec_weight[i*9+4]),
            .bias(dec_bias[i*9+4])
        );
        feed_forward dec_feed_forward(
            .clk(clk),
            .reset(reset),
            .input_data(dec_output_2),
            .output_data(dec_output_3),
            .weight(dec_weight[i*9+9]),
            .bias(dec_bias[i*9+9])
        );
        residual_connection dec_residual_3(
            .clk(clk),
            .reset(reset),
            .input_data(dec_output_2),
            .output_data(dec_output_3),
            .weight(dec_weight[i*9+10]),
            .bias(dec_bias[i*9+10])
        );
        assign dec_input_ready = 1'b0;
        assign dec_input = dec_output_3;
    end
    
        // 输出层
    output_data output_layer(
        .clk(clk),
        .reset(reset),
        .data_valid(1'b1),
        .data_out(dec_output),
        .output_ready(output_ready)
    );

endmodule