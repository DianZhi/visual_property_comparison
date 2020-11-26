function [result, vec_result, overall_stats] = extract_object_similarity(subexpIDs, agent, cevent_variable, visual_property_funcname, level)
% this function read the cevent variable and extract the similarity matrices that the cevent coding is the same as the cropped object 
%  
% subexpIDs: array of subject IDs or an experiment ID
% agent: char. Either 'child' or 'parent'. The generated matrices will be saved in all_objs/agent folder
% cevent_variable: char. Name of an existing cevent varaible. The variable should have 3 columns: instance onsets, instance offsets, cat_value
% visual_property_funcname: char. The visual property extraction function name. E.g. 'pixel_comparison'. 
% level: char. One of three options: 'experiment', 'subject', instances
%
% E.g. [result, stats] = extract_object_similarity([4501, 4502], 'child', 'cevent_eye_roi_child', 'pixel_comparison', 'instances')

subs = unique(cIDs(subexpIDs));

expID = unique(sub2exp(subs));
if numel(expID) > 1
    error('[-] Your entered subjects are from more than one experiment. Please run one experiment at a time.')
end

similarity_matrix_dir = fullfile(get_multidir_root, ['experiment_' num2str(expID)], 'included', 'all_objs', agent, visual_property_funcname);
matrix_files_dir_struct = dir(fullfile(similarity_matrix_dir, ['experiment_' num2str(expID) '_' visual_property_funcname '_obj*.mat']));

% check the existence of the similarity matrix folder
if isempty(matrix_files_dir_struct)
    error(['[-] Experiment ' num2str(expID) ' does not have all_objs > ' agent ' > ' visual_property_funcname ' matrix'])
end

% get matrix filenames and object IDs
matrix_filenames = {matrix_files_dir_struct.name};
objIDs = cellfun(@(x) sscanf(x, ['experiment_' num2str(expID) '_' visual_property_funcname '_obj%d.mat']), matrix_filenames);

% get the matrix that is consisted of subject IDs, valid frames, and ROI
sub_frame_ROI = [];
for col = 1:numel(matrix_filenames)
    current_mat = matrix_filenames{col};
    current_obj = objIDs(col);
    T = load_similarity_table(fullfile(similarity_matrix_dir, current_mat));
    img_names = T.Properties.VariableNames;
    frame_nums = cellfun(@img_name2frame_num, img_names);
    subIDs = cellfun(@img_name2subID, img_names);
    sub_frame_ROI = [sub_frame_ROI; [reshape(subIDs, [], 1) reshape(frame_nums, [], 1) ones(numel(subIDs), 1)*current_obj]];
end

