//�������ģ�齫�����16λģ�������ź�����8λ������8λ�������õ�һ��8λ�������źš�
module quantizer(
  input signed [15:0] audio_input, // ����ģ�������ź�
  output signed [7:0] quantized_audio // ���������������ź�
);

  assign quantized_audio = $signed(audio_input >> 8); // ����Ϊ8λ
  
endmodule