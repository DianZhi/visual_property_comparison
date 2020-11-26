%%
% script that generates the similarity matrix and extract data
% ***make sure all your workspace varaibles are saved. This session will clear the workspace varaibles***
% ***please click 'Run Section' button or press Ctrl+Enter to run the sessions one by one from top to the bottom***
clear
clc

% add the functions search paths to the Matlab environment
addpath('\\cantor.psych.indiana.edu\space\dianzhi\scripts\acuity + cropping\visual_similairty_comparison')

%%
% genrate similarity matrices for experiment 45 child using pixel-wise comparison
% the generated matrices will be stored at: 
%   \\marr.psych.indiana.edu\multiwork\experiment_45\included\all_objs\child\pixel_comparison
generate_similarity_matrix(45, 'child', @pixel_comparison, true, true)
% 45                    ->      expID
% 'child'               ->      agent
% @pixel_comparison     ->      function_handle. pixel_comparison is a function 
%                                   that takes an image path and return a 1xN
%                                   vector that contains the extracted visual
%                                   feature of the image.
% true                  ->      overwrite the existing matrices files
% true                  ->      keep the temp file that stores the image features

% show the created matrices 
ls('\\marr.psych.indiana.edu\multiwork\experiment_45\included\all_objs\child\pixel_comparison\*.mat')

% load one of them so you can check the matrix
load('\\marr.psych.indiana.edu\multiwork\experiment_45\included\all_objs\child\pixel_comparison\experiment_45_pixel_comparison_obj1.mat')
similarity_matrix

%%
% extract similarity matrices using cevent_eye_roi_child for subject 4521 and 4522
cev_name = 'cevent_eye_roi_child';
[exp_level, exp_vector, stats] = extract_object_similarity([4521 4522], 'child', cev_name, 'pixel_comparison', 'experiment');
[sub_level, sub_vector] = extract_object_similarity([4521 4522], 'child', cev_name, 'pixel_comparison', 'subject');
[ins_level, ins_vector] = extract_object_similarity([4521 4522], 'child', cev_name, 'pixel_comparison', 'instance');

% [4521 4522]           ->      subject list
% 'child'               ->      agent
% cev_name              ->      cevent varaible that used to select frames
% 'pixel_comparison'    ->      the feature extraction function name. Differnt 
%                                   matrices extracted by using different feature
%                                   extraction functions will be stored at 
%                                   different folders named after the feature
%                                   extraction function
% 'experiment'/'subject'/'instance'->      Different level of comparison

% show overall stats

disp('Four variables were added to the workspace: ')
disp('==============================')
disp('exp_level: experiment level comparison, merge accross subjects. 3 columns represent 3 toys')
disp('exp_vector: experiment level comparison, matrices turned into arrays of visual propery distances')
disp('------------------------------')
disp('sub_level: subject level comparison, merge accross instances. 3 columns represent 3 toys, two rows represent 2 subjects 4521 and 4522')
disp('sub_vector: subject level comparison, matrices turned into arrays of visual propery distances')
disp('------------------------------')
disp('ins_level: instance level comparison. 3 columns represent 3 toys, two rows represent 2 subjects 4521 and 4522, each element in the cell is a cell array of tables, each table is one instance''s similarity matrix')
disp('ins_vector: instance level comparison, matrices turned into arrays of visual propery distances')
disp('------------------------------')
disp('stats: the overall stats which records how many cropped frames are missing, etc.')


