%% simula_link_terra_aria - Maximum link range versus aircraft altitude with the Simulink model
% For several aircraft altitudes the model link_terra_aria flies the aircraft away from
% Monte Cavo at 900 km/h. The script measures the distance at which the link is lost and
% the received power at that point, and compares them with the smooth-earth theory.
cartella = fileparts(mfilename('fullpath'));
addpath(fullfile(fileparts(cartella), 'matlab', 'utils'));
mdl = 'link_terra_aria';
if ~exist(fullfile(cartella, [mdl '.slx']), 'file'), run(fullfile(cartella, 'build_link_model.m')); end
load_system(fullfile(cartella, [mdl '.slx']));

h_tx = 969; Re = 4/3*6371;
quote = [100 300 1000 3000 10000];
fig = figure('Position', [100 100 900 450]); hold on;
fprintf('simula_link_terra_aria - Simulink, aircraft at 900 km/h\n');
for k = 1:numel(quote)
    in = Simulink.SimulationInput(mdl);
    in = in.setVariable('h_air', quote(k));
    out = sim(in);
    d = out.d_out; prx = out.prx_out; ok = logical(out.link_out);
    i_last = find(ok, 1, 'last');                       % last instant with a working link
    d_teo = sqrt(2*Re*h_tx/1000) + sqrt(2*Re*quote(k)/1000);
    fprintf(' aircraft at %5d m\n', quote(k));
    riga('maximum link range', d(i_last), d_teo, 'km');
    fprintf('  %-42s measured = %10.1f dBm\n', 'received power at maximum range', prx(i_last));
    plot(d, prx, 'LineWidth', 1.4, 'DisplayName', sprintf('%d m', quote(k)));
end
yline(-100, 'r--', 'receiver sensitivity', 'HandleVisibility', 'off');
xlabel('distance from Monte Cavo [km]'); ylabel('received power [dBm]'); grid on; legend;
title('Received power along the outbound flight - the link is lost at the radio horizon');
salva_fig(fig, 'simulink_link_terra_aria');
