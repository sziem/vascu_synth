% instructions:
% change impath to folder containing image*-folders.
% Adjust params if desired
% run script
% NOTE: matlab needs ~3GB on HD to save khoros's config for PSF generation!

% TODO: view psf/otf
% TODO: view fourier spectrum of obj
% TODO: maintain this script for generation and specify paths
% TODO: save tiff instead of mat

%% Set Parameters
% seed2: 200 png-image-stacks of size 400x400x100
% seed3: 120 png-image-stacks of size 400x400x100
% seed4: 200 png-image-stacks of size 400x400x100
% seed5: 200 png-image-stacks of size 400x400x100
% --> use create_simulated_data_pairs_split.m
% --> some might be badly constructed, although they should be okay

% -------
% seed6 and above: 200 png-images-stacks of size 400x100x100
% --> use create_simulated_data_pairs.m

impath = '/home/soenke/code/vascu_synth/seed2';
target_path = impath; % consider moving this to data-HD right away
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
%impath = strcat(base_path, '/', 'original_images');
subdirs = get_subdirs(impath);
for i = 1:numel(subdirs)
    sd = subdirs{i}; % image0 ... image99
    path = strcat(impath, '/', sd, '/original_image/');
    
    % Load Object
    % [obj, info] = ReadData3D(strcat(path, '/', fname), false);
    obj = stack_all_pngs(path);
    obj = obj ./max(obj) * 255;
    %   size(obj);
    
    % shift x to z
    obj = shiftdim(obj, 1); % shift x to z
%   size(obj);

    % subsample along z
    % my own function filtered_subsample applies low-pass before
    % subsampling to avoid aliasing
    obj = filtered_subsample1d(obj, 4, 3);
%     size(obj)
    
    % TODO it is currently not possible to call 
      % obj = filtered_subsample(obj, [1 1 4]);
    % in analogy with dip_image's subsample function.
      
    % NOTE: dip_image's 
      % subsample(obj, [1 1 4]) 
    % is equivalent to 
      % obj = obj(:,:,0:4:end);
    % and will lead to aliasing
      
    % create psf
    if (i == 1)
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
        oversize=[size(obj,1)*oversampXY, size(obj,2)*oversampXY, size(obj,3)*oversampZ];
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
    im = simulate_wf_imaging_poisson(obj, psf, max_photons, bgr_photons, padding);
    
    % --> TODO: why not image first and then subsample?
    % there was some reason, but I don't remember
    % nice: could solve aliasing problem
    % bad: psf needs extra processing or is it just wrong?
    % obj = obj(:,:,0:4:end);
    % im = im(:,:,0:4:end);
    
    % make ready for storing
    if usecuda
        obj = ConditionalCudaConvert(obj, 0);
        im = ConditionalCudaConvert(im, 0);
    end
    
    % reduce storage size  -> binaries will be saved!
    % TODO: check if really 0...255
    % --> should be the case.  objs are rescaled above, ims are rescaled in
    % simulate_wf_imaging_poisson
    obj = uint8(round(obj));
    im = uint8(round(im));
    
    %% save as mat-files
    % TODO: save tiff instead of mat
    id = strcat('num_photons', num2str(max_photons), '_', ...
                'bgr', num2str(bgr_photons), '_', padding);
    psf_id = strcat('na', num2str(na), '_ri', num2str(ri), ...
                    '_scaleXY', num2str(scaleXY), '_scaleZ', num2str(scaleZ));
    savedir = strcat(target_path, '/simulated_data_pairs/', 'poisson/', ...
                     id, '/', psf_id, '/', sd, '/');

    if ~exist(savedir, 'dir')
        mkdir(savedir)
    end
    
    if (i == 1)
        save(strcat(savedir,'psf'), 'psf', '-v7')
        % save(strcat(savedir,'psf_subsam'), 'psf_subsam', '-v7')
    end
    save(strcat(savedir,'obj'), 'obj', '-v7')
    save(strcat(savedir,'im'),  'im', '-v7')
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
