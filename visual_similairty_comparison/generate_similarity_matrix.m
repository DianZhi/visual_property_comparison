function generate_similarity_matrix(expIDs, agent, func, overwriteFlag, keepTempFlag)
% this function generate the overall similarity matrices for all the experiments listed in the expIDs parameter using the given image feature extraction function
%  
% expIDs : array of experiment IDs
% agent: char. Either 'child' or 'parent'. The generated matrices will be saved in all_objs/agent folder
% func: function_handle. The function should take one image path char array as the only input and the extracted visual feature as the first output. E.g. @pixel_comparison. 
% overwriteFlag: boolean. Whether the existing matrices will be overwritten or not. Default to be false (not overwrite existing files)
% keepTempFlag: boolean. Whether keep the temp files or not. Default to be false (remove the temp file after the matrices are generated)
%
% E.g. generate_similarity_matrix(45, 'child', @pixel_comparison, true, true)

if nargin < 4 || ~exist('overwriteFlag', 'var')
    overwriteFlag = false;
end

if nargin < 5 || ~exist('deleteTempFlag', 'var')
    keepTempFlag = false;
end

% check the entered experiment IDs, only use the valid experiments
expIDs = sort(unique(sub2exp(cIDs(expIDs))));
disp(['[*] Found ' num2str(numel(expIDs)) ' valid experiment(s):'])
disp(expIDs)

