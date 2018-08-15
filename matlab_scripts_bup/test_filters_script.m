im_size = [20, 20];
subsam_factor = 2;

filter_type = 'butterworth';
order = 2;
D0 = min(im_size)./(2*subsam_factor);

%% with dip_image
a_ft = newim(im_size);
% a_ft(floor(im_size(1)/2), floor(im_size(2)/2)-1) = 1;  % no aliasing
% a_ft(floor(im_size(1)/2), floor(im_size(2)/2)+1) = 1;  % no aliasing
a_ft(floor(im_size(1)/2), im_size(2)-2) = 1;  % aliasing
a_ft(floor(im_size(1)/2), 2) = 1;  % aliasing

a = ift2d(a_ft);  % -1,1,-1,1,...
if max(max(imag(a))) < 1e-8
    a = real(a);
else 
    disp(strcat('max imaginary part of a is ', num2str(max(max(imag(a))))));
end

% simply subsampling leads to aliasing
a_subsam_aliased = a(1:subsam_factor:end, 1:subsam_factor:end);

% lowpass before subsampling solves this
% TODO: wouldn't padding also solve aliasing even without filter??
my_filter = lowpass_filter(filter_type, im_size, D0, order);

% would padding make sense?
% w/ "circular" padding
% if strcmp(padding, 'circular')
%     a_ft_filtered = a_ft .* my_filter;
% elseif strcmp(paddin, 'same')
%     a_pad = extract(a, 2*size(a));
%     psf_pad = extract(psf, 2*size(psf));
%     obj_pad_ft = ft(obj_pad);
%     psf_pad_ft = ft(psf_pad);
%     extract(real(ift(obj_pad_ft .* psf_pad_ft)), size(obj))
% end

a_ft_filtered = a_ft .* my_filter;
a_filtered = ift2d(a_ft_filtered);

if max(max(imag(a_filtered))) < 1e-8
    a_filtered = real(a_filtered);
else 
    disp(strcat('max imaginary part of a_filtered is ', num2str(max(max(imag(a_filtered))))));
end
a_subsam_filtered = a_filtered(1:subsam_factor:end, 1:subsam_factor:end);

% Testing own methods
% original, subsampled from original (aliasing), filtered original, subsampled from filtered
cat(1, log(1+abs(a_ft)), extract(log(1 + abs(ft2d(a_subsam_aliased))), size(a_ft)), log(1 + abs(a_ft_filtered)), extract(log(1 + abs(ft2d(a_subsam_filtered))), size(a_ft)))
cat(1, a, resample(a_subsam_aliased, subsam_factor, -1, 'linear'), a_filtered, resample(a_subsam_filtered, subsam_factor, -1, 'linear'))

% Testing dip_image inbuilt functions resample and subsample
% - seem to have a strange shift and aliasing
% - resample and subsample do the same operation
% aliased, approx. correctly subsampled, dip_image resample, dip_image subsample
cat(1, a_subsam_aliased, a_subsam_filtered, resample(a, 1/subsam_factor), subsample(a, subsam_factor))

%% without dip_image
% a_ft = zeros(im_size);
% a_ft(1, floor(im_size(2)/2)) = 1;
% a_ft(1, floor(im_size(2)/2) + 2) = 1;
% a = fft2(a_ft);  % -1,1,-1,1,...
% disp(max(max(imag(a))));
% % imshow(a)
% 
% a_subsam = a(1:subsam_factor:end, 1:subsam_factor:end);
% % imshow(a_subsam)  % aliasing
% 
% my_filter = lowpass_filter(filter_type, im_size, D0, order);
% a_ft_filter = a_ft .* my_filter; % TODO: padding
% % imshow(log(a_ft_filter +1))
% 
% a_filter = ifft2(a_ft_filter);
% a_subsam2 = a_filter(1:subsam_factor:end, 1:subsam_factor:end);
% imshow(a_subsam2)  % no aliasing