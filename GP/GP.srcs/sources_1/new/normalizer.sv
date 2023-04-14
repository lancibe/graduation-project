/*
这个归一化模块使用一个帧长为N的缓存数组，用于存储当前帧的语音信号。
每当缓存数组填满一帧时，就计算当前帧的均值和标准差，并对当前帧的每个样本进行归一化处理。
对于标准差为0的情况，直接输出0。最终输出一个8位归一化后的语音信号。
*/
module normalizer#(
    parameter M=12, // 倒谱系数的维度
    parameter N=256)// 语音信号的帧长
    (
    input clk,
    input signed [7:0] quantized_audio, // 输入量化后的语音信号
    output reg signed  [7:0] normalized_audio // 输出归一化后的语音信号
);

    reg signed [7:0] audio_buffer [0:N-1]; // 存储当前帧的语音信号
    integer buffer_ptr = 0; // 当前帧指针
    integer frame_count = 0; // 当前帧计数器
    integer sum = 0;
    integer mean = 0;
    integer variance = 0;
    integer std = 0;
  
    always @(posedge clk) begin
        audio_buffer[buffer_ptr] = quantized_audio;
        buffer_ptr = buffer_ptr + 1;
        if (buffer_ptr == N) begin
        // 当前帧处理完毕，开始归一化处理
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
            // 如果标准差为0，说明语音信号全部相等，直接输出0 
            normalized_audio = 0; 
            end else begin 
            // 进行归一化处理 
            normalized_audio = (quantized_audio - mean) * 128 / std; 
            end 

        end 

    end

endmodule

