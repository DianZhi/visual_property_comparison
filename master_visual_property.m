function master_visual_property(expIDs, agent, bbox_mappings, overwriteFlag)

addpath(genpath('/cantor/space/dianzhi/scripts/acuity + cropping'))
addpath(genpath('/cantor/space/dianzhi/scripts/svens_matlab_code-master'))

expIDs = unique(sub2exp(cIDs(expIDs)));

switch agent
    case 'child'
        agent_bool = [1 0];
    case 'parent'
        agent_bool = [0 1];
    case 'both'
        agent_bool = [1 1];
end

for expID = expIDs'
    
    if agent_bool(1)
        % generate cropped images
        generate_cropped_images(expID, 'child', bbox_mappings, overwriteFlag)
        generate_cropped_image_collage(expID, 'child', false, overwriteFlag)
        
        % apply acuity filter to the images
        generate_acuity_images(expID, 'child', 70, overwriteFlag)
        generate_acuity_video(expID, 'child', true, '', overwriteFlag)
        
        % calculate similairty matrices
        % pixel comparison
        generate_similarity_matrix(expID, 'child', @pixel_comparison, overwriteFlag, true)
        
        % GIST feature
        % generate_similarity_matrix(expID, 'child', @gist_comparison, overwriteFlag, true)
    end
    
    if agent_bool(2)
        % generate cropped images
        generate_cropped_images(expID, 'parent', bbox_mappings, overwriteFlag)
        generate_cropped_image_collage(expID, 'parent', false, overwriteFlag)
        
        % apply acuity filter to the images
        generate_acuity_images(expID, 'parent', 70, overwriteFlag)
        generate_acuity_video(expID, 'parent', true, '', overwriteFlag)
        
        % calculate similairty matrices
        % pixel comparison
        generate_similarity_matrix(expID, 'parent', @pixel_comparison, overwriteFlag, true)
        
        % GIST feature
        % generate_similarity_matrix(expID, 'parent', @gist_comparison, overwriteFlag, true)
    end
end