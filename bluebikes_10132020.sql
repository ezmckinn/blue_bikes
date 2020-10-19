-- run this file by copying this command into command line:
-- $ psql <name of database> <name of user> -f ./bluebikes_10132020.sql


-- drop existing tables 
DROP TABLE IF EXISTS trips;
DROP TABLE IF EXISTS start_st;
DROP TABLE IF EXISTS end_st;
DROP TABLE IF EXISTS trip_ct;
DROP TABLE IF EXISTS trip_ct_user;
DROP TABLE IF EXISTS trip_join;
DROP TABLE IF EXISTS segment;
DROP TABLE IF EXISTS results;
DROP TABLE IF EXISTS local_results;
DROP TABLE IF EXISTS local_rides;
DROP TABLE IF EXISTS hourly_trips;
DROP TABLE IF EXISTS start_loc_hour_count;
DROP TABLE IF EXISTS end_loc_hour_count;

-- enable postGIS
-- CREATE EXTENSION postgis;

-- create start stations table 

CREATE TABLE start_st (
	start_id VARCHAR, 
	loc VARCHAR,
	lat NUMERIC,
	lon NUMERIC,
	district VARCHAR,
	open VARCHAR,
	docks INTEGER,
    CONSTRAINT start_pkey PRIMARY KEY (start_id)
);

-- populate start_stations data
COPY start_st
FROM '/Volumes/Samsung_T5/BlueBikes_COVID_Project/raw_data/current_bluebikes_stations.csv'
DELIMITER ',' 
CSV HEADER;


ALTER TABLE start_st  -- add new column for geometry
    ADD COLUMN geom geometry (POINT, 4326);

UPDATE start_st SET geom = ST_SetSRID(ST_MakePoint(lon, lat), 4326);

-- create end stations table

CREATE TABLE end_st (
	end_id VARCHAR,
	loc VARCHAR,
	lat NUMERIC,
	lon NUMERIC,
	district VARCHAR,
	public_ VARCHAR,
	docks INTEGER,
    CONSTRAINT end_pkey PRIMARY KEY (end_id)
);

-- populate end_stations data
COPY end_st
FROM '/Volumes/Samsung_T5/BlueBikes_COVID_Project/raw_data/current_bluebikes_stations.csv'
DELIMITER ',' 
CSV HEADER;

-- add new column for geometry
ALTER TABLE end_st  
    ADD COLUMN geom geometry (POINT, 4326);
-- populate column
UPDATE end_st SET geom = ST_SetSRID(ST_MakePoint(lon, lat), 4326);

-- create segment table that draws a line between start and end geometries 
CREATE TABLE segment AS 
	SELECT e.loc AS end_loc,
		   e.geom AS end_geom,
		   e.district AS end_dist,
		   s.loc AS start_loc, 
		   s.geom AS start_geom,
		   s.district AS start_dist,
		   ST_MakeLine(s.geom, e.geom) AS segment_geom
	FROM end_st AS e
	CROSS JOIN start_st AS s;

-- Assing a unique ID to each O-D pair
ALTER TABLE segment 
ADD COLUMN segment_id SERIAL NOT NULL;

-- create table for trips
CREATE TABLE trips (
	duration INTEGER,
	start_time VARCHAR,
	stop_time VARCHAR,
	start_id INTEGER,
	start_loc VARCHAR,
	start_lat NUMERIC,
	start_lon NUMERIC,
	end_id INTEGER,
	end_loc VARCHAR,
	end_lat NUMERIC,
	end_lon NUMERIC,
	bikeid INTEGER,
	user_type VARCHAR,
	zip VARCHAR
    -- FOREIGN KEY (start_id) REFERENCES start_st(start_id),
    -- FOREIGN KEY (end_id) REFERENCES end_st(end_id);
);

-- populate trips data

COPY trips FROM '/Volumes/Samsung_T5/BlueBikes_COVID_Project/raw_data/202009-bluebikes-tripdata.csv' DELIMITER ',' CSV HEADER;
COPY trips FROM '/Volumes/Samsung_T5/BlueBikes_COVID_Project/raw_data/202008-bluebikes-tripdata.csv' DELIMITER ',' CSV HEADER;
COPY trips FROM '/Volumes/Samsung_T5/BlueBikes_COVID_Project/raw_data/202007-bluebikes-tripdata.csv' DELIMITER ',' CSV HEADER;
COPY trips FROM '/Volumes/Samsung_T5/BlueBikes_COVID_Project/raw_data/202006-bluebikes-tripdata.csv' DELIMITER ',' CSV HEADER;
COPY trips FROM '/Volumes/Samsung_T5/BlueBikes_COVID_Project/raw_data/202005-bluebikes-tripdata.csv' DELIMITER ',' CSV HEADER;
COPY trips FROM '/Volumes/Samsung_T5/BlueBikes_COVID_Project/raw_data/202004-bluebikes-tripdata.csv' DELIMITER ',' CSV HEADER;
COPY trips FROM '/Volumes/Samsung_T5/BlueBikes_COVID_Project/raw_data/202003-bluebikes-tripdata.csv' DELIMITER ',' CSV HEADER;

