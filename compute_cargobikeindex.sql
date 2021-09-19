-------------------------------------------------------------------------------
-- compute index --
-------------------------------------------------------------------------------
select * from ways limit 10;

-- create boolean column "both_directions"

ALTER TABLE ways
ADD both_directions boolean; 

UPDATE ways
SET both_directions = true 
WHERE (ways.tags -> 'oneway' <> 'yes' OR NOT exist(ways.tags, 'oneway')
			and ways.tags -> 'oneway:bicycle' <> 'no' OR NOT exist(ways.tags, 'oneway:bicycle') )
		and (ways.tags -> 'cycleway:right' in ('track', 'lane', 'opposite_lane', 'share_busway') or
			 ways.tags -> 'cycleway:left' in ('track', 'lane', 'opposite_lane', 'share_busway') or
			 ways.tags -> 'cycleway' in ('track', 'lane', 'opposite_lane', 'share_busway') or
			 ways.tags -> 'cycleway:both' in ('track', 'lane', 'opposite_lane', 'share_busway') or 
			exist (ways.tags, 'bicycle:lanes:forward') or 
			exist (ways.tags, 'bicycle:lanes:backward'));
		
-- select * from ways where both_directions isnull;

update ways
set both_directions = false 
where both_directions isnull;


-----------
-- create column bicycle lane id (forward, backward, both) from column bicycle_lanes

alter table ways 
add bicycle_lane_id int
add bicycle_lane_forward int,
add bicycle_lane_backward int;

update ways
set bicycle_lane_id = array_position(regexp_split_to_array(ways.tags -> 'bicycle:lanes', '\|'), 'designated'),
	bicycle_lane_forward = array_position(regexp_split_to_array(ways.tags -> 'bicycle:lanes:forward', '\|'), 'designated'),
	bicycle_lane_backward = array_position(regexp_split_to_array(ways.tags -> 'bicycle:lanes:backward', '\|'), 'designated');


-- create column bicycle lane width (forward, backward both) from width lanes

alter table ways 
add cycleway_width_forward_extracted varchar, 
add cycleway_width_backward_extracted varchar, 
add cycleway_width_extracted varchar;

update ways
set cycleway_width_extracted = (regexp_split_to_array(ways.tags -> 'width:lanes', '\|'))[bicycle_lane_id],
cycleway_width_forward_extracted = (regexp_split_to_array(ways.tags -> 'width:lanes:forward', '\|'))[bicycle_lane_forward],
cycleway_width_backward_extracted = (regexp_split_to_array(ways.tags -> 'width:lanes:backward', '\|'))[bicycle_lane_backward];


-- check if width extraction worked 
--select ways.tags -> 'bicycle:lanes:forward', 
--ways.tags -> 'width:lanes:forward',
--bicycle_lane_forward,
--cycleway_width_forward_extracted
--from ways
--where exist(ways.tags, 'bicycle:lanes:forward');

--------
-- combine cycleway and width tagging to one
alter table ways 
add cycleway_combined varchar, 
add cycleway_right varchar, 
add cycleway_left varchar,
add cycleway_width_combined varchar,
add cycleway_right_width varchar,
add cycleway_left_width varchar,
add cycleway_oneway_combined varchar;

UPDATE ways
set cycleway_combined = COALESCE(ways.tags -> 'cycleway:right', ways.tags -> 'cycleway:left', ways.tags -> 'cycleway', ways.tags -> 'cycleway:both'),
    cycleway_right = COALESCE(ways.tags -> 'cycleway:right', ways.tags -> 'cycleway', ways.tags -> 'cycleway:both'),
    cycleway_left = COALESCE(ways.tags -> 'cycleway:left', ways.tags -> 'cycleway', ways.tags -> 'cycleway:both'),
    cycleway_width_combined = COALESCE(ways.tags -> 'cycleway:right:width', ways.tags -> 'cycleway:left:width', ways.tags -> 'cycleway:width', ways.tags -> 'cycleway:both:width'),
    cycleway_right_width = COALESCE(ways.tags -> 'cycleway:right:width', cycleway_width_forward_extracted),
    cycleway_left_width = COALESCE(ways.tags -> 'cycleway:left:width', cycleway_width_backward_extracted),
    cycleway_oneway_combined = COALESCE(ways.tags -> 'cycleway:right:oneway', ways.tags -> 'cycleway:left:oneway', ways.tags -> 'cycleway:oneway', ways.tags -> 'cycleway:both:oneway');

-- also include streets, that are highway=cycleway instead of using the tag "cycleway"
update ways
set cycleway_combined = 'track',
    cycleway_width_combined = ways.tags -> 'width',
    cycleway_oneway_combined = ways.tags -> 'oneway'
