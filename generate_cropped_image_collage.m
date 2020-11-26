function generate_cropped_image_collage(expIDs, agent, generateAllFlag, overwriteFlag, collage_width)

addpath(genpath('Z:\dianzhi\scripts\svens_matlab_code-master')) % add sven repo to the matlab search paths

if nargin < 5 || ~exist('collage_width', 'var')
    collage_width = 2000;
end

if nargin < 4 || ~exist('overwriteFlag', 'var')
    overwriteFlag = false;
end

if nargin < 3 || ~exist('generateAllFlag', 'var')
    generateAllFlag = false;
end

expIDs = unique(sub2exp(cIDs(expIDs)));

for exp = expIDs'
    subIDs = cIDs(exp);
    root = fullfile(get_multidir_root, ['experiment_' num2str(exp)], 'included', 'all_objs', agent);
    root_dir_struct = dir(root);
    
    % get the full path name of the object folders
    obj_dir_names = {root_dir_struct.name};
    obj_dir_names = obj_dir_names([root_dir_struct.isdir]);
    obj_dirs = {};
    for i = 1:numel(obj_dir_names)
        obj_dirID = str2num(obj_dir_names{i});
        if ~isempty(obj_dirID)
            obj_dirs{end+1} = obj_dir_names{i};
        end
    end
    obj_dirs = fullfile(root, obj_dirs);
    
    % loop through the object folders
    for i = 1:numel(obj_dirs)
        clear img_struct collage collage_savepath 
        current_obj_dir = obj_dirs{i};
        objID = str2num(current_obj_dir(find(current_obj_dir == filesep(), 1, 'last')+1:end));
        
        % check to see if the subs dir is created or not
        subs_dir = fullfile(current_obj_dir, 'subs');
        if ~exist(subs_dir, 'dir')
            warning(['[!] subs folder does not exist for experiment ' num2str(exp) ' object ' num2str(objID) '. The script will create the folder automaticaly'])
            mkdir(subs_dir)
        end
        
        for sub = subIDs'
            disp(['[*] Processing object ' num2str(objID) ' for subject ' num2str(sub)])
            
            % check to see if the file already exist or not. If exists, based on the overwrite flag, determine whether to overwrite the current subject collage or not
            collage_savepath = fullfile(subs_dir, [num2str(sub) '_' num2str(objID) '.jpg']);
            if exist(collage_savepath, 'file') && ~overwriteFlag
                warning(['[!] the collage image for subject ' num2str(sub) ' object ' num2str(objID) ' already exists. Based on the overwriteFlag, the image will not be overwritten. Skipped'])
                continue
            end
            
            img_dir_struct = dir(fullfile(current_obj_dir, [num2str(sub) '_*_*.jpg']));
        
            % check to see if the object folder contain any images for the current subject
            if isempty(img_dir_struct)
                warning(['[-] ' current_obj_dir ' folder does not contain any cropped images for subject ' num2str(sub) '. Skipped'])
                continue
            end
        
            % get a list of image names that was found in the object folder
            img_dirs = fullfile(current_obj_dir, {img_dir_struct.name});
        
            % initialize image_struct
            img_struct = struct();
            img_struct(numel(img_dirs)) = struct();
            
            % create the image_structure
            for j = 1:numel(img_dirs)
                current_img_path = img_dirs{j};
                img_struct(j).img_path = current_img_path;
                img = imread(current_img_path);
                [rows, cols, ~] = size(img);
                img_struct(j).img_size = [rows cols];
                img_struct(j).crop_position = [];
            end
            
            try
                collage = image_collage(img_struct, collage_width);
                imwrite(collage, collage_savepath)
            catch ME
                disp(ME.message)
            end
        end
        
        if generateAllFlag
            % write the overall collage for each of the objectID
            disp(['[*] Processing object ' num2str(objID) ' for all experiment ' num2str(exp) ' images'])
            collage_savepath = fullfile(subs_dir, ['all_' num2str(objID) '.jpg']);
            if exist(collage_savepath, 'file') && ~overwriteFlag
                warning(['[!] the collage image for subject ' num2str(sub) ' object ' num2str(objID) ' already exists. Based on the overwriteFlag, the image will not be overwritten. Skipped'])
                continue
            end
            try
                imwrite(image_collage(get_images_from_directory(current_obj_dir), collage_width), collage_savepath)
            catch ME
                disp(ME.message)
            end
        end
    end
end
end