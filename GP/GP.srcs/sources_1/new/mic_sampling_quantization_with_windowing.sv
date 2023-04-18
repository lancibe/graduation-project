module mic_sampling_quantization_with_windowing
(
    input clk,      // FPGA ��ʱ���ź�
    input reset,    // �����ź�
    input mic_in,   // ��Ͳ�����ź�
    output reg [7:0] sample_out,   // ���������������������ź�
    output reg sample_ready       // �����������ź�
);

parameter FRAME_SIZE = 256;        // ����֡��С
parameter SUB_FRAME_SIZE = 64;     // ��֡��С
parameter OVERLAP_SIZE = 16;       // �ص������С
parameter HAMMING_WINDOW = 1;      // �Ƿ�ʹ�ú�����

reg [7:0] sample_value;            // �洢����ֵ

reg [7:0] frame [FRAME_SIZE-1:0];     // �洢����֡����
reg [7:0] sub_frame [SUB_FRAME_SIZE-1:0];  // �洢��ǰ��֡����
reg sub_frame_index = 0;           // ��ǰ��֡����

// ʵ����MFCCģ�飬��ÿ����֡��Ϊ����
mfcc_module mfcc_inst (
    .clk(clk),
    .reset(reset),
    .audio_in(sub_frame),
    .mfcc_out(mfcc_features)
);

reg [31:0] mfcc_features [11:0];  // �洢MFCC����ֵ

always @(posedge clk) begin
    if (reset) begin   // ��������ź�Ϊ�ߵ�ƽ�����������ֵ������ź�
        sample_value <= 8'h00;
        sample_out <= 8'h00;
        sample_ready <= 1'b0;
        frame <= {FRAME_SIZE{8'h00}};
        sub_frame <= {SUB_FRAME_SIZE{8'h00}};
        sub_frame_index <= 0;
        mfcc_features <= {12{32'h00000000}};
    end else begin
        // �ӻ�Ͳ�����ź��н��в��������������Ϊ 8 λ�����ź�
        sample_value <= mic_in;
        sample_out <= sample_value >> 1;   // ����һλ��������
        sample_ready <= 1'b1;              // ���ò�������ź�
        
        frame[FRAME_SIZE-1:1] <= frame[FRAME_SIZE-2:0];   // �ƶ�����֡����
        frame[0] <= sample_value;                         // �洢�µĲ���ֵ
        
        if (sub_frame_index == SUB_FRAME_SIZE - 1) begin   // �����ǰ��֡�����ˣ�ִ�мӴ��ͷָ����
            if (HAMMING_WINDOW) begin   // ����������
                for (int i=0; i<SUB_FRAME_SIZE; i=i+1) begin
                    sub_frame[i] <= (((int)frame[i] - 128) * 
                                     (0.54 - 0.46 * $cos(2*3.1415926*i/(SUB_FRAME_SIZE-1)))) >> 6;
                end
            end else begin   // ����������
                for (int i=0; i<SUB_FRAME_SIZE; i=i+1) begin
                    sub_frame[i] <= frame[i] >> 2;
                end
            end
            
            // ����ǰ��֡�洢����������������ƶ���֡����
            sub_frame_index <= OVERLAP_SIZE-1;
            for (int i=0; i<SUB_FRAME_SIZE-OVERLAP_SIZE; i=i+1) begin
                frame[FRAME_SIZE-SUB_FRAME_SIZE+i] <= sub_frame[i+OVERLAP_SIZE];
            end

            // ����MFCCģ�飬����ǰ��֡��Ϊ����
            mfcc_inst.audio_in <= sub_frame;
            
            // �洢MFCC����ֵ
            for (int i=0; i<12; i=i+1) begin
                mfcc_features[i] <= mfcc_inst.mfcc_out[i];
            end
        end else begin
            sub_frame[sub_frame_index] <= sample_value;  // �洢�µĲ���ֵ����ǰ��֡��
            sub_frame_index <= sub_frame_index + 1;      // ������֡����
        end
    end
end

endmodule