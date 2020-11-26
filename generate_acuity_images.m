function generate_acuity_images(subexpIDs, agent, hor_FOV, overwriteFlag, camID)
% This function applies the acuity filter to first person view frames of
% selected subjects. 
% ***This function make use of a toolbox that only runs on linux machines.
% input:
%   subExpIDs: can be either a list of subjects from the same experiment or
%       a single experiment ID.
%   agent: either 'child' or 'parent'
%   hor_FOV: horizontal field of view in Euler degree. E.g. for exp 12,
%       hor_FOV = 70
%   overrideFlag: optional, determine whether to override the existing
%       acuity images
%   camID: optional, specify which folder conatins the raw egocentric view
%       images. If not given, set camID to 'cam07' for child and set camID
%       to 'cam08' for parent


addpath('/data/dianzhi/util')
addpath(genpath('/cantor/space/dianzhi/scripts/svens_matlab_code-master'))

if ~exist('camID', 'var') || nargin < 5
    if strcmp(agent, 'child')
        camID = 'cam07';
    elseif strcmp(agent, 'parent')
        camID = 'cam08';
    end
end

if ~exist('overwriteFlag', 'var') || nargin < 4
    overwriteFlag = false;
end


subs = cIDs(subexpIDs);

% Check if the user entered subjects from more than one experiment. If yes, raise error message
expID = unique(sub2exp(subs));
if numel(expID) > 1
    error('[-] Your entered subjects are from more than one experiment. Please run one experiment at a time.')
end

for sub = subs'
    
    % check to see if the subject has gaze variable. If not exist, skip to next subject
    if ~has_variable(sub, ['cont2_eye_xy_' agent])
        warning(['[-] Subject ' num2str(sub) ' does not have cont2_eye_xy_' agent ' variable. Skipped'])
        continue
    end
    
    sub_root = get_subject_dir(sub);
    raw_img_dir = fullfile(sub_root, [camID '_frames_p']);
    
    % check the existence of the raw egocentric frame folder. If not exist, skip to next subject
    if ~exist(raw_img_dir, 'dir')
        warning(['[-] Subject ' num2str(sub) ' does not have ' camID '_frames_p folder. Skipped'])
        continue
    end
    
    % look for raw images. If no images detected, skip to next subject
    dir_struct = dir(fullfile(raw_img_dir, 'img_*.jpg'));
    if numel(dir_struct) == 0
        warning(['[-] Subject ' num2str(sub) ' no images were found under ' camID '_frames_p folder. Skipped'])
        continue
    end
    
    % check for the existence of acuity folder, if not exist, create one
    acuity_img_dir = fullfile(sub_root, [camID '_acuity_p']);
    if ~exist(acuity_img_dir, 'dir')
        try
            mkdir(acuity_img_dir)
        catch ME
            disp(ME.message)
            continue
        end
    end
    
    % get all the raw egocentric frame paths (sorted) & IDs
    sorted_dir_struct = sort_file_name_by_seq(dir_struct);
    img_paths = strcat(raw_img_dir, filesep(), {sorted_dir_struct.name})';
    img_ids = cellfun(@(x) str2double(x(5:end-4)), {sorted_dir_struct.name}, 'UniformOutput', false)';
    img_ids = sscanf(sprintf('%d ', img_ids{:}), '%d');
    
    % load the first image and get frame resolution
    [img_y, img_x, ~] = size(imread(img_paths{1}));
    
    % convert image frame nunmbers to timestamps
    corresponding_ts = frame_num2time(img_ids, sub);
    
    % load gaze
    gaze_cont = get_variable(sub, ['cont2_eye_xy_' agent]);
    
    for i = 1: numel(img_paths)
        img_path = img_paths{i};
        disp(['[*] Processing image ' img_path])
        
        % check for the existence of the acuity image. If not overwrite and the image already exist, skip this image
        acuity_img_path = fullfile(acuity_img_dir, ['img_' num2str(img_ids(i)) '.jpg']);
        if ~overwriteFlag && exist(acuity_img_path, 'file')
            continue
        end
        
        current_ts = corresponding_ts(i);
        gaze_row = gaze_cont(abs(gaze_cont(:, 1)-current_ts) < 0.01, :);
        gaze_x = gaze_row(2);
        gaze_y = gaze_row(3);
        
        % if the gaze_x and gaze_y are not fall within the FOV (> imgx/y or <1 or is NaN), skip the frame
        if isnan(gaze_x) || isnan(gaze_y) || gaze_x > img_x || gaze_y > img_y || gaze_x < 1 || gaze_y < 1
            warning('[-] The gaze xy point is not within the FOV, Skipped')
            continue
        end
        
        % Horizontal field of view of the camera that captured the frame need to be multiplied by two.
        acuity_image = simulate_real_acuity(img_path, [gaze_y, gaze_x], hor_FOV * 2);
        imwrite(acuity_image, acuity_img_path)
    end
end
end