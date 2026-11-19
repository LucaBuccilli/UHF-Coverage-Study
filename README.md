UHF Ground-to-Air Coverage Study – Monte Cavo (Rome)

In this project I studied the radio coverage of a UHF ground-to-air station in the military aeronautical band (225–400 MHz), placed on Monte Cavo (Colli Albani, about 949 m a.s.l.), south-east of Rome. My goal was to answer two questions a designer would ask before installing such a station:

Can the six air bases around Rome receive the station, and with what margin?
Up to what distance can an aircraft receive it, depending on its altitude?

I implemented the study twice, to compare a simple analytical model with a terrain-based tool:

File	Tool	Propagation model
studio_copertura_UHF.py	Python (NumPy, pandas, Matplotlib)	Free space on a smooth spherical earth (k = 4/3)
studio_copertura_UHF.m	MATLAB + Antenna Toolbox	Free space and Longley-Rice on real terrain

The results in this README come from the Python version. Code comments are in Italian.

1. Input data and where I took them
1.1 Sites
Site	Role	ICAO	Latitude	Longitude	Ground elevation [m a.s.l.]
Monte Cavo	Transmitter	–	41.7508 N	12.7083 E	949
Pratica di Mare	Air base (receiver)	LIRE	41.6548 N	12.4452 E	13
Ciampino	Air base (receiver)	LIRA	41.7994 N	12.5949 E	129
Latina	Air base (receiver)	LIRL	41.5424 N	12.9090 E	29
Guidonia	Air base (receiver)	LIRG	41.9903 N	12.7270 E	88
Viterbo	Air base (receiver)	LIRV	42.4303 N	12.0640 E	305
Frosinone	Air base (receiver)	LIRH	41.6464 N	13.2994 E	181
Coordinates: taken from public maps (OpenStreetMap / Google Maps), rounded to 4 decimal places (about 10 m), which is more than enough for links of tens of kilometres.
Air base elevations: the published aerodrome elevations (ENAV AIP Italia), converted from feet to metres and rounded.
Monte Cavo elevation: summit height from topographic maps (IGM / OpenStreetMap).

I chose these sites because they are real military and state airports around Rome, so the scenario looks like a real design case: one high site serving several bases.

1.2 System parameters (design assumptions)
Parameter	Value	Why I chose it
Frequency	300 MHz (λ = 1 m)	Centre of the NATO military UHF air band (225–400 MHz)
Transmit power	50 W (47 dBm)	Typical power class of ground-to-air UHF transmitters
Antenna	Vertical half-wave dipole, 2.15 dBi	Simplest omnidirectional reference antenna; vertical polarisation as used in air-ground radio
Mast height	20 m	Typical lattice tower on a hill-top site
Cable and connector losses	2 dB	Short coaxial run plus connectors at 300 MHz
Receiver sensitivity	−100 dBm	Conservative value: real UHF airband receivers are usually a few dB better
Receive antenna gain	0 dBi	Conservative assumption for aircraft and ground stations
Ground receiver height	2 m	Worst case: a portable or vehicle radio on the ground
Atmosphere	Standard, k = 4/3	Standard effective earth radius for propagation planning
1.3 Models and formulas
What	Model / reference
Free-space loss	Friis formula (ITU-R P.525)
Effective earth radius	Re = k · 6371 km with k = 4/3 (standard atmosphere, ITU-R P.453)
Dipole pattern	Half-wave dipole far field (antenna theory, e.g. Balanis)
Fresnel zone clearance	First Fresnel zone radius, as used in line-of-sight link planning (ITU-R P.530)
Terrain (MATLAB only)	Longley-Rice / Irregular Terrain Model (NTIA/ITS), GMTED2010 elevation data
2. How I did it, step by step
Step 1 – I defined the scenario and the questions

One transmitter on high ground, six fixed receivers and aircraft at different altitudes. I wanted the received power, the margin over the receiver sensitivity and whether each path is in line of sight.

Step 2 – I collected the site data

I wrote down coordinates and elevations of the seven sites (table 1.1) and fixed the system parameters (table 1.2) at the top of the script, so they are easy to change.

Step 3 – I modelled the antenna

I computed the elevation pattern of a vertical half-wave dipole:

G(θ) = 1.64 · [cos(π/2 · cos θ) / sin θ]² (θ measured from the dipole axis)

Maximum gain is 1.64 = 2.15 dBi on the horizon, with nulls straight up and straight down (figure 1). I used this pattern to take the real gain in the direction of each receiver, instead of always using the maximum.

Step 4 – I computed the distances

I used the haversine formula for the great-circle distance between transmitter and each receiver (10.8 km to Ciampino, up to 92.4 km to Viterbo).

Step 5 – I computed the elevation angle and the antenna gain toward each receiver

The angle of the ray leaving the antenna, including earth curvature:

elevation = arctan[(h₂ − h₁)/d − d/(2·Re)]

All ground receivers are seen between −0.7° and −4.5°, so the dipole gain stays between 2.11 and 2.15 dBi: for these links the pattern costs almost nothing.

Step 6 – I computed the link budget

Prx = Ptx + Gtx − Lcables − FSPL + Grx, with FSPL = 20 log₁₀(d_km) + 20 log₁₀(f_MHz) + 32.44

Margin = Prx − receiver sensitivity.

Step 7 – I checked the radio horizon

