"""
Studio di copertura UHF su terreno reale (DEM Copernicus GLO-90) - verifica in Python
Progetto personale - Luca Buccilli

Riproduce in Python la logica di matlab/studio_copertura_mapping.m (Mapping Toolbox):
  1) lettura del DEM GeoTIFF (data/dem_roma.tif)
  2) quote dei siti dal DEM
  3) profili del terreno, sgombero della 1a zona di Fresnel, diffrazione knife-edge (ITU-R P.526)
  4) zone in vista da Monte Cavo (viewshed a raggi radiali, k = 4/3)

Uso:  python studio_copertura_terreno_dem.py      (figure nella cartella ./figures)
Dipendenze: numpy, scipy, pandas, matplotlib, pillow
"""
import os
import numpy as np
import pandas as pd
from PIL import Image
from scipy.ndimage import map_coordinates
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

QUI = os.path.dirname(os.path.abspath(__file__))
FILE_DEM = os.path.join(QUI, "..", "data", "dem_roma.tif")
OUT = os.path.join(QUI, "figures")
os.makedirs(OUT, exist_ok=True)

# ---------------- parametri (identici allo studio MATLAB) ----------------
f_Hz = 300e6; f_MHz = f_Hz / 1e6; lam = 3e8 / f_Hz
Ptx_dBm = 10 * np.log10(50e3); L_cavi = 2; S_rx = -100; G_rx = 0
h_mast = 20; h_rx_ground = 2
Re_km = 4 / 3 * 6371

tx = dict(nome="Monte Cavo", lat=41.7508, lon=12.7083)
siti = pd.DataFrame({
    "Sito": ["Pratica di Mare (AB)", "Ciampino (AB)", "Latina (AB)",
             "Guidonia (AB)", "Viterbo (AB)", "Frosinone (AB)"],
    "lat": [41.6548, 41.7994, 41.5424, 41.9903, 42.4303, 41.6464],
    "lon": [12.4452, 12.5949, 12.9090, 12.7270, 12.0640, 13.2994],
    "quota_ipotesi": [13, 129, 29, 88, 305, 181],
})


# ---------------- funzioni (stesse formule di matlab/utils) ----------------
def distanza_km(lat1, lon1, lat2, lon2):
    p1, p2 = np.radians(lat1), np.radians(lat2)
    a = np.sin((p2 - p1) / 2) ** 2 + np.cos(p1) * np.cos(p2) * np.sin(np.radians(lon2 - lon1) / 2) ** 2
    return 2 * 6371 * np.arcsin(np.sqrt(a))


def fspl_db(d_km):
    return 32.45 + 20 * np.log10(d_km) + 20 * np.log10(f_MHz)


def angolo_elevazione_deg(h1, h2, d_km):
    return np.degrees(np.arctan((h2 - h1) / (d_km * 1e3) - d_km / (2 * Re_km)))


def guadagno_dipolo_dbi(el):
    th = np.clip(np.radians(90 - el), 1e-6, np.pi - 1e-6)
    F = np.cos(np.pi / 2 * np.cos(th)) / np.sin(th)
    return 10 * np.log10(1.64 * F ** 2 + 1e-12)


def perdita_knife_edge(nu):
    nu = np.asarray(nu, float)
    J = 6.9 + 20 * np.log10(np.sqrt((nu - 0.1) ** 2 + 1) + nu - 0.1)
    return np.where(nu > -0.78, J, 0.0)


# ---------------- 1) lettura del DEM ----------------
img = Image.open(FILE_DEM)
Z = np.array(img, dtype=np.float64)
scala = img.tag_v2[33550]            # ModelPixelScaleTag
tie = img.tag_v2[33922]              # ModelTiepointTag
dlon, dlat = scala[0], scala[1]
lon0, lat0 = tie[3], tie[4]          # primo campione (angolo nord-ovest)
Z[(Z < -500) | np.isnan(Z)] = 0
nr, nc = Z.shape
lat_lim = (lat0 - (nr - 1) * dlat, lat0)
lon_lim = (lon0, lon0 + (nc - 1) * dlon)
print(f"DEM: {nr} x {nc} celle, lat {lat_lim[0]:.2f}-{lat_lim[1]:.2f}, lon {lon_lim[0]:.2f}-{lon_lim[1]:.2f}, "
      f"quote {Z.min():.0f} - {Z.max():.0f} m")


def geointerp(lat, lon):
    """Interpolazione bilineare del DEM (equivalente di geointerp(Z, R, lat, lon, 'linear'))."""
    r = (lat0 - np.asarray(lat)) / dlat
    c = (np.asarray(lon) - lon0) / dlon
    return map_coordinates(Z, [np.ravel(r), np.ravel(c)], order=1, mode="nearest").reshape(np.shape(r))


