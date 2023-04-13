//����ģ��
module transformer(input clk, input reset, input [31:0]in_data,
                   input in_valid, output reg [31:0]out_data, output reg out_valid);

    //����ģ�͵Ĳ���
    parameter integer N = 6; //Transformerģ���еĲ���
    parameter integer d_model = 512; //ģ�͵�ά��
    parameter integer d_ff = 2048; //ǰ�����������ز��ά��
    parameter integer h = 8; //ͷ��
    parameter integer dropout = 0.1; //dropout�ı���
    
    integer i, j, ki;

    //���������������������
    reg [31:0] in_vec [0:511]; //��������
    reg [31:0] out_vec [0:511]; //�������

    //����ģ�͵���ģ��
    //sub_module_mha mha [0:5] (clk, reset, in_vec, in_valid, masked, out_vec, out_valid); //��ͷ��ע������ģ��
    //sub_module_ffn ffn (clk, reset, out_vec, out_valid, in_vec, in_valid); //ǰ��������ģ��
    //sub_module_add_norm add_norm(clk, reset, in_vec_1, in_vec_2, in_valid, out_vec, out_valid);//�в����ӡ��淶��ģ��

    //����ģ�͵�����
    always @(posedge clk) begin
        if (reset) begin
            for (i = 0 ; i < 512 ; i = i+1) begin
                in_vec[i] <= 0; //������������
                out_vec[i] <= 0; //�����������
            end
        end else if (in_valid) begin
            for (i = 0; i < d_model-1; i = i + 1) begin
                in_vec[i] = in_vec[i+1];
            end
            in_vec[d_model-1] = in_data; //������������ӵ�����������ĩβ
            out_valid = 1; //�����Ч�ź�
        end else begin
            out_valid = 0; //�����Ч�ź�
        end
    end

    //�����ͷ��ע������ģ��
    module mha(input clk, input reset, input [31:0] in_vec [0:511], input in_valid, input masked, 
               output reg [31:0] out_vec [0:511], output reg out_valid);
        parameter integer N = 6; //��ģ���еĲ���
        parameter integer d_model = 512; //ģ�͵�ά��
        parameter integer d_k = 64; //���Ͳ�ѯ������ά��
        parameter integer d_v = 64; //ֵ������ά��
        parameter integer h = 8; //ͷ��
        parameter integer dropout = 0.1; //dropout�ı���

        //������ģ���еļĴ���
        reg [31:0] q [0:h-1][0:d_k-1]; //��ѯ����
        reg [31:0] k [0:h-1][0:d_k-1]; //������
        reg [31:0] v [0:h-1][0:d_v-1]; //ֵ����
        reg [31:0] q_temp [0:h*d_k-1]; //��ʱ�����������ݴ��ѯ����
        reg [31:0] k_temp [0:h*d_k-1]; //��ʱ�����������ݴ������
        reg [31:0] v_temp [0:h*d_v-1]; //��ʱ�����������ݴ�ֵ����
        reg [31:0] qk [0:h-1][0:d_k-1]; //��ѯ�����ͼ������ĳ˻�
        reg [31:0] qkv [0:h-1][0:d_v-1]; //��ѯ��������������ֵ�����ĳ˻�
        reg [31:0] attn [0:h-1][0:d_v-1]; //ע��������
        reg [31:0] layer_norm [0:h-1][0:d_model-1]; //��淶������
        reg [31:0] dropout_out [0:h-1][0:d_model-1]; //dropout�������
        reg [31:0] out_vec_tmp [0:d_model-1]; //��ʱ�������
        reg [31:0] exp_sum = 0;
        reg [31:0] weighted_sum [0:d_model-1];
        

        //������ģ���е�����
        always @(posedge clk) begin
            if (reset) begin
                for(i = 0 ; i < h ; i = i + 1) begin
                    for(j = 0 ; j < d_k ; j = j + 1) begin
                        q[i][j] <= 0; //���ò�ѯ����
                        k[i][j] <= 0;
                    end
                    for(j = 0 ; j < d_v ; j = j + 1)begin
                        v[i][j] <= 0; //����ֵ����
                    end
                    for(j = 0 ; j < d_model ; j = j + 1)begin
                        layer_norm[i][j] <= 0; //���ò�淶������
                        dropout_out[i][j] <= 0; //����dropout�������
                    end
                end
                for(i = 0 ; i < d_model ; i = i + 1)begin
                    out_vec_tmp[i] <= 0; //������ʱ�������
                end
            end else if (in_valid) begin
                //������������ͷ����ά�Ƚ��зָ��ֵ
                for (i = 0; i < h; i = i + 1) begin
                    q[i] <= in_vec[i*d_k*d_model+:(d_k*d_model)];
                    k[i] <= in_vec[(h+i)*d_k*d_model+:(d_k*d_model)];
                    v[i] <= in_vec[(2*h+i)*d_v*d_model+:(d_v*d_model)];
                end

                //�����ѯ�����ͼ������ĳ˻�
                for (i = 0; i < h; i = i + 1) begin
                    for (j = 0; j < d_k; j = j + 1) begin
                        qk[i][j] = 0;
                        for (ki = 0; ki < d_model; ki = ki + 1) begin
                            qk[i][j] = qk[i][j] + q[i][j*d_model+ki] * k[i][j*d_model+ki];
                        end
                    end
                end

                //�����ѯ��������������ֵ�����ĳ˻�������ע��������
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
                //��ע������������softmax��һ��
                    for (i = 0; i < h; i = i + 1) begin
                        for (j = 0; j < d_v; j = j + 1) begin
                            exp_sum = exp_sum + $exp($real(attn[i][j]));
                        end
                        for (j = 0; j < d_v; j = j + 1) begin
                            attn[i][j] = $exp($real(attn[i][j])) / exp_sum;
                        end
                    end
                end else begin
                //������ע����ģ��
                    for (i = 0; i < h; i = i + 1) begin
                        for (j = 0; j < d_v; j = j + 1) begin 
                            if (j >= i*64 && j < (i+1)*64) begin 
                                //���� 
                                attn[i][j] = -999999; //�����벿�ֵ�ע������������Ϊ������ 
                            end else begin 
                                exp_sum = exp_sum + $exp($real(attn[i][j])); 
                            end 
                        end 
                        for (j = 0; j < d_v; j = j + 1) begin 
                            if (j >= i*64 && j < (i+1)*64) begin 
                                //���� 
                                attn[i][j] = -999999; //�����벿�ֵ�ע������������Ϊ������ 
                            end else begin 
                                attn[i][j] = $exp($real(attn[i][j])) / exp_sum; 
                            end 
                        end 
                    end
                end

                //����������������в�淶����dropout
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

                //���������ƴ�ӳ�һ����������ֵ���������
                for (i = 0; i < d_model; i = i + 1) begin
                    for (j = 0; j < h; j = j + 1) begin
                        out_vec_tmp[i] = out_vec_tmp[i] + dropout_out[j][i];
                    end
                end
                for(i = 0 ; i <d_model ; i = i +1)begin
                    out_vec[i] <= out_vec_tmp[i];
                end

                out_valid = 1; //�����Ч�ź�
            end else begin
                out_valid = 0; //�����Ч�ź�
            end
        end
    endmodule

    //����ǰ��������ģ��
    module ffn(input clk, input reset, input [31:0] in_vec [0:511], input in_valid,
               output reg [31:0] out_vec [0:511], output reg out_valid);
        parameter integer N = 6; //��ģ���еĲ���
        parameter integer d_model = 512; //ģ�͵�ά��
        parameter integer d_ff = 2048; //ǰ�����������ز��ά��
        parameter integer dropout = 0.1; //dropout�ı���

        //������ģ���еļĴ���
        reg [31:0] fc1_out [0:d_ff-1]; //ǰ�������һ����������
        reg [31:0] fc2_out [0:d_model-1]; //ǰ������ڶ�����������
        reg [31:0] layer_norm [0:d_model-1]; //��淶������
        reg [31:0] dropout_out [0:d_model-1]; //dropout�������

        //������ģ���е�����
        always @(posedge clk) begin
            if (reset) begin
                for(i = 0 ; i < d_ff ; i = i + 1) begin
                    fc1_out[i] <= 0; //����ǰ�������һ����������
                end
                for(i = 0 ; i < d_model ; i = i+1)begin
                    fc2_out[i] <= 0; //����ǰ������ڶ�����������
                    layer_norm[i] <= 0; //���ò�淶������
                    dropout_out[i] <= 0; //����dropout�������
                end
            end else if (in_valid) begin
                //ǰ�������һ�㣬ʹ��ReLU�����
                for (i = 0; i < d_ff; i = i + 1) begin
                    fc1_out[i] = $max(0, (in_vec[i] * $random()));
                end

                //ǰ������ڶ��㣬ʹ�����Լ����
                for (i = 0; i < d_model; i = i + 1) begin
                    fc2_out[i] = fc1_out[i] * $random();
                end

                //��淶����dropout
                for (i = 0; i < d_model; i = i + 1) begin
                    layer_norm[i] = fc2_out[i] + in_vec[i] - $average(fc2_out);
                    dropout_out[i] = layer_norm[i] * $random() > dropout;
                end
                for (i = 0 ; i < d_model; i = i+1)begin
                    out_vec[i] <= dropout_out[i]; //�����������ֵ������˿�
                end
                out_valid = 1; //�����Ч�ź�
            end else begin
                out_valid = 0; //�����Ч�ź�
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
    parameter integer d_model = 512; //ģ�͵�ά��
    parameter integer epsilon = 1e-6; //�淶��ʱ��ƫ����

    reg [31:0] add_out [0:d_model-1]; //�ӷ�������������
    reg [31:0] norm_out [0:d_model-1]; //��淶�����������
    reg [31:0] mean;
    reg [31:0] variance;
    reg [31:0] tsum = 0;
    
    always @(posedge clk) begin
        if (reset) begin
            for(i = 0 ;i < d_model ; i = i+1) begin
                add_out[i] <= 0; //���üӷ�������������
                norm_out[i] <= 0; //���ò�淶�����������
            end
        end else if (in_valid) begin
            //���мӷ�����
            for (i = 0; i < d_model; i = i + 1) begin
                add_out[i] = in_vec_1[i] + in_vec_2[i];
            end

            //���в�淶��
            mean = $average(add_out); //�����ֵ
            for (i = 0; i < d_model; i = i + 1) begin//���㷽��
                tsum = tsum + (add_out[i] - mean) * (add_out[i] - mean);
            end
            variance = tsum / d_model; 
            
            for (i = 0; i < d_model; i = i + 1) begin
                norm_out[i] = (add_out[i] - mean) / ($sqrt($real(variance + epsilon))); //���й淶��
            end
            for (i = 0 ; i < d_model; i = i+1)begin
                out_vec[i] <= norm_out[i]; //���淶�������������ֵ������˿�
            end
            out_valid = 1; //�����Ч�ź�
        end else begin
            out_valid = 0; //�����Ч�ź�
        end
    end

    endmodule

endmodule