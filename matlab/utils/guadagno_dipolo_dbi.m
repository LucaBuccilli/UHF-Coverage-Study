function G = guadagno_dipolo_dbi(el_deg)
%GUADAGNO_DIPOLO_DBI Gain [dBi] of a vertical half-wave dipole at elevation el_deg.
%   G(theta) = 1.64 * [cos(pi/2 cos theta) / sin theta]^2, theta from the dipole axis.
th = deg2rad(90 - el_deg);
th = min(max(th, 1e-6), pi - 1e-6);
F = cos(pi/2*cos(th)) ./ sin(th);
G = 10*log10(1.64*F.^2 + 1e-12);
end