where ways.tags -> 'highway' = 'cycleway';


ALTER TABLE ways
ALTER COLUMN cycleway_width_combined TYPE numeric 
USING regexp_replace(cycleway_width_combined, '[[:alpha:]]','','g')::numeric;

ALTER TABLE ways
ALTER COLUMN cycleway_right_width TYPE numeric 
USING regexp_replace(cycleway_right_width, '[[:alpha:]]','','g')::numeric;

ALTER TABLE ways
ALTER COLUMN cycleway_left_width TYPE numeric 
USING regexp_replace(cycleway_left_width, '[[:alpha:]]','','g')::numeric;
  

-- combine surface tagging schemes ------------------
-- combine all cycleways surface to single variable


alter table ways
add cycleway_surface_right varchar,
add cycleway_surface_left varchar,
add cycleway_surface_combined varchar,
add cycleway_smoothness_right varchar,
add cycleway_smoothness_left varchar,
add cycleway_smoothness_combined varchar,
add surface_right varchar,
add surface_left varchar,
add surface_combined varchar,
add smoothness_right varchar,
add smoothness_left varchar,
add smoothness_combined varchar;

UPDATE ways
set cycleway_surface_right = COALESCE(ways.tags -> 'cycleway:right:surface', ways.tags -> 'cycleway:surface', ways.tags -> 'cycleway:surface:both'),
    cycleway_surface_left = COALESCE(ways.tags -> 'cycleway:left:surface', ways.tags -> 'cycleway:surface', ways.tags -> 'cycleway:surface:both'),
    cycleway_surface_combined = COALESCE(ways.tags -> 'cycleway:right:surface', ways.tags -> 'cycleway:left:surface', ways.tags -> 'cycleway:surface', ways.tags -> 'cycleway:surface:both'),
    cycleway_smoothness_right = COALESCE(ways.tags -> 'cycleway:right:smoothness', ways.tags -> 'cycleway:smoothness', ways.tags -> 'cycleway:smoothness:both'),
    cycleway_smoothness_left = COALESCE(ways.tags -> 'cycleway:left:smoothness', ways.tags -> 'cycleway:smoothness', ways.tags -> 'cycleway:smoothness:both'),
    cycleway_smoothness_combined = COALESCE(ways.tags -> 'cycleway:right:smoothness', ways.tags -> 'cycleway:left:smoothness', ways.tags -> 'cycleway:smoothness', ways.tags -> 'cycleway:smoothness:both');
  

update ways 
set surface_right = 
   (CASE   
      WHEN ways.tags -> 'highway' = 'cycleway' then ways.tags -> 'surface'
      WHEN cycleway_surface_right notnull THEN cycleway_surface_right
      when cycleway_right <> ('track') or cycleway_right ISNULL then ways.tags -> 'surface' --if cycleway is not a separate track assume same surface as road surface
   end);
  
  update ways 
   set surface_left = 
   (CASE   
      WHEN ways.tags -> 'highway' = 'cycleway' then ways.tags -> 'surface'
      WHEN cycleway_surface_left notnull THEN cycleway_surface_left
      when cycleway_left <> ('track') or cycleway_left ISNULL then ways.tags -> 'surface' --if cycleway is not a separate track assume same surface as road surface
   end);
  
  update ways
  set surface_combined = 
   (CASE   
      WHEN ways.tags -> 'highway' = 'cycleway' then ways.tags -> 'surface'
      WHEN cycleway_surface_combined notnull THEN cycleway_surface_combined
      when cycleway_combined <> ('track') or cycleway_combined isnull then ways.tags -> 'surface' --if cycleway is not a separate track assume same surface as road surface
   end);
  
update ways 
set smoothness_right = 
   (CASE   
      WHEN ways.tags -> 'highway' = 'cycleway' then ways.tags -> 'smoothness'
      WHEN cycleway_smoothness_right notnull THEN cycleway_smoothness_right
      when cycleway_right <> ('track') or cycleway_right ISNULL then ways.tags -> 'smoothness' --if cycleway is not a separate track assume same smoothness as road smoothness
   end);
  
update ways 
set smoothness_left = 
   (CASE   
      WHEN ways.tags -> 'highway' = 'cycleway' then ways.tags -> 'smoothness'
      WHEN cycleway_smoothness_left notnull THEN cycleway_smoothness_left
      when cycleway_left <> ('track') or cycleway_left ISNULL then ways.tags -> 'smoothness' --if cycleway is not a separate track assume same smoothness as road smoothness
   end);
  
  update ways 
