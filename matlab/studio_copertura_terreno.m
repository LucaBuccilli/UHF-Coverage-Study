%% STUDIO DI COPERTURA UHF TERRA-ARIA - Sito di Monte Cavo (RM)
% Progetto personale - Luca Buccilli
%
% Obiettivo: valutare la copertura radio UHF (banda aeronautica militare
% 225-400 MHz) di una stazione terra-aria su un sito collinare vicino a Roma,
% verso ricevitori a terra e verso aeromobili in volo.
%
% Requisiti: MATLAB R2020a o successivo + Antenna Toolbox
% (oppure Communications Toolbox). Serve la connessione Internet: il terreno
% (modello GMTED2010) e le mappe vengono scaricati dai server MathWorks.
%
% Eseguire una sezione alla volta (Ctrl+Invio) e guardare i risultati.

clear; clc; close all;

%% 1) PARAMETRI DEL SISTEMA (ipotesi di progetto)
f        = 300e6;   % frequenza [Hz] - centro banda UHF militare
Ptx_W    = 50;      % potenza del trasmettitore [W]
hTx      = 20;      % altezza dell'antenna sul traliccio [m]
Lcavi_dB = 2;       % perdite di cavi e connettori [dB]
Srx_dBm  = -100;    % sensibilita' del ricevitore [dBm] (ipotesi conservativa)

Ptx_dBm = 10*log10(Ptx_W*1e3);
fprintf('Potenza trasmessa: %.1f dBm\n', Ptx_dBm);

%% 2) ANTENNA: dipolo progettato a 300 MHz
% Dipolo verticale: diagramma omnidirezionale sul piano orizzontale
ant = design(dipole, f);
figure; pattern(ant, f);                 % diagramma 3D
title('Dipolo a 300 MHz - diagramma di radiazione 3D');
figure; patternElevation(ant, f);        % taglio in elevazione
title('Dipolo a 300 MHz - taglio in elevazione');

%% 3) SITO TRASMITTENTE
% Monte Cavo (Colli Albani), circa 949 m s.l.m.
tx = txsite("Name", "Monte Cavo", ...
    "Latitude", 41.7508, "Longitude", 12.7083, ...
    "Antenna", ant, ...
    "AntennaHeight", hTx, ...
    "TransmitterFrequency", f, ...
    "TransmitterPower", Ptx_W, ...
    "SystemLoss", Lcavi_dB);

viewer = siteviewer("Name", "Studio copertura UHF");
show(tx);
fprintf('Quota del terreno al sito: %.0f m s.l.m.\n', elevation(tx));

%% 4) MODELLI DI PROPAGAZIONE
pmFS = propagationModel("freespace");       % spazio libero (riferimento)
pmLR = propagationModel("longley-rice");    % terreno irregolare (ITM)

%% 5) MAPPA DI COPERTURA VERSO TERRA (ricevitore a 2 m)
% Livelli di segnale da mostrare: dalla sensibilita' fino a -60 dBm
clearMap(viewer);
coverage(tx, pmLR, ...
    "SignalStrengths", Srx_dBm:10:-60, ...
    "MaxRange", 120e3, ...
    "Resolution", 250, ...
    "ReceiverAntennaHeight", 2);
% -> Fai uno screenshot della mappa per la relazione tecnica

%% 6) COLLEGAMENTI PUNTO-PUNTO VERSO SITI DI INTERESSE
nomi = ["Pratica di Mare (AB)", "Ciampino (AB)", "Latina (AB)", ...
        "Guidonia (AB)", "Viterbo (AB)", "Frosinone (AB)"];
lat  = [41.6548, 41.7994, 41.5424, 41.9903, 42.4303, 41.6464];
lon  = [12.4452, 12.5949, 12.9090, 12.7270, 12.0640, 13.2994];

rxTerra = rxsite("Name", nomi, "Latitude", lat, "Longitude", lon, ...
    "AntennaHeight", 2, "ReceiverSensitivity", Srx_dBm);

