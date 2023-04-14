module audio_processor(
  input clk, // 时钟信号
  input reset, // 复位信号
  input signed [15:0] audio_input, // 输入模拟语音信号
  output signed [11:0] cepstral_coeff // 输出倒谱系数特征
);

  wire signed [7:0] quantized_audio; // 量化后的语音信号
  wire signed [7:0] normalized_audio; // 归一化后的语音信号
  
  // 实现量化模块
  quantizer quantizer_inst(
    .clk(clk),
    .audio_input(audio_input),
    .quantized_audio(quantized_audio)
  );
  
  // 实现归一化模块
  normalizer normalizer_inst(
    .quantized_audio(quantized_audio),
    .normalized_audio(normalized_audio)
  );
  
  // 实现倒谱系数模块
  cepstral_coefficients cepstral_coeff_inst(
    .clk(clk),
    .audio_signal(normalized_audio),
    .cepstral_coeff_out(cepstral_coeff)
  );
  
endmodule