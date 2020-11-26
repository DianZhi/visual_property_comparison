function generate_cropped_images(subexpIDs, agent, mappings, overwriteFlag, camID)

subs = cIDs(subexpIDs);
% Check if the user entered subjects from more than one experiment. If yes, raise error message
expID = unique(sub2exp(subs));
if numel(expID) > 1
    error('[-] Your entered subjects are from more than one experiment. Please run one experiment at a time.')
end

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

% if expID is 15, the box data mapping is: row 1:8 map to objectIDs
% 1:8; row 9, 11, 12 all map to objectID 9; row 10 map to objectID 10.
if expID == 15 && strcmp(mappings, 'exp15')
    mappings = [1:10 9 9];
end

for sub = subs'
    % check to see if the subject has ROI variable. If not exist, skip to next subject
    if ~has_variable(sub, ['cstream_eye_roi_' agent])
        warning(['[-] Subject ' num2str(sub) ' does not have cstream_eye_roi_' agent ' variable. Skipped'])
        continue
    end
    
    sub_root = get_subject_dir(sub);
    box_path = fullfile(sub_root, 'extra_p', [num2str(sub) '_' agent '_boxes.mat']); 
    % check to see if the subject has bbox file. If not exist, skip to next subject
    if ~exist(box_path, 'file')
        warning(['[-] Subject ' num2str(sub) ' does not have ' agent ' bounding box file. Skipped'])
        continue
    end
    
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
    
    % create crop root folder for the current subject if it doesn't exist
%     crop_root = fullfile(sub_root, [camID '_images_objs']);
    crop_root = fullfile(get_multidir_root(), ['experiment_' num2str(expID)], 'included', 'all_objs', agent);
    mkdir_if_not_exist(crop_root);
    
    % loop through all the objectIDs and create object folders (if not exist yet)
    objIDs = unique(mappings);
    for i = 1:numel(objIDs)
        current_obj = objIDs(i);
        obj_root = fullfile(crop_root, num2str(current_obj));
        mkdir_if_not_exist(obj_root)
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
    
    % load ROI
    roi = get_variable(sub, ['cstream_eye_roi_' agent]);
    
    % load box data
    load(box_path)
    if isa(box_data, 'struct')
        try
            box_fnums = [box_data(:).frame_id]';
            box_coords = {box_data(:).post_boxes}';
        catch ME
            disp(['[-] The loaded ' sub ' box struct is not in the standard format'])
            assignin('base', 'box_data', box_data)
            error(ME.message)
        end
    elseif isa(box_data, 'cell')
        box_fnums = double([box_data{:, 3}]');
        box_coords = box_data(:, 4);
    else
        warning('[-] The box file is neither a cell array nor a struct. Not the standard data format. Skipped')
    end
    
    %
    for i = 1:numel(img_paths)
        current_fnum = img_ids(i);
        disp(['[*] Processing subject ' num2str(sub) ' frame ' num2str(current_fnum)])
        img_path = img_paths{i};
        current_ts = corresponding_ts(i);
        current_roi = roi(abs(roi(:, 1)-current_ts) < 0.01, 2);
        try
            current_boxes = box_coords{box_fnums == current_fnum};
        catch
            warning(['[-] No detection found for subject ' num2str(sub) ' frame ' num2str(current_fnum)])
        end
        if ismember(current_roi, mappings)
            crop_savepath = fullfile(crop_root, num2str(current_roi), [num2str(sub) '_' num2str(current_fnum) '_' num2str(current_roi) '.jpg']);
            if ~overwriteFlag && exist(crop_savepath, 'file')
                continue
            end
            
            box_rows = current_boxes(mappings == current_roi, :);
            
            % get rid of box rows that have NaN values
            box_rows = box_rows(sum(isnan(box_rows), 2) == 0, :);
            box_row = box_rows(sum(box_rows ~= 0, 2) >= 2, :);
            if size(box_row, 1) ~= 1
                warning('[!] There were no object / more than one object detected. Skip this frame')
                continue
            end
            
            % the experiment 12 was using yolo detection and the box
            % format is: centerx, centery, width, height rather than
            % topleftx, toplefty, width, height
            if expID == 12
                box_row = centerxy2topleftxy(box_row);
            end
            
            box_row = trim_box_to_frame(box_row, img_x, img_y);
            
            % get topleft corner and bottomright corner xy axis
            tl_x = box_row(1);
            tl_y = box_row(2);
            br_x = (box_row(1) + box_row(3));
            br_y = (box_row(2) + box_row(4));
                
            % load current image and do the cropping
            im = imread(img_path);
            cropped_img = im(tl_y:br_y, tl_x:br_x, :);
            imwrite(cropped_img, crop_savepath)
        end
    end
end
end

function mkdir_if_not_exist(dirPath)
if ~exist(dirPath, 'dir')
    mkdir(dirPath)
end
end

function new_boxes = centerxy2topleftxy(boxes)
new_boxes = nan(size(boxes));
new_boxes(:, 1) = boxes(:, 1) - boxes(:, 3) / 2;
new_boxes(:, 2) = boxes(:, 2) - boxes(:, 4) / 2;
new_boxes(:, 3) = boxes(:, 3);
new_boxes(:, 4) = boxes(:, 4);
end

function new_boxes = trim_box_to_frame(boxes, img_x, img_y)
new_boxes(:, 1) = max(1, min(ceil(boxes(:, 1)*img_x), img_x));
new_boxes(:, 2) = max(1, min(ceil(boxes(:, 2)*img_y), img_y));
new_boxes(:, 3) = max(1, min(ceil(boxes(:, 3)*img_x), img_x-new_boxes(:, 1)));
new_boxes(:, 4) = max(1, min(ceil(boxes(:, 4)*img_y), img_y-new_boxes(:, 2)));
end