d_km    = distance(tx, rxTerra) / 1e3;
visib   = los(tx, rxTerra);                     % visibilita' ottica
PrxFS   = sigstrength(rxTerra, tx, pmFS);       % potenza ricevuta, spazio libero
PrxLR   = sigstrength(rxTerra, tx, pmLR);       % potenza ricevuta, Longley-Rice
margine = PrxLR - Srx_dBm;                      % margine di collegamento

risultatiTerra = table(nomi', round(d_km',1), visib', round(PrxFS',1), ...
    round(PrxLR',1), round(margine',1), margine' > 0, ...
    'VariableNames', ["Sito","Distanza_km","LOS","Prx_FS_dBm", ...
                      "Prx_LR_dBm","Margine_dB","Collegamento_OK"]);
disp('--- COLLEGAMENTI VERSO TERRA (rx a 2 m) ---');
disp(risultatiTerra);

clearMap(viewer); show(tx);
link(rxTerra, tx, pmLR);   % verde = collegamento OK, rosso = non OK

%% 7) VERIFICA DEL LINK BUDGET A MANO (spazio libero)
% FSPL [dB] = 20log10(d_km) + 20log10(f_MHz) + 32.44
% Prx = Ptx + Gtx - Lcavi - FSPL + Grx   (Grx = 0 dBi ipotizzato)
Gtx_dBi   = 2.15;                       % guadagno teorico di un dipolo
FSPL_dB   = 20*log10(d_km) + 20*log10(f/1e6) + 32.44;
PrxMano   = Ptx_dBm + Gtx_dBi - Lcavi_dB - FSPL_dB;
disp('--- CONFRONTO: calcolo a mano vs MATLAB (spazio libero) ---');
disp(table(nomi', round(PrxMano',1), round(PrxFS',1), ...
    'VariableNames', ["Sito","Prx_a_mano_dBm","Prx_MATLAB_dBm"]));
% Le differenze piccole dipendono dal guadagno effettivo del dipolo
% simulato nella direzione del ricevitore (non esattamente 2.15 dBi).

%% 8) COPERTURA TERRA-ARIA (aeromobile a 1000 m sul terreno)
clearMap(viewer); show(tx);
coverage(tx, pmLR, ...
    "SignalStrengths", Srx_dBm:10:-60, ...
    "MaxRange", 200e3, ...
    "Resolution", 500, ...
    "ReceiverAntennaHeight", 1000);
% Confronta questa mappa con quella del punto 5:
% in quota il terreno blocca molto meno e la copertura si allarga.

%% 9) PORTATA IN FUNZIONE DELLA QUOTA DELL'AEROMOBILE
% Punto lontano verso nord-ovest (circa 150 km, mar Tirreno/Toscana)
quote = [100 300 500 1000 2000 3000 5000];
Prx_q = zeros(size(quote));
for k = 1:numel(quote)
    rxA = rxsite("Name","Aereo","Latitude",42.80,"Longitude",11.40, ...
                 "AntennaHeight", quote(k));
    Prx_q(k) = sigstrength(rxA, tx, pmLR);
end
figure;
plot(quote, Prx_q, '-o', 'LineWidth', 1.5); hold on;
yline(Srx_dBm, 'r--', 'Sensibilita'' ricevitore');
grid on; xlabel('Quota dell''aeromobile sul terreno [m]');
ylabel('Potenza ricevuta [dBm]');
title(sprintf('Monte Cavo -> punto a %.0f km: segnale in funzione della quota', ...
      distance(tx, rxA)/1e3));

%% 10) CONCLUSIONI (da scrivere nella relazione tecnica)
% - Quali siti a terra sono coperti e con quale margine?
% - Dove il terreno blocca il segnale (colonna LOS = false)?
% - Quanto differiscono spazio libero e Longley-Rice? Perche'?
% - Da quale quota un aeromobile a ~150 km riceve il segnale?
% - Cosa cambieresti nel progetto (altezza antenna, potenza, secondo sito)?