-- correct typo in Graham St station

UPDATE public.trips SET start_loc = 'Graham and Parks School' WHERE start_loc LIKE 'Graham%';
UPDATE public.trips SET end_loc = 'Graham and Parks School' WHERE end_loc LIKE 'Graham%';
UPDATE public.start_st SET loc = 'Graham and Parks School' WHERE loc LIKE 'Graham%';
UPDATE public.end_st SET loc = 'Graham and Parks School' WHERE loc LIKE 'Graham%';

-- correct namespace issue in Mt. Auburn station

UPDATE public.trips SET start_loc = '699 Mt. Auburn St' WHERE start_loc LIKE '699 Mt Auburn St';
UPDATE public.trips SET end_loc = '699 Mt. Auburn St' WHERE end_loc LIKE '699 Mt Auburn St';
UPDATE public.start_st SET loc = '699 Mt. Auburn St' WHERE loc LIKE '699 Mt Auburn St';
UPDATE public.end_st SET loc = '699 Mt. Auburn St' WHERE loc LIKE '699 Mt Auburn St';

-- split date columns on trips 

ALTER TABLE trips
        ADD COLUMN month VARCHAR,
        ADD COLUMN date VARCHAR,
        ADD COLUMN time VARCHAR,
        ADD COLUMN hour VARCHAR;

UPDATE trips SET month = split_part(trips.start_time::TEXT,'-', 2);
UPDATE trips SET date = split_part(trips.start_time::TEXT,' ', 1);
UPDATE trips SET time = split_part(trips.start_time::TEXT,' ', 2);
UPDATE trips SET hour = split_part(trips.time::TEXT,':', 1);

-- count arrivals and departures to each station by hour
CREATE TABLE start_loc_hour_count AS 
(SELECT start_loc, hour, COUNT(*) FROM trips GROUP BY start_loc, hour);

CREATE TABLE end_loc_hour_count AS 
(SELECT end_loc, hour, COUNT(*) FROM trips GROUP BY end_loc, hour);

CREATE TABLE hourly_trips AS 
(SELECT s.count as dep_ct, -- departure count
 		e.count as arr_ct, -- arrival count
 		s.start_loc as loc,
 		e.end_loc,
 		s.hour as hour,
 		e.hour as e_hr
	 FROM start_loc_hour_count as s
LEFT JOIN end_loc_hour_count as e
	   ON s.start_loc = e.end_loc AND s.hour = e.hour);

-- clean up 
ALTER TABLE hourly_trips
	DROP COLUMN end_loc,
	DROP COLUMN e_hr;


-- create TRIP COUNT table 

CREATE TABLE trip_ct AS 
(SELECT start_loc, end_loc, COUNT(*)
     FROM trips
     WHERE duration > 0
     GROUP BY start_loc, end_loc
);

ALTER TABLE trip_ct ADD COLUMN user_type VARCHAR;
UPDATE trip_ct SET user_type = 'All';

-- create TRIP COUNT by user type table

CREATE TABLE trip_ct_user AS 
(SELECT start_loc, end_loc, COUNT(*), user_type
     FROM trips
     WHERE duration > 0
     GROUP BY start_loc, end_loc, user_type
);

-- CREATE SUMMARY TABLE, which for each station includes both users and overall counts
CREATE TABLE trip_join AS 
SELECT * FROM trip_ct
UNION
SELECT * FROM trip_ct_user;

-- join trip count to segment geometries
CREATE TABLE results AS 
	SELECT t.*, s.segment_geom, s.start_dist, s.end_dist 
	FROM trip_join as t
	LEFT JOIN segment as s
		ON s.start_loc = t.start_loc AND s.end_loc = t.end_loc
	WHERE s.start_dist = 'Cambridge' OR s.end_dist = 'Cambridge';

-- Create Table for Local Rides; Join to station geometry for visualization
CREATE TABLE local_rides as 
(SELECT count, start_loc, user_type
FROM results
WHERE start_loc = end_loc);

CREATE TABLE local_results AS (
	SELECT * FROM start_st
	LEFT JOIN local_rides
		ON start_st.loc = local_rides.start_loc
);

/* ALTERNATE APPROACH FOR LONGER DISTANCES, TO SHOW CURVED ROUTE LINES 

DROP TABLE IF EXISTS experimental;

CREATE TABLE experimental AS 
	(SELECT e.loc AS end_loc,
		   e.geom AS end_geom,
		   e.district AS end_dist,
		   s.loc AS start_loc, 
		   s.geom AS start_geom,
		   s.district AS start_dist 
	FROM end_st AS e
	CROSS JOIN start_st AS s);

ALTER TABLE experimental
ADD COLUMN exp_geom geometry (LINESTRING, 4326);

UPDATE experimental
SET exp_geom = 
(SELECT ST_Transform(ST_Segmentize(ST_MakeLine(
       ST_Transform(s.geom, 953027),
       ST_Transform(e.geom, 953027)
     ), 50), 4326 ) as geom
  FROM start_st as s, end_st as e
  WHERE e.loc = experimental.end_loc  
   AND s.loc = experimental.start_loc);  
 
 SELECT * FROM experimental LIMIT 20;

*/