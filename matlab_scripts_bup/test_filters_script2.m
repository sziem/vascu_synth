% uses dip_image

im_size = [20, 20];
subsam_factor = 2;

%% create testimage
a_ft = newim(im_size);
% a_ft(floor(im_size(1)/2), floor(im_size(2)/2)-1) = 1;  % no aliasing
% a_ft(floor(im_size(1)/2), floor(im_size(2)/2)+1) = 1;  % no aliasing
a_ft(floor(im_size(1)/2), im_size(2)-2) = 1;  % aliasing
a_ft(floor(im_size(1)/2), 2) = 1;  % aliasing

a = ift2d(a_ft);
if max(imag(a(:))) < 1e-5 * max(real(a(:)))
    a = real(a);
else 
    disp(strcat('max imaginary part of a is ', num2str(max(max(imag(a))))));
end

%% subsample
% simply subsampling leads to aliasing
a_subsam_aliased = subsample(a, 2); % a(1:subsam_factor:end, 1:subsam_factor:end) % is shifted;

% lowpass before subsampling solves this
a_subsam_filtered = filtered_subsampling(a, 2);

% Testing own methods
% original, incorrectly subsampled (aliasing), correctly subsampled 
% cat(1, log(1+abs(a_ft)), extract(log(1 + abs(ft2d(a_subsam_aliased))), size(a_ft)), log(1 + abs(a_ft_filtered)), extract(log(1 + abs(ft2d(a_subsam_filtered))), size(a_ft)))
cat(1, a, resample(a_subsam_aliased, subsam_factor, 0, 'linear'), resample(a_subsam_filtered, subsam_factor, 0, 'linear'))

%% old
% Testing dip_image inbuilt functions resample and subsample
% - seem to do some shift, but lead to aliasing
% - resample and subsample do the same operation
% aliased, approx. correctly subsampled, dip_image resample, dip_image subsample
% cat(1, a_subsam_aliased, a_subsam_filtered, resample(a, 1/subsam_factor), subsample(a, subsam_factor))