set smoothness_combined = 
   (CASE   
      WHEN ways.tags -> 'highway' = 'cycleway' then ways.tags -> 'smoothness'
      WHEN cycleway_smoothness_combined notnull THEN cycleway_smoothness_combined
      when cycleway_combined <> ('track') or cycleway_combined isnull then ways.tags -> 'smoothness' --if cycleway is not a separate track assume same smoothness as road smoothness
   end);



 -- seperate or use_sidepath indicates own line for cycleway - therefore remove those and only keep the actual cycleway
 -- streets <- streets %>%
 --   filter(!cycleway_combined %in% c("separate", "use_sidepath") | is.na(cycleway_combined))

  
--- dismount necessary
alter table ways
add dismount_necessary boolean;

update ways
set dismount_necessary = 
(CASE 
   WHEN (ways.tags -> 'highway' in ('footway', 'pedestrian') and  
         ways.tags -> 'bicycle' not in ('yes', 'permissive', 'designated') and 
         (ways.tags -> 'segregated' <> 'yes' or NOT exist(ways.tags,'segregated'))) then true
   WHEN (ways.tags -> 'highway' = ('path') and ways.tags -> 'bicycle' in ('no', 'dismount')) then true
   ELSE false
  end);
  
 
-- set cargo bikability values ---------------------------------------------
alter table ways 
ADD COLUMN IF NOT EXISTS  cbi_cycleways numeric,
ADD COLUMN IF NOT EXISTS  cbi_cycleways_forward numeric,
ADD COLUMN IF NOT EXISTS  cbi_cycleways_backward numeric,
ADD COLUMN IF NOT EXISTS  cbi_surface numeric,
ADD COLUMN IF NOT EXISTS  cbi_surface_forward numeric,
ADD COLUMN IF NOT EXISTS  cbi_surface_backward numeric;

update ways 
set cbi_cycleways = 
(case 
	when ways.tags -> 'bicycle_road' = 'yes' then 5
	when cycleway_width_combined >= 4 and cycleway_oneway_combined = 'no' then 5
	when (cycleway_width_combined >= 3.2 and cycleway_width_combined <= 4.0) and cycleway_oneway_combined = 'no' then 4
    when (cycleway_width_combined >= 2.4 and cycleway_width_combined <= 3.2) and cycleway_oneway_combined = 'no' then 3
    when cycleway_width_combined < 2.4 and cycleway_oneway_combined = 'no' then 1
    when cycleway_width_combined >= 2 and cycleway_combined in ('track', 'lane') then 5
    when cycleway_width_combined >= 1.6 and cycleway_width_combined <= 2 and cycleway_combined in ('track', 'lane') then 4
    when cycleway_width_combined >= 1.2 and cycleway_width_combined <= 1.6 and cycleway_combined = 'lane' then 4
    when cycleway_width_combined >= 1.2 and cycleway_width_combined <= 1.6 and cycleway_combined = 'track' then 3 -- schmalerer track schlechter als schmale lane
    when cycleway_width_combined < 1.2 and cycleway_combined = 'lane' then 2
    when cycleway_width_combined < 1.2 and cycleway_combined = 'track' then 1
    when cycleway_combined = 'lane' then 4
    when cycleway_combined = 'track' then 3
    when cycleway_combined = 'opposite_lane' then 5 -- eigene Spur für Gegenrichtung in Einbahnstraße
    when cycleway_combined = 'opposite' then 3 -- keine Spur für Gegenrichtung in der Einbahnstraße
    when cycleway_combined = 'share_busway' then 3
    when ways.tags -> 'highway' = 'steps' then 0 -- # stairs not passable
    when ways.tags -> 'highway' = 'track' and (ways.tags -> 'bicycle' in ('no', 'dismount')) then 1 -- # track where cyclists have to dismount
    when ways.tags -> 'highway' = 'track' and ways.tags ->'tracktype' = 'grade1' then 4
    when ways.tags -> 'highway' = 'track' and ways.tags ->'tracktype' = 'grade2' then 3
    when ways.tags -> 'highway' = 'track' and ways.tags ->'tracktype' = 'grade5' then 0 -- # not passable for regular cargobikes
    when ways.tags -> 'highway' = 'track' then 1 -- # track without tracktype or tracktype < grade 2
    when (ways.tags -> 'highway' in ('path', 'footway', 'pedestrian')) and (ways.tags ->'segregated' = 'yes') then 3 -- # is there a separate cycleway?
    when (ways.tags -> 'highway' in ('path', 'footway', 'pedestrian')) and (ways.tags ->'bicycle' in ('yes', 'permissive', 'designated')) or
          ways.tags -> 'highway' = 'path' and ((ways.tags ->'bicycle' not in ('no', 'dismount') or not exist(ways.tags, 'bicycle'))) then 2 -- # bicycle share street with pedestrians
    when (ways.tags -> 'highway' in ('path', 'footway', 'pedestrian')) then 1 -- # cyclists have to dismount
    when  ways.tags -> 'highway' = 'corridor' and (ways.tags ->'bicycle' in ('yes', 'permissive', 'designated')) then 2
    when ways.tags -> 'highway' = 'corridor' then 1
    when ways.tags -> 'highway' = 'bridleway' and (ways.tags ->'bicycle' in ('yes', 'permissive', 'designated')) then 2
    when ways.tags -> 'highway' = 'busway' and (ways.tags ->'bicycle' in ('yes', 'permissive', 'designated')) then 3
    when ways.tags ->'bicycle' = 'no' then 0 -- # motorways that do not allow bicycles - not even pushing the bike
    when ways.tags -> 'highway' = 'service' then 2
    when ways.tags -> 'highway' = 'residential' or ways.tags -> 'highway' = 'living_street' then 4 -- # residential streets
    when ways.tags -> 'highway' = 'unclassified' then 4
    when ways.tags -> 'highway' = 'trunk' and (ways.tags ->'bicycle' in ('yes', 'permissive', 'designated')) then 2
    when ways.tags -> 'highway' = 'trunk_link' and (ways.tags ->'bicycle' in ('yes', 'permissive', 'designated')) then 2
    when ways.tags -> 'highway' = 'primary' then 1 -- # Hauptstraße ohne Radwege
    when ways.tags -> 'highway' = 'primary_link' then 1
    when ways.tags -> 'highway' = 'secondary' then 2
    when ways.tags -> 'highway' = 'secondary_link' then 2
    when ways.tags -> 'highway' = 'tertiary' then 3
    when ways.tags -> 'highway' = 'tertiary_link' then 3
    when ways.tags -> 'highway' = 'road' then 2
    else 3
end);

