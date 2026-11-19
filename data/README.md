# Terrain data

`dem_roma.tif` is the digital elevation model used by `matlab/studio_copertura_mapping.m` and `python/studio_copertura_terreno_dem.py`.

| Property | Value |
| --- | --- |
| Dataset | Copernicus GLO-90 Digital Surface Model (DGED 2023_1) |
| Source | OpenTopography, job of 19 November 2026 |
| Area | 41.4–42.6 N, 11.9–13.5 E (Monte Cavo and all six air bases) |
| Grid | 3 arc-seconds (about 90 m), 1 440 × 1 920 samples, float32 |
| Coordinates | WGS 84 (EPSG:4326), heights in metres above the EGM2008 geoid |
| Format | GeoTIFF, LZW compression, about 10 MB |

## How I obtained it

1. Signed in to OpenTopography (https://portal.opentopography.org) with a free account.
2. Opened the dataset **Copernicus GLO-90 Digital Elevation Model**.
3. Entered the selection coordinates manually: Xmin 11.9, Ymin 41.4, Xmax 13.5, Ymax 42.6.
4. Chose **GeoTiff** as output format and submitted the job (it completed in about 10 seconds).
5. Downloaded `rasters_COP90.tar.gz`, extracted `output_hh.tif` and renamed it `dem_roma.tif`.

The same area can be downloaded again through the OpenTopography Global DEM API (`demtype=COP90`) with a personal API key.

Copernicus is a surface model: it includes buildings and vegetation, so heights at the airports are slightly above bare ground.

## Licence

Copernicus DEM © DLR e.V. 2010-2014 and © Airbus Defence and Space GmbH 2014-2018, provided under COPERNICUS by the European Union and ESA; all rights reserved. GLO-90 is distributed free of charge under the Copernicus licence.

Citation: European Space Agency (2024). Copernicus Global Digital Elevation Model. Distributed by OpenTopography. https://doi.org/10.5069/G9028PQB
