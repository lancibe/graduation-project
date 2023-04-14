/*
���Verilog-Aģ��ʵ���˴�ģ�������ź�����ȡ����ϵ�������Ĺ��̡�
ģ���������һ��Nλ�������źţ������һ��Mλ�ĵ���ϵ��������

������˵��ģ�����Ƚ������źŰ���֡��N���з�֡���������ص�����
Ȼ�󣬶�ÿһ֡�źŽ��и���Ҷ�任��������źŵĹ����ף���������������ϵ���͵���ϵ����
��󣬶Ե���ϵ�����й�һ�������Ŵ����������ģ�������˿ڡ�
*/

module cepstral_coefficients #(
    parameter M=12, // ����ϵ����ά��
    parameter N=256,// �����źŵ�֡��
    parameter frame_overlap = N/2 // ֡�ص�����
    )
    (
    input clk,
    input [N-1:0] audio_signal, // ���������ź�
    output reg [M-1:0] cepstral_coeff_out // �������ϵ��
);

    real audio_frame[N]; // �洢��ǰ֡�������ź�
    real power_spectrum[N]; // �洢��ǰ֡�Ĺ�����
    real autocorrelation[N]; // �洢��ǰ֡�������ϵ��
    real cepstral_coeff_internal[N]; // �洢��ǰ֡�ĵ���ϵ��
    integer frame_count = 0; // ��ǰ֡������
    integer sample_count = 0; // ��ǰ����������
    integer overlap_count = 0; // ��ǰ֡�ص�������
    real cepstral_coeff_out_internal [M]; //��¼����ϵ��

    initial begin
    // ��ʼ�������������ͻ�������
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
    // ÿ��ʱ�����ڴ���һ������
        automatic real sample = $itor(audio_signal[sample_count]);
        audio_frame[frame_overlap + overlap_count] = sample;
        overlap_count = overlap_count + 1;
        if (overlap_count == frame_overlap) begin
            // ��ǰ֡������ϣ���ʼ��ȡ����ϵ��
            overlap_count = 0;
            frame_count = frame_count + 1;
            power_spectrum = abs(fft(audio_frame));
            autocorrelation = ifft(power_spectrum * conj(power_spectrum));
            cepstral_coeff_internal = $real($ifft($log($abs(autocorrelation))));
            cepstral_coeff_internal = cepstral_coeff_internal[0:M-1];
            cepstral_coeff_internal = (cepstral_coeff_internal - mean(cepstral_coeff_internal)) / std(cepstral_coeff_internal); // ��һ�� 
            cepstral_coeff_internal = cepstral_coeff_internal * pow(10, -3); // ����

            // �������ϵ��
            for(integer i = 0 ; i < M ; i = i + 1) begin
                automatic real scaled_coeff = cepstral_coeff_internal[i] * pow(2, M-1);
                cepstral_coeff_out_internal[i] = $signed($floor(scaled_coeff));
            end
            cepstral_coeff_out = $bits(cepstral_coeff_out_internal);

        end
        sample_count = sample_count + 1;
    end

endmodule

