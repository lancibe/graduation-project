% 定义滤波器组 
b_lpf = fir1(20, 0.3, 'low'); % 低通滤波器 
b_hpf = fir1(20, 0.5, 'high'); % 高通滤波器

% 生成测试信号 
fs = 1000; % 采样频率 
t = 0 : 1/fs : 1; % 时间 
x = cos(2*pi*100*t) + cos(2*pi*1000*t); % 混叠信号

% 过滤 
y_lpf = filter(b_lpf, 1, x); % 低通滤波 
y_hpf = filter(b_hpf, 1, x); % 高通滤波

% 绘制滤波结果 
figure; subplot(3,1,1); plot(t, x); title('原始信号');

subplot(3,1,2); plot(t, y_lpf); title('低通滤波结果');

subplot(313); plot(t, y_hpf); title('高通滤波结果');