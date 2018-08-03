function [ im, psf, otf, obj_blur ] = simulate_wf_imaging( obj )
%SIMULATE_WF_IMAGING simulates a widefield image of an object 
%   Detailed explanation goes here

% load obj
% obj = readim(filename_obj);

% Simulate PSF.  For reference here the relevant arguments to kSimPSF:
% some are chosen by default below
% 'na', 1.2 -> numerical aperture
% 'ri', 1.33 -> refractive index of immersion oil
% 'sX', size(obj,1) -> number of elements in x-direction.
% 'scaleX', 40 -> size of a voxel in x-direction in nm
% y,z accordingly
% 'confocal', 1 -> is supposed to return a confocal PSF, but does not work
psf = kSimPSF(...
      {'sX', size(obj,1); 'sY', size(obj,2); 'sZ', size(obj,3);...
      'scaleX', 40; 'scaleY', 40; 'scaleZ', 100;...
      'confocal', 0}...
);

% convolve obj with psf through multiplication in fourier space 
% -> circular convolution, since there is no padding
obj_ft = ft(obj);
otf = ft(psf);
obj_blur = sqrt(prod(size(obj))) * real(ift(obj_ft .* otf));

% determine params of noise
if strcmp(noise_type, 'poisson')
    % conversion = pixel_value / NumPhotons
    % NumPhotons (lambda) = variance    (= mean) for poisson
    % => NumPhotons = pixel_value / conversion  (= variance)
    % low NumPhotons <-> low noise (a little counterintuitive)
    conversion = max(obj_blur)/NumPhotons;
    param = conversion;
    id = NumPhotons;
    % TODO: how to get Offset in there correctly, when using "conversion"?
    % I think it should be 
    %   im = noise(obj_blur + offset*conversion, 'poisson', conversion)
    % which corresponds to inputing sth like
    %   noise(NumPhotons*obj_blur/max(obj_blur), 'poisson')
elseif strcmp(noise_type, 'gaussian')
    % 
    param = std;
    id = std;
end

% apply noise
im = noise(obj_blur, noise_type, param);


end

