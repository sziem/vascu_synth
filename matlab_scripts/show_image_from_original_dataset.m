%% Load and image obj
% Set Parameters
bgr = 10;
num_photons = 10;

% Simulate PSF.  For reference here the relevant arguments to kSimPSF:
% some are chosen by default
% 'na', 1.2 -> numerical aperture
% 'ri', 1.33 -> refractive index of immersion oil
% 'sX', size(obj,1) -> number of elements in x-direction.
% 'scaleX', 40 -> size of a voxel in x-direction in nm
% y,z accordingly
% 'confocal', 1 -> is supposed to return a confocal PSF, but does not work

subdirs = get_subdirs(pwd);
group_index = 1;  % 1...10
data_index = 5;  % 1...12
sd = subdirs{group_index};
subsubdirs = get_subdirs(sd);
ssd = subsubdirs{data_index};
path = strcat(pwd, '/', sd, '/', ssd);
fname = get_mhd(path);

% Load Object
[obj, info] = ReadData3D(strcat(path, '/', fname), false);
obj = dip_image(obj)
% % psf
% psf = kSimPSF(...
% {'na', .1; 'sX', size(obj,1); 'sY', size(obj,2); 'sZ', size(obj,3);...
% 'scaleX', 500; 'scaleY', 500; 'scaleZ', 2000;...
% 'confocal', 0}...
% );
% % perform imaging
% im = simulate_wf_imaging_poisson( obj, psf, bgr, num_photons);

%% add random fluorescence fluctuations
% filterf=gaussf(rand(size(obj))>0.99, 4);
% filterf = filterf-min(filterf);
% filterf=filterf/max(filterf);
% filterf*obj

%% save as mat-files
%id = strcat(num2str(num_photons), '_', num2str(bgr));
%savedir = strcat('images/', 'poisson/', id, '/', sd, '/', ssd, '/');

%if ~exist(savedir)
%    mkdir(savedir)
%end
%save(strcat(savedir,'obj'), 'obj')
%save(strcat(savedir,'psf'), 'psf')
%save(strcat(savedir,'im'),  'im')

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