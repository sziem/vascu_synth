% uses dip_image

imsize = [20, 20, 20];
subsam_factor = 2;
dim = 3;

%% create testimage
a_ft = newim(imsize);

%% 3d
% in z
a_ft(floor(imsize(1)/2), floor(imsize(2)/2), floor(imsize(3)/2)-1) = 1;  % no aliasing
a_ft(floor(imsize(1)/2), floor(imsize(2)/2), floor(imsize(3)/2)+1) = 1;  % no aliasing
a_ft(floor(imsize(1)/2), floor(imsize(2)/2), imsize(3)-2) = 1;           % aliasing
a_ft(floor(imsize(1)/2), floor(imsize(2)/2), 2) = 1;                     % aliasing
% in y
% a_ft(floor(imsize(1)/2), floor(imsize(2)/2)-1, floor(imsize(3)/2)) = 1;  % no aliasing
% a_ft(floor(imsize(1)/2), floor(imsize(2)/2)+1, floor(imsize(3)/2)) = 1;  % no aliasing
% a_ft(floor(imsize(1)/2), imsize(2)-2,          floor(imsize(3)/2)) = 1;  % aliasing
% a_ft(floor(imsize(1)/2), 2,                    floor(imsize(3)/2)) = 1;  % aliasing
% in x
% a_ft(floor(imsize(1)/2)-1, floor(imsize(2)/2), floor(imsize(3)/2)) = 1;  % no aliasing
% a_ft(floor(imsize(1)/2)+1, floor(imsize(2)/2), floor(imsize(3)/2)) = 1;  % no aliasing
% a_ft(imsize(1)-2,          floor(imsize(2)/2), floor(imsize(3)/2)) = 1;  % aliasing
% a_ft(2,                    floor(imsize(2)/2), floor(imsize(3)/2)) = 1;  % aliasing

%% 2d
% in y
% a_ft(floor(imsize(1)/2), floor(imsize(2)/2)-1) = 1;  % no aliasing
% a_ft(floor(imsize(1)/2), floor(imsize(2)/2)+1) = 1;  % no aliasing
% a_ft(floor(imsize(1)/2), imsize(2)-2) = 1;           % aliasing
% a_ft(floor(imsize(1)/2), 2) = 1;                     % aliasing
% in x
% a_ft(floor(imsize(1)/2)-1, floor(imsize(2)/2)) = 1;  % no aliasing
% a_ft(floor(imsize(1)/2)+1, floor(imsize(2)/2)) = 1;  % no aliasing
% a_ft(imsize(1)-2,          floor(imsize(2)/2)) = 1;  % aliasing
% a_ft(2,                    floor(imsize(2)/2)) = 1;  % aliasing

a = ift(a_ft);

if max(imag(a(:))) < 1e-5 * max(real(a(:)))
    a = real(a);
else 
    disp(strcat('max imaginary part of a is ', num2str(max(max(imag(a))))));
end

%% subsample
subsam_factors = ones(size(imsize));
subsam_factors(dim) = subsam_factor;

% simply subsampling leads to aliasing
a_subsam_aliased = subsample(a, subsam_factors); % == subsample(a, 2); % 

% lowpass before subsampling solves this
% TODO allow to pass an array of upsampling factors to fxn
a_subsam_filtered = filtered_subsample1d(a, subsam_factor, dim);

% Testing own methods
% original, incorrectly subsampled (aliasing), correctly subsampled 
% cat(1, log(1+abs(a_ft)), extract(log(1 + abs(ft2d(a_subsam_aliased))), size(a_ft)), log(1 + abs(a_ft_filtered)), extract(log(1 + abs(ft2d(a_subsam_filtered))), size(a_ft)))
cat(dim, a, resample(a_subsam_aliased, subsam_factors, 0, 'linear'), resample(a_subsam_filtered, subsam_factors, 0, 'linear'))

%% old
% Testing dip_image inbuilt functions resample and subsample
% - seem to do some shift, but lead to aliasing
% - resample and subsample do the same operation
% aliased, approx. correctly subsampled, dip_image resample, dip_image subsample
% cat(1, a_subsam_aliased, a_subsam_filtered, resample(a, 1/subsam_factor), subsample(a, subsam_factor))