# ---------------- 2) quote dei siti ----------------
tx["quota"] = float(geointerp(tx["lat"], tx["lon"]))
siti["quota_DEM"] = geointerp(siti["lat"].values, siti["lon"].values).round(0)
print(f"\nQuota di Monte Cavo dal DEM: {tx['quota']:.0f} m (ipotesi 949 m)")
print(siti[["Sito", "quota_ipotesi", "quota_DEM"]].to_string(index=False))

# ---------------- 3) profili, Fresnel e diffrazione ----------------
righe = []
fig, axs = plt.subplots(3, 2, figsize=(13, 10))
for k, s in siti.iterrows():
    lat = np.linspace(tx["lat"], s.lat, 1500); lon = np.linspace(tx["lon"], s.lon, 1500)
    z = geointerp(lat, lon)
    d_km = distanza_km(tx["lat"], tx["lon"], lat, lon); D = d_km[-1]
    d1 = d_km * 1e3; d2 = (D - d_km) * 1e3
    h1 = z[0] + h_mast; h2 = z[-1] + h_rx_ground
    raggio = h1 + (h2 - h1) * d1 / (D * 1e3)
    ostacolo = z + d1 * d2 / (2 * Re_km * 1e3)
    sgombero = raggio - ostacolo
    r1 = np.sqrt(lam * d1 * d2 / (D * 1e3))
    nu = -np.sqrt(2) * sgombero / np.maximum(r1, 1e-9)
    i = 1 + np.argmax(nu[1:-1])
    J = float(perdita_knife_edge(nu[i]))
    los = bool(np.all(sgombero[1:-1] > 0))
    el = angolo_elevazione_deg(h1, h2, D)
    P_fs = Ptx_dBm + guadagno_dipolo_dbi(el) - L_cavi - fspl_db(D) + G_rx
    P_t = P_fs - J
    righe.append([s.Sito, D, los, np.min(sgombero[1:-1] / r1[1:-1]), nu[i], J, d_km[i], P_fs, P_t, P_t - S_rx])

    ax = axs.flat[k]
    ax.fill_between(d_km, ostacolo, ostacolo.min() - 50, color=(0.80, 0.72, 0.60), lw=0,
                    label="terreno + curvatura (k = 4/3)")
    ax.plot(d_km, raggio, "b", lw=1.2, label="raggio diretto")
    ax.plot(d_km, raggio - r1, "b--", label="1a zona di Fresnel")
    ax.plot(d_km, raggio - 0.6 * r1, "b:", label="0,6 r$_1$")
    ax.plot(d_km[i], ostacolo[i], "rv", ms=8, label="ostacolo dominante")
    ax.set_xlim(0, D); ax.grid(alpha=0.4)
    ax.set_xlabel("distanza da Monte Cavo [km]"); ax.set_ylabel("quota [m]")
    ax.set_title(f"{s.Sito}: {'in vista' if los else 'OSTRUITO'}, "
                 f"$\\nu_{{max}}$ = {nu[i]:.2f}, diffrazione {J:.1f} dB", fontsize=10)
h, l = axs.flat[0].get_legend_handles_labels()
fig.legend(h, l, loc="lower center", ncol=5)
fig.suptitle("Profili del terreno da Monte Cavo alle basi aeree (DEM Copernicus GLO-90)")
fig.tight_layout(rect=(0, 0.04, 1, 0.97))
fig.savefig(os.path.join(OUT, "6_profili_terreno.png"), dpi=130); plt.close(fig)

res = pd.DataFrame(righe, columns=["Sito", "Distanza_km", "LOS_terreno", "Sgombero_min_r1", "nu_max",
                                   "Diffrazione_dB", "Ostacolo_km", "Prx_liscia_dBm", "Prx_terreno_dBm",
                                   "Margine_dB"])
pd.set_option("display.width", 200)
print("\n--- COLLEGAMENTI SU TERRENO REALE ---")
print(res.round(2).to_string(index=False))