update ways 
set cbi_cycleways_forward =
  (case
    when ways.tags -> 'bicycle_road' = 'yes' then 5
    when cycleway_right_width >= 4 and ways.tags -> 'cycleway:right:oneway' = 'no' then 5
    when (cycleway_right_width >= 3.2 and cycleway_right_width <= 4.0) and ways.tags -> 'cycleway:right:oneway' = 'no' then 4
    when (cycleway_right_width >= 2.4 and cycleway_right_width <= 3.2) and ways.tags -> 'cycleway:right:oneway' = 'no' then 3
    when cycleway_right_width < 2.4 and ways.tags -> 'cycleway:right:oneway' = 'no' then 1
    when cycleway_right_width >= 2 and cycleway_right in ('track', 'lane') then 5
    when cycleway_right_width >= 1.6 and cycleway_right_width <= 2 and cycleway_right in ('track', 'lane') then 4
    when cycleway_right_width >= 1.2 and cycleway_right_width <= 1.6 and cycleway_right = 'lane' then 4
    when cycleway_right_width >= 1.2 and cycleway_right_width <= 1.6 and cycleway_right = 'track' then 3 -- schmalerer track schlechter als schmale lane
    when cycleway_right_width < 1.2 and cycleway_right = 'lane' then 2
    when cycleway_right_width < 1.2 and cycleway_right = 'track' then 1
    when cycleway_right = 'lane' then 4
    when cycleway_right = 'track' then 3
    when cycleway_right = 'opposite_lane' then 5 -- eigene Spur für Gegenrichtung in Einbahnstraße
    when cycleway_right = 'opposite' then 3 -- keine Spur für Gegenrichtung in der Einbahnstraße
    when cycleway_right = 'share_busway' then 3
    when ways.tags -> 'highway' = 'steps' then 0 -- stairs not passable
    when ways.tags -> 'highway' = 'track' and (ways.tags -> 'bicycle' = 'no') then 1 -- track where cyclists have to dismount
    when ways.tags -> 'highway' = 'track' and ways.tags -> 'tracktype' = 'grade1' then 4
    when ways.tags -> 'highway' = 'track' and ways.tags -> 'tracktype' = 'grade2' then 3
    when ways.tags -> 'highway' = 'track' and ways.tags -> 'tracktype' = 'grade5' then 0 -- not passable for regular cargobikes
    when ways.tags -> 'highway' = 'track' then 1 -- track without ways.tags -> 'tracktype' or ways.tags -> 'tracktype' < grade 2
    when (ways.tags -> 'highway' in ('path', 'footway', 'pedestrian')) and (ways.tags -> 'segregated' = 'yes') then 3 -- is there a separate cycleway?
    when (ways.tags -> 'highway' in ('path', 'footway', 'pedestrian')) and (ways.tags -> 'bicycle' in ('yes', 'permissive', 'designated')) or
      ways.tags -> 'highway' = 'path' and ((ways.tags ->'bicycle' not in ('no', 'dismount') or not exist(ways.tags, 'bicycle'))) then 2 -- bicycle share street with pedestrians
    when (ways.tags -> 'highway' in ('path', 'footway', 'pedestrian')) then 1 -- cyclists have to dismount
    when ways.tags -> 'highway' = 'corridor' and (ways.tags -> 'bicycle' in ('yes', 'permissive', 'designated')) then 2
    when ways.tags -> 'highway' = 'corridor' then 1
    when ways.tags -> 'highway' = 'bridleway' and (ways.tags -> 'bicycle' in ('yes', 'permissive', 'designated')) then 2
    when ways.tags -> 'highway' = 'busway' and (ways.tags -> 'bicycle' in ('yes', 'permissive', 'designated')) then 3
    when ways.tags -> 'bicycle' = 'no' then 0 -- motorways that do not allow ways.tags -> 'bicycle' -- not even pushing the bike
    when ways.tags -> 'highway' = 'service' then 2
    when ways.tags -> 'highway' = 'residential' or ways.tags -> 'highway' = 'living_street' then 4 -- residential streets
    when ways.tags -> 'highway' = 'unclassified' then 4
    when ways.tags -> 'highway' = 'trunk' and (ways.tags -> 'bicycle' in ('yes', 'permissive', 'designated')) then 2
    when ways.tags -> 'highway' = 'trunk_link' and (ways.tags -> 'bicycle' in ('yes', 'permissive', 'designated')) then 2
    when ways.tags -> 'highway' = 'primary' then 1 -- Hauptstraße ohne Radwege
    when ways.tags -> 'highway' = 'primary_link' then 1
    when ways.tags -> 'highway' = 'secondary' then 2
    when ways.tags -> 'highway' = 'secondary_link' then 2
    when ways.tags -> 'highway' = 'tertiary' then 3
    when ways.tags -> 'highway' = 'tertiary_link' then 3
    when ways.tags -> 'highway' = 'road' then 2
    else 3
  end);

