function dip_out = filtered_subsampling(dip_in, subsam_factor)
% works only for square images!

% create 2nd order butterworth filter
D0 = min(size(dip_in))/(2*subsam_factor);
filter_type='butterworth';
order = 2;
my_filter = lowpass_filter(filter_type, size(dip_in), D0, order);

% filter in Fourier space
% TODO: do I need to pad?
dip_in_ft = ft(dip_in);
dip_in_ft_filtered = dip_in_ft .* my_filter;
dip_in_filtered = ift(dip_in_ft_filtered);

if max(imag(dip_in_filtered(:))) < 1e-5 * max(real(dip_in_filtered(:)))
    dip_in_filtered = real(dip_in_filtered);
else 
    disp('max imaginary part of a_filtered is significant.  Not casting to real.');
end

% subsample
% TODO check -> this might introduce a shift
dip_out = subsample(dip_in_filtered, subsam_factor);  
end