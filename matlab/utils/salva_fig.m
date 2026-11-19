function path = salva_fig(fig, nome)
%SALVA_FIG Salva la figura in matlab/figures/<nome>.png
cartella = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'figures');
if ~exist(cartella, 'dir'), mkdir(cartella); end
path = fullfile(cartella, [nome '.png']);
print(fig, path, '-dpng', '-r130');
end