update ways 
set cbi_cycleways_backward =
(case
  when ways.tags -> 'bicycle_road' = 'yes' then 5
  when cycleway_left_width >= 4 and ways.tags -> 'cycleway:left:oneway' = 'no' then 5
  when (cycleway_left_width >= 3.2 and cycleway_left_width <= 4.0) and ways.tags -> 'cycleway:left:oneway' = 'no' then 4
  when (cycleway_left_width >= 2.4 and cycleway_left_width <= 3.2) and ways.tags -> 'cycleway:left:oneway' = 'no' then 3
  when cycleway_left_width < 2.4 and ways.tags -> 'cycleway:left:oneway' = 'no' then 1
  when cycleway_left_width >= 2 and cycleway_left in ('track', 'lane') then 5
  when cycleway_left_width >= 1.6 and cycleway_left_width <= 2 and cycleway_left in ('track', 'lane') then 4
  when cycleway_left_width >= 1.2 and cycleway_left_width <= 1.6 and cycleway_left = 'lane' then 4
  when cycleway_left_width >= 1.2 and cycleway_left_width <= 1.6 and cycleway_left = 'track' then 3 -- schmalerer track schlechter als schmale lane
  when cycleway_left_width < 1.2 and cycleway_left = 'lane' then 2
  when cycleway_left_width < 1.2 and cycleway_left = 'track' then 1
  when cycleway_left = 'lane' then 4
  when cycleway_left = 'track' then 3
  when cycleway_left = 'opposite_lane' then 5 -- eigene Spur für Gegenrichtung in Einbahnstraße
  when cycleway_left = 'opposite' then 3 -- keine Spur für Gegenrichtung in der Einbahnstraße
  when cycleway_left = 'share_busway' then 3
  when ways.tags -> 'highway' = 'steps' then 0 -- stairs not passable
  when ways.tags -> 'highway' = 'track' and (ways.tags -> 'bicycle'  = 'no') then 1 -- track where cyclists have to dismount
  when ways.tags -> 'highway' = 'track' and ways.tags -> 'tracktype' = 'grade1' then 4
  when ways.tags -> 'highway' = 'track' and ways.tags -> 'tracktype' = 'grade2' then 3
  when ways.tags -> 'highway' = 'track' and ways.tags -> 'tracktype' = 'grade5' then 0 -- not passable for regular cargobikes
  when ways.tags -> 'highway' = 'track' then 1 -- track without ways.tags -> 'tracktype' or ways.tags -> 'tracktype' < grade 2
  when (ways.tags -> 'highway' in ('path', 'footway', 'pedestrian')) and (ways.tags -> 'segregated' = 'yes') then 3 -- is there a separate cycleway?
  when (ways.tags -> 'highway' in ('path', 'footway', 'pedestrian')) and (ways.tags -> 'bicycle' in ('yes', 'permissive', 'designated')) or
     ways.tags -> 'highway' = 'path' and ((ways.tags ->'bicycle' not in ('no', 'dismount') or not exist(ways.tags, 'bicycle'))) then 2 -- ways.tags -> 'bicycle' share street with pedestrians
  when (ways.tags -> 'highway' in ('path', 'footway', 'pedestrian')) then 1 -- cyclists have to dismount
  when ways.tags -> 'highway' = 'corridor' and (ways.tags -> 'bicycle' in ('yes', 'permissive', 'designated')) then 2
  when ways.tags -> 'highway' = 'corridor' then 1
  when ways.tags -> 'highway' = 'bridleway' and (ways.tags -> 'bicycle' in ('yes', 'permissive', 'designated')) then 2
  when ways.tags -> 'highway' = 'busway' and (ways.tags -> 'bicycle' in ('yes', 'permissive', 'designated')) then 3
  when ways.tags -> 'bicycle' = 'no' then 0 -- motorways that do not allow ways.tags -> 'bicycle's - not even pushing the bike
  when ways.tags -> 'highway' = 'service' then 2
  when ways.tags -> 'highway' = 'residential' or ways.tags -> 'highway' = 'living_street' then 4 -- residential streets
  when ways.tags -> 'highway' = 'unclassified' then 4
  when ways.tags -> 'highway' = 'trunk' and (ways.tags -> 'bicycle' in ('yes', 'permissive', 'designated')) then 2
  when ways.tags -> 'highway' = 'trunk_link' and (ways.tags -> 'bicycle' in ('yes', 'permissive', 'designated')) then 2
  when ways.tags -> 'highway' = 'primary' then 1 -- Hauptstraße ohne Radwege
  when ways.tags -> 'highway' = 'primary_link' then 1
  when ways.tags -> 'highway' = 'secondary' then 2
  when ways.tags -> 'highway' = 'secondary_link' then 2
  when ways.tags -> 'highway' = 'tertiary' then 3
  when ways.tags -> 'highway' = 'tertiary_link' then 3
  when ways.tags -> 'highway' = 'road' then 2
  else 3
end);

