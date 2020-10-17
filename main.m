clear,clc,close all
% 车牌识别
%% ======================输入图像===============================
[filename, pathname] = uigetfile('*.jpg;*.bmp;*.png;*.tif', '选择车牌图像');
I = imread([pathname filename]);
I = im2double(I);

%% ======================图像预处理===============================
I1 = rgb2gray(I); % 灰度图
I2 = edge(I1,'Roberts',0.18); % Roberts算子边缘检测
SE = strel('line',3,90);
I3 = imerode(I2,SE); % 腐蚀
SE = strel('rectangle',[25,25]);
I4 = imclose(I3,SE); % 图像聚类，填充图像
I5 = bwareaopen(I4,2000); % 去除聚团灰度值小于2000的部分
[m, n] = size(I5);
%% ======================车牌定位===============================
% Y方向车牌区域确定
area_y = sum(I5,2); % 车牌区域y轴上像素点统计
% MaxY为车牌区域y轴上像素点统计的最大值的位置
[~, MaxY] = max(area_y);
% 从最大值向两边检测
PY1 = MaxY;
while (area_y(PY1)>=5) && (PY1>1) % 找出车牌区域y轴上边界
    PY1 = PY1-1;
end
PY2 = MaxY;
while (area_y(PY2)>=5) && (PY2<m) % 找出车牌区域y轴下边界
    PY2 = PY2+1;
end
IY = I(PY1:PY2,:,:);
% X方向车牌区域确定
area_x = sum(I5); % 车牌区域x轴上像素点统计
% 从两边向中间检测
PX1 = 1;
while (area_x(PX1)<3) && (PX1<n) % 找出车牌区域x轴左边界
    PX1 = PX1+1;
end
PX2 = n;
while (area_x(PX2)<3) && (PX2>PX1) % 找出车牌区域x轴右边界
    PX2 = PX2-1;
end
PX1 = PX1-1; % 对车牌区域的矫正
PX2 = PX2+1;
dw = I(PY1:PY2-5,PX1:PX2,:); % 车牌区域图像


%% %%%%%%%%%%%%%%%%%%%%%%%%车牌区域图像处理%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
b = rgb2gray(dw); % 将车牌图像转换为灰度图
g_max = max(b,[],'all');
g_min = min(b,[],'all');
T = g_max-(g_max-g_min)/3; % T为二值化的阈值
d = imbinarize(b,T); % d:二值图像
% 滤波
h = fspecial('average',3);
% 建立预定义的滤波算子，average为均值滤波，模板尺寸为3*3
d1 = imbinarize(filter2(h,double(d))); % 使用指定的滤波器h对h进行d即均值滤波
% 膨胀或腐蚀
SE = eye(2); % 单位矩阵
[m1,n1] = size(d1); % 返回图像尺寸
if bwarea(d1)/(m1*n1) >= 0.365 % 计算二值图像中对象的总面积与整个面积的比是否大于0.365
    d2 = imerode(d1,SE); % 如果大于0.365则需要腐蚀
elseif bwarea(d1)/(m1*n1) <= 0.235 % 计算二值图像中对象的总面积与整个面积的比值是否小于0.235
    d2 = imdilate(d1,SE); % 如果小于则需要膨胀
else
    d2 = d1;
end

%% ======================字符分割===============================
% 寻找连续有文字的块，若长度大于某阈值，则认为该块有两个字符组成，需要分割
d3 = qiege(d1);
[~, n2] = size(d3);
k1 = 1;
k2 = 1;
s = sum(d3); % 车牌区域x轴上像素点统计
j = 1;
while j < n2
    while s(j) == 0
        j = j+1;
    end
    k1 = j; % 字符左边界
    while s(j)>0 && j<n2
        j = j+1;
    end
    k2 = j-1; % 字符右边界
    if k2-k1 >= round(n2/6.5) % 区域过长
        [~, num] = min(sum(d3(:,k1+5:k2-5)));
        d3(:,k1+5+num) = 0; % 在最小值处分割
    end
end
%再切割
d4 = qiege(d3);

% 切割出7个字符
% 第一个字符为汉字，切割出第一个字符
y1 = 10;
y2 = 0.25;
flag = false;
word = cell(1,7);
while flag == false
    [m2, ~] = size(d4);
    left = 1;
    wide = 0;
    while sum(d4(:,wide+1)) > 0
        wide = wide+1;
    end
    if wide < y1 % 宽度小于10，认为是左干扰
        d4(:,1:wide) = 0;
        d4 = qiege(d4);
    else
        temp = qiege(imcrop(d4,[1 1 wide m2]));
        [m3,~] = size(temp);
        all = sum(temp,'all');
        two_thirds = sum(temp(round(m3/3):round(m3*2/3),:),'all');
        % 一个字符从1/3到2/3处的白色区域占总白色区域的比值大于0.25则存在字符
        if two_thirds/all > y2
            flag = true;
            word{1} = temp; % 取出字符
        end
        d4(:,1:wide) = 0; % 去除已识别字符
        d4 = qiege(d4);
    end
end

% 第二至七个字符为字母和数字，分割出第二至七个字符
for i = 2:7
    [word{i},d4] = getword(d4);
end

% 归一化大小为40*20
for i = 1:7
    word{i} = imresize(word{i},[40 20]);
end

%% ======================字符识别===============================
liccode = ['0':'9' 'A':'Z' '京辽鲁陕苏豫浙'];
Code = '';
SubBw2 = zeros(40,20);
Error = zeros(1,43);
for k = 1:7
    SegBw2 = word{k};
    if k == 1 % 第一位汉字识别
        kmin = 37;
        kmax = 43;
    elseif k == 2 % 第二位字母识别
        kmin = 11;
        kmax = 36;
    elseif k >= 3 % 第三位后字母或数字识别
        kmin = 1;
        kmax = 36;
    end
    for k2 = kmin:kmax
        if (liccode(k2)~='O') && (liccode(k2)~='I') % 车牌中没有字母'O'和'I'
            fname = ['字符模板\',liccode(k2),'.jpg'];
            SamBw2 = imread(fname); % 读取字符模板
        else
            SamBw2 = ones(40,20);
        end
        if size(SamBw2,3) == 3 % 如果是RGB图像，转为灰度图像
            SamBw2 = rgb2gray(SamBw2);
        end
        SamBw2 = imbinarize(SamBw2); % 二值化
        SubBw2 = SegBw2 - SamBw2; % 两幅图相减得第三幅图
        Error(k2) = sum(SubBw2 ~= 0,'all'); % 统计误差
    end
    Error1 = Error(kmin:kmax); % 取出相应字符类型的误差
    [~, findc] = min(Error1); % 找出最小误差
    Code(k) = liccode(findc(1)+kmin-1);
end

%% ======================写入文件===============================
imwrite(b,'1.车牌灰度图像.jpg');
imwrite(d,'2.车牌二值图像.jpg');
imwrite(d1,'4.均值滤波后.jpg');
imwrite(d2,'5.膨胀或腐蚀处理后.jpg');
imwrite(dw,'dw.jpg'); % 将彩色车牌写入dw文件中
for i = 1:7
    imwrite(word{i},[num2str(i) '.jpg']);
end

%% ======================显示结果===============================
figure,imshow(I),title('原图')
figure,imshow(I1),title('灰度图')
figure,imhist(I1),title('灰度化直方图')
figure,imshow(I2),title('边缘检测')
figure,imshow(dw),title('定位车牌')
figure
for i = 1:7
    subplot(1,7,i),imshow(word{i}),title(num2str(i))
end
figure,imshow(dw),title(['车牌号码：',Code])