# ---------------- 4) viewshed a raggi radiali ----------------
# Per ogni azimut si campiona il terreno lungo il raggio e si tiene il massimo progressivo della
# pendenza apparente dell'orizzonte (curvatura con raggio effettivo). Un bersaglio e' in vista se la
# sua pendenza e' maggiore di quella di tutto il terreno che lo precede (stesso criterio di viewshed).
fatt = 2                                         # DEM sottocampionato 1:2 come georesize(Z, R, 0.5)
Zv = Z[::fatt, ::fatt]
LATv = lat0 - np.arange(Zv.shape[0]) * dlat * fatt
LONv = lon0 + np.arange(Zv.shape[1]) * dlon * fatt
LON, LAT = np.meshgrid(LONv, LATv)
Dg = np.maximum(distanza_km(tx["lat"], tx["lon"], LAT, LON), 0.05)
kx = 111.32 * np.cos(np.radians(tx["lat"])); ky = 110.57
AZg = np.arctan2((LON - tx["lon"]) * kx, (LAT - tx["lat"]) * ky)

n_az, passo = 7200, 0.045                         # 0,05 deg di azimut, 45 m lungo il raggio
r = np.arange(1, int(Dg.max() / passo) + 2) * passo
az = np.linspace(-np.pi, np.pi, n_az, endpoint=False)
Rr, AZr = np.meshgrid(r, az)
zr = geointerp(tx["lat"] + Rr * np.cos(AZr) / ky, tx["lon"] + Rr * np.sin(AZr) / kx)
h_oss = tx["quota"] + h_mast
caduta = (Rr * 1e3) ** 2 / (2 * Re_km * 1e3)     # abbassamento apparente per la curvatura
pend_terreno = (zr - caduta - h_oss) / (Rr * 1e3)
orizzonte = np.maximum.accumulate(pend_terreno, axis=1)
orizzonte_prec = np.concatenate([np.full((n_az, 1), -np.inf), orizzonte[:, :-1]], axis=1)

ia = np.round((AZg + np.pi) / (2 * np.pi) * n_az).astype(int) % n_az
ir = np.clip(np.round(Dg / passo).astype(int) - 1, 0, len(r) - 1)

casi = [(2, "AGL", "ricevitore a terra (2 m)"),
        (1000, "MSL", "aeromobile a 1000 m s.l.m."),
        (3000, "MSL", "aeromobile a 3000 m s.l.m.")]
fig, axs = plt.subplots(1, 3, figsize=(17, 5.6))
coperture = []
for ax, (h_t, rif, nome) in zip(axs, casi):
    h_bers = (Zv + h_t) if rif == "AGL" else np.full_like(Zv, h_t)
    pend_bers = (h_bers - (Dg * 1e3) ** 2 / (2 * Re_km * 1e3) - h_oss) / (Dg * 1e3)
    vis = pend_bers >= orizzonte_prec[ia, ir]
    E = angolo_elevazione_deg(h_oss, h_bers, Dg)
    P = Ptx_dBm + guadagno_dipolo_dbi(E) - L_cavi - fspl_db(Dg) + G_rx
    P = np.where(vis, P, np.nan)
    cop = np.mean(vis & (np.nan_to_num(P, nan=-999) > S_rx)) * 100
    coperture.append((nome, cop))
    print(f"{nome:30s} area del DEM in vista e sopra soglia: {cop:.1f} %")

    im = ax.imshow(P, extent=(LONv[0], LONv[-1], LATv[-1], LATv[0]), origin="upper",
                   cmap="viridis", vmin=-100, vmax=-40, aspect=1 / np.cos(np.radians(42)))
    ax.contour(LON, LAT, Zv, levels=np.arange(200, 2600, 200), colors="0.55", linewidths=0.3)
    ax.plot(tx["lon"], tx["lat"], "r*", ms=15, mec="k")
    ax.plot(siti.lon, siti.lat, "k^", mfc="w")
    ax.set_xlabel("longitudine [°]"); ax.set_ylabel("latitudine [°]")
    ax.set_title(f"{nome}: {cop:.0f}% coperto", fontsize=10)
    fig.colorbar(im, ax=ax, shrink=0.8, label="P$_{rx}$ [dBm]")
fig.suptitle("Copertura UHF da Monte Cavo su terreno reale (viewshed, k = 4/3) - in bianco le zone in ombra")
fig.tight_layout()
fig.savefig(os.path.join(OUT, "7_viewshed_copertura.png"), dpi=130); plt.close(fig)

with open(os.path.join(QUI, "..", "risultati_terreno_python.txt"), "w", encoding="utf-8") as f:
    f.write(f"Quota Monte Cavo dal DEM: {tx['quota']:.0f} m\n\n")
    f.write(siti[["Sito", "quota_ipotesi", "quota_DEM"]].to_string(index=False) + "\n\n")
    f.write(res.round(2).to_string(index=False) + "\n\n")
    for nome, cop in coperture:
        f.write(f"{nome:30s} {cop:.1f} %\n")
print("\nFigure salvate in python/figures")
