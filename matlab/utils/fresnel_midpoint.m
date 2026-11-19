function [r1_m, bulge_m, sgombero_m] = fresnel_midpoint(h1_m, h2_m, d_km, f_Hz, Re_km)
%FRESNEL_MIDPOINT First Fresnel zone radius, earth bulge and clearance at mid-path [m].
d1 = d_km/2; d2 = d_km/2;
r1_m = 17.32*sqrt(d1.*d2./((f_Hz/1e9).*d_km));
bulge_m = d1.*d2./(2*Re_km)*1e3;
sgombero_m = (h1_m + h2_m)/2 - bulge_m;
end
