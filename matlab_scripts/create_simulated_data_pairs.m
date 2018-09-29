% instructions:
% change impath to folder containing image*-folders.
% Adjust params if desired
% run script
% NOTE: matlab needs ~3GB on HD to save khoros's config for PSF generation!

% TODO: view psf/otf
% TODO: view fourier spectrum of obj
% TODO: maintain this script for generation and specify paths
% TODO: save tiff instead of mat
% TODO: adapt dimensions of vascu_synth to NA
% TODO: change anisotropy using NA
% TODO: simulate without psf, only noise

% Example critical SAMPLING distances (https://svi.nl/NyquistCalculator)
% critical sampling for na=1.3, ri=1.33, wl=520
% x: 100 nm, y: 100 nm, z: 254 nm
% critical sampling for na=1.2, ri=1.33, wl=520
% x: 108 nm, y: 108 nm, z: 348 nm
% critical sampling for na=0.5, ri=1.33, wl=520:
% x: 260 nm, y: 260 nm, z: 2682 nm
% --> formulas given in code

%% Set Parameters
% seed2: 197 png-image-stacks of size 400x400x100 (3 are faulty 24, 25, 87)  % --> indices 117, 118, 187
% seed3: 120 png-image-stacks of size 400x400x100
% seed4: 200 png-image-stacks of size 400x400x100
% seed5: 200 png-image-stacks of size 400x400x100
% --> use create_simulated_data_pairs_split.m
% --> some might be badly constructed, although they should be okay

% -------
% seed6 and above: 200 png-images-stacks of size 400x100x100
% --> use create_simulated_data_pairs.m
%base_path = '/home/soenke/code/vascu_synth/CHANGE_NAME';
base_paths = {'/media/soenke/Data/Soenke/datasets/vascu_synth/small', ...
              '/media/soenke/Data/Soenke/datasets/vascu_synth/new_datasets/small', ...
              '/media/soenke/Data/Soenke/datasets/vascu_synth/big'};

% use max_photons to impact amount of noise
max_photonss = [10 50 100 1000 10000 100000];  % high value: high variance of noise, but also high SNR default: 10000
% bgr --> see loop

% use wl to change amount of blur
% Sampling is determined from the first value.  Changing it has no effect,
% only relative changes between the values do.
% --> Values should be increasing
% absolute minimum: 1/2 * first value (critical sampling), 
% but not recommended for deconv to allow for reconstruction of frequencies.  
% empirical maximum: approx. 16*first value (psf reaches border)
% at this point wraparound will really harm the simulation
% TODO: quantify size of psf
wls = [520, 2*520, 4*520, 8*520];  % nm (emission) default: 520. 
subsampleZs = [4 1];


%% Parameters 2 (only change if you know what you are doing)
na = 1.064;  % at about 1.064, scaleXY/4 ~ scaleZ_ny/2
ri = 1.33;  % water
base_wl = wls(1);  % used to determine sampling

% border is largely ignored by unet, so padding conv is not THAT important
padding = 'same';  

% Do NOT use critical sampling to allow deconv to perform
% "super"-resolution!  Recommendation: oversample by factor 2 in XY.
% CAREFUL: Input object is subsampled!
% Sampling in Z is chosen as 1/4 of sampling in XY. 
% You might need to adjust the code in case of sampling issues
oversampling_factor = 2;

for k = 1:length(base_paths)
    base_path = base_paths{k};
    disp(base_path)
    for subsampleZ = subsampleZs
        for wl = wls
            for max_photons = max_photonss
                disp(wl)
                disp(max_photons)
                % background influences noise floor.  I had a background of 10 photons at 10000.
                bgr_photons = uint8(max(1, 10*max_photons/10000));
                target_path = base_path; % consider moving this to data-HD right away

                %impath = strcat(base_path, '/', 'original_images');
                source_path = strcat(base_path, '/original_data');
                subdirs = get_subdirs(source_path);
                for i = 1:numel(subdirs)
                    %% Load and process obj
                    sd = subdirs{i}; % image0 ... image99
                    impath = strcat(source_path, '/', sd, '/original_image/');

                    % Load Object
                    % [obj, info] = ReadData3D(strcat(path, '/', fname), false);
                    obj = stack_all_pngs(impath);
                    obj = obj ./max(obj) * 255;
                    % size(obj);

                    % exchange x and z, because psf will be generated as x,y,z
                    obj = permute(obj, [3,2,1]);
                    % size(obj);

                    % Subsample along z
                    % - Since I also need downsampled objects for unet, I cannot
                    % convolve with psf first and then image.
                    % - My own function filtered_subsample applies low-pass before
                    % subsampling to avoid aliasing.
                    % TODO: it is currently not possible to call 
                    %   obj = filtered_subsample(obj, [1 1 4]);
                    % in analogy with dip_image's subsample function.
                    % - NOTE: dip_image's 
                      % subsample(obj, [1 1 4]) 
                    % is equivalent to 
                      % obj = obj(:,:,0:4:end);
                    % and will lead to aliasing
                    obj = filtered_subsample1d(obj, subsampleZ, 3);  % z-dim is 3
                    obj = obj ./max(obj) * 255;
                    % size(obj)

                    %% create psf
                    if (i == 1)
                        % calculate input to GenericPSFSim and run a simple check for sampling
                        sampXY_ny = floor(base_wl / (4*na));
                        sampZ_ny = floor(base_wl / (2*ri*(1-cos(asin(na/ri)))));

                        % isotropic sampling as in vascu synth for now
                        % --> will subsample later
                        sampXY = sampXY_ny / oversampling_factor;
                        if sampXY > sampXY_ny/2
                            warning('you are sampling at less than half Nyquist sampling in xy')
                            disp(strcat('sampXY_ny: ', int2str(sampXY_ny)))
                            disp(strcat('sampXY:___ ', int2str(sampXY)))
                            if sampXY > sampXY_ny
                                error('current sampZ leads to undersampling')
                            end
                        end
                        
                        sampZ = subsampleZ*sampXY;  % sampZ_ny / oversampling factor
                        if sampZ > sampZ_ny/2
                            warning('you are sampling at less than half Nyquist sampling in z')
                            disp(strcat('sampZ_ny: ', int2str(sampZ_ny)))
                            disp(strcat('sampZ:___ ', int2str(sampZ)))
                            if sampZ > sampZ_ny
                                error('current sampZ leads to undersampling')
                            end
                        end

                        % RichardsWolf needs oversampling to avoid dip in sum(psf,[],[1 2]);
                        % Trick: oversample during generation, then subsample after
                        % note that psf generation will take longer with "oversampling"
                        % you can also try fixWFPSF, but that fxn is a bit hacky
                        % note that oversamp has nothing to do with oversampling mentioned
                        % above and is only used during psf-generation
                        % TODO: oversamp in z might not be necessary
                        Method = 'RichardsWolffInt';
                        oversampXY=12;
                        if oversampXY >= (size(obj, 3)/size(obj, 1))
                            oversampZ = oversampXY/ (size(obj, 3)/size(obj, 1));
                        else
                            oversampZ = oversampXY;
                        end
                        oversize=[size(obj,1)*oversampXY, size(obj,2)*oversampXY, size(obj,3)*oversampZ];
                        ImageParam = struct('Sampling',[sampXY/oversampXY sampXY/oversampXY sampZ/oversampZ], ...
                                            'Size',oversize);
                        PSFParam = struct('NA', na, 'n', ri, 'lambdaEm', wl); % 'MinOtf',1.2e-3

                        psf = GenericPSFSim(ImageParam, PSFParam, Method);
                        psf = psf(0:oversampXY:end, 0:oversampXY:end, 0:oversampZ:end);
                        psf = psf / sum(psf);

                        % This probably does not work just like this would it?
                        % it could be better to generate 2 psfs for both samplings?
                        % psf_subsam = psf(:,:,0:4:end);

                        % checks: sum should be 1
                        % disp(sum(psf))
                        % disp(max(psf))
                    end

                    %% perform imaging
                    im = simulate_wf_imaging_poisson(obj, psf, max_photons, bgr_photons, padding);

                    %% save as mat-files
                    % TODO: save tiff instead of mat
                    id = strcat('num_photons', num2str(max_photons), '_', ...
                                'bgr', num2str(bgr_photons), '_', padding);
                    psf_id = strcat('wl', num2str(wl), '_na', num2str(na), '_ri', num2str(ri), ...
                                    '_scaleXY', num2str(sampXY), '_scaleZ', num2str(sampZ));
                    if subsampleZ > 1
                        target_path = strcat(target_path, '/subsam', num2str(subsampleZ));
                    end
                    save_path = strcat(target_path, '/simulated_data_pairs/', 'poisson/', ...
                                       id, '/', psf_id, '/', sd, '/');
                    if ~exist(save_path, 'dir')
                        mkdir(save_path)
                    end

                    % save psf
                    % TODO consider rescaling and saving uint8
                    if (i == 1)
                        psf_check = psf;
                        % save psf as mat-file from float array
                        % exchange z and x, because unet expects (z,y,x)
                        % then change back to do the other convolutions
                        if usecuda
                            psf = ConditionalCudaConvert(psf, 0);
                        end
                        psf = permute(dip_array(psf), [3 2 1]);   % x <-> z
                        save(strcat(save_path,'psf'), 'psf', '-v7')
                        psf = dip_image(permute(psf, [3 2 1]));   % z <-> x
                        if usecuda
                            psf = ConditionalCudaConvert(psf, 1);
                        end
                        % TODO: make sure psf is the same as before
                        if psf_check ~= psf
                            error('psf is not the same after save-conversions')
                            % TODO delete psf_check here
                        end
                    end

                    % save obj and im
                    % TODO: make sure it is really 0...255
                    if (min(min(min(round(obj)))) < 0) || (max(max(max(round(obj)))) > 255)
                        warning(strcat('min(obj): ', num2str(min(min(min(round(obj))))), ...
                                    ', max(obj): ', num2str(max(max(max(round(obj))))), ...
                                    ' not in [0...255].'));
                    end
                    if (min(min(min(round(im)))) < 0) || (max(max(max(round(im)))) > 255)
                        warning(strcat('min(im): ', num2str(min(min(min(round(im))))), ...
                                    ', max(im): ', num2str(max(max(max(round(im))))), ...
                                    'not in [0...255].'));
                    end
                    if usecuda
                        obj = ConditionalCudaConvert(obj, 0);
                        im = ConditionalCudaConvert(im, 0);
                    end
                    obj = uint8(round(obj));
                    im = uint8(round(im));
                    % exchange z and x, because unet expects (z,y,x)
                    obj = permute(obj, [3,2,1]);
                    im = permute(im, [3,2,1]);

                    save(strcat(save_path,'obj'), 'obj', '-v7')
                    save(strcat(save_path,'im'),  'im', '-v7')
                    disp(strcat(num2str(i), '/', num2str(numel(subdirs))))
                end   
            end
        end
    end
end



%% functions
function subdirs = get_subdirs(path)
    d = dir(path);
    is_subdir = [d(:).isdir];
    subdirs = {d(is_subdir).name}';
    subdirs(ismember(subdirs,{'.','..'})) = [];
end

% function fname = get_mhd(path)
%     f = dir(fullfile(path, '*.mhd'));
%     fname = f.name;
% end

function image_stack = stack_all_pngs(path)
    % Get structure array with list of all png files in this directory
    imagefiles = dir(strcat(path, '*.png'));
    nfiles = length(imagefiles);  % Number of files found
    for ii=1:nfiles
        current_filename = imagefiles(ii).name;
        current_image = readim(strcat(path, current_filename));
        if ii == 1
             [rows, columns, ~] = size(current_image);  % always treats them as greyvalue
             image_stack = newim(rows, columns, nfiles);
        end
        image_stack(:, :, ii-1) = current_image;
    end
end
