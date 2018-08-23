% instructions:
% change impath to folder containing image*-folders.
% Adjust params if desired
% run script
% NOTE: matlab needs ~3GB on HD to save khoros's config for PSF generation!
% NOTE: fails if a section of the image is zero
% TODO: catch that case

% TODO: view psf/otf
% TODO: view fourier spectrum of obj
% TODO: save tiff instead of mat

%% Set Parameters
% seed2: 197 png-image-stacks of size 400x400x100  (3 are faulty 24, 25, 87)  --> indices 117, 118, 187
% seed3: 120 png-image-stacks of size 400x400x100  (1 is faulty 86) --> index 107
% seed4: 200 png-image-stacks of size 400x400x100 (1 is equal to just zero: #85) --> index 186
% seed5: 200 png-image-stacks of size 400x400x100 (1 is equal to just zero: #84) --> index 185
% --> use create_simulated_data_pairs_split.m
% --> some might be badly constructed, although they should be okay

% -------
% seed6 and above: 200 png-images-stacks of size 400x100x100
% --> use create_simulated_data_pairs.m

base_path = '/home/soenke/code/vascu_synth/seed4';
target_path = base_path; % consider moving this to data-HD right away
bgr_photons = 10;
max_photons = 10000;  % high value: high variance of noise, but also high SNR
padding = 'same';  % border is largely ignored by unet, so padding is not THAT important


%% Parameters 2 (only change if you know what you are doing)
na = 1.064;  % at about 1.064, scaleXY/4 ~ scaleZ_ny/2
ri = 1.33;  % water
wl = 520;  % nm (emission)

% Do NOT use critical sampling to allow deconv to perform
% "super"-resolution!
% Recommendation: oversample by factor 2
% in z, this may not always be feasable
oversampling_factor = 2;

% SAMPLING:  --> switched to calculating it myself
% https://svi.nl/NyquistCalculator
% critical sampling for na=1.3, ri=1.33, wl=520
% x: 100 nm, y: 100 nm, z: 254 nm
% critical sampling for na=1.2, ri=1.33, wl=520
% x: 108 nm, y: 108 nm, z: 348 nm
% critical sampling for na=0.5, ri=1.33, wl=520:
% x: 260 nm, y: 260 nm, z: 2682 nm

% vascu_synth pixel size: 20 µm squared --> redefine it to scaleZ_ny/2
% --> also subsample z by factor 4

%% calculate input to GenericPSFSim and run a simple check for sampling
scaleXY_ny = floor(wl / (4*na));
scaleZ_ny = floor(wl / (2*ri*(1-cos(asin(na/ri)))));

scaleXY = scaleXY_ny / oversampling_factor;  
scaleZ = scaleXY*4;

if scaleZ > scaleZ_ny/2
    warning('you are sampling at less than half Nyquist sampling in z')
    disp(strcat('scaleZ_ny: ', int2str(scaleZ_ny)))
    disp(strcat('scaleZ:___ ', int2str(scaleZ)))
    if scaleZ > scaleZ_ny
        error('current scaleZ leads to undersampling')
    end
end

% scaleZ = scaleXY;  % only in case of isotropic sampling (with original 
                     % vascu structures and no subsampling in z)

%% Load and process obj
source_path = strcat(base_path, '/original_data');
subdirs = get_subdirs(source_path);
for i = 1:numel(subdirs)  % sorted by 1 10 100 11 12 etc.
    sd = subdirs{i}; % image0 ... image199
    impath = strcat(source_path, '/', sd, '/original_image/');
    
    % Load Object
    % [obj, info] = ReadData3D(strcat(path, '/', fname), false);
    obj = stack_all_pngs(impath);
    obj = obj ./max(obj) * 255;
    
    % 400x400x100 objs don't fit in gpu-memory (together with unet-weights):
    % also, 100x400x100 after subsampling would not fit
    % split into four 400x100x100 objs
    obj1 = obj(:, 0:99, :);
    obj2 = obj(:, 100:199, :);
    obj3 = obj(:, 200:299, :);
    obj4 = obj(:, 300:399, :);
    
    % shift x to z
    obj1 = shiftdim(obj1, 1); % shift x to z
    obj2 = shiftdim(obj2, 1);
    obj3 = shiftdim(obj3, 1);
    obj4 = shiftdim(obj4, 1);
    % size(obj1);
    
    % subsample along z
    % my own function filtered_subsample applies low-pass before
    % subsampling to avoid aliasing.
    
    % This fails in case image is constant zero (Might happen if by chance
    % one region of the image does not receive any nodes)
    % TODO: warning not shown??
    try
        obj1 = filtered_subsample1d(obj1, 4, 3);
    catch ME
        if (max(obj1) == 0)
            warning('obj1 is constant zero')
            obj1 = subsample(obj1, [1 1 4]);
        else
            rethrow ME
        end
    end
    try
        obj2 = filtered_subsample1d(obj2, 4, 3);
    catch ME
        if (max(obj2) == 0)
            warning('obj2 is constant zero')
            obj2 = subsample(obj2, [1 1 4]);
        else
            rethrow ME
        end
    end
    try
        obj3 = filtered_subsample1d(obj3, 4, 3);
    catch ME
        if (max(obj3) == 0)
            warning('obj3 is constant zero')
            obj3 = subsample(obj3, [1 1 4]);
        else
            rethrow ME
        end
    end
    try
        obj4 = filtered_subsample1d(obj4, 4, 3);
    catch ME
        if (max(obj4) == 0)
            warning('obj4 is constant zero')
            obj4 = subsample(obj4, [1 1 4]);
        else
            rethrow ME
        end
    end
    % obj1 = filtered_subsample1d(obj1, 4, 3);
    % obj2 = filtered_subsample1d(obj2, 4, 3);
    % obj3 = filtered_subsample1d(obj3, 4, 3);
    % obj4 = filtered_subsample1d(obj4, 4, 3); 
    % size(obj1);

    % TODO it is currently not possible to call 
      % obj1 = filtered_subsample(obj1, [1 1 4]);
    % in analogy with dip_image's subsample function.
      
    % NOTE: dip_image's 
      % subsample(obj1, [1 1 4]) 
    % is equivalent to 
      % obj1 = obj1(:,:,0:4:end);
    % and will lead to aliasing
      
    % create psf
    if (i == 1)
%         if strcmp(padding, 'full') + strcmp(padding, 'same')
%             obj1 = extract(obj1, 
        
        % RichardsWolf needs oversampling to avoid dip in sum(psf,[],[1 2]);
        % Trick: oversample during generation, then subsample after
        % note that psf generation will take longer with "oversampling"
        % you can also try fixWFPSF, but that fxn is a bit hacky
        % note that oversamp has nothing to do with oversampling mentioned
        % above and is only used during psf-generation
        % TODO: oversamp in z might not be necessary
        Method = 'RichardsWolffInt';
        oversampXY=12;
        oversampZ=oversampXY/2;
        oversize=[size(obj1,1)*oversampXY, size(obj1,2)*oversampXY, size(obj1,3)*oversampZ];
        ImageParam = struct('Sampling',[scaleXY/oversampXY scaleXY/oversampXY scaleZ/oversampZ], ...
                            'Size',oversize);
        PSFParam = struct('NA', na, 'n', ri, 'lambdaEm', wl); % 'MinOtf',1.2e-3

        psf = GenericPSFSim(ImageParam, PSFParam, Method);
        psf = psf(0:oversampXY:end, 0:oversampXY:end, 0:oversampZ:end);
        psf = psf / sum(psf);
        
        % This probably does not work just like this would it?
        % it could be better to generate 2 psfs for both samplings?
        % psf_subsam = psf(:,:,0:4:end);  
        
        if usecuda
            psf = ConditionalCudaConvert(psf, 0);
            % psf_subsam = ConditionalCudaConvert(psf_subsam, 0);
        end
        
        % checks: sum should be 1
        % disp(sum(psf))
        % disp(max(psf))
    end
    
    % perform imaging
    im1 = simulate_wf_imaging_poisson(obj1, psf, max_photons, bgr_photons, padding);
    im2 = simulate_wf_imaging_poisson(obj2, psf, max_photons, bgr_photons, padding);
    im3 = simulate_wf_imaging_poisson(obj3, psf, max_photons, bgr_photons, padding);
    im4 = simulate_wf_imaging_poisson(obj4, psf, max_photons, bgr_photons, padding);
    
    % --> TODO: why not image first and then subsample?
    % there was some reason, but I don't remember
    % could solve aliasing problem

%     obj1 = obj1(:,:,0:4:end);
%     obj2 = obj2(:,:,0:4:end);
%     obj3 = obj3(:,:,0:4:end);
%     obj4 = obj4(:,:,0:4:end);
%     
%     im1 = im1(:,:,0:4:end);
%     im2 = im2(:,:,0:4:end);
%     im3 = im3(:,:,0:4:end);
%     im4 = im4(:,:,0:4:end);
    
    % make ready for storing
    if usecuda
        obj1 = ConditionalCudaConvert(obj1, 0);
        obj2 = ConditionalCudaConvert(obj2, 0);
        obj3 = ConditionalCudaConvert(obj3, 0);
        obj4 = ConditionalCudaConvert(obj4, 0);
        im1 = ConditionalCudaConvert(im1, 0);
        im2 = ConditionalCudaConvert(im2, 0);
        im3 = ConditionalCudaConvert(im3, 0);
        im4 = ConditionalCudaConvert(im4, 0);
    end
    
    % reduce storage size  -> binaries will be saved!
    % TODO: save tiff instead of mat
    % TODO: check if really 0...255
    % --> should be the case.  objs are rescaled above, ims are rescaled in
    % simulate_wf_imaging_poisson
    obj1 = uint8(round(obj1));
    obj2 = uint8(round(obj2));
    obj3 = uint8(round(obj3));
    obj4 = uint8(round(obj4));
    
    im1 = uint8(round(im1));
    im2 = uint8(round(im2));
    im3 = uint8(round(im3));
    im4 = uint8(round(im4));
    
    % objs = dip_image(cat(1, obj1, obj2, obj3, obj4));
    % ims = dip_image(cat(1, im1, im2, im3, im4));
    % cat(4, objs, ims)
    % dip_image(psf)
    
    %% save as mat-files
    id = strcat('num_photons', num2str(max_photons), '_', ...
                'bgr', num2str(bgr_photons), '_', padding);
    psf_id = strcat('na', num2str(na), '_ri', num2str(ri), ...
                    '_scaleXY', num2str(scaleXY), '_scaleZ', num2str(scaleZ));
    save_path = strcat(target_path, '/simulated_data_pairs/', 'poisson/', ...
                     id, '/', psf_id, '/', sd, '/');

    if ~exist(save_path, 'dir')
        mkdir(save_path)
    end
    
    if (i == 1)
        save(strcat(save_path,'psf'), 'psf', '-v7')
        % save(strcat(savedir,'psf_subsam'), 'psf_subsam', '-v7')
    end
    % disp(save_path)
    save(strcat(save_path,'obj1'), 'obj1', '-v7')
    save(strcat(save_path,'obj2'), 'obj2', '-v7')
    save(strcat(save_path,'obj3'), 'obj3', '-v7')
    save(strcat(save_path,'obj4'), 'obj4', '-v7')
    save(strcat(save_path,'im1'),  'im1', '-v7')
    save(strcat(save_path,'im2'),  'im2', '-v7')
    save(strcat(save_path,'im3'),  'im3', '-v7')
    save(strcat(save_path,'im4'),  'im4', '-v7')
    disp(strcat(num2str(i), '/', num2str(numel(subdirs))))
end




%% functions
function subdirs = get_subdirs(path)
    d = dir(path);
    is_subdir = [d(:).isdir];
    subdirs = {d(is_subdir).name}';
    subdirs(ismember(subdirs,{'.','..'})) = [];
end

function fname = get_mhd(path)
    f = dir(fullfile(path, '*.mhd'));
    fname = f.name;
end

function image_stack = stack_all_pngs(path)
    % Get structure array with list of all png files in this directory
    imagefiles = dir(strcat(path, '*.png'));
    nfiles = length(imagefiles);  % Number of files found
    for ii=1:nfiles
        current_filename = imagefiles(ii).name;
        current_image = readim(strcat(path, current_filename));
        if ii == 1
             [rows, columns, channels] = size(current_image);  % always treats them as greyvalue
             image_stack = newim(rows, columns, nfiles);
        end
        image_stack(:, :, ii-1) = current_image;
    end
end
