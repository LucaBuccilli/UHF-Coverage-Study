%% build_link_model - Builds the Simulink model "link_terra_aria" from library blocks only
% Ground-to-air UHF link between Monte Cavo and an aircraft flying radially away
% at constant altitude. At each time step the model computes:
%   distance d(t) = d0 + v*t
%   elevation of the ray (effective earth radius Re)
%   gain of the vertical half-wave dipole towards the aircraft
%   free-space path loss, received power and link margin
%   line of sight on a smooth earth (d < radio horizon)
%   link status = (margin > 0) AND (line of sight)
% Workspace variables (set below as defaults): h_air, v_kms, d0, T_sim and the link budget.
cartella = fileparts(mfilename('fullpath'));
mdl = 'link_terra_aria';
if bdIsLoaded(mdl), close_system(mdl, 0); end
new_system(mdl);
open_system(mdl);

% default parameters (overridden by simula_link_terra_aria.m)
par = struct('h_tx', 969, 'Re', 4/3*6371, 'f_MHz', 300, 'Ptx_dBm', 10*log10(50e3), ...
             'L_cavi', 2, 'G_rx', 0, 'S_rx', -100, 'h_air', 3000, 'v_kms', 0.25, ...
             'd0', 5, 'T_sim', 2400);
nomi = fieldnames(par);
for k = 1:numel(nomi), assignin('base', nomi{k}, par.(nomi{k})); end

blk = @(nome) [mdl '/' nome];
% --- distance d(t) = d0 + v*t [km]
add_block('simulink/Sources/Clock', blk('Tempo'), 'Position', [30 100 60 130]);
add_block('simulink/Math Operations/Gain', blk('Velocita'), 'Gain', 'v_kms', 'Position', [100 100 150 130]);
add_block('simulink/Math Operations/Bias', blk('Distanza iniziale'), 'Bias', 'd0', 'Position', [190 100 240 130]);
add_line(mdl, 'Tempo/1', 'Velocita/1');
add_line(mdl, 'Velocita/1', 'Distanza iniziale/1');

% --- elevation of the ray [rad]: atan((h_air - h_tx)/(1000 d) - d/(2 Re))
add_block('simulink/Sources/Constant', blk('Quota aereo'), 'Value', 'h_air', 'Position', [190 170 240 200]);
add_block('simulink/Signal Routing/Mux', blk('Mux'), 'Inputs', '2', 'Position', [290 100 295 200]);
add_block('simulink/User-Defined Functions/Fcn', blk('Elevazione'), ...
    'Expr', 'atan((u(2) - h_tx)/(u(1)*1000) - u(1)/(2*Re))', 'Position', [340 135 520 165]);
add_line(mdl, 'Distanza iniziale/1', 'Mux/1');
add_line(mdl, 'Quota aereo/1', 'Mux/2');
add_line(mdl, 'Mux/1', 'Elevazione/1');

% --- dipole gain [dBi]: 10 log10(1.64 (cos(pi/2 sin el)/cos el)^2)
add_block('simulink/User-Defined Functions/Fcn', blk('Guadagno dipolo'), ...
    'Expr', '10*log10(1.64*(cos(1.5707963267948966*sin(u(1)))/cos(u(1)))^2)', 'Position', [570 135 760 165]);
add_line(mdl, 'Elevazione/1', 'Guadagno dipolo/1');

% --- free-space path loss [dB]
add_block('simulink/User-Defined Functions/Fcn', blk('FSPL'), ...
    'Expr', '20*log10(u(1)) + 20*log10(f_MHz) + 32.44', 'Position', [340 230 520 260]);
add_line(mdl, 'Distanza iniziale/1', 'FSPL/1', 'autorouting', 'on');

% --- received power: (Ptx - Lcavi + Grx) + Gtx - FSPL
add_block('simulink/Sources/Constant', blk('Potenza e perdite'), 'Value', 'Ptx_dBm - L_cavi + G_rx', ...
    'Position', [570 60 700 90]);
add_block('simulink/Math Operations/Sum', blk('Potenza ricevuta'), 'Inputs', '++-', ...
    'IconShape', 'rectangular', 'Position', [810 60 840 270]);
add_line(mdl, 'Potenza e perdite/1', 'Potenza ricevuta/1', 'autorouting', 'on');
add_line(mdl, 'Guadagno dipolo/1', 'Potenza ricevuta/2', 'autorouting', 'on');
add_line(mdl, 'FSPL/1', 'Potenza ricevuta/3', 'autorouting', 'on');

% --- margin over the receiver sensitivity
add_block('simulink/Sources/Constant', blk('Sensibilita'), 'Value', 'S_rx', 'Position', [810 300 860 330]);
add_block('simulink/Math Operations/Sum', blk('Margine'), 'Inputs', '+-', 'Position', [900 150 930 180]);
add_line(mdl, 'Potenza ricevuta/1', 'Margine/1', 'autorouting', 'on');
add_line(mdl, 'Sensibilita/1', 'Margine/2', 'autorouting', 'on');
add_block('simulink/Logic and Bit Operations/Compare To Zero', blk('Margine positivo'), ...
    'relop', '>', 'Position', [980 150 1030 180]);
add_line(mdl, 'Margine/1', 'Margine positivo/1');

% --- line of sight on a smooth earth: d < sqrt(2 Re h_tx) + sqrt(2 Re h_air)
add_block('simulink/Sources/Constant', blk('Orizzonte radio'), ...
    'Value', 'sqrt(2*Re*h_tx/1000) + sqrt(2*Re*h_air/1000)', 'Position', [570 380 760 410]);
add_block('simulink/Logic and Bit Operations/Relational Operator', blk('In vista'), ...
    'Operator', '<', 'Position', [810 360 850 400]);
add_line(mdl, 'Distanza iniziale/1', 'In vista/1', 'autorouting', 'on');
add_line(mdl, 'Orizzonte radio/1', 'In vista/2', 'autorouting', 'on');

% --- link status
add_block('simulink/Logic and Bit Operations/Logical Operator', blk('Collegamento OK'), ...
    'Operator', 'AND', 'Position', [1080 160 1110 390]);
add_line(mdl, 'Margine positivo/1', 'Collegamento OK/1', 'autorouting', 'on');
add_line(mdl, 'In vista/1', 'Collegamento OK/2', 'autorouting', 'on');

% --- outputs
uscite = {'Distanza iniziale', 'd_out'; 'Potenza ricevuta', 'prx_out'; ...
          'Margine', 'margine_out'; 'Collegamento OK', 'link_out'};
for k = 1:size(uscite, 1)
    y = 460 + 60*k;
    add_block('simulink/Sinks/To Workspace', blk(uscite{k, 2}), 'VariableName', uscite{k, 2}, ...
        'SaveFormat', 'Array', 'Position', [1160 y 1230 y+30]);
    add_line(mdl, [uscite{k, 1} '/1'], [uscite{k, 2} '/1'], 'autorouting', 'on');
end
add_block('simulink/Sinks/Scope', blk('Scope'), 'NumInputPorts', '2', 'Position', [1160 60 1200 120]);
add_line(mdl, 'Potenza ricevuta/1', 'Scope/1', 'autorouting', 'on');
add_line(mdl, 'Collegamento OK/1', 'Scope/2', 'autorouting', 'on');

set_param(mdl, 'Solver', 'FixedStepDiscrete', 'FixedStep', '1', 'StopTime', 'T_sim');
save_system(mdl, fullfile(cartella, [mdl '.slx']));
fprintf('Model %s created in %s\n', mdl, cartella);
