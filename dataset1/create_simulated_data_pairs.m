% instructions:
% put this script into the dataset folder, adjust params and run it

%% Load and image obj
% Set Parameters
bgr_photons = 10;
max_photons = 10000;  % high value: high noise; high SNR

% Parameters to kSimPSF:
% 'na', 1.2 -> numerical aperture
% 'ri', 1.33 -> refractive index of immersion oil
% 'sX', size(obj,1) -> number of elements in x-direction.
% 'scaleX', 40 -> size of a voxel in x-direction in nm
% y,z accordingly
% 'confocal', 0 -> widefield

na = 1.2;
ri = 1.33;
wl = 520;  % nm

% vascu_synth pixel size: 20 µm squared --> redefine them for correct
% sampling

% --> Imagine Original Structures squeezed by factor of about 10 in z  -->
% no!! preserve isotropy
% TODO: or do subsampling?

% critical sampling for microscope parameters na=0.5, ri=1.33, wl=520 (from Rainer's app):
% pixel size 260 nm in x,y and 2665 in z;
% Do NOT use critical sampling to allow deconv to perform
% "super"-resolution!

% Recommendation: super-sample by factor 2  (--> TODO: ask bene for app)

oversamp=4;  % psf generation will take longer with oversampling, but will be more accurate
scaleXY = 70/oversamp;  % nm, same value for xy implying rotational symmetry
scaleZ = 70/oversamp; % nm  -> already extremely oversampled

impath = strcat(pwd, '/', 'original_images');
subdirs = get_subdirs(impath);
for i = 1:numel(subdirs)
    sd = subdirs{i}; % image0 ... image99
    path = strcat(impath, '/', sd, '/original_image/');
        
    obj = stack_all_pngs(path);
    mysize=[size(obj,1)*oversamp size(obj,2)*oversamp size(obj,3)];

    % Load Object
    % [obj, info] = ReadData3D(strcat(path, '/', fname), false);

    if (i == 1)
        ImageParam = struct('Sampling',[scaleXY scaleXY scaleZ], ...
                            'Size',mysize);
        PSFParam = struct('NA', na, 'n', ri, 'lambdaEm', wl); % 'MinOtf',1.2e-3
        Method = 'RichardsWolffInt';  %is default, but needs oversampling to avoid dip in sum(psf,[],[1 2]); also try fixWFPSF, but that fxn is a bit hacky
        psf = GenericPSFSim(ImageParam, PSFParam, Method);
        psf = psf(0:oversamp:end,0:oversamp:end,:);
        psf = psf / sum(psf);
%         disp(sum(psf))
%         disp(max(psf))
    end
    
    % perform imaging
    im = simulate_wf_imaging_poisson(obj, psf, max_photons, bgr_photons);
    % TODO: how to convert cuda datatype to matlab inbuilt?  -->
    % dip_image_force or ConditionalCudaConvert(im,0)
    
    %     DBG
    %     cat(4, im, obj)
    
    %% save as mat-files
    id = strcat('num_photons', num2str(max_photons), '_', ...
                'bgr', num2str(bgr_photons));
    psf_id = strcat('na', num2str(na), '_ri', num2str(ri), ...
                    '_scaleXY', num2str(scaleXY), '_scaleZ', num2str(scaleZ));
    savedir = strcat('simulated_data_pairs/', 'poisson/', id, '/', ...
                     psf_id, '/', sd, '/');

    if ~exist(savedir)
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
    
    