On a smooth earth with k = 4/3, a path is in line of sight if the distance is shorter than

d_horizon = √(2·Re·h₁) + √(2·Re·h₂) (heights above sea level)

With the antenna at 969 m a.s.l. the transmitter horizon alone is 128 km.

Step 8 – I checked the first Fresnel zone

At mid-path I compared the height of the direct ray, minus the earth bulge, with the radius of the first Fresnel zone:

r₁ = 17.32 · √(d₁·d₂ / (f_GHz · d)) [m, km] earth bulge = d₁·d₂ / (2·Re)

A clearance of at least 0.6 · r₁ is the usual criterion for a free-space-like path.

Step 9 – I computed the ground-to-air range

For aircraft between 100 m and 10,000 m I computed the radio horizon and the received power at that distance (figure 2).

Step 10 – I drew the coverage maps

For aircraft at 1,000 m and 3,000 m I computed the received power on a grid of 600 × 600 points around the site, masking everything beyond the radio horizon (figure 3).

Step 11 – I prepared the terrain-based check in MATLAB

The MATLAB script repeats the scenario with the Antenna Toolbox (txsite, rxsite, propagationModel("longley-rice"), coverage, link), which downloads real terrain data. This is the step that shows which paths are blocked by hills or mountains.

3. Worked example: Monte Cavo → Pratica di Mare (by hand)
Quantity	Calculation	Result
Distance	haversine	24.3 km
Free-space loss	20 log₁₀(24.3) + 20 log₁₀(300) + 32.44 = 27.71 + 49.54 + 32.44	109.7 dB
Received power	47.0 + 2.14 − 2 − 109.7	−62.6 dBm
Margin	−62.6 − (−100)	37.4 dB
Radio horizon	√(2 · 8495 · 0.969) + √(2 · 8495 · 0.015) = 128.3 + 16.0	144.3 km > 24.3 km → LOS
Fresnel radius at mid-path	17.32 · √(12.15 · 12.15 / (0.3 · 24.3))	78 m
Earth bulge at mid-path	12.15 · 12.15 / (2 · 8495) · 1000	8.7 m
Clearance	(969 + 15)/2 − 8.7 = 483 m → 483 / 78	6.2 · r₁
4. Results
4.1 Ground links (receiver at 2 m)
Site	Distance [km]	LOS (smooth earth)	Prx [dBm]	Margin [dB]	Fresnel r₁ [m]	Clearance / r₁
Pratica di Mare	24.3	yes	−62.6	37.4	78.0	6.2
Ciampino	10.8	yes	−55.6	44.4	52.1	10.5
Latina	28.5	yes	−64.0	36.0	84.5	5.8
Guidonia	26.7	yes	−63.4	36.6	81.7	6.4
Viterbo	92.4	yes	−74.2	25.8	152.0	3.4
Frosinone	50.4	yes	−68.9	31.1	112.3	4.8
4.2 Ground-to-air range versus aircraft altitude
Aircraft altitude [m a.s.l.]	Radio horizon [km]	Prx at horizon [dBm]	Margin [dB]
100	170	−79.4	20.6
300	200	−80.9	19.1
500	220	−81.7	18.3
1,000	259	−83.1	16.9
2,000	313	−84.7	15.3
3,000	354	−85.8	14.2
5,000	420	−87.3	12.7
8,000	497	−88.8	11.2
10,000	540	−89.5	10.5
4.3 Figures

Figure 1 – Elevation pattern of the half-wave dipole

Dipole elevation pattern

Figure 2 – Ground-to-air range versus aircraft altitude

Range versus aircraft altitude

Figure 3 – Ground-to-air coverage maps (aircraft at 1,000 m and 3,000 m)

Ground-to-air coverage maps

5. What I learned
Range is limited by the radio horizon, not by transmit power. With 50 W the link budget would reach about 1,800 km in free space, but the real range is 170–540 km depending on the aircraft altitude. At UHF, antenna height is worth more than power, which is why these stations sit on hills and mountains.
All six ground links close with a large margin on a smooth earth (26–44 dB), and the Fresnel clearance is well above the 0.6 · r₁ criterion. The real risk is terrain: a ridge between Monte Cavo and Viterbo or Frosinone could block the path, which the smooth-earth model cannot see. That is why I added the Longley-Rice version in MATLAB.
The antenna pattern matters little here because all rays are almost horizontal. It would matter for aircraft flying close to and above the site, where the dipole has a null.
6. Limitations and next steps
Add a digital terrain model (SRTM) to the Python version and draw the terrain profile of each link, to compare with the MATLAB Longley-Rice results.
Use a dedicated air-to-ground model (ITU-R P.528) for the aircraft coverage.
Add fade margins for multipath and the effect of different k values (sub-refraction).
Study interference and electromagnetic compatibility with other transmitters on the same site, which is a real issue on crowded hill-top sites like Monte Cavo.
How to run

Python

bash
pip install -r requirements.txt
python studio_copertura_UHF.py

Figures (PNG) and tables (CSV) are written to figures/.

MATLAB (R2020a or later, Antenna Toolbox or Communications Toolbox, internet connection for terrain data): open studio_copertura_UHF.m and run it one section at a time (Ctrl+Enter).

Author

Luca Buccilli – M.Sc. Telecommunications Engineering, Sapienza University of Rome
