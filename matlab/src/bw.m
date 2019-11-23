clear;
clc;
close all;

% read a image
img = imread('800x600.png');
imshow(img);
title('original image');

[size_h, size_w, o] = size(img);
% size_h = size_h;
% size_w = size_w;
new_img_nnp = zeros(size_h, size_w, 3);

degree = input('input to degree : ');
c = round(cosd(degree) * 16384);
s = round(sind(degree) * 16384);

group_ac = {size_h};
group_as = {size_h};
group_400_add_bc = {size_w};
group_300_diff_bs = {size_w};
for i = 1:size_w
    a = i - size_h/2;
    ac = a * c;
    as = a * s;

    if i <= size_h
        group_ac{i} = ac;
        group_as{i} = as;
    end

    bc = ac - round(size_w/2 - size_h/2) * c;
    bs = as - round(size_w/2 - size_h/2) * s;
    group_400_add_bc{i} = bc + bitshift(round(size_w/2), 14, 'int64');
    group_300_diff_bs{i} = bitshift(round(size_h/2), 14, 'int64') - bs;
end

for j = 1:size_h
    % a = j-300;

    for i = 1:size_w
        % b = i-400;

        % col = b*c + a*s + bitshift(400, 14, 'int64');
        % row = -b*s + a*c + bitshift(300, 14, 'int64');
        col = group_400_add_bc{i} + group_as{j};
        row = group_300_diff_bs{i} + group_ac{j};

        x1 = bitshift(col, -14, 'int64');
        y1 = bitshift(row, -14, 'int64');
        x2 = x1 + 1;
        y2 = y1 + 1;

        col_round = bitshift((bitshift(col, -13, 'int64') + 1), -1, 'int64');
        row_round = bitshift((bitshift(row, -13, 'int64') + 1), -1, 'int64');
        if row_round < 1 || col_round < 1 || row_round > size_h || col_round > size_w
            new_img_nnp(j, i) = 0;
        elseif row_round == 1 || col_round == 1 || row_round == size_h || col_round == size_w
            new_img_nnp(j, i, 1) = img(row_round, col_round, 1);
            new_img_nnp(j, i, 2) = img(row_round, col_round, 2);
            new_img_nnp(j, i, 3) = img(row_round, col_round, 3);
        else
            decimal_bits = 12;
            val_bits = 14 - decimal_bits;

            decimal_col = bitshift(col - bitshift(x1, 14, 'int64'), -decimal_bits, 'int64');
            decimal_row = bitshift(row - bitshift(y1, 14, 'int64'), -decimal_bits, 'int64');

            for channel = 1:3
                val11 = double(img(y1, x1, channel));
                val21 = double(img(y2, x1, channel));
                val12 = double(img(y1, x2, channel));
                val22 = double(img(y2, x2, channel));

                temp_b = (val21 - val11) * decimal_row + bitshift(val11, val_bits, 'int64');
                temp_a = (val22 - val12) * decimal_row + bitshift(val12, val_bits, 'int64') - temp_b;
                val =  bitshift(temp_a * decimal_col, -val_bits, 'int64') + temp_b;
                new_img_nnp(j, i, channel) = bitshift(val, -val_bits, 'int64');
            end
        end
    end
end
figure, imshow(new_img_nnp/255), title('bw');
