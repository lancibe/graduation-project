module audio_processor(
  input clk, // ʱ���ź�
  input reset, // ��λ�ź�
  input signed [15:0] audio_input, // ����ģ�������ź�
  output signed [11:0] cepstral_coeff // �������ϵ������
);

  wire signed [7:0] quantized_audio; // ������������ź�
  wire signed [7:0] normalized_audio; // ��һ����������ź�
  
  // ʵ������ģ��
  quantizer quantizer_inst(
    .clk(clk),
    .audio_input(audio_input),
    .quantized_audio(quantized_audio)
  );
  
  // ʵ�ֹ�һ��ģ��
  normalizer normalizer_inst(
    .quantized_audio(quantized_audio),
    .normalized_audio(normalized_audio)
  );
  
  // ʵ�ֵ���ϵ��ģ��
  cepstral_coefficients cepstral_coeff_inst(
    .clk(clk),
    .audio_signal(normalized_audio),
    .cepstral_coeff_out(cepstral_coeff)
  );
  
endmodule