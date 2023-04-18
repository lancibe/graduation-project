module mic_sampling_quantization_with_windowing
(
    input clk,      // FPGA 的时钟信号
    input reset,    // 重置信号
    input mic_in,   // 话筒输入信号
    output reg [7:0] sample_out,   // 输出采样和量化后的数字信号
    output reg sample_ready       // 输出采样完成信号
);

parameter FRAME_SIZE = 256;        // 采样帧大小
parameter SUB_FRAME_SIZE = 64;     // 子帧大小
parameter OVERLAP_SIZE = 16;       // 重叠区域大小
parameter HAMMING_WINDOW = 1;      // 是否使用汉明窗

reg [7:0] sample_value;            // 存储采样值

reg [7:0] frame [FRAME_SIZE-1:0];     // 存储采样帧数据
reg [7:0] sub_frame [SUB_FRAME_SIZE-1:0];  // 存储当前子帧数据
reg sub_frame_index = 0;           // 当前子帧索引

// 实例化MFCC模块，将每个子帧作为输入
mfcc_module mfcc_inst (
    .clk(clk),
    .reset(reset),
    .audio_in(sub_frame),
    .mfcc_out(mfcc_features)
);

reg [31:0] mfcc_features [11:0];  // 存储MFCC特征值

always @(posedge clk) begin
    if (reset) begin   // 如果重置信号为高电平，则清零采样值和输出信号
        sample_value <= 8'h00;
        sample_out <= 8'h00;
        sample_ready <= 1'b0;
        frame <= {FRAME_SIZE{8'h00}};
        sub_frame <= {SUB_FRAME_SIZE{8'h00}};
        sub_frame_index <= 0;
        mfcc_features <= {12{32'h00000000}};
    end else begin
        // 从话筒输入信号中进行采样，最后将其量化为 8 位数字信号
        sample_value <= mic_in;
        sample_out <= sample_value >> 1;   // 右移一位进行量化
        sample_ready <= 1'b1;              // 设置采样完成信号
        
        frame[FRAME_SIZE-1:1] <= frame[FRAME_SIZE-2:0];   // 移动采样帧数据
        frame[0] <= sample_value;                         // 存储新的采样值
        
        if (sub_frame_index == SUB_FRAME_SIZE - 1) begin   // 如果当前子帧存满了，执行加窗和分割操作
            if (HAMMING_WINDOW) begin   // 汉明窗处理
                for (int i=0; i<SUB_FRAME_SIZE; i=i+1) begin
                    sub_frame[i] <= (((int)frame[i] - 128) * 
                                     (0.54 - 0.46 * $cos(2*3.1415926*i/(SUB_FRAME_SIZE-1)))) >> 6;
                end
            end else begin   // 海宁窗处理
                for (int i=0; i<SUB_FRAME_SIZE; i=i+1) begin
                    sub_frame[i] <= frame[i] >> 2;
                end
            end
            
            // 将当前子帧存储到输出缓冲区，并移动子帧索引
            sub_frame_index <= OVERLAP_SIZE-1;
            for (int i=0; i<SUB_FRAME_SIZE-OVERLAP_SIZE; i=i+1) begin
                frame[FRAME_SIZE-SUB_FRAME_SIZE+i] <= sub_frame[i+OVERLAP_SIZE];
            end

            // 调用MFCC模块，将当前子帧作为输入
            mfcc_inst.audio_in <= sub_frame;
            
            // 存储MFCC特征值
            for (int i=0; i<12; i=i+1) begin
                mfcc_features[i] <= mfcc_inst.mfcc_out[i];
            end
        end else begin
            sub_frame[sub_frame_index] <= sample_value;  // 存储新的采样值到当前子帧中
            sub_frame_index <= sub_frame_index + 1;      // 更新子帧索引
        end
    end
end

endmodule