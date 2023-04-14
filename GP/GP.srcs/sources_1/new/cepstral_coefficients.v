/*
���Verilog-Aģ��ʵ���˴�ģ�������ź�����ȡ����ϵ�������Ĺ��̡�
ģ���������һ��Nλ�������źţ������һ��Mλ�ĵ���ϵ��������

������˵��ģ�����Ƚ������źŰ���֡��N���з�֡���������ص�����
Ȼ�󣬶�ÿһ֡�źŽ��и���Ҷ�任��������źŵĹ����ף���������������ϵ���͵���ϵ����
��󣬶Ե���ϵ�����й�һ�������Ŵ����������ģ�������˿ڡ�
*/

module cepstral_coefficients(
    input [N-1:0] audio_signal, // ���������ź�
    output [M-1:0] cepstral_coeff // �������ϵ��
);

    parameter M = 12; // ����ϵ����ά��
    parameter N = 256; // �����źŵ�֡��
    parameter frame_overlap = N/2; // ֡�ص�����

    real audio_frame[N]; // �洢��ǰ֡�������ź�
    real power_spectrum[N]; // �洢��ǰ֡�Ĺ�����
    real autocorrelation[N]; // �洢��ǰ֡�������ϵ��
    real cepstral_coeff[N]; // �洢��ǰ֡�ĵ���ϵ��
    integer frame_count = 0; // ��ǰ֡������
    integer sample_count = 0; // ��ǰ����������
    integer overlap_count = 0; // ��ǰ֡�ص�������

    initial begin
    // ��ʼ�������������ͻ�������
        frame_count = 0;
        sample_count = 0;
        overlap_count = N - frame_overlap;
        audio_frame = {N{0}};
        power_spectrum = {N{0}};
        autocorrelation = {N{0}};
        cepstral_coeff = {N{0}};
    end

    always @(posedge clk) begin
    // ÿ��ʱ�����ڴ���һ������
        real sample = $itor(audio_signal[sample_count]);
        audio_frame[frame_overlap + overlap_count] = sample;
        overlap_count = overlap_count + 1;
        if (overlap_count == frame_overlap) begin
            // ��ǰ֡������ϣ���ʼ��ȡ����ϵ��
            overlap_count = 0;
            frame_count = frame_count + 1;
            power_spectrum = abs(fft(audio_frame));
            autocorrelation = ifft(power_spectrum * conj(power_spectrum));
            cepstral_coeff = real(ifft(log(abs(autocorrelation))));
            cepstral_coeff = cepstral_coeff[0:M-1];
            cepstral_coeff = (cepstral_coeff - mean(cepstral_coeff)) / std(cepstral_coeff); // ��һ�� cepstral_coeff = cepstral_coeff * pow(10, -3); // ����

            // �������ϵ��
            cepstral_coeff = $itor(cepstral_coeff);
            cepstral_coeff = $floor(cepstral_coeff * pow(2, M-1));
            cepstral_coeff = $signed(cepstral_coeff);
            cepstral_coeff = cepstral_coeff / pow(2, M-1);
            cepstral_coeff = cepstral_coeff * pow(10, 3);
            cepstral_coeff = $itor(cepstral_coeff);
            cepstral_coeff = $signed(cepstral_coeff);
        end
        sample_count = sample_count + 1;
    end

endmodule