% overall stats in the format: subID, eventID, event_duration (in #frames), #frames that the cropped image within the event, #frames that the cropped item is the same as the event coding
overall_stats = [];

sub_num = numel(subs);
obj_num = numel(objIDs);

switch level
    case 'experiment'
        intermediate_cell = cell(1, obj_num);
    case 'subject'
        intermediate_cell = cell(sub_num, obj_num);
    case 'instance'
        intermediate_cell = cell(sub_num, obj_num);
end

for sub = subs'
    if ~has_variable(sub, cevent_variable)
        warning(['[!] subject ' num2str(sub) ' does not have ' cevent_variable ' variable. Skipped'])
    end
    
    cev_data = get_variable(sub, cevent_variable);
    
    current_sub_sub_frame_ROI = sub_frame_ROI(sub_frame_ROI(:, 1) == sub, :);
    
    for col = 1:size(cev_data, 1)
        % get the current event. i is the event ID
        current_event = cev_data(col, :);
        current_obj = current_event(3);
        % count the number of frames in this event
        fnums = (time2frame_num(current_event(1), sub) : time2frame_num(current_event(2), sub)-1);
        % get the cropped images within this event (always <= fnums since there are cases that the attended object is not in FOV)
        current_event_sub_frame_ROI = current_sub_sub_frame_ROI(ismember(current_sub_sub_frame_ROI(:, 2), fnums), :);
        % get the cropped images that has the same target object as the cevent codings
        current_event_sub_frame_ROI_same_as_coding = current_event_sub_frame_ROI(current_event_sub_frame_ROI(:, 3) == current_event(3), :);
        % update the overal statistics
        overall_stats = [overall_stats; [sub, col, numel(fnums), size(current_event_sub_frame_ROI, 1), size(current_event_sub_frame_ROI_same_as_coding, 1)]];
        % based on different level param, update the intermediate cell array 
        switch level
            case 'experiment'
                tmp = intermediate_cell{current_obj == objIDs};
                intermediate_cell{current_obj == objIDs} = [tmp; current_event_sub_frame_ROI_same_as_coding];
            case 'subject'
                tmp = intermediate_cell{sub == subs, current_obj == objIDs};
                intermediate_cell{sub == subs, current_obj == objIDs} = [tmp; current_event_sub_frame_ROI_same_as_coding];
            case 'instance'
                tmp = intermediate_cell{sub == subs, current_obj == objIDs};
                tmp{end+1} = current_event_sub_frame_ROI_same_as_coding;
                intermediate_cell{sub == subs, current_obj == objIDs} = tmp;
        end
    end
end

overall_stats = array2table(overall_stats, 'VariableNames', {'subID', 'instanceID', ...
    'duration in frames', '#cropped images within cevent', ...
    '#cropped images same cat_value as cevent'});

result = intermediate_cell;
vec_result = intermediate_cell;
% replace the sub_frame_ROI structure in the intermediate_cell with simulairty matrices
% loop through objects (columns)
for col = 1:obj_num
    current_mat = matrix_filenames{col};
    T = load_similarity_table(fullfile(similarity_matrix_dir, current_mat));
    switch level
        case 'experiment' % loop through objects
            result{col} = sub_frame_ROI2similarity_matrix(intermediate_cell{col}, T);
            vec_result{col} = similarity_matrix2vector(result{col});
        case 'subject'
            % loop through subjects (rows)
            for row = 1:sub_num
                result{row, col} = sub_frame_ROI2similarity_matrix(intermediate_cell{row, col}, T);
                vec_result{row, col} = similarity_matrix2vector(result{row, col});
            end
        case 'instance'
            % loop through subjects (rows)
            for row = 1:sub_num
                instances_cell = intermediate_cell{row, col};
                % loop through instances
                for ins = 1:numel(instances_cell)
                    result{row, col}{ins} = sub_frame_ROI2similarity_matrix(intermediate_cell{row, col}{ins}, T);
                    vec_result{row, col}{ins} = similarity_matrix2vector(result{row, col}{ins});
                end
            end
    end
end
end

function T = load_similarity_table(similairty_filepath)
tmp = load(similairty_filepath, 'similarity_matrix');
T = tmp.similarity_matrix;
end

function subID = img_name2subID(img_name)
subID = str2double(img_name(1: find(img_name=='_', 1)-1));
end

function frame_num = img_name2frame_num(img_name)
tmp = find(img_name=='_', 2);
frame_num = str2double(img_name(tmp(1)+1 : tmp(2)-1));
end

function similarity_table = sub_frame_ROI2similarity_matrix(sub_frame_ROI, obj_matrix)
numOfFrames = size(sub_frame_ROI, 1);
if numOfFrames == 0
    similarity_table = NaN;
else
    frame_names = sub_frame_ROI2frame_name(sub_frame_ROI);
    similarity_mat = nan(numOfFrames);
    for i = 1:numOfFrames
        f1 = sub_frame_ROI2frame_name(sub_frame_ROI(i, :));
        for j = 1:numOfFrames
            if i == j
                similarity_mat(i, j) = 0;
            elseif i > j
                similarity_mat(i, j) = similarity_mat(j, i);
            else
                f2 = sub_frame_ROI2frame_name(sub_frame_ROI(j, :));
                similarity_mat(i, j) = table2array(obj_matrix(f1, f2));
            end
        end
    end
    similarity_table = array2table(similarity_mat, 'VariableNames', frame_names, 'RowNames', frame_names);
end
end

function result = sub_frame_ROI2frame_name(sub_frame_ROI)
numOfFrames = size(sub_frame_ROI, 1);
result = cell(numOfFrames, 1);
for i = 1:numOfFrames
    result{i} = [num2str(sub_frame_ROI(i, 1)) '_' num2str(sub_frame_ROI(i, 2)) '_' num2str(sub_frame_ROI(i, 3)) '.jpg'];
end
end

function vector = similarity_matrix2vector(similarity_matrix)
if numel(similarity_matrix) == 1
    vector = NaN;
else
    vector = [];
    for i = 2:height(similarity_matrix)
        vector = [vector; reshape(similarity_matrix{i, 1:i-1}, [], 1)];
    end
end
end



