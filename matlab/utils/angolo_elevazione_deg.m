function el = angolo_elevazione_deg(h1_m, h2_m, d_km, Re_km)
%ANGOLO_ELEVAZIONE_DEG Elevation of the ray from site 1 towards site 2 [deg],
%   including earth curvature (effective radius Re_km).
el = atand((h2_m - h1_m)./(d_km*1e3) - d_km./(2*Re_km));
end
