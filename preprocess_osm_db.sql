-------------------------------------------------------------------------------
-- The following script creates a new table for the pgsql simple schema for
-- storing full way geometries.
-------------------------------------------------------------------------------

-- drop table if it exists
DROP TABLE IF EXISTS way_geometry;

-- create table
CREATE TABLE way_geometry(
  way_id bigint NOT NULL
);
-- add PostGIS geometry column
SELECT AddGeometryColumn('', 'way_geometry', 'geom', 4326, 'GEOMETRY', 2);

-- add a linestring for every way (create a polyline)
INSERT INTO way_geometry select id, ( select ST_LineFromMultiPoint( ST_Collect(nodes.geom) ) from nodes 
left join way_nodes on nodes.id=way_nodes.node_id where way_nodes.way_id=ways.id ) FROM ways 
where ways.tags -> 'highway' <> '';

-- create index on way_geometry
CREATE INDEX idx_way_geometry_way_id ON way_geometry USING btree (way_id);
CREATE INDEX idx_way_geometry_geom ON way_geometry USING gist (geom);

-- select count(*) from way_geometry;

-------------------------------------------------------------------------------
-- The following script creates a table for intersections of relevant barriers and highways --
-------------------------------------------------------------------------------

-- drop table if it exists
DROP TABLE IF EXISTS barrier_ways_intersection;

-- create table
CREATE TABLE barrier_ways_intersection(
    way_id bigint NOT null,
  	barrier_id bigint not null
);

INSERT INTO barrier_ways_intersection SELECT way_geometry.way_id as way_id, nodes.id as barrier_id
FROM way_geometry, nodes

WHERE ST_INTERSECTS(way_geometry.geom, nodes.geom)
and nodes.tags -> 'barrier' IN ('bollard', 'block', 'cycle_barrier', 'kerb', 'lift_gate');

-- select count(*) from barrier_ways_intersection;



