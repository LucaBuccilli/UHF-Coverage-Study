function J = perdita_knife_edge(nu)
%PERDITA_KNIFE_EDGE Single knife-edge diffraction loss [dB], ITU-R P.526 approximation.
%   J(nu) = 6.9 + 20 log10( sqrt((nu - 0.1)^2 + 1) + nu - 0.1 )   for nu > -0.78
%   J(nu) = 0                                                    otherwise
J = zeros(size(nu));
k = nu > -0.78;
J(k) = 6.9 + 20*log10(sqrt((nu(k) - 0.1).^2 + 1) + nu(k) - 0.1);
end
