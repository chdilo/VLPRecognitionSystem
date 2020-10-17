function J = qiege(I)
% 切割去除图像上下左右边界的数值为0的像素
% I,输入待切割图像
% J,输出切割后图像
[m, n] = size(I);
top = 1;
bottom = m;
left = 1;
right = n;
while sum(I(top,:))==0 && top<=m
    top = top+1;
end
while sum(I(bottom,:))==0 && bottom>1
    bottom = bottom-1;
end
while sum(I(:,left))==0 && left<n
    left = left + 1;
end
while sum(I(:,right))==0 && right>=1
    right = right - 1;
end
width = right - left;
height = bottom - top;
J = imcrop(I, [left top width height]);
end