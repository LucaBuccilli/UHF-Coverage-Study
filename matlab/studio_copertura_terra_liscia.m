%% STUDIO DI COPERTURA UHF TERRA-ARIA - Monte Cavo (RM) - terra sferica liscia
% Progetto personale - Luca Buccilli
%
% Versione in MATLAB base (nessun toolbox) dello studio di copertura:
%   1) diagramma del dipolo a mezz'onda verticale
%   2) link budget verso 6 basi aeree (guadagno reale del dipolo verso ogni sito)
%   3) orizzonte radio su terra liscia con raggio equivalente k = 4/3
%   4) sgombero della prima zona di Fresnel a meta' tratta
%   5) portata terra-aria in funzione della quota dell'aeromobile
%   6) mappe di copertura per aeromobili a 1000 m e 3000 m
% Il terreno reale non e' modellato: vedi studio_copertura_terreno.m (Longley-Rice).
clear; close all;
addpath(fullfile(fileparts(mfilename('fullpath')), 'utils'));

%% 1) Parametri del sistema
f_Hz      = 300e6;        % frequenza [Hz], centro della banda UHF militare 225-400 MHz
Ptx_W     = 50;           % potenza del trasmettitore [W]
h_mast    = 20;           % altezza dell'antenna sul traliccio [m]
L_cavi    = 2;            % perdite di cavi e connettori [dB]
S_rx      = -100;         % sensibilita' del ricevitore [dBm]
G_rx      = 0;            % guadagno dell'antenna ricevente [dBi]
k_factor  = 4/3;          % atmosfera standard
Re_km     = k_factor*6371;
f_MHz     = f_Hz/1e6;
Ptx_dBm   = 10*log10(Ptx_W*1e3);

% Sito trasmittente: Monte Cavo
tx.lat = 41.7508; tx.lon = 12.7083; tx.quota = 949;
h_tx = tx.quota + h_mast;                         % quota dell'antenna s.l.m. [m]

% Siti riceventi (quote s.l.m. degli aeroporti, antenna a 2 m)
siti = table(["Pratica di Mare (AB)"; "Ciampino (AB)"; "Latina (AB)"; ...
              "Guidonia (AB)"; "Viterbo (AB)"; "Frosinone (AB)"], ...
             [41.6548; 41.7994; 41.5424; 41.9903; 42.4303; 41.6464], ...
             [12.4452; 12.5949; 12.9090; 12.7270; 12.0640; 13.2994], ...
             [13; 129; 29; 88; 305; 181], ...
             'VariableNames', {'Sito', 'lat', 'lon', 'quota'});
h_rx_ground = 2;

%% 2) Diagramma del dipolo
el = linspace(-90, 90, 721);
G_el = guadagno_dipolo_dbi(el);
fig1 = figure('Position', [100 100 560 560]);
polarplot(deg2rad(el), max(G_el, -30) + 30, 'LineWidth', 2); hold on;
polarplot(deg2rad(180 - el), max(G_el, -30) + 30, 'LineWidth', 2, 'Color', [0 0.45 0.74]);
rlim([0 35]); rticks(0:10:30); rticklabels({'-30', '-20', '-10', '0'});
title(sprintf('Dipolo \\lambda/2 verticale a %.0f MHz - elevazione [dBi], max %.2f dBi', f_MHz, max(G_el)));
salva_fig(fig1, '1_diagramma_dipolo');

G_tx_max = guadagno_dipolo_dbi(0);
EIRP = Ptx_dBm + G_tx_max - L_cavi;

%% 3) Link budget verso i siti a terra
d    = distanza_km(tx.lat, tx.lon, siti.lat, siti.lon);
h_rx = siti.quota + h_rx_ground;
oriz = orizzonte_km(h_tx, Re_km) + orizzonte_km(h_rx, Re_km);
el_s = angolo_elevazione_deg(h_tx, h_rx, d, Re_km);
G_tx = guadagno_dipolo_dbi(el_s);
Prx  = Ptx_dBm + G_tx - L_cavi - fspl_db(d, f_MHz) + G_rx;
[r1, ~, sgombero] = fresnel_midpoint(h_tx, h_rx, d, f_Hz, Re_km);

risultati = table(siti.Sito, round(d, 1), round(oriz, 1), d < oriz, round(el_s, 2), ...
    round(G_tx, 2), round(fspl_db(d, f_MHz), 1), round(Prx, 1), round(Prx - S_rx, 1), ...
    round(r1, 1), round(sgombero./r1, 1), ...
    'VariableNames', {'Sito', 'Distanza_km', 'Orizzonte_km', 'LOS', 'Elevazione_deg', ...
                      'G_tx_dBi', 'FSPL_dB', 'Prx_dBm', 'Margine_dB', 'Fresnel_r1_m', 'Sgombero_su_r1'});

