function [d_km, z_m, lat, lon] = profilo_terreno(Z, R, lat1, lon1, lat2, lon2, npts)
%PROFILO_TERRENO Terrain profile between two points from a DEM (Mapping Toolbox).
%   Samples npts points along the path and interpolates the DEM elevations with
%   geointerp. For paths of up to ~100 km the straight line in latitude/longitude
%   is a very good approximation of the great circle.
if nargin < 7, npts = 1000; end
lat = linspace(lat1, lat2, npts);
lon = linspace(lon1, lon2, npts);
z_m = geointerp(Z, R, lat, lon, 'linear');
z_m(isnan(z_m)) = 0;                              % no-data cells (sea) at 0 m
d_km = distanza_km(lat1, lon1, lat, lon);
end
