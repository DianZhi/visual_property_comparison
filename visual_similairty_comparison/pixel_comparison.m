function result = pixel_comparison(img_path)
im = imread(img_path);
im = imresize(im, [100, 100]);
result = reshape(im, [], 1);
end