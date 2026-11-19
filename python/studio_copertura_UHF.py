"""
STUDIO DI COPERTURA UHF TERRA-ARIA - Sito di Monte Cavo (RM)
Progetto personale - Luca Buccilli

Versione Python dello studio MATLAB (studio_copertura_UHF.m).

Modello usato: TERRA SFERICA LISCIA con raggio equivalente k = 4/3
(atmosfera standard). Il terreno reale (rilievi) NON e' modellato: per
quello serve un modello digitale del terreno (DEM, es. SRTM) e un modello
come Longley-Rice / ITU-R P.452. Lo script quindi stabilisce:
  - il link budget in spazio libero (con il guadagno reale del dipolo
    nella direzione del ricevitore),
  - l'orizzonte radio e la visibilita' sulla terra liscia,
  - lo sgombero della 1a zona di Fresnel rispetto al rigonfiamento terrestre,
  - la portata terra-aria in funzione della quota dell'aeromobile.

Requisiti: Python 3 + numpy, pandas, matplotlib.
Uso:  python studio_copertura_UHF.py      (risultati nella cartella ./figures)
"""

import os
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt


def salva(fig, nome, **kw):
    """Salva la figura in PNG."""
    fig.savefig(os.path.join(OUT, nome + ".png"), dpi=150, **kw)

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "figures")
os.makedirs(OUT, exist_ok=True)

# ---------------------------------------------------------------------------
# 1) PARAMETRI DEL SISTEMA (ipotesi di progetto)
# ---------------------------------------------------------------------------
f_Hz = 300e6           # frequenza [Hz] - centro banda UHF militare 225-400 MHz
Ptx_W = 50.0           # potenza del trasmettitore [W]
h_tx_mast = 20.0       # altezza antenna sul traliccio [m]
L_cavi_dB = 2.0        # perdite cavi e connettori [dB]
S_rx_dBm = -100.0      # sensibilita' ricevitore [dBm] (ipotesi conservativa)
G_rx_dBi = 0.0         # guadagno antenna ricevente [dBi] (ipotesi)
k_factor = 4.0 / 3.0   # fattore k atmosfera standard
R_earth_km = 6371.0
Re_km = k_factor * R_earth_km   # raggio terrestre equivalente

f_MHz = f_Hz / 1e6
lam_m = 3e8 / f_Hz
Ptx_dBm = 10 * np.log10(Ptx_W * 1e3)

# Sito trasmittente: Monte Cavo (Colli Albani)
TX = dict(nome="Monte Cavo", lat=41.7508, lon=12.7083, quota_terreno=949.0)
h_tx_amsl = TX["quota_terreno"] + h_tx_mast   # quota antenna s.l.m. [m]

# Siti riceventi a terra (quote s.l.m. approssimate) - antenna a 2 m
SITI = pd.DataFrame([
    ("Pratica di Mare (AB)", 41.6548, 12.4452, 13),
    ("Ciampino (AB)",        41.7994, 12.5949, 129),
    ("Latina (AB)",          41.5424, 12.9090, 29),
    ("Guidonia (AB)",        41.9903, 12.7270, 88),
    ("Viterbo (AB)",         42.4303, 12.0640, 305),
    ("Frosinone (AB)",       41.6464, 13.2994, 181),
], columns=["Sito", "lat", "lon", "quota_terreno"])
h_rx_ground = 2.0


# ---------------------------------------------------------------------------
# FUNZIONI
# ---------------------------------------------------------------------------
def distanza_km(lat1, lon1, lat2, lon2):
    """Distanza ortodromica (formula dell'haversine)."""
    p1, p2 = np.radians(lat1), np.radians(lat2)
    dp, dl = p2 - p1, np.radians(lon2 - lon1)
    a = np.sin(dp / 2) ** 2 + np.cos(p1) * np.cos(p2) * np.sin(dl / 2) ** 2
    return 2 * R_earth_km * np.arcsin(np.sqrt(a))


def fspl_dB(d_km):
    """Attenuazione di spazio libero: 20log10(d_km) + 20log10(f_MHz) + 32.44."""
    return 20 * np.log10(d_km) + 20 * np.log10(f_MHz) + 32.44


def orizzonte_km(h_m):
    """Distanza dell'orizzonte radio per un'antenna a quota h [m] s.l.m."""
    return np.sqrt(2 * Re_km * np.maximum(h_m, 0) / 1e3)


def angolo_elevazione_deg(h1_m, h2_m, d_km):
    """Elevazione del raggio visto dal sito 1 verso il sito 2 (terra k=4/3)."""
    return np.degrees(np.arctan((h2_m - h1_m) / (d_km * 1e3) - d_km / (2 * Re_km)))


def guadagno_dipolo_dBi(elev_deg):
    """Dipolo a mezz'onda verticale: G(theta) = 1.64 * [cos(pi/2 cos t)/sin t]^2,
    con theta = angolo dall'asse del dipolo (90 deg = orizzonte)."""
    th = np.radians(90.0 - np.asarray(elev_deg, dtype=float))
    th = np.clip(th, 1e-6, np.pi - 1e-6)
    F = np.cos(np.pi / 2 * np.cos(th)) / np.sin(th)
    return 10 * np.log10(1.64 * F ** 2 + 1e-12)


