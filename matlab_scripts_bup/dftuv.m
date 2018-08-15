% not needed when using dip_image
% function [U, V] = dftuv(im_size)
%     
%     M = im_size(1); %x
%     N = im_size(2); %y
%     
%     u = single(0:(M-1));
%     v = single(0:(N-1));
%     
%     idx = find(u > M/2);
%     u(idx) = u(idx) - M;
%     idy = find(v > N/2);
%     v(idy) = v(idy) - N;
%     
%     [V, U] = meshgrid(v,u);
%     
% end