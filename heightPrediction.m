door_height = 2;

img = imread('image/1.jpg');
I = rgb2gray(img);
figure(1); imshow(I);

bw = edge(I, 'sobel', 0.03); % bw is logical 二值图
se = strel('disk', 1);
bw = imclose(bw, se); % 填平狭窄断裂
figure(2); imshow(bw);

[H, T, R] = hough(bw); % H为二值图经过霍夫变换后得到的矩阵，即参数空间矩阵
P = houghpeaks(H, 5); % P为参数矩阵的极大值点的坐标，对应图像空间直线参数方程的ρ和θ
% 线段合并，舍弃，提取 https://blog.csdn.net/xsjwangyb/article/details/10917945
lines = houghlines(bw, T, R, P, 'FillGap', 500, 'Minlength', 7);

figure(3); imshow(I);
hold on;
	for	k = 1:length(lines)
		xy = [lines(k).point1; lines(k).point2];
		plot(xy(:,1), xy(:,2), 'LineWidth', 2, 'Color', 'green');
		plot(xy(1,1), xy(1,2), 'x', 'LineWidth', 2, 'Color', 'yellow');
		plot(xy(2,1), xy(2,2), 'x', 'LineWidth', 2, 'Color', 'red');
	end
hold off;

p1 = cat(1, lines.point1); % https://baike.baidu.com/item/cat/4623515?fr=aladdin
p2 = cat(1, lines.point2);
pcnt = size(p1, 1); pselect = []; cnt = 0;
for i = 1:pcnt-1
	for j = i:pcnt
		a.x = p1(i, 1); a.y = p1(i, 2); b.x = p2(i, 1); b.y = p2(i, 2);
		c.x = p1(j, 1); c.y = p1(j, 2); d.x = p2(j, 1); d.y = p2(j, 2);
		dnm = (b.y - a.y)*(d.x - c.x) - (b.x - a.x)*(d.y - c.y);
		if abs(dnm) < 200
			continue;
		end
		% 已知四个点求交点
		x = ((b.x - a.x) * (d.x - c.x) * (c.y - a.y) + (b.y - a.y) * (d.x - c.x) * a.x ...
					- (d.y - c.y) * (b.x - a.x) *	c.x) / dnm;
		y = -((b.y - a.y) * (d.y - c.y) * (c.x - a.x) + (b.x - a.x) * (d.y - c.y) * a.y ...
					- (d.x - c.x) * (b.y - a.y) * c.y) / dnm;
		cnt = cnt + 1;
		pselect(cnt, 1:2) = [x y];
	end
end
figure(4); imshow(I);
hold on; plot(pselect(:, 1), pselect(:, 2), 'r+'); hold off;
% 交点过滤
pselect = round(pselect); pcorner = []; ccnt = 0;
for i = 1:cnt
	if pselect(i, 1) > 0 && pselect(i, 1) <= 250 && pselect(i, 2) > 0 && pselect(i, 2) <= 390
		 ccnt = ccnt + 1;
		 pcorner(ccnt, 1:2) = pselect(i, 1:2);
	end
end

% 确定4个顶点
loccir = mean(pcorner(:, :));
% 质心做原点
disxy(:, 1) = pcorner(:, 1) - loccir(1);
disxy(:, 2) = pcorner(:, 2) - loccir(2);
disflag = disxy>0;
% 0+3 1+3 0+1 1+1
ind = xor(disflag(:, 1), disflag(:, 2)) + disflag(:, 2) * 2 + 1; 
for i=1:4
	flag = ind==i;
	tempoints = pcorner(flag,:);
	dis = (tempoints(:, 1) - loccir(1)).^2 + (tempoints(:, 2) - loccir(2)).^2;
	% 返回第一个距离为最大距离的下标（该点）
	pidx = find(dis == max(dis), 1, 'first');
	ROIpoints(i, :) = tempoints(pidx, :);
end
figure(5); imshow(I);
hold on; plot(ROIpoints(:, 1), ROIpoints(:, 2), 'r+'); hold off;

% 变换 变换矩阵 x是列数，y是行数
x = ROIpoints(:, 2); y = ROIpoints(:, 1);
width = round(max(x) - min(x)); height = round(max(y) - min(y));
Y(1) = min(y); Y(4) = Y(1); Y(2:3) = Y(1) + height;
X(1:2) = min(x); X(3:4) = X(1) + width;
% 变换矩阵
tform = fitgeotrans(ROIpoints, [Y' X'], 'Projective'); % https://blog.csdn.net/xiamentingtao/article/details/50810121
% 输出视图
output = imref2d(size(I)); % 将图片放到世界坐标系下，即标上刻度
% 将变化矩阵应用到输入图像，并呈现在输出视图上
Is = imwarp(I, tform, 'OutputView', output);
figure(6); imshow(Is);
hold on; plot(Y, X, 'r+'); hold off;

ROIimg = Is(X(2):X(4), Y(1):Y(3));
figure(8); imshow(ROIimg);
hm = X(3) - X(1);

bw1 = edge(ROIimg, 'canny', 0.16); % bw is logical 二值图
se = strel('disk', 1);
bw1 = imclose(bw1, se); % 填平狭窄断裂
figure(9); imshow(bw1);

[bbox, ROI] = getmaxROI(bw1);
ROIimgselect = ROIimg(bbox(2):bbox(4), bbox(1):bbox(3));
figure(10); imshow(ROIimgselect);

hr = bbox(4) - bbox(2);
human_height = door_height * (hr/hm)