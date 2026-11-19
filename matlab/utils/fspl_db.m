function L = fspl_db(d_km, f_MHz)
%FSPL_DB Free-space path loss [dB]: 20log10(d_km) + 20log10(f_MHz) + 32.44
L = 20*log10(d_km) + 20*log10(f_MHz) + 32.44;
end
