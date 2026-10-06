# NYC Fire Hydrant Density and Coverage Analysis

A spatial analysis of 109,725 fire hydrants across all 262 New York City Neighborhood Tabulation Areas (NTAs). The analysis was completed twice: first with PostgreSQL/PostGIS and then with Python and GeoPandas.

The project compares both workflows while investigating hydrant counts, density, and the percentage of each neighborhood located within 100 metres of a hydrant.

![NYC fire hydrant density by neighborhood](images/density_choropleth.png)

## Questions

- How many hydrants are located in each NTA?
- Which neighborhoods have the highest hydrant density per square kilometre?
- Which neighborhoods contain no hydrants?
- What percentage of each neighborhood lies within 100 metres of a hydrant?

## Data

The project uses two datasets from NYC Open Data:

- [NYCDEP Citywide Hydrants](https://data.cityofnewyork.us/Environment/NYCDEP-Citywide-Hydrants/6pui-xhxz) — 109,725 point features
- [2020 Neighborhood Tabulation Areas](https://data.cityofnewyork.us/City-Government/2020-Neighborhood-Tabulation-Areas-NTAs-/9nt8-h7nd) — 262 polygon features

Both source datasets use EPSG:4326. The geometries were reprojected to EPSG:2263 before calculating distances and areas.

The raw datasets are not tracked in Git. Downloaded files should be placed in `data/raw/`.

## Workflow

The analysis was first performed in PostGIS and then reproduced in GeoPandas.

| Task | PostGIS | GeoPandas |
|---|---|---|
| Filter records | `WHERE` | Boolean indexing |
| Match hydrants to NTAs | `ST_Contains` | `gpd.sjoin(..., predicate="within")` |
| Count hydrants | `GROUP BY` and `COUNT` | `.groupby().size()` |
| Preserve NTAs with zero hydrants | `LEFT JOIN` | `.merge(..., how="left")` |
| Calculate area | `ST_Transform` and `ST_Area` | `.to_crs().area` |
| Create 100 m coverage zones | `ST_Buffer` | `.buffer()` |
| Merge overlapping buffers | `ST_Union` | `.union_all()` |
| Calculate covered area | `ST_Intersection` | `.intersection()` |

A projected coordinate system was necessary because EPSG:4326 stores coordinates in degrees rather than measurement units. EPSG:2263 uses feet, so the 100-metre buffer distance was converted to approximately 328.0833 feet.

## Results

### Hydrant density

Dividing the hydrant count by NTA area gives a more useful comparison than total count alone.

| Rank | NTA | Borough | Hydrants per km² |
|---:|---|---|---:|
| 1 | Gramercy | Manhattan | 384.7 |
| 2 | SoHo–Little Italy–Hudson Square | Manhattan | 359.9 |
| 3 | Tribeca–Civic Center | Manhattan | 343.3 |

### Neighborhoods with no hydrants

Three NTAs contain no hydrants:

| NTA code | NTA | Borough |
|---|---|---|
| BK0471 | The Evergreens Cemetery | Brooklyn |
| BK5692 | Jamaica Bay (West) | Brooklyn |
| SI9591 | Hoffman & Swinburne Islands | Staten Island |

Using a left join was important here. An inner join would have removed these neighborhoods from the results.

### Coverage within 100 metres

Coverage was calculated by buffering every hydrant by 100 metres, merging the overlapping buffers, and intersecting the resulting coverage geometry with each NTA.

Two NTAs had zero coverage:

- Jamaica Bay (West)
- Hoffman & Swinburne Islands

The Evergreens Cemetery contained no hydrants but still had approximately 19.85% coverage because buffers from hydrants outside its boundary extended into the NTA. This demonstrates that hydrant count and spatial coverage measure different things.

## Visualizations

The GeoPandas workflow produces:

- A static density choropleth created with Matplotlib
- An interactive density map created with GeoPandas `.explore()`

The interactive map can be viewed by running [`analysis.ipynb`](analysis.ipynb).

## Project files

- [`analysis.sql`](analysis.sql) — PostGIS analysis
- [`analysis.ipynb`](analysis.ipynb) — GeoPandas analysis and visualizations
- [`images/density_choropleth.png`](images/density_choropleth.png) — static density map
- [`data/processed/hydrant_density.parquet`](data/processed/hydrant_density.parquet) — processed GeoParquet output for reuse

## Limitations

- A 100-metre Euclidean buffer does not account for street networks, buildings, barriers, or actual emergency access.
- The analysis represents hydrant locations in the source dataset and does not assess their condition or operational status.
- NTAs are statistical geographies. Some represent parks, airports, cemeteries, and other non-residential areas rather than conventional neighborhoods.
- Results depend on the versions of the datasets used when the analysis was performed.

## What I learned

While SQL was efficient for querying, spatial joins and aggregating data stored in a database, GeoPandas offered more flexibility for further analysis like visualizing the results and exporting reusable spatial data. With Python, I created a static choropleth (Matplotlib) and an interactive map using GeoPandas `.explore()`, without importing the results into QGIS or ArcGIS. Overall, SQL's syntax felt easier for database queries, while Python (GeoPandas) offered more options for presentation.
