% instructions:
% put this script into the dataset folder, adjust params and run it

% TODO: prevent wraparound by padding with zeroes
% TODO: view psf/otf

%% Load and image obj
% Set Parameters
bgr_photons = 10;
max_photons = 10000;  % high value: high noise; high SNR

na = 1.3;
ri = 1.33;
wl = 520;  % nm (emission)

% Do NOT use critical sampling to allow deconv to perform
% "super"-resolution!
% Recommendation: oversample by factor 2
% But this leads to the value of the psf almost not vanishing in z
% TODO: write function to calculate this
oversampling_factor = 2;

% SAMPLING:
% https://svi.nl/NyquistCalculator
% critical sampling for na=1.3, ri=1.33, wl=520
% x: 100 nm, y: 100 nm, z: 254 nm
% critical sampling for na=1.2, ri=1.33, wl=520
% x: 108 nm, y: 108 nm, z: 348 nm
% critical sampling for na=0.5, ri=1.33, wl=520:
% x: 260 nm, y: 260 nm, z: 2682 nm

% vascu_synth pixel size: 20 µm squared 
%--> redefine them for correct sampling
% --> preserve isotropy!
% TODO: or do subsampling?
% TODO: or rotate image and do subsampling
% TODO: or redefine z?

scaleXY = wl / (4*na) / oversampling_factor;
% scaleZ = scaleXY;  % in case of isotropic sampling
scaleZ = floor(wl / (2*ri*(1-cos(asin(na/ri)))) / oversampling_factor);

impath = strcat(pwd, '/', 'original_images');
subdirs = get_subdirs(impath);
for i = 1:numel(subdirs)
    sd = subdirs{i}; % image0 ... image99
    path = strcat(impath, '/', sd, '/original_image/');
    
    % Load Object
    % [obj, info] = ReadData3D(strcat(path, '/', fname), false);
    obj = stack_all_pngs(path);
    size(obj)

    % create psf
    if (i == 1)
        % RichardsWolf needs oversampling to avoid dip in sum(psf,[],[1 2]);
        % Trick: oversample during generation, then subsample
        % note that psf generation will take longer with "oversampling"
        % you can also try fixWFPSF, but that fxn is a bit hacky
        % note that oversamp has nothing to do with oversampling mentioned
        % above and is only used during psf-generation
        Method = 'RichardsWolffInt';
        oversamp=4;
        oversize=[size(obj,1)*oversamp size(obj,2)*oversamp size(obj,3)];
        ImageParam = struct('Sampling',[scaleXY/oversamp scaleXY/oversamp scaleZ/oversamp], ...
                            'Size',oversize);
        PSFParam = struct('NA', na, 'n', ri, 'lambdaEm', wl); % 'MinOtf',1.2e-3

        psf = GenericPSFSim(ImageParam, PSFParam, Method);
        psf = psf(0:oversamp:end,0:oversamp:end,:);
        psf = psf / sum(psf);
%         disp(sum(psf))
%         disp(max(psf))
    end
    break
    
    % perform imaging
    im = simulate_wf_imaging_poisson(obj, psf, max_photons, bgr_photons, 'same');
    % border is largely ignored by unet, so padding is not THAT important
    % TODO: how to convert cuda datatype to matlab inbuilt?  -->
    % dip_image_force or ConditionalCudaConvert(im,0)
    if usecuda
        im = ConditionalCudaConvert(im, 0);
    end
    %     DBG
    %     cat(4, im, obj)
    
    %% save as mat-files
    id = strcat('num_photons', num2str(max_photons), '_', ...
                'bgr', num2str(bgr_photons));
    psf_id = strcat('na', num2str(na), '_ri', num2str(ri), ...
                    '_scaleXY', num2str(scaleXY), '_scaleZ', num2str(scaleZ));
    savedir = strcat('simulated_data_pairs/', 'poisson/', id, '/', ...
                     psf_id, '/', sd, '/');

    if ~exist(savedir, 'dir')
        mkdir(savedir)
    end
    
    if (i == 1)
        save(strcat(savedir,'psf'), 'psf', '-v7')
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
    f = dir(fullfile(path, '*.mhd'))
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
    
    