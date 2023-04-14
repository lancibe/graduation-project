/*
这个Verilog-A模块实现了从模拟语音信号中提取倒谱系数特征的过程。
模块的输入是一个N位的语音信号，输出是一个M位的倒谱系数特征。

具体来说，模块首先将输入信号按照帧长N进行分帧，并进行重叠处理。
然后，对每一帧信号进行傅里叶变换，计算出信号的功率谱，进而计算出自相关系数和倒谱系数。
最后，对倒谱系数进行归一化和缩放处理，并输出到模块的输出端口。
*/

module cepstral_coefficients #(
    parameter M=12, // 倒谱系数的维度
    parameter N=256,// 语音信号的帧长
    parameter frame_overlap = N/2 // 帧重叠长度
    )
    (
    input clk,
    input [N-1:0] audio_signal, // 输入语音信号
    output reg [M-1:0] cepstral_coeff_out // 输出倒谱系数
);

    real audio_frame[N]; // 存储当前帧的语音信号
    real power_spectrum[N]; // 存储当前帧的功率谱
    real autocorrelation[N]; // 存储当前帧的自相关系数
    real cepstral_coeff_internal[N]; // 存储当前帧的倒谱系数
    integer frame_count = 0; // 当前帧计数器
    integer sample_count = 0; // 当前样本计数器
    integer overlap_count = 0; // 当前帧重叠计数器
    real cepstral_coeff_out_internal [M]; //记录倒谱系数

    initial begin
    // 初始化各个计数器和缓存数组
        frame_count = 0;
        sample_count = 0;
        overlap_count = N - frame_overlap;
        for (int i = 0; i < N; i = i + 1) begin
            audio_frame[i] = 0;
            power_spectrum[i] = 0;
            autocorrelation[i] = 0;
            cepstral_coeff_internal[i] = 0;
        end
    end

    always @(posedge clk) begin
    // 每个时钟周期处理一个样本
        automatic real sample = $itor(audio_signal[sample_count]);
        audio_frame[frame_overlap + overlap_count] = sample;
        overlap_count = overlap_count + 1;
        if (overlap_count == frame_overlap) begin
            // 当前帧处理完毕，开始提取倒谱系数
            overlap_count = 0;
            frame_count = frame_count + 1;
            power_spectrum = abs(fft(audio_frame));
            autocorrelation = ifft(power_spectrum * conj(power_spectrum));
            cepstral_coeff_internal = $real($ifft($log($abs(autocorrelation))));
            cepstral_coeff_internal = cepstral_coeff_internal[0:M-1];
            cepstral_coeff_internal = (cepstral_coeff_internal - mean(cepstral_coeff_internal)) / std(cepstral_coeff_internal); // 归一化 
            cepstral_coeff_internal = cepstral_coeff_internal * pow(10, -3); // 缩放

            // 输出倒谱系数
            for(integer i = 0 ; i < M ; i = i + 1) begin
                automatic real scaled_coeff = cepstral_coeff_internal[i] * pow(2, M-1);
                cepstral_coeff_out_internal[i] = $signed($floor(scaled_coeff));
            end
            cepstral_coeff_out = $bits(cepstral_coeff_out_internal);

        end
        sample_count = sample_count + 1;
    end

endmodule

