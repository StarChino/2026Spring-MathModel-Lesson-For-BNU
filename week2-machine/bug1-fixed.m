%% 这是一个只考虑了风速和风向的洛杉矶着火模拟
% 不考虑原始地形
% 没有赋值RGB,灰白色图层

%  初始化 
[X,Y] = meshgrid(1:200);
Z = peaks(200); % 基础地形
Z(50:70,30:50) = Z(50:70,30:50)*0.3; % 模拟峡谷

states = zeros(size(Z)); % 0:空地 1:植被 2:燃烧 3:建筑物 4:烧毁
flammability = zeros(size(Z)); % 易燃系数矩阵

wind_dir = [1, -1]; % 东北风向量
wind_speed = 0.7; % 0-1区间

% 灌木易燃区（洛杉矶特征）
flammability(Z > 0.5) = 0.9; % 山地灌木
flammability(Z <= 0.5) = 0.6; % 平缓区域
flammability(rand(size(Z))<0.05) = 0.2; % 人工绿化带

buildings = randi([0 1],200,200); % 随机建筑分布
buildings(180:200,:) = buildings(180:200,:).*0.3; % 模拟贫民区密集建筑
states(buildings==1) = 3; 

% 让未被建筑覆盖的区域随机分配植被
veg_density = 0.7; % 植被覆盖率
rand_veg = rand(size(Z)) < veg_density;
states(rand_veg & states == 0) = 1; % 让这些地方变成植被

% 让部分区域有更稠密的植被，比如山地和峡谷
states(Z > 0.5 & rand(size(Z)) < 0.8) = 1; % 80% 概率成为植被

fire_dept = ones(size(Z))*0.8; % 基础灭火概率
fire_dept(90:110,80:120) = 0.2; % 预算削减区域
fire_dept(rand(size(Z))<0.1) = 0; % 无水消防栓
figure;
colormap([0.8 0.8 0.8;   % 空地 - 灰色
          0.1 0.7 0.1;   % 植被 - 绿色（调整为更亮的绿色）
          1   0.0 0;     % 燃烧 - 红色
          0.5 0.5 0.5;   % 建筑 - 深灰
          0.1 0.1 0.1]); % 烧毁 - 黑色

% 设置初始火点（模拟多起火点）
states(50,50) = 2;
states(180,30) = 2;
states(150,170) = 2;

%% 主循环
for t = 1:300
    % 风场实时变化（圣安娜风增强）
    if mod(t,50)==0
        wind_speed = min(wind_speed*1.2, 0.95);
    end
    
    % 地形影响计算
    slope_effect = abs(gradient(Z))*3; % 坡度加速燃烧
    
    new_states = states;
    [rows,cols] = size(states);
    
    for i = 2:rows-1
        for j = 2:cols-1
            if states(i,j) == 2 % 燃烧状态
                % 消防系统作用
                if rand() < fire_dept(i,j)
                    new_states(i,j) = 0; % 灭火成功
                else
                    new_states(i,j) = 4; % 变为烧毁状态
                end
                
                % 传播火焰
                for dx = -1:1
                    for dy = -1:1
                        ni = i+dx;
                        nj = j+dy;
                        % 风场影响计算
                        wind_effect = dot([dx,dy], wind_dir)*wind_speed;
                        
                        if rand() < (0.3 + wind_effect + slope_effect(i,j))* flammability(ni,nj)   #原文件疑似未正确换行出错
                            if states(ni,nj)==1 || states(ni,nj)==3
                                new_states(ni,nj) = 2;
                            end
                        end
                    end
                end
                
            elseif (states(i,j) > 0 && states(i,j) < 2) || states(i,j) == 3 % 植被/建筑物
                % 基础设施隐患（随机自燃）
                if rand() < 0.0001*flammability(i,j) 
                    new_states(i,j) = 2;
                end
            end
        end
    end
    
    states = new_states;
    
    % 可视化
    imagesc(states);
    title(sprintf('洛杉矶大火模拟 t=%d 风速%.2f',t,wind_speed));
    drawnow;
    
    % 保存动画帧
    frame = getframe(gcf);
    im{t} = frame2im(frame);
end

% 保存为GIF
filename = 'la_fire_simulation.gif';
for idx = 1:length(im)
    [A,map] = rgb2ind(im{idx},256);
    if idx == 1
        imwrite(A,map,filename,'gif','LoopCount',Inf,'DelayTime',0.1);
    else
        imwrite(A,map,filename,'gif','WriteMode','append','DelayTime',0.1);
    end
end