fprintf('%s\nSTUDIO DI COPERTURA UHF - MONTE CAVO (terra liscia, k = 4/3)\n%s\n', repmat('=', 1, 78), repmat('=', 1, 78));
fprintf('Frequenza %.0f MHz | Ptx %.0f W = %.1f dBm | EIRP %.1f dBm\n', f_MHz, Ptx_W, Ptx_dBm, EIRP);
fprintf('Antenna a %.0f m s.l.m. -> orizzonte radio proprio %.1f km\n\n', h_tx, orizzonte_km(h_tx, Re_km));
disp('--- COLLEGAMENTI VERSO TERRA (rx a 2 m) ---');
disp(risultati);

% verifica dell'esempio svolto a mano (Pratica di Mare)
Prx_mano = 46.99 + 2.14 - 2 - (20*log10(24.3) + 20*log10(300) + 32.44);
riga('Pratica di Mare: Prx script vs calcolo a mano', Prx(1), Prx_mano, 'dBm');

%% 4) Portata terra-aria in funzione della quota
quote = [100 300 500 1000 2000 3000 5000 8000 10000];
oriz_air = orizzonte_km(h_tx, Re_km) + orizzonte_km(quote, Re_km);
el_b = angolo_elevazione_deg(h_tx, quote, oriz_air, Re_km);
Prx_bordo = Ptx_dBm + guadagno_dipolo_dbi(el_b) - L_cavi - fspl_db(oriz_air, f_MHz) + G_rx;
FSPL_max = EIRP + G_rx - S_rx;
d_potenza = 10^((FSPL_max - 20*log10(f_MHz) - 32.44)/20);

tab_air = table(quote.', round(oriz_air.'), round(Prx_bordo.', 1), round(Prx_bordo.' - S_rx, 1), ...
    'VariableNames', {'Quota_aereo_m', 'Orizzonte_km', 'Prx_bordo_dBm', 'Margine_bordo_dB'});
disp('--- PORTATA TERRA-ARIA ---');
disp(tab_air);
fprintf('Portata limitata dalla sola potenza (spazio libero): %.0f km\n', d_potenza);

fig2 = figure('Position', [100 100 800 450]);
plot(quote, oriz_air, '-o', 'LineWidth', 2); grid on;
xlabel('Quota dell''aeromobile s.l.m. [m]'); ylabel('Portata [km]');
title(sprintf('Monte Cavo - portata UHF terra-aria (limite di potenza %.0f km, fuori scala)', d_potenza));
ylim([0 max(oriz_air)*1.15]);
salva_fig(fig2, '4_portata_vs_quota');

%% 5) Mappe di copertura terra-aria
span = 380;
xs = linspace(-span, span, 600);
[X, Y] = meshgrid(xs, xs);
D = max(hypot(X, Y), 0.05);
fig3 = figure('Position', [100 100 1250 560]);
quote_mappa = [1000 3000];
for k = 1:2
    q = quote_mappa(k);
    E = angolo_elevazione_deg(h_tx, q, D, Re_km);
    P = Ptx_dBm + guadagno_dipolo_dbi(E) - L_cavi - fspl_db(D, f_MHz) + G_rx;
    P(D > orizzonte_km(h_tx, Re_km) + orizzonte_km(q, Re_km)) = NaN;     % oltre l'orizzonte
    subplot(1, 2, k);
    contourf(X, Y, min(max(P, -100), -50), -100:10:-50, 'LineColor', 'none'); hold on;
    [sx, sy] = deal(deg2rad(siti.lon - tx.lon)*6371*cosd(tx.lat), deg2rad(siti.lat - tx.lat)*6371);
    plot(sx, sy, 'w^', 'MarkerFaceColor', 'w'); plot(0, 0, 'rp', 'MarkerSize', 14, 'MarkerFaceColor', 'r');
    axis equal; grid on; colorbar; caxis([-100 -50]);
    xlabel('Est [km]'); ylabel('Nord [km]');
    title(sprintf('Aeromobile a %d m s.l.m.: raggio %.0f km', q, orizzonte_km(h_tx, Re_km) + orizzonte_km(q, Re_km)));
end
sgtitle('Copertura UHF terra-aria da Monte Cavo (terra liscia k = 4/3, spazio libero) [dBm]');
salva_fig(fig3, '5_mappa_copertura_aria');
