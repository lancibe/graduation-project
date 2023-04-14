/*
�����һ��ģ��ʹ��һ��֡��ΪN�Ļ������飬���ڴ洢��ǰ֡�������źš�
ÿ��������������һ֡ʱ���ͼ��㵱ǰ֡�ľ�ֵ�ͱ�׼����Ե�ǰ֡��ÿ���������й�һ������
���ڱ�׼��Ϊ0�������ֱ�����0���������һ��8λ��һ����������źš�
*/
module normalizer#(
    parameter M=12, // ����ϵ����ά��
    parameter N=256)// �����źŵ�֡��
    (
    input clk,
    input signed [7:0] quantized_audio, // ����������������ź�
    output reg signed  [7:0] normalized_audio // �����һ����������ź�
);

    reg signed [7:0] audio_buffer [0:N-1]; // �洢��ǰ֡�������ź�
    integer buffer_ptr = 0; // ��ǰָ֡��
    integer frame_count = 0; // ��ǰ֡������
    integer sum = 0;
    integer mean = 0;
    integer variance = 0;
    integer std = 0;
  
    always @(posedge clk) begin
        audio_buffer[buffer_ptr] = quantized_audio;
        buffer_ptr = buffer_ptr + 1;
        if (buffer_ptr == N) begin
        // ��ǰ֡������ϣ���ʼ��һ������
            buffer_ptr = 0;
            frame_count = frame_count + 1;
            sum = 0;
            for (int i = 0; i < N; i = i + 1) begin
            sum = sum + audio_buffer[i];
            end
            mean = sum / N;
            variance = 0;
            for (int i = 0; i < N; i = i + 1) begin
            variance = variance + (audio_buffer[i] - mean) ** 2;
            end
            variance = variance / N;
            std = $sqrt(variance);
            if (std == 0) begin
            // �����׼��Ϊ0��˵�������ź�ȫ����ȣ�ֱ�����0 
            normalized_audio = 0; 
            end else begin 
            // ���й�һ������ 
            normalized_audio = (quantized_audio - mean) * 128 / std; 
            end 

        end 

    end

endmodule

