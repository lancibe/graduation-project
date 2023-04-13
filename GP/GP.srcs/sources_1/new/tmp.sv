//定义模块
module transformer(input clk, input reset, input [31:0]in_data,
                   input in_valid, output reg [31:0]out_data, output reg out_valid);

    //定义模型的参数
    parameter integer N = 6; //Transformer模型中的层数
    parameter integer d_model = 512; //模型的维度
    parameter integer d_ff = 2048; //前馈网络中隐藏层的维度
    parameter integer h = 8; //头数
    parameter integer dropout = 0.1; //dropout的比例
    
    integer i, j, ki;

    //定义输入向量和输出向量
    reg [31:0] in_vec [0:511]; //输入向量
    reg [31:0] out_vec [0:511]; //输出向量

    //定义模型的子模块
    //sub_module_mha mha [0:5] (clk, reset, in_vec, in_valid, masked, out_vec, out_valid); //多头自注意力子模块
    //sub_module_ffn ffn (clk, reset, out_vec, out_valid, in_vec, in_valid); //前馈网络子模块
    //sub_module_add_norm add_norm(clk, reset, in_vec_1, in_vec_2, in_valid, out_vec, out_valid);//残差连接、规范化模块

    //定义模型的主体
    always @(posedge clk) begin
        if (reset) begin
            for (i = 0 ; i < 512 ; i = i+1) begin
                in_vec[i] <= 0; //重置输入向量
                out_vec[i] <= 0; //重置输出向量
            end
        end else if (in_valid) begin
            for (i = 0; i < d_model-1; i = i + 1) begin
                in_vec[i] = in_vec[i+1];
            end
            in_vec[d_model-1] = in_data; //将输入数据添加到输入向量的末尾
            out_valid = 1; //输出有效信号
        end else begin
            out_valid = 0; //输出无效信号
        end
    end

    //定义多头自注意力子模块
    module mha(input clk, input reset, input [31:0] in_vec [0:511], input in_valid, input masked, 
               output reg [31:0] out_vec [0:511], output reg out_valid);
        parameter integer N = 6; //子模块中的层数
        parameter integer d_model = 512; //模型的维度
        parameter integer d_k = 64; //键和查询向量的维度
        parameter integer d_v = 64; //值向量的维度
        parameter integer h = 8; //头数
        parameter integer dropout = 0.1; //dropout的比例

        //定义子模块中的寄存器
        reg [31:0] q [0:h-1][0:d_k-1]; //查询向量
        reg [31:0] k [0:h-1][0:d_k-1]; //键向量
        reg [31:0] v [0:h-1][0:d_v-1]; //值向量
        reg [31:0] q_temp [0:h*d_k-1]; //临时变量，用于暂存查询向量
        reg [31:0] k_temp [0:h*d_k-1]; //临时变量，用于暂存键向量
        reg [31:0] v_temp [0:h*d_v-1]; //临时变量，用于暂存值向量
        reg [31:0] qk [0:h-1][0:d_k-1]; //查询向量和键向量的乘积
        reg [31:0] qkv [0:h-1][0:d_v-1]; //查询向量、键向量和值向量的乘积
        reg [31:0] attn [0:h-1][0:d_v-1]; //注意力向量
        reg [31:0] layer_norm [0:h-1][0:d_model-1]; //层规范化向量
        reg [31:0] dropout_out [0:h-1][0:d_model-1]; //dropout输出向量
        reg [31:0] out_vec_tmp [0:d_model-1]; //临时输出向量
        reg [31:0] exp_sum = 0;
        reg [31:0] weighted_sum [0:d_model-1];
        

        //定义子模块中的主体
        always @(posedge clk) begin
            if (reset) begin
                for(i = 0 ; i < h ; i = i + 1) begin
                    for(j = 0 ; j < d_k ; j = j + 1) begin
                        q[i][j] <= 0; //重置查询向量
                        k[i][j] <= 0;
                    end
                    for(j = 0 ; j < d_v ; j = j + 1)begin
                        v[i][j] <= 0; //重置值向量
                    end
                    for(j = 0 ; j < d_model ; j = j + 1)begin
                        layer_norm[i][j] <= 0; //重置层规范化向量
                        dropout_out[i][j] <= 0; //重置dropout输出向量
                    end
                end
                for(i = 0 ; i < d_model ; i = i + 1)begin
                    out_vec_tmp[i] <= 0; //重置临时输出向量
                end
            end else if (in_valid) begin
                //将输入向量按头数和维度进行分割并赋值
                for (i = 0; i < h; i = i + 1) begin
                    q[i] <= in_vec[i*d_k*d_model+:(d_k*d_model)];
                    k[i] <= in_vec[(h+i)*d_k*d_model+:(d_k*d_model)];
                    v[i] <= in_vec[(2*h+i)*d_v*d_model+:(d_v*d_model)];
                end

                //计算查询向量和键向量的乘积
                for (i = 0; i < h; i = i + 1) begin
                    for (j = 0; j < d_k; j = j + 1) begin
                        qk[i][j] = 0;
                        for (ki = 0; ki < d_model; ki = ki + 1) begin
                            qk[i][j] = qk[i][j] + q[i][j*d_model+ki] * k[i][j*d_model+ki];
                        end
                    end
                end

                //计算查询向量、键向量和值向量的乘积并计算注意力向量
                for (i = 0; i < h; i = i + 1) begin
                    for (j = 0; j < d_v; j = j + 1) begin
                        qkv[i][j] = 0;
                        for (ki = 0; ki < d_k; ki = ki + 1) begin
                            qkv[i][j] = qkv[i][j] + (q[i][ki*d_model+j/d_v*d_model+j%d_v] * v[i][j]);
                        end
                        attn[i][j] = qkv[i][j] / sqrt(d_k);
                    end
                end

                if(~masked) begin
                //对注意力向量进行softmax归一化
                    for (i = 0; i < h; i = i + 1) begin
                        for (j = 0; j < d_v; j = j + 1) begin
                            exp_sum = exp_sum + $exp($real(attn[i][j]));
                        end
                        for (j = 0; j < d_v; j = j + 1) begin
                            attn[i][j] = $exp($real(attn[i][j])) / exp_sum;
                        end
                    end
                end else begin
                //掩码自注意力模块
                    for (i = 0; i < h; i = i + 1) begin
                        for (j = 0; j < d_v; j = j + 1) begin 
                            if (j >= i*64 && j < (i+1)*64) begin 
                                //掩码 
                                attn[i][j] = -999999; //将掩码部分的注意力向量设置为负无穷 
                            end else begin 
                                exp_sum = exp_sum + $exp($real(attn[i][j])); 
                            end 
                        end 
                        for (j = 0; j < d_v; j = j + 1) begin 
                            if (j >= i*64 && j < (i+1)*64) begin 
                                //掩码 
                                attn[i][j] = -999999; //将掩码部分的注意力向量设置为负无穷 
                            end else begin 
                                attn[i][j] = $exp($real(attn[i][j])) / exp_sum; 
                            end 
                        end 
                    end
                end

                //计算输出向量并进行层规范化和dropout
                for (i = 0; i < h; i = i + 1) begin
                    for (j = 0; j < d_v; j = j + 1) begin
                        for (ki = 0; ki < d_model; ki = ki + 1) begin
                            weighted_sum[ki] = weighted_sum[ki] + (attn[i][j] * v[i][j*d_model+ki]);
                        end
                    end
                    for (j = 0; j < d_model; j = j + 1) begin
                        layer_norm[i][j] = weighted_sum[j] + q[i][j] - $average(weighted_sum);
                        dropout_out[i][j] = layer_norm[i][j] * $random() > dropout;
                    end
                end

                //将输出向量拼接成一个向量并赋值给输出向量
                for (i = 0; i < d_model; i = i + 1) begin
                    for (j = 0; j < h; j = j + 1) begin
                        out_vec_tmp[i] = out_vec_tmp[i] + dropout_out[j][i];
                    end
                end
                for(i = 0 ; i <d_model ; i = i +1)begin
                    out_vec[i] <= out_vec_tmp[i];
                end

                out_valid = 1; //输出有效信号
            end else begin
                out_valid = 0; //输出无效信号
            end
        end
    endmodule

    //定义前馈网络子模块
    module ffn(input clk, input reset, input [31:0] in_vec [0:511], input in_valid,
               output reg [31:0] out_vec [0:511], output reg out_valid);
        parameter integer N = 6; //子模块中的层数
        parameter integer d_model = 512; //模型的维度
        parameter integer d_ff = 2048; //前馈网络中隐藏层的维度
        parameter integer dropout = 0.1; //dropout的比例

        //定义子模块中的寄存器
        reg [31:0] fc1_out [0:d_ff-1]; //前馈网络第一层的输出向量
        reg [31:0] fc2_out [0:d_model-1]; //前馈网络第二层的输出向量
        reg [31:0] layer_norm [0:d_model-1]; //层规范化向量
        reg [31:0] dropout_out [0:d_model-1]; //dropout输出向量

        //定义子模块中的主体
        always @(posedge clk) begin
            if (reset) begin
                for(i = 0 ; i < d_ff ; i = i + 1) begin
                    fc1_out[i] <= 0; //重置前馈网络第一层的输出向量
                end
                for(i = 0 ; i < d_model ; i = i+1)begin
                    fc2_out[i] <= 0; //重置前馈网络第二层的输出向量
                    layer_norm[i] <= 0; //重置层规范化向量
                    dropout_out[i] <= 0; //重置dropout输出向量
                end
            end else if (in_valid) begin
                //前馈网络第一层，使用ReLU激活函数
                for (i = 0; i < d_ff; i = i + 1) begin
                    fc1_out[i] = $max(0, (in_vec[i] * $random()));
                end

                //前馈网络第二层，使用线性激活函数
                for (i = 0; i < d_model; i = i + 1) begin
                    fc2_out[i] = fc1_out[i] * $random();
                end

                //层规范化和dropout
                for (i = 0; i < d_model; i = i + 1) begin
                    layer_norm[i] = fc2_out[i] + in_vec[i] - $average(fc2_out);
                    dropout_out[i] = layer_norm[i] * $random() > dropout;
                end
                for (i = 0 ; i < d_model; i = i+1)begin
                    out_vec[i] <= dropout_out[i]; //将输出向量赋值给输出端口
                end
                out_valid = 1; //输出有效信号
            end else begin
                out_valid = 0; //输出无效信号
            end
        end
    endmodule

    module add_norm(
        input clk, 
        input reset, 
        input [31:0] in_vec_1 [0:511], 
        input [31:0] in_vec_2 [0:511], 
        input in_valid,
        output reg [31:0] out_vec [0:511], 
        output reg out_valid
    );
    parameter integer d_model = 512; //模型的维度
    parameter integer epsilon = 1e-6; //规范化时的偏置量

    reg [31:0] add_out [0:d_model-1]; //加法运算的输出向量
    reg [31:0] norm_out [0:d_model-1]; //层规范化的输出向量
    reg [31:0] mean;
    reg [31:0] variance;
    reg [31:0] tsum = 0;
    
    always @(posedge clk) begin
        if (reset) begin
            for(i = 0 ;i < d_model ; i = i+1) begin
                add_out[i] <= 0; //重置加法运算的输出向量
                norm_out[i] <= 0; //重置层规范化的输出向量
            end
        end else if (in_valid) begin
            //进行加法运算
            for (i = 0; i < d_model; i = i + 1) begin
                add_out[i] = in_vec_1[i] + in_vec_2[i];
            end

            //进行层规范化
            mean = $average(add_out); //计算均值
            for (i = 0; i < d_model; i = i + 1) begin//计算方差
                tsum = tsum + (add_out[i] - mean) * (add_out[i] - mean);
            end
            variance = tsum / d_model; 
            
            for (i = 0; i < d_model; i = i + 1) begin
                norm_out[i] = (add_out[i] - mean) / ($sqrt($real(variance + epsilon))); //进行规范化
            end
            for (i = 0 ; i < d_model; i = i+1)begin
                out_vec[i] <= norm_out[i]; //将规范化的输出向量赋值给输出端口
            end
            out_valid = 1; //输出有效信号
        end else begin
            out_valid = 0; //输出无效信号
        end
    end

    endmodule

endmodule