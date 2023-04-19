module mfcc_module
(
    input clk,              // 时钟信号
    input reset,            // 重置信号
    input signed [7:0] audio_in [63:0],   // 输入信号
    output reg signed [31:0] mfcc_out [11:0]  // 输出MFCC特征值
);

parameter FFT_SIZE = 64;        // FFT变换大小
parameter MEL_FILTER_NUM = 20;  // Mel滤波器数量

reg signed [15:0] fft_real [FFT_SIZE-1:0];  // 存储FFT变换实部数据
reg signed [15:0] fft_imag [FFT_SIZE-1:0];  // 存储FFT变换虚部数据
reg signed [15:0] mel_filter [MEL_FILTER_NUM-1:0][FFT_SIZE/2-1:0];  // 存储Mel滤波器系数
reg signed [31:0] dct_coef [MEL_FILTER_NUM-1:0][MEL_FILTER_NUM-1:0];  // 存储DCT系数
reg signed [31:0] mfcc_result [MEL_FILTER_NUM-1:0];  // 存储MFCC结果

reg real_val;
reg freq_step;
reg a_real, a_imag, b_real, b_imag, a_index, b_index;
reg stage_size;
reg twiddle_factor_real, twiddle_factor_imag;

// 初始化Mel滤波器系数和DCT系数
initial begin
    for (int i=0; i<MEL_FILTER_NUM; i=i+1) begin
        for (int j=0; j<FFT_SIZE/2; j=j+1) begin
            real_val = ((j+0.5)*8000/FFT_SIZE) * $pow((2*3.1415926), -10);
            if (real_val > -5 && real_val < 5) begin
                mel_filter[i][j] = ((real_val+5)*32768/10) ** 4 * 0.015625;
            end else if (real_val > 5 && real_val < 15) begin
                mel_filter[i][j] = ((15-real_val)*32768/10)**4 * 0.015625;
            end else begin
                mel_filter[i][j] = 0;
            end
        end
    end

    for (int i=0; i<MEL_FILTER_NUM; i=i+1) begin
        for (int j=0; j<MEL_FILTER_NUM; j=j+1) begin
            dct_coef[i][j] = ((2*cos(3.1415926*(i+0.5)*(j+0.5)/MEL_FILTER_NUM))/sqrt(MEL_FILTER_NUM)) * 32768;
        end
    end
end

always @(posedge clk) begin
    if (reset) begin   // 如果重置信号为高电平，则清零MFCC结果
        for(int i=0; i < MEL_FILTER_NUM; i=i+1)
            mfcc_out[i] <= 0;
    end else begin
    // 执行FFT变换
    for (int i=0; i<FFT_SIZE; i=i+1) begin
        fft_real[i] <= audio_in[i];
        fft_imag[i] <= 16'h0000;
    end
    for (int i=0; i<6; i=i+1) begin
    stage_size = $pow(2, (i+1));
        for (int j=0; j<FFT_SIZE/stage_size/2; j=j+1) begin
        freq_step = $pow(2, (16-i));
        twiddle_factor_real = cos(2*3.1415926*j/FFT_SIZE*freq_step);
        //twiddle_factor_imag = -$cos(2*3.1415926*j/FFT_SIZE*freq_step);
        twiddle_factor_imag = -$sin(2*3.1415926*j/FFT_SIZE*freq_step);
            for (int k=0; k<stage_size; k=k+1) begin
                a_index = j*stage_size+k;
                b_index = j*stage_size+k+stage_size/2;
                a_real = fft_real[a_index];
                a_imag = fft_imag[a_index];
                b_real = fft_real[b_index] * twiddle_factor_real - fft_imag[b_index] * twiddle_factor_imag;
                b_imag = fft_real[b_index] * twiddle_factor_imag + fft_imag[b_index] * twiddle_factor_real;
                fft_real[a_index] = a_real + b_real;
                fft_imag[a_index] = a_imag + b_imag;
                fft_real[b_index] = a_real - b_real;
                fft_imag[b_index] = a_imag - b_imag;
            end
        end
    end

    // 执行Mel滤波器和DCT系数计算得到MFCC结果
    for (int i=0; i<MEL_FILTER_NUM; i=i+1) begin
        mfcc_result[i] = 0;
        for (int j=0; j<FFT_SIZE/2; j=j+1) begin
            mfcc_result[i] = $int(mfcc_result[i] + mel_filter[i][j] * $log10($abs(fft_real[j]))) << 16;
        end
        for (int j=0; j<MEL_FILTER_NUM; j=j+1) begin
            mfcc_result[i] = $int(mfcc_result[i] + dct_coef[i][j] * $cos((j+0.5)*3.1415926/MEL_FILTER_NUM)) << 15;
        end
    end
    mfcc_out <= mfcc_result;
    end
end

endmodule