update ways 
set cbi_surface = 
(case -- first: test if cycleway attributes are present. Then check general smoothness
  when smoothness_combined = 'excellent' then 5
  when smoothness_combined = 'good' then 4
  when smoothness_combined = 'intermediate' then 3
  when smoothness_combined = 'bad' then 2
  when smoothness_combined = 'very bad' then 1
  when smoothness_combined = 'horrible' then 0
  when smoothness_combined = 'very horrible' then 0
  when smoothness_combined = 'impassable' then 0
  when surface_combined = 'paved' then 4
  when surface_combined = 'asphalt' then 5
  when surface_combined = 'paving_stones' then 4
  when surface_combined = 'concrete' then 4
  when surface_combined = 'concrete:plates' then 4
  when surface_combined = 'concrete:lanes' then 2
  when surface_combined = 'sett' then 2
  when (surface_combined = 'cobblestone') or (surface_combined = 'cobblestone:flattened') then 2
  when surface_combined = 'unhewn_cobblestone' then 1
  when surface_combined = 'compacted' then 3
  when surface_combined = 'fine_gravel' then 2
  when surface_combined = 'metal' then 3
  when surface_combined = 'rock' then 0
  when surface_combined = 'sand' then 0
  when surface_combined = 'mud' then 0
  when surface_combined in (
    'unpaved', 'grass', 'ground', 'gravel', 'dirt',
    'pebblestone', 'earth', 'grass_paver', 'woodchips'
  ) then 1
end);

