% 元胞自动机 
% 森林火灾模型规则:
% (1) 正在燃烧的树变成空格位;
% (2) 如果绿树格位的最近邻居中有一个树在燃烧, 则它依概率 q 变成正在燃烧的树;
% (3) 在空格位, 树以概率 p 生长;
% (4) 在最近的邻居中没有正在燃烧的树的情况下树在每一时步以概率 f (闪电) 变为正在燃烧的树.
% 参考文献: 祝玉学, 赵学龙译, <<物理系统的元胞自动机模拟>>, P23
% S == 2 燃烧
% S == 1 绿树
% S == 0 已燃
clear, clc, close all;
figure;
p = 0.00001;
q = 0.7;
f = 0.005;
M = 100;	% 森林边长
rng('default');
rng('shuffle');
S = randi([0, 1], M);	% 随机初始化森林状态
Sk = zeros(M + 2);
Sk(2 : M + 1, 2 : M + 1) = S;	% 加边开始的森林初值 这是为了使边界上的元胞使用一样的判定规则
% 红色表示正在燃烧(S中等于2的位置) 
% 绿色表示绿树(S中等于1的位置) 
% 黑色表示空格位(S中等于0的位置)
C = zeros(M + 2, M + 2, 3);
R = zeros(M);
G = zeros(M);
R(S == 2) = 1;
G(S == 1) = 1;
C(2 : M + 1, 2 : M + 1, 1) = R;   %红色图层
C(2 : M + 1, 2 : M + 1, 2) = G;   %绿色图层
Ci = imshow(C, 'InitialMagnification', 'fit');
tp = title('T = 0');	% 时间记录
% 在循环前添加
videoObj = VideoWriter('forest_fire.avi'); 
videoObj.FrameRate = 10; % 设置帧率
open(videoObj);
for ti = 1 : 100
	%% (1)
	St = Sk;	% St表示t时刻的森林情况
	St(Sk == 2) = 0;

	%% (2)被燃烧
	Su = zeros(M + 2);
	Sf = Sk;	% Sf表示模拟着火的过程
	Sf(Sf < 1.5) = 0;	% 只留下着火点
	Sf = Sf / 2;	% 着火点变为1, 此处Sf只有着火和空格两种
	% 平移后八个方向叠加, 记录下Su周围八个点, 有多少个在燃烧
	Su(2 : M + 1, 2 : M + 1) = ( ...
		  Sf(1 : M, 1 : M)		   + Sf(1 : M, 2 : M + 1) ...
		+ Sf(1 : M, 3 : M + 2)	   + Sf(2 : M + 1, 1 : M) ...
		+ Sf(2 : M + 1, 3 : M + 2) + Sf(3 : M + 2, 1 : M) ...
		+ Sf(3 : M + 2, 2 : M + 1) + Sf(3 : M + 2, 3 : M + 2) ...
	) .* Sk(2 : M + 1, 2 : M + 1);
	d = find(Su > 0.5);
	d_len = length(d);
	r = rand(d_len, 1);
	Su(d) = round(2 * (r <= q) + (r > q));
	Su(Su < 0.5) = 1;
	St = St .* Su;	% Sf -> St着火, 空白, 树

	%% (3)长树
    % 将森林的空白处变为1, 其他地方为0
	Se = Sk(2 : M + 1, 2 : M + 1);
	Se(Se < 0.5) = 4;	% 空白地方赋值为4
	Se(Se < 3) = 0;	% 有树和着火赋值为0
	Se(Se > 3) = 1;	% 空白地方赋值为1
	% 长树, 更新t时刻的森林St
	St(2 : M + 1, 2 : M + 1) = St(2 : M + 1, 2 : M + 1) + Se .* (rand(M) < p);

	%% (4)周围没有燃烧的树，自然着火的树
	Ss = zeros(M + 2);
	Ss(Sk == 2) = 1;	% 讨论邻居的燃烧情况
	% 平移后八个方向叠加, 记录下Ss周围八个点, 有多少个树在燃烧
	Ss(2 : M + 1, 2 : M + 1) = ...
		  Ss(1 : M, 1 : M)		   + Ss(1 : M, 2 : M + 1) ...
		+ Ss(1 : M, 3 : M + 2)	   + Ss(2 : M + 1, 1 : M) ...
		+ Ss(2 : M + 1, 3 : M + 2) + Ss(3 : M + 2, 1 : M) ...
		+ Ss(3 : M + 2, 2 : M + 1) + Ss(3 : M + 2, 3 : M + 2);
	Ss(Ss > 0.5) = 1;
	Ss(Ss < 0.5) = 0;
	d = find(Ss == 0 & Sk == 1); %周围没有燃烧的树（Ss == 0)，目前还绿着（Sk == 1)
	d_len = length(d);
	r = rand(d_len, 1);
	St(d) = round(2 * (r <= f) + (r > f)); %以一定概率自燃

	%% 更新t时刻的森林St
	Sk = St;
	R = zeros(M + 2);
	G = zeros(M + 2);
	R(Sk == 2) = 1;
	G(Sk == 1) = 1;
	C(:, :, 1) = R;
	C(:, :, 2) = G;
	set(Ci, 'CData', C);
	set(tp, 'string', ['T = ', num2str(ti)]);
	pause(0.01);
    % 在循环内添加（放在set(tp...)之后）
    frame = getframe(gcf);
    writeVideo(videoObj, frame);
end
% % 在循环结束后添加
close(videoObj); #源文件疑似此处注释掉导致无法保存视频