% loop through experiments
for exp = expIDs'
    disp('==============================')
    disp(['[*] processing experiment ' num2str(exp)])
    disp('==============================')
    all_root_path = fullfile(get_multidir_root, ['experiment_' num2str(exp)], 'included', 'all_objs', agent);
    all_root_struct = dir(all_root_path);
    
    % check the existence of the all_objs folder
    if isempty(all_root_struct)
        warning(['[-] Experiment ' num2str(exp) ' does not have all_objs > ' agent ' folder. Skipped'])
        continue
    end
    
    % get the full path name of the object folders
    obj_dir_names = {all_root_struct.name};
    obj_dir_names = obj_dir_names([all_root_struct.isdir]);
    obj_dirs = {};
    for i = 1:numel(obj_dir_names)
        obj_dirID = str2num(obj_dir_names{i});
        if ~isempty(obj_dirID)
            obj_dirs{end+1} = obj_dir_names{i};
        end
    end
    obj_dirs = strcat(all_root_path, filesep, obj_dirs);
    
    % loop through the object folders
    for i = 1:numel(obj_dirs)
        current_obj_dir = obj_dirs{i};
        objID = str2num(current_obj_dir(find(current_obj_dir == filesep(), 1, 'last')+1:end));
        disp('------------------------------')
        disp(['[*] Processing object ' num2str(objID)])
        disp('------------------------------')
        
        img_dir_struct = dir(fullfile(current_obj_dir, '*_*_*.jpg'));
        
        % check to see if the object folder contain any images 
        if isempty(img_dir_struct)
            warning(['[-] ' current_obj_dir ' folder does not contain any cropped images. Skipped'])
            continue
        end
        
        % get a list of image names that was found in the object folder
        img_dir_names = {img_dir_struct.name};
        
        % sort the names by image frame numbers
        frame_nums = cellfun(@img_name2frame_num, img_dir_names);
        [~, ind_f] = sort(frame_nums);
        img_dir_names = img_dir_names(ind_f);
        
        % sort the mames by image subject IDs
        subIDs = cellfun(@img_name2subID, img_dir_names);
        [~, ind_s] = sort(subIDs);
        img_dir_names = img_dir_names(ind_s);
        
        % data cell array init
        data_cell = cell(numel(img_dir_names), 2);
        data_cell(:, 1) = img_dir_names';
        
        % check to see if there is any existed temp files that stores the extracted visual properties
        tmp_folder_path = fullfile(all_root_path, func2str(func), 'temp');
        % if exist temp folder, check for files
        if exist(tmp_folder_path, 'dir')
            temp_file_dir_struct = dir(fullfile(tmp_folder_path, [func2str(func) '_obj' num2str(objID) '_*.mat']));
            if ~isempty(temp_file_dir_struct)
                disp(['[+] Detected temp files for experiment ' num2str(exp) ' ' agent ' ' func2str(func) 'function results'])
                temp_filenames = strcat(tmp_folder_path, filesep, {temp_file_dir_struct.name});
                % load existing temp files 
                for j = 1:numel(temp_filenames)
                    current_temp_file = temp_filenames{j};
                    tmp = load(current_temp_file, 'data');
                    tmp = tmp.data;
                    for k = 1:size(tmp, 1)
                        data_cell{strcmp(tmp(k, 1), data_cell(:, 1)), 2} = tmp{k, 2};
                    end
                end
                disp('[+] Pre-existing data loaded')
            end
        else
            mkdir(tmp_folder_path)
        end
        
        % loop through the images and extract visual properties (save to temp files)
        prev_j = 0;
        for j = 1: numel(img_dir_names)
            current_img = img_dir_names{j};
            % if not extracted yet, extract using the given function handle
            if isempty(data_cell{j, 2})
                data_cell{j, 2} = double(func(fullfile(current_obj_dir, current_img)));
            end
            
            % if the output array is not a vector or not a 1xN array, reshape it into a 1xN array
            if size(data_cell{j, 2}, 1) > 1
                data_cell{j, 2} = reshape(data_cell{j, 2}, 1, []);
            end
            
            % for every 100 images, save the extracted image features to temp files
            if rem(j, 100) == 0 || j == numel(img_dir_names)
                temp_file_path = fullfile(tmp_folder_path, [func2str(func) '_obj' num2str(objID) '_' num2str(prev_j+1) '-' num2str(j) '.mat']);
                data = data_cell(prev_j+1:j, :);
                prev_j = j;
                save(temp_file_path, 'data')
                disp(['[+] ' temp_file_path ' saved'])
            end
        end
        
        % check the existence of the object similarity matrix, if already
        % exist & overwrite == false, skip to the next object
        mat_save_dir = fullfile(all_root_path, func2str(func));
        mat_save_path = fullfile(mat_save_dir, ['experiment_' num2str(exp) '_' func2str(func) '_obj' num2str(objID) '.mat']);
        if ~overwriteFlag && exist(mat_save_path, 'file')
            warning(['[!] The ' func2str(func) ' for experiment ' num2str(exp) ' object ' num2str(objID) ' already exist. Based on the overwriteFlag=false, the file will not be overwritten by this function'])
            continue
        end
        
        % calculate the whole similairty matrix for the object
        disp(['[*] Calculating the similarity matrix for experiment ' num2str(exp), ' object ' num2str(objID)])
        num_of_imgs = size(data_cell, 1);
        similarity_matrix = nan(num_of_imgs); 
        for j = 1:num_of_imgs
            for k = 1:num_of_imgs
                if j > k
                    similarity_matrix(j, k) = similarity_matrix(k, j);
                elseif j == k
                    similarity_matrix(j, k) = 0;
                else
                    if numel(data_cell{j, 2}) == numel(data_cell{k, 2})
                        similarity_matrix(j, k) = cal_distance(data_cell{j, 2}, data_cell{k, 2});
                    else
                        similarity_matrix(j, k) = NaN;
                    end
                end
            end
        end
        
        % convert array to table and add row names and column headers
        similarity_matrix = array2table(similarity_matrix);
        similarity_matrix.Properties.VariableNames = data_cell(:, 1);
        similarity_matrix.Properties.RowNames = data_cell(:, 1);
        
        % save matrix
        save(mat_save_path, 'similarity_matrix')
        disp(['[+] Similarity matrix is saved: ' mat_save_path])
    end
    
    % if deleteTempFlag == true, remove the temp folder and all the contents
    if ~keepTempFlag
        rmdir(tmp_folder_path, 's')
        disp(['[+] The ' func2str(func) ' for experiment ' num2str(exp) ' temp folder is removed'])
    end
end

end

function subID = img_name2subID(img_name)
subID = str2double(img_name(1: find(img_name=='_', 1)-1));
end

function frame_num = img_name2frame_num(img_name)
tmp = find(img_name=='_', 2);
frame_num = str2double(img_name(tmp(1)+1 : tmp(2)-1));
end

function dist = cal_distance(vec1, vec2)
dist = sqrt(sum((vec1-vec2).^2));
end