update ways 
set cbi_surface_forward = 
(case -- first: test if cycleway attributes are present. Then check general smoothness
  when smoothness_right = 'excellent' then 5
  when smoothness_right = 'good' then 4
  when smoothness_right = 'intermediate' then 3
  when smoothness_right = 'bad' then 2
  when smoothness_right = 'very bad' then 1
  when smoothness_right = 'horrible' then 0
  when smoothness_right = 'very horrible' then 0
  when smoothness_right = 'impassable' then 0
  when surface_right = 'paved' then 4
  when surface_right = 'asphalt' then 5
  when surface_right = 'paving_stones' then 4
  when surface_right = 'concrete' then 4
  when surface_right = 'concrete:plates' then 4
  when surface_right = 'concrete:lanes' then 2
  when surface_right = 'sett' then 2
  when surface_right = 'cobblestone' or surface_right = 'cobblestone:flattened' then 2
  when surface_right = 'unhewn_cobblestone' then 1
  when surface_right = 'compacted' then 3
  when surface_right = 'fine_gravel' then 2
  when surface_right = 'metal' then 3
  when surface_right = 'rock' then 0
  when surface_right = 'sand' then 0
  when surface_right = 'mud' then 0
  when surface_right in (
    'unpaved', 'grass', 'ground', 'gravel', 'dirt',
    'pebblestone', 'earth', 'grass_paver', 'woodchips'
  ) then 1
  end);
 
update ways 
set cbi_surface_backward = 
(case -- first: test if cycleway attributes are present. Then check general smoothness
  when smoothness_left = 'excellent' then 5
  when smoothness_left = 'good' then 4
  when smoothness_left = 'intermediate' then 3
  when smoothness_left = 'bad' then 2
  when smoothness_left = 'very bad' then 1
  when smoothness_left = 'horrible' then 0
  when smoothness_left = 'very horrible' then 0
  when smoothness_left = 'impassable' then 0
  when surface_left = 'paved' then 4
  when surface_left = 'asphalt' then 5
  when surface_left = 'paving_stones' then 4
  when surface_left = 'concrete' then 4
  when surface_left = 'concrete:plates' then 4
  when surface_left = 'concrete:lanes' then 2
  when surface_left = 'sett' then 2
  when surface_left = 'cobblestone' or surface_left = 'cobblestone:flattened' then 2
  when surface_left = 'unhewn_cobblestone' then 1
  when surface_left = 'compacted' then 3
  when surface_left = 'fine_gravel' then 2
  when surface_left = 'metal' then 3
  when surface_left = 'rock' then 0
  when surface_left = 'sand' then 0
  when surface_left = 'mud' then 0
  when surface_left in (
    'unpaved', 'grass', 'ground', 'gravel', 'dirt',
    'pebblestone', 'earth', 'grass_paver', 'woodchips'
  ) then 1
  end);

----- TODO: include barrier information ------
alter table ways 
add cbi_barrier numeric;

----- combine to one index --------
alter table ways 
ADD COLUMN IF NOT EXISTS cbi_street_quality numeric,
ADD COLUMN IF NOT EXISTS cbi_street_quality_forward numeric,
ADD COLUMN IF NOT EXISTS cbi_street_quality_backward numeric,
ADD COLUMN IF NOT EXISTS cbi numeric,
ADD COLUMN IF NOT EXISTS cbi_forward numeric,
ADD COLUMN IF NOT EXISTS cbi_backward numeric;

update ways 
set cbi_street_quality = 
(case 
	when cbi_surface notnull and cbi_cycleways notnull then round(cast(sqrt(cbi_surface*cbi_cycleways) as numeric), 1)
	when cbi_surface isnull then cbi_cycleways
	when cbi_cycleways isnull then cbi_surface 
	end);

update ways 
set cbi_street_quality_forward = 
(case 
	when cbi_surface_forward notnull and cbi_cycleways_forward notnull then round(cast(sqrt(cbi_surface_forward*cbi_cycleways_forward) as numeric), 1)
	when cbi_surface_forward isnull then cbi_cycleways_forward
	when cbi_cycleways_forward isnull then cbi_surface_forward 
	end);

update ways 
set cbi_street_quality_backward = 
(case 
	when cbi_surface_backward notnull and cbi_cycleways_backward notnull then round(cast(sqrt(cbi_surface_backward*cbi_cycleways_backward) as numeric), 1)
	when cbi_surface_backward isnull then cbi_cycleways_backward
	when cbi_cycleways_backward isnull then cbi_surface_backward 
	end);

-- TODO: add cbi with barrier combined

update ways 
set cbi = 
(case 
	when cbi_street_quality notnull and cbi_barrier notnull then round(cast(sqrt(cbi_street_quality*cbi_barrier) as numeric), 1)
	when cbi_street_quality isnull then cbi_barrier
	when cbi_barrier isnull then cbi_street_quality 
	end);

