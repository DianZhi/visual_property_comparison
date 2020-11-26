%%
% the script that generate test cropped images for subject 4521 and 4522 (dummy subjects)
root_dir = fullfile(get_multidir_root, 'experiment_45', 'included', 'all_objs', 'child');
patch_sz = 100;

% generated frames should be named in the followig format: subID_fnum_objID
% subject 4521 and 4522 are used for testing
subs = [4521 4522];
num_frames = 180;
for sub = subs
    sub_str = num2str(sub);
    subrois = randi(3, [num_frames, 1]);
    tb = make_time_base(sub);
    cst = [tb, subrois];
    cev = cstream2cevent(cst);
    record_variable(sub, 'cstream_eye_roi_child', cst)
    record_variable(sub, 'cevent_eye_roi_child', cev)
    for i = 1:num_frames
        if randi(10) > 8
            continue
        end
        current_roi = subrois(i);
        rgb = zeros(1, 3);
        rgb(current_roi) = 1;
        im = make_square(make_color_patch([patch_sz, randi(2)*50], rgb));
        im_savepath = fullfile(root_dir, num2str(current_roi), [sub_str '_' num2str(i) '_' num2str(current_roi) '.jpg']);
        imwrite(im, im_savepath)
    end
end


% function that create color patch
function im = make_color_patch(sz, rgb)
r = ones(sz(1), sz(2)) * rgb(1);
g = ones(sz(1), sz(2)) * rgb(2);
b = ones(sz(1), sz(2)) * rgb(3);
im(:, :, 1) = r;
im(:, :, 2) = g;
im(:, :, 3) = b;
end

% function that make color patch square by adding black to the shorter side
function square_patch = make_square(im)
h = size(im, 1);
w = size(im, 2);
square_patch = zeros(max(h, w));
square_patch(1:h, 1:w, 1) = im(1, 1, 1);
square_patch(1:h, 1:w, 2) = im(1, 1, 2);
square_patch(1:h, 1:w, 3) = im(1, 1, 3);
end