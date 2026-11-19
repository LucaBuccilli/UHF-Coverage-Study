%% STUDIO DI COPERTURA UHF TERRA-ARIA - Monte Cavo (RM) - terreno reale con Mapping Toolbox
% Progetto personale - Luca Buccilli
%
% Aggiunge il terreno reale allo studio analitico (studio_copertura_terra_liscia.m):
%   1) carica un modello digitale del terreno (DEM) con readgeoraster
%   2) confronta le quote ipotizzate dei siti con quelle del DEM
%   3) estrae il profilo del terreno di ogni collegamento (geointerp)
%   4) verifica visibilita' e sgombero della 1a zona di Fresnel lungo tutto il profilo
%   5) stima la perdita di diffrazione dell'ostacolo dominante (knife-edge, ITU-R P.526)
%   6) calcola con viewshed le zone in vista per ricevitori a terra e aeromobili
%
% Requisiti: MATLAB R2020a o successivo + Mapping Toolbox.
% Dati: file GeoTIFF del DEM in ../data/dem_roma.tif (vedi README, sezione Terrain data).
clear; close all;
radice = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(radice, 'matlab', 'utils'));

%% 1) Parametri (identici allo studio analitico)
f_Hz = 300e6; f_MHz = f_Hz/1e6;
Ptx_dBm = 10*log10(50e3); L_cavi = 2; S_rx = -100; G_rx = 0;
h_mast = 20; h_rx_ground = 2;
Re_km = 4/3*6371;                                    % raggio terrestre equivalente
fattore_viewshed = 0.5;                              % sottocampionamento del DEM per viewshed

tx.nome = "Monte Cavo"; tx.lat = 41.7508; tx.lon = 12.7083;
siti = table(["Pratica di Mare (AB)"; "Ciampino (AB)"; "Latina (AB)"; ...
              "Guidonia (AB)"; "Viterbo (AB)"; "Frosinone (AB)"], ...
             [41.6548; 41.7994; 41.5424; 41.9903; 42.4303; 41.6464], ...
             [12.4452; 12.5949; 12.9090; 12.7270; 12.0640; 13.2994], ...
             [13; 129; 29; 88; 305; 181], ...
             'VariableNames', {'Sito', 'lat', 'lon', 'quota_ipotesi'});

%% 2) Caricamento del DEM
file_dem = fullfile(radice, 'data', 'dem_roma.tif');
if ~isfile(file_dem)
    error(['DEM non trovato: %s\nScaricare un GeoTIFF Copernicus GLO-90 (o GLO-30) da OpenTopography ' ...
           'per lat 41.4-42.6 N, lon 11.9-13.5 E e salvarlo come data/dem_roma.tif'], file_dem);
end
[Z, R] = readgeoraster(file_dem, 'OutputType', 'double');
Z(Z < -500) = NaN;                                   % valori "no data"
Z(isnan(Z)) = 0;                                     % mare e celle vuote a 0 m
fprintf('DEM: %d x %d celle, lat %.2f-%.2f, lon %.2f-%.2f\n', size(Z, 1), size(Z, 2), ...
    R.LatitudeLimits, R.LongitudeLimits);
tutti_lat = [tx.lat; siti.lat]; tutti_lon = [tx.lon; siti.lon];
if any(tutti_lat < R.LatitudeLimits(1) | tutti_lat > R.LatitudeLimits(2) | ...
       tutti_lon < R.LongitudeLimits(1) | tutti_lon > R.LongitudeLimits(2))
    error('Il DEM non copre tutti i siti: serve almeno lat 41.5-42.5 N, lon 12.0-13.4 E.');
end

%% 3) Quote dei siti: ipotesi vs DEM
tx.quota = geointerp(Z, R, tx.lat, tx.lon, 'linear');
siti.quota_DEM = geointerp(Z, R, siti.lat, siti.lon, 'linear');
fprintf('\nQuota di Monte Cavo dal DEM: %.0f m (ipotesi 949 m)\n', tx.quota);
disp(siti(:, {'Sito', 'quota_ipotesi', 'quota_DEM'}));
% Nota: Copernicus e' un modello di superficie (DSM): include edifici e vegetazione.

%% 4) Profili del terreno, Fresnel e diffrazione
n = height(siti);
res = table(siti.Sito, zeros(n,1), false(n,1), zeros(n,1), zeros(n,1), zeros(n,1), ...
            zeros(n,1), zeros(n,1), zeros(n,1), zeros(n,1), ...
            'VariableNames', {'Sito', 'Distanza_km', 'LOS_terreno', 'Sgombero_min_r1', ...
            'nu_max', 'Diffrazione_dB', 'Ostacolo_km', 'Prx_liscia_dBm', 'Prx_terreno_dBm', 'Margine_dB'});
