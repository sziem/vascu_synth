function dip_out = filtered_subsample1d(dip_in, subsam_factor, dim)
% subsamples along one dimension

% create 4th order butterworth filter
% Gonzalez Woods actually recommends 2nd, but am worried about frequencies
imsize = size(dip_in);
D0 = imsize(dim)/(2*subsam_factor);
filter_type='butterworth';
order = 4;

subsam_factors = ones(size(imsize));
subsam_factors(dim) = subsam_factor;
filter_size = ones(size(imsize));
filter_size(dim) = imsize(dim);
rep_size = imsize;
rep_size(dim) = 1;

my_filter = lowpass_filter(filter_type, filter_size, D0, order);

% filter in Fourier space
% TODO: do I need to pad?
dip_in_ft = ft(dip_in);
dip_in_ft_filtered = dip_in_ft .* repmat(my_filter, rep_size);  % "broadcasting"
dip_in_filtered = ift(dip_in_ft_filtered);

if max(imag(dip_in_filtered(:))) < 1e-5 * max(real(dip_in_filtered(:)))
    dip_in_filtered = real(dip_in_filtered);
else 
    disp('max imaginary part of a_filtered is significant.  Not casting to real.');
end

% subsample
dip_out = subsample(dip_in_filtered, subsam_factors);  
end