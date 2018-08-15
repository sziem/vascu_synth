%% with dip_image
function transfer_function = lowpass_filter(type, im_size, D0, n)
    
    D = rr(im_size);
    
    switch type
    case 'ideal'
        transfer_function = D < D0;
    case 'butterworth'
        transfer_function = 1./(1 + (D./D0).^(2*n));
    case 'gauss'
        transfer_function = exp(-(D.^2)./(2*(D0^2)));
    otherwise
        error('Unknown filter type.')
    end
%     transfer_function
end


%% without dip_image
% function transfer_function = lowpass_filter(type, im_size, D0, n)
%     
%     [U, V] = dftuv(im_size);
%     D = hypot(U, V); % cartesian distance
%     
%     switch type
%     case 'ideal'
%         transfer_function = single(D<=D0);
%     case 'butterworth'
%         transfer_function = 1./(1 + (D./D0).^(2*n));
%     case 'gauss'
%         transfer_function = exp(-(D.^2)./(2*(D0^2)));
%     otherwise
%         error('Unknown filter type.')
%     end
%     
% end