im_size = [20, 20];
subsam_factor = 2;

filter_type = 'butterworth';
order = 2;
D0 = min(im_size)/2;

a_ft = zeros(im_size);
a_ft(1, floor(im_size(2)/2)) = 1;
a_ft(1, floor(im_size(2)/2) + 2) = 1;
a = fft2(a_ft);  % -1,1,-1,1,...
disp(max(max(imag(a))));
% imshow(a)

a_subsam = a(1:subsam_factor:end, 1:subsam_factor:end);
% imshow(a_subsam)  % aliasing

my_filter = lowpass_filter(filter_type, im_size, D0, order);
a_ft_filter = a_ft .* my_filter; % TODO: padding
% imshow(log(a_ft_filter +1))

a_filter = ifft2(a_ft_filter);
a_subsam2 = a_filter(1:subsam_factor:end, 1:subsam_factor:end);
imshow(a_subsam2)  % no aliasing