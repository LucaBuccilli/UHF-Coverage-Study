function d = distanza_km(lat1, lon1, lat2, lon2)
%DISTANZA_KM Great-circle distance (haversine formula) in km. Inputs in degrees.
R = 6371;
dp = deg2rad(lat2 - lat1); dl = deg2rad(lon2 - lon1);
a = sin(dp/2).^2 + cos(deg2rad(lat1)).*cos(deg2rad(lat2)).*sin(dl/2).^2;
d = 2*R*asin(sqrt(a));
end