def fresnel_midpoint(h1_m, h2_m, d_km):
    """Raggio 1a zona di Fresnel, rigonfiamento terrestre e sgombero a meta' tratta."""
    d1 = d2 = d_km / 2
    r1_m = 17.32 * np.sqrt(d1 * d2 / ((f_Hz / 1e9) * d_km))
    bulge_m = d1 * d2 / (2 * Re_km) * 1e3
    linea_m = (h1_m + h2_m) / 2
    sgombero_m = linea_m - bulge_m
    return r1_m, bulge_m, sgombero_m


# ---------------------------------------------------------------------------
# 2) ANTENNA: diagramma del dipolo a mezz'onda
# ---------------------------------------------------------------------------
el = np.linspace(-90, 90, 721)
G_el = guadagno_dipolo_dBi(el)
fig = plt.figure(figsize=(6, 6))
ax = fig.add_subplot(projection="polar")
ax.plot(np.radians(el), np.maximum(G_el, -30), lw=2, color="#1f5a96")
ax.plot(np.radians(180 - el), np.maximum(G_el, -30), lw=2, color="#1f5a96")
ax.set_rlim(-30, 5)
ax.set_title(f"Dipolo λ/2 verticale a {f_MHz:.0f} MHz\nTaglio in elevazione [dBi]  (max {G_el.max():.2f} dBi)")
fig.tight_layout()
salva(fig, "1_diagramma_dipolo")
plt.close(fig)

G_tx_max = guadagno_dipolo_dBi(0.0)
EIRP_dBm = Ptx_dBm + G_tx_max - L_cavi_dB

# ---------------------------------------------------------------------------
# 3) LINK BUDGET VERSO I SITI A TERRA
# ---------------------------------------------------------------------------
righe = []
for _, s in SITI.iterrows():
    d = distanza_km(TX["lat"], TX["lon"], s.lat, s.lon)
    h_rx_amsl = s.quota_terreno + h_rx_ground
    oriz = orizzonte_km(h_tx_amsl) + orizzonte_km(h_rx_amsl)
    el_deg = angolo_elevazione_deg(h_tx_amsl, h_rx_amsl, d)
    G_tx = guadagno_dipolo_dBi(el_deg)
    Prx = Ptx_dBm + G_tx - L_cavi_dB - fspl_dB(d) + G_rx_dBi
    r1, bulge, sgombero = fresnel_midpoint(h_tx_amsl, h_rx_amsl, d)
    righe.append(dict(
        Sito=s.Sito,
        Distanza_km=round(d, 1),
        Orizzonte_km=round(oriz, 1),
        LOS_terra_liscia="SI" if d < oriz else "NO",
        Elevazione_deg=round(el_deg, 2),
        G_tx_dBi=round(float(G_tx), 2),
        FSPL_dB=round(fspl_dB(d), 1),
        Prx_dBm=round(float(Prx), 1),
        Margine_dB=round(float(Prx - S_rx_dBm), 1),
        Fresnel_r1_m=round(r1, 1),
        Sgombero_su_r1=round(sgombero / r1, 1),
    ))
tab = pd.DataFrame(righe)
tab.to_csv(os.path.join(OUT, "2_collegamenti_terra.csv"), index=False)

# ---------------------------------------------------------------------------
# 4) PORTATA TERRA-ARIA IN FUNZIONE DELLA QUOTA DELL'AEROMOBILE
# ---------------------------------------------------------------------------
quote = np.array([100, 300, 500, 1000, 2000, 3000, 5000, 8000, 10000])
oriz_air = orizzonte_km(h_tx_amsl) + orizzonte_km(quote)

# Portata limitata solo dalla potenza (spazio libero, al bordo dell'orizzonte
# il raggio e' quasi orizzontale -> guadagno dipolo ~ massimo)
FSPL_max = EIRP_dBm + G_rx_dBi - S_rx_dBm
d_potenza_km = 10 ** ((FSPL_max - 20 * np.log10(f_MHz) - 32.44) / 20)

Prx_bordo = []
for q, d in zip(quote, oriz_air):
    e = angolo_elevazione_deg(h_tx_amsl, q, d)
    Prx_bordo.append(Ptx_dBm + guadagno_dipolo_dBi(e) - L_cavi_dB - fspl_dB(d) + G_rx_dBi)
tab_air = pd.DataFrame(dict(
    Quota_aereo_m=quote,
    Orizzonte_radio_km=np.round(oriz_air, 0),
    Prx_al_bordo_dBm=np.round(Prx_bordo, 1),
    Margine_al_bordo_dB=np.round(np.array(Prx_bordo) - S_rx_dBm, 1),
))
tab_air.to_csv(os.path.join(OUT, "3_portata_terra_aria.csv"), index=False)

