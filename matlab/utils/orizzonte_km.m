function d = orizzonte_km(h_m, Re_km)
%ORIZZONTE_KM Radio horizon [km] of an antenna at height h_m [m] above sea level,
%   on a smooth earth with effective radius Re_km.
d = sqrt(2*Re_km*max(h_m, 0)/1e3);
end
