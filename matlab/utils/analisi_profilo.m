function a = analisi_profilo(d_km, z_m, h1_agl, h2_agl, f_Hz, Re_km)
%ANALISI_PROFILO Line of sight, Fresnel clearance and diffraction on a real terrain profile.
%   d_km    distances from the transmitter along the path [km] (0 ... D)
%   z_m     terrain elevation at those points [m a.s.l.]
%   h1_agl  transmit antenna height above ground [m]
%   h2_agl  receive antenna height above ground [m]
%   Re_km   effective earth radius [km] (k = 4/3 -> 8495 km)
% Output struct:
%   a.raggio      height of the direct ray [m]
%   a.bulge       earth bulge d1*d2/(2 Re) [m]
%   a.ostacolo    terrain + bulge [m] (what the ray must clear)
%   a.r1          first Fresnel zone radius [m]
%   a.sgombero    clearance ray - obstacle [m]
%   a.nu          Fresnel-Kirchhoff parameter along the path
%   a.nu_max, a.i_max   dominant obstacle (largest nu) and its index
%   a.J_dB        knife-edge diffraction loss of the dominant obstacle
%   a.los         true if the ray clears the terrain everywhere
%   a.sgombero_r1_min   minimum clearance normalized to r1
lam = 3e8 / f_Hz;
D = d_km(end);
d1 = d_km(:).' * 1e3;  d2 = (D - d_km(:).') * 1e3;          % [m]
h1 = z_m(1) + h1_agl;  h2 = z_m(end) + h2_agl;             % antenna heights a.s.l.
a.raggio   = h1 + (h2 - h1) * d1 / (D*1e3);
a.bulge    = d1 .* d2 / (2 * Re_km * 1e3);
a.ostacolo = z_m(:).' + a.bulge;
a.sgombero = a.raggio - a.ostacolo;
a.r1       = sqrt(lam * d1 .* d2 / (D*1e3));
interni    = 2:numel(d1)-1;                                % exclude the two antennas
a.nu       = -sqrt(2) * a.sgombero ./ max(a.r1, 1e-9);
[a.nu_max, k] = max(a.nu(interni));
a.i_max    = interni(k);
a.J_dB     = perdita_knife_edge(a.nu_max);
a.los      = all(a.sgombero(interni) > 0);
a.sgombero_r1_min = min(a.sgombero(interni) ./ a.r1(interni));
end
