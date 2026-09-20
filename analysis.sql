-- =============================================================================
-- NYC Hydrant Density Analysis. analysis.sql
-- Portfolio Project 2, Modern GIS Accelerator
--
-- Five progressive PostGIS queries that build up to a normalized density
-- analysis and a 100-meter coverage analysis.
--
-- Assumes:
--   - Database "nyc" with PostGIS extension enabled
--   - Tables loaded:
--       nyc_neighborhoods (polygon, EPSG:4326, geom column called "geom",
--                          attributes including "neighborhood" and "borough")
--       nyc_hydrants      (point,   EPSG:4326, geom column called "geom",
--                          attributes including "hydrant_id")
--   - Spatial indexes on both geom columns (CREATE INDEX ... USING GIST (geom))
--
-- Run all queries:
--   psql -h localhost -U gis -d nyc -f analysis.sql
-- =============================================================================


-- -----------------------------------------------------------------------------
-- Query 1: Filter

-- Goal: Sanity check that the data loaded. Pull all neighborhoods in Manhattan.
-- Expected output: ~37 rows (Manhattan neighborhoods).
-- -----------------------------------------------------------------------------

-- Select all neighborhoods in Manhattan borough from the nyc_neighborhoods table. Order by neighborhood name.

SELECT ntaname, boroname
FROM public.nyc_neighborhoods
WHERE boroname = 'Manhattan'
ORDER BY ntaname;

-- -----------------------------------------------------------------------------
-- Query 2: Spatial join

-- Goal: Match each hydrant to the neighborhood that contains it, using
-- ST_Contains.
-- Expected output: one row per hydrant (~109,725) with the neighborhood name.
-- -----------------------------------------------------------------------------

-- Joining nyc_neighborhoods and nyc_hydrants using ST_Contains (neighborhood polygons containing hydrant points). Show first 10 rows.

SELECT h.unitid, n.ntaname, n.boroname
FROM public.nyc_neighborhoods AS n
JOIN public.nyc_hydrants AS h ON ST_Contains(n.geom, h.geom)
LIMIT 10;

-- -----------------------------------------------------------------------------
-- Query 3: Aggregate
--
-- Goal: Count hydrants per neighborhood.
-- Expected output: 262 rows (one per neighborhood) with a hydrant_count.
-- -----------------------------------------------------------------------------

-- Count hydrants per neighborhood and return one row for each neighbourhood; Order by number of hydrants in descending order. 
-- Left Join includes neighborhoods with zero matched hydrants. nta2020 uniquely identifies each neighborhood, while ntaname and boroname remain as readable labels.

SELECT n.nta2020, n.ntaname, n.boroname, COUNT(h.unitid) AS hydrant_count
FROM public.nyc_neighborhoods AS n
LEFT JOIN public.nyc_hydrants AS h ON ST_Contains(n.geom, h.geom)
GROUP BY n.nta2020, n.ntaname, n.boroname
ORDER BY hydrant_count DESC;


-- -----------------------------------------------------------------------------
-- Query 4: Normalize (this is your headline result)
--
-- Goal: Compute density per square kilometer. Reproject to EPSG:2263
-- (NY State Plane Long Island, feet) before computing area, then convert
-- square feet to square kilometers.
-- Expected output: 262 rows with hydrant_count, area_km2, density_per_km2.
-- -----------------------------------------------------------------------------

-- Reproject each NTA to EPSG:2263 to calculate area for each NTA in square feet. Convert area to square kilometers (area_km2)
-- and divide each NTA´s hydrant count (hydrant_count) by the area. Sort the resulting hydrants-per-km2 values descending.

SELECT 
    n.ntaname, n.nta2020, n.boroname,
    ST_Area(ST_Transform(n.geom, 2263)) / 10763910.42  AS area_km2,
    COUNT(h.unitid) AS hydrant_count,
    COUNT(h.unitid) /  (ST_Area(ST_Transform(n.geom, 2263)) / 10763910.42) AS density_per_km2
FROM public.nyc_neighborhoods AS n
LEFT JOIN public.nyc_hydrants as h ON ST_Contains(n.geom, h.geom)
GROUP BY n.geom, n.nta2020, n.ntaname, n.boroname
ORDER BY density_per_km2 DESC;

-- -----------------------------------------------------------------------------
-- Query 5: Buffer + Union + Intersection (coverage analysis)
--
-- Goal: For each neighborhood, what percent of its area is within 100 meters
-- of a hydrant? This is the deeper finding.
-- Expected output: 262 rows with neighborhood, area_km2, covered_pct.
-- -----------------------------------------------------------------------------

-- Create a 100m buffer for each hydrant and merge all buffer polygons using ST_Union. Then query intersections with each neighborhood polygon.
-- Finally divide the intersected coverage area by that neighborhood´s total area and multiply by 100.

WITH hydrant_coverage AS (
    SELECT
        ST_Union(ST_Buffer(ST_Transform(h.geom, 2263), 328.0833)) AS coverage_geom
        FROM public.nyc_hydrants as h
    )
SELECT 
    n.ntaname, n.nta2020, n.boroname,
    ROUND(((ST_Area(ST_Intersection(ST_Transform(n.geom, 2263), hc.coverage_geom))
    / ST_Area(ST_Transform(n.geom,2263)))*100)::numeric, 2) AS coverage_pct
FROM 
    public.nyc_neighborhoods AS n
    CROSS JOIN hydrant_coverage as hc
ORDER BY coverage_pct DESC;