fig, ax = plt.subplots(figsize=(8, 5))
ax.plot(quote, oriz_air, "-o", lw=2, color="#1f5a96", label="Orizzonte radio (k = 4/3)")
ax.axhline(d_potenza_km, color="#c0392b", ls="--",
           label=f"Limite di potenza in spazio libero ({d_potenza_km:,.0f} km)")
ax.set_xlabel("Quota dell'aeromobile s.l.m. [m]")
ax.set_ylabel("Portata [km]")
ax.set_title("Monte Cavo - portata UHF terra-aria")
ax.set_ylim(0, max(oriz_air.max(), 100) * 1.15)
ax.text(quote[-1], d_potenza_km * 0.0 + ax.get_ylim()[1] * 0.93,
        f"limite di potenza ≈ {d_potenza_km:,.0f} km (fuori scala)",
        ha="right", va="top", color="#c0392b", fontsize=9)
ax.grid(alpha=0.3)
ax.legend(loc="lower right")
fig.tight_layout()
salva(fig, "4_portata_vs_quota")
plt.close(fig)

# ---------------------------------------------------------------------------
# 5) MAPPA DI COPERTURA TERRA-ARIA (aeromobile a 1000 m e 3000 m s.l.m.)
# ---------------------------------------------------------------------------
def to_xy_km(lat, lon):
    """Coordinate locali [km] centrate sul trasmettitore."""
    x = np.radians(lon - TX["lon"]) * R_earth_km * np.cos(np.radians(TX["lat"]))
    y = np.radians(lat - TX["lat"]) * R_earth_km
    return x, y

span = 380
xs = np.linspace(-span, span, 600)
X, Y = np.meshgrid(xs, xs)
D = np.maximum(np.hypot(X, Y), 0.05)

fig, axes = plt.subplots(1, 2, figsize=(13, 6.2))
livelli = [-100, -90, -80, -70, -60, -50]
for ax, q in zip(axes, [1000, 3000]):
    e = angolo_elevazione_deg(h_tx_amsl, q, D)
    P = Ptx_dBm + guadagno_dipolo_dBi(e) - L_cavi_dB - fspl_dB(D) + G_rx_dBi
    P = np.where(D <= orizzonte_km(h_tx_amsl) + orizzonte_km(q), P, np.nan)
    cf = ax.contourf(X, Y, np.clip(P, -100, -50), levels=livelli, cmap="viridis")
    ax.contour(X, Y, np.nan_to_num(P, nan=-200), levels=[S_rx_dBm], colors="red", linewidths=1.2)
    for _, s in SITI.iterrows():
        sx, sy = to_xy_km(s.lat, s.lon)
        ax.plot(sx, sy, "w^", ms=6, mec="k")
        ax.annotate(s.Sito.replace(" (AB)", ""), (sx, sy), xytext=(4, 4),
                    textcoords="offset points", fontsize=7, color="white")
    ax.plot(0, 0, "r*", ms=13, mec="k")
    ax.set_title(f"Aeromobile a {q} m s.l.m. - raggio coperto "
                 f"{orizzonte_km(h_tx_amsl) + orizzonte_km(q):.0f} km")
    ax.set_xlabel("Est [km]"); ax.set_ylabel("Nord [km]")
    ax.set_aspect("equal"); ax.grid(alpha=0.25)
fig.colorbar(cf, ax=axes, label="Potenza ricevuta [dBm]", shrink=0.85)
fig.suptitle("Copertura UHF terra-aria da Monte Cavo (terra liscia k = 4/3, spazio libero)", fontsize=12)
salva(fig, "5_mappa_copertura_aria", bbox_inches="tight")
plt.close(fig)

# ---------------------------------------------------------------------------
# 6) STAMPA RISULTATI
# ---------------------------------------------------------------------------
pd.set_option("display.width", 200)
pd.set_option("display.max_columns", 20)
print("=" * 78)
print("STUDIO DI COPERTURA UHF - MONTE CAVO")
print("=" * 78)
print(f"Frequenza {f_MHz:.0f} MHz (lambda = {lam_m:.2f} m) | Ptx {Ptx_W:.0f} W = {Ptx_dBm:.1f} dBm")
print(f"Guadagno dipolo max {G_tx_max:.2f} dBi | perdite {L_cavi_dB:.1f} dB | EIRP {EIRP_dBm:.1f} dBm")
print(f"Antenna TX a {h_tx_amsl:.0f} m s.l.m. -> orizzonte radio proprio {orizzonte_km(h_tx_amsl):.1f} km")
print(f"Sensibilita' RX {S_rx_dBm:.0f} dBm -> attenuazione max ammessa {FSPL_max:.1f} dB")
print(f"Portata limitata dalla sola potenza (spazio libero): {d_potenza_km:,.0f} km\n")
print("--- COLLEGAMENTI VERSO TERRA (rx a 2 m) ---")
print(tab.to_string(index=False))
print("\n--- PORTATA TERRA-ARIA ---")
print(tab_air.to_string(index=False))
print(f"\nFile salvati in: python/figures")
