//这个量化模块将输入的16位模拟语音信号右移8位，将高8位舍弃，得到一个8位的量化信号。
module quantizer(
  input signed [15:0] audio_input, // 输入模拟语音信号
  output signed [7:0] quantized_audio // 输出量化后的语音信号
);

  assign quantized_audio = $signed(audio_input >> 8); // 量化为8位
  
endmodule