update ways 
set cbi_forward = 
(case 
	when cbi_street_quality_forward notnull and cbi_barrier notnull then round(cast(sqrt(cbi_street_quality_forward*cbi_barrier) as numeric), 1)
	when cbi_street_quality_forward isnull then cbi_barrier
	when cbi_barrier isnull then cbi_street_quality_forward 
	end);

update ways 
set cbi_backward = 
(case 
	when cbi_street_quality_backward notnull and cbi_barrier notnull then round(cast(sqrt(cbi_street_quality_backward*cbi_barrier) as numeric), 1)
	when cbi_street_quality_backward isnull then cbi_barrier
	when cbi_barrier isnull then cbi_street_quality_backward 
	end);

-- only keep respective indices: if cycleway is twoway, then keep different indices for foward and backward.
----- if only one street with identical index, then remove special indices for forward and backward

update ways
set cbi = (case when both_directions then null else cbi end),
cbi_forward = (case when both_directions then cbi_forward else null end),
cbi_backward = (case when both_directions then cbi_backward else null end);

-- remove index for road not allowed for bikes
update ways 
set cbi = null,
cbi_forward = null,
cbi_backward = null
where ways.tags -> 'highway' = 'proposed'
  or ((ways.tags -> 'motorroad' = 'yes'
    or ways.tags -> 'highway' in ('motorway', 'motorwar_link', 'trunk', 'trunk_link', 'bus_guideway','escape', 'bridleway', 'corridor', 'busway')
    or ways.tags -> 'access' in ('agricultural', 'customers', 'delivery', 'private', 'permit', 'bus', 'public_transport', 'emergency', 'forestry')) 
   and (not exist(ways.tags, 'bicycle') or ways.tags -> 'bicycle' not in ('yes', 'designated', 'permissive', 'dismount')));


--cbi_street_quality = (case when both_directions then null else cbi_street_quality end),
--cbi_street_quality_forward = (case when both_directions then cbi_street_quality_forward else null end),
--cbi_street_quality_backward = (case when both_directions then cbi_street_quality_backward else null end);

update ways
SET tags = tags || hstore('cbi', cbi::text)
where not both_directions;

update ways 
set tags = tags || hstore('cbi_forward', cbi_forward::text),
tags = tags || hstore('cbi_backward', cbi_backward::text)
where both_directions;

----- check results -----
-- select * from ways limit 10;

-- select cbi, 
-- cbi_forward,
-- cbi_backward,
-- cbi_street_quality_forward,
-- ways.tags -> 'cbi' as CBI,
-- ways.tags -> 'cbi_forward'as CBI_forward,
-- ways.tags -> 'cbi_backward'as CBI_backward
-- where exist(ways.tags, 'cbi');

-- from ways where ways.tags -> 'cycleway:right' = 'lane';

-- select(case 
--	when cbi_surface notnull and cbi_cycleways notnull then round(cast(sqrt(cbi_surface*cbi_cycleways) as numeric), 1)
--	when cbi_surface isnull then cbi_cycleways
--	end),cbi_street_quality, cbi_surface, cbi_cycleways from ways;

-- select count(ways.tags -> 'cbi') from ways where ways.tags -> 'cbi' notnull;
-- select count(cbi) from ways where cbi notnull;
  


------ at the end: drop all temp columns -------
    
alter table ways 
drop both_directions,
drop bicycle_lane_id,
drop bicycle_lane_forward,
drop bicycle_lane_backward,
drop cycleway_width_forward_extracted, 
drop cycleway_width_backward_extracted, 
drop cycleway_width_extracted,
drop cycleway_combined,
drop cycleway_right,
drop cycleway_left,
drop cycleway_width_combined,
drop cycleway_right_width,
drop cycleway_left_width, 
drop cycleway_oneway_combined,
drop cycleway_surface_right,
drop cycleway_surface_left,
drop cycleway_surface_combined,
drop cycleway_smoothness_right,
drop cycleway_smoothness_left,
drop cycleway_smoothness_combined,
drop surface_right,
drop surface_left,
drop surface_combined,
drop dismount_necessary,
drop smoothness_left,
drop smoothness_right,
drop smoothness_combined,
drop cbi_cycleways,
drop cbi_cycleways_forward,
drop cbi_cycleways_backward,
drop cbi_surface,
drop cbi_surface_forward,
drop cbi_surface_backward,
drop cbi,
drop cbi_forward,
drop cbi_backward,
drop cbi_street_quality,
drop cbi_street_quality_forward,
drop cbi_street_quality_backward,
drop cbi_barrier;