fig1 = figure('Position', [50 50 1300 900]);
for k = 1:n
    [d_km, z_m] = profilo_terreno(Z, R, tx.lat, tx.lon, siti.lat(k), siti.lon(k), 1500);
    a = analisi_profilo(d_km, z_m, h_mast, h_rx_ground, f_Hz, Re_km);
    D = d_km(end);
    % link budget in spazio libero con il guadagno del dipolo verso il sito
    el = angolo_elevazione_deg(z_m(1) + h_mast, z_m(end) + h_rx_ground, D, Re_km);
    Prx_fs = Ptx_dBm + guadagno_dipolo_dbi(el) - L_cavi - fspl_db(D, f_MHz) + G_rx;
    Prx_terr = Prx_fs - a.J_dB;
    res(k, 2:end) = {D, a.los, a.sgombero_r1_min, a.nu_max, a.J_dB, d_km(a.i_max), ...
                     Prx_fs, Prx_terr, Prx_terr - S_rx};

    subplot(3, 2, k); hold on;
    area(d_km, a.ostacolo, min(a.ostacolo) - 50, 'FaceColor', [0.80 0.72 0.60], 'EdgeColor', 'none');
    plot(d_km, a.raggio, 'b', 'LineWidth', 1.2);
    plot(d_km, a.raggio - a.r1, 'b--');
    plot(d_km, a.raggio - 0.6*a.r1, 'b:');
    plot(d_km(a.i_max), a.ostacolo(a.i_max), 'rv', 'MarkerFaceColor', 'r');
    grid on; xlim([0 D]);
    xlabel('distanza da Monte Cavo [km]'); ylabel('quota [m]');
    if a.los, s = 'in vista'; else, s = 'OSTRUITO'; end
    title(sprintf('%s: %s, \\nu_{max} = %.2f, diffrazione %.1f dB', siti.Sito(k), s, a.nu_max, a.J_dB));
end
legend({'terreno + curvatura (k = 4/3)', 'raggio diretto', '1a zona di Fresnel', '0,6 r_1', ...
        'ostacolo dominante'}, 'Location', 'southoutside', 'Orientation', 'horizontal');
sgtitle('Profili del terreno da Monte Cavo alle basi aeree (DEM Copernicus)');
salva_fig(fig1, '6_profili_terreno');

fprintf('\n--- COLLEGAMENTI SU TERRENO REALE ---\n');
disp(res);

%% 5) Copertura con viewshed: ricevitori a terra e aeromobili
[Zv, Rv] = georesize(Z, R, fattore_viewshed);        % DEM piu' leggero per viewshed
[XI, YI] = meshgrid(1:Rv.RasterSize(2), 1:Rv.RasterSize(1));
[LAT, LON] = intrinsicToGeographic(Rv, XI, YI);
D = distanza_km(tx.lat, tx.lon, LAT, LON);
D = max(D, 0.05);
Ra_m = 6371e3; Re_m = Re_km*1e3;                     % raggio reale ed effettivo [m]

casi = {2, 'AGL', 'ricevitore a terra (2 m)'; ...
        1000, 'MSL', 'aeromobile a 1000 m s.l.m.'; ...
        3000, 'MSL', 'aeromobile a 3000 m s.l.m.'};
fig2 = figure('Position', [50 50 1500 480]);
for k = 1:size(casi, 1)
    [h_tgt, rif, nome] = casi{k, :};
    vis = viewshed(Zv, Rv, tx.lat, tx.lon, h_mast, h_tgt, 'AGL', rif, Ra_m, Re_m);
    if strcmp(rif, 'AGL'), h_abs = Zv + h_tgt; else, h_abs = h_tgt*ones(size(Zv)); end
    E = angolo_elevazione_deg(tx.quota + h_mast, h_abs, D, Re_km);
    P = Ptx_dBm + guadagno_dipolo_dbi(E) - L_cavi - fspl_db(D, f_MHz) + G_rx;
    P(~vis) = NaN;                                    % celle in ombra del terreno
    coperta = mean(vis(:) & P(:) > S_rx) * 100;
    fprintf('%-30s area del DEM in vista e sopra soglia: %.1f %%\n', nome, coperta);

    subplot(1, 3, k);
    imagesc(LON(1, :), LAT(:, 1), P, 'AlphaData', ~isnan(P)); axis xy; hold on;
    contour(LON, LAT, Zv, 0:200:2000, 'Color', [0.6 0.6 0.6], 'LineWidth', 0.3);
    plot(tx.lon, tx.lat, 'rp', 'MarkerSize', 14, 'MarkerFaceColor', 'r');
    plot(siti.lon, siti.lat, 'k^', 'MarkerFaceColor', 'w');
    caxis([-100 -40]); colorbar; daspect([1 cosd(mean(R.LatitudeLimits)) 1]);
    xlabel('longitudine [°]'); ylabel('latitudine [°]');
    title(sprintf('%s: %.0f%% coperto', nome, coperta));
end
sgtitle('Copertura UHF da Monte Cavo su terreno reale (viewshed, k = 4/3) - potenza ricevuta [dBm]');
salva_fig(fig2, '7_viewshed_copertura');
