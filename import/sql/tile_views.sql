--- Shared ---

CREATE OR REPLACE FUNCTION railway_line_high(z integer, x integer, y integer)
  RETURNS bytea
  LANGUAGE SQL
  IMMUTABLE
  STRICT
  PARALLEL SAFE
RETURN (
  SELECT
    ST_AsMVT(tile, 'railway_line_high', 4096, 'way')
  FROM (
    -- TODO calculate labels in frontend
    SELECT
      id,
      osm_id,
      way,
      way_length,
      feature,
      state,
      usage,
      service,
      highspeed,
      tunnel,
      bridge,
      CASE
        WHEN ref IS NOT NULL AND name IS NOT NULL THEN ref || ' ' || name
        ELSE COALESCE(ref, name)
      END AS standard_label,
      ref,
      track_ref,
      track_class,
      array_to_string(reporting_marks, ', ') as reporting_marks,
      preferred_direction,
      rank,
      maxspeed,
      speed_label,
      train_protection_rank,
      train_protection,
      train_protection_construction_rank,
      train_protection_construction,
      electrification_state,
      voltage,
      frequency,
      electrification_label,
      future_voltage,
      future_frequency,
      railway_to_int(gauge0) AS gaugeint0,
      gauge0,
      railway_to_int(gauge1) AS gaugeint1,
      gauge1,
      railway_to_int(gauge2) AS gaugeint2,
      gauge2,
      gauge_label,
      loading_gauge,
      array_to_string(operator, ', ') as operator,
      traffic_mode,
      radio,
      wikidata,
      wikimedia_commons,
      image,
      mapillary,
      wikipedia,
      note,
      description
    FROM (
      SELECT
        id,
        osm_id,
        ST_AsMVTGeom(
          way,
          ST_TileEnvelope(z, x, y),
          4096, 64, true
        ) as way,
        way_length,
        feature,
        state,
        usage,
        service,
        rank,
        highspeed,
        reporting_marks,
        layer,
        bridge,
        tunnel,
        track_ref,
        track_class,
        ref,
        name,
        preferred_direction,
        maxspeed,
        speed_label,
        train_protection_rank,
        train_protection,
        train_protection_construction_rank,
        train_protection_construction,
        electrification_state,
        voltage,
        frequency,
        railway_electrification_label(COALESCE(voltage, future_voltage), COALESCE(frequency, future_frequency)) AS electrification_label,
        future_voltage,
        future_frequency,
        gauges[1] AS gauge0,
        gauges[2] AS gauge1,
        gauges[3] AS gauge2,
        (select string_agg(gauge, ' | ') from unnest(gauges) as gauge where gauge ~ '^[0-9]+$') as gauge_label,
        loading_gauge,
        operator,
        traffic_mode,
        radio,
        wikidata,
        wikimedia_commons,
        image,
        mapillary,
        wikipedia,
        note,
        description
      FROM railway_line
      WHERE
        way && ST_TileEnvelope(z, x, y)
        -- conditionally include features based on zoom level
        AND CASE
          WHEN z < 7 THEN
            state = 'present'
              AND service IS NULL
              AND (
                feature = 'rail' AND usage = 'main'
              )
          WHEN z < 8 THEN
            state = 'present'
              AND service IS NULL
              AND (
                feature = 'rail' AND usage IN ('main', 'branch')
              )
          WHEN z < 9 THEN
            state IN ('present', 'construction', 'proposed')
              AND service IS NULL
              AND (
                feature = 'rail' AND usage IN ('main', 'branch')
              )
          WHEN z < 10 THEN
            state IN ('present', 'construction', 'proposed')
              AND service IS NULL
              AND (
                feature = 'rail' AND usage IN ('main', 'branch', 'industrial')
                  OR (feature = 'light_rail' AND usage IN ('main', 'branch'))
              )
          WHEN z < 11 THEN
            state IN ('present', 'construction', 'proposed')
              AND service IS NULL
              AND (
                feature IN ('rail', 'narrow_gauge', 'light_rail', 'monorail', 'subway', 'tram')
              )
          WHEN z < 12 THEN
            (service IS NULL OR service IN ('spur', 'yard'))
              AND (
                feature IN ('rail', 'narrow_gauge', 'light_rail')
                  OR (feature IN ('monorail', 'subway', 'tram') AND service IS NULL)
              )
          ELSE
            true
        END
    ) AS r
    ORDER by
      layer,
      rank NULLS LAST,
      maxspeed NULLS FIRST
  ) as tile
  WHERE way IS NOT NULL
);

-- Function metadata
DO $do$ BEGIN
  EXECUTE 'COMMENT ON FUNCTION railway_line_high IS $tj$' || $$
  {
    "vector_layers": [
      {
        "id": "railway_line_high",
        "fields": {
          "id": "integer",
          "osm_id": "integer",
          "way_length": "number",
          "feature": "string",
          "state": "string",
          "usage": "string",
          "service": "string",
          "highspeed": "boolean",
          "preferred_direction": "string",
          "tunnel": "boolean",
          "bridge": "boolean",
          "ref": "string",
          "standard_label": "string",
          "track_ref": "string",
          "maxspeed": "number",
          "speed_label": "string",
          "train_protection": "string",
          "train_protection_rank": "integer",
          "train_protection_construction": "string",
          "train_protection_construction_rank": "integer",
          "electrification_state": "string",
          "frequency": "number",
          "voltage": "integer",
          "future_frequency": "number",
          "future_voltage": "integer",
          "electrification_label": "string",
          "gauge0": "string",
          "gaugeint0": "number",
          "gauge1": "string",
          "gaugeint1": "number",
          "gauge2": "string",
          "gaugeint2": "number",
          "gauge_label": "string",
          "loading_gauge": "string",
          "track_class": "string",
          "reporting_marks": "string",
          "operator": "string",
          "traffic_mode": "string",
          "radio": "string",
          "wikidata": "string",
          "wikimedia_commons": "string",
          "image": "string",
          "mapillary": "string",
          "wikipedia": "string",
          "note": "string",
          "description": "string"
        }
      }
    ]
  }
  $$::json || '$tj$';
END $do$;

--- Standard ---

CREATE OR REPLACE VIEW railway_text_stations AS
  SELECT
    id,
    nullif(array_to_string(osm_ids, U&'\001E'), '') as osm_id,
    center as way,
    railway_ref,
    railway,
    station,
    CASE
      WHEN route_count >= 20 AND railway_ref IS NOT NULL THEN 'large'
      WHEN route_count >= 8 THEN 'normal'
      ELSE 'small'
    END AS station_size,
    name,
    CASE
      WHEN railway = 'station' AND station = 'light_rail' THEN 450
      WHEN railway = 'station' AND station = 'subway' THEN 400
      WHEN railway = 'station' THEN 800
      WHEN railway = 'halt' AND station = 'light_rail' THEN 500
      WHEN railway = 'halt' THEN 550
      WHEN railway = 'tram_stop' THEN 300
      WHEN railway = 'service_station' THEN 600
      WHEN railway = 'yard' THEN 700
      WHEN railway = 'junction' THEN 650
      WHEN railway = 'spur_junction' THEN 420
      WHEN railway = 'site' THEN 600
      WHEN railway = 'crossover' THEN 700
      ELSE 50
    END AS rank,
    uic_ref,
    route_count,
    count,
    nullif(array_to_string(wikidata, U&'\001E'), '') as wikidata,
    nullif(array_to_string(wikimedia_commons, U&'\001E'), '') as wikimedia_commons,
    nullif(array_to_string(image, U&'\001E'), '') as image,
    nullif(array_to_string(mapillary, U&'\001E'), '') as mapillary,
    nullif(array_to_string(wikipedia, U&'\001E'), '') as wikipedia,
    nullif(array_to_string(note, U&'\001E'), '') as note,
    nullif(array_to_string(description, U&'\001E'), '') as description
  FROM
    grouped_stations_with_route_count
  ORDER BY
    rank DESC NULLS LAST,
    route_count DESC NULLS LAST;

CREATE OR REPLACE VIEW standard_railway_text_stations_low AS
  SELECT
    way,
    id,
    osm_id,
    railway,
    station,
    station_size,
    railway_ref as label,
    name,
    uic_ref,
    wikidata,
    wikimedia_commons,
    image,
    mapillary,
    wikipedia,
    note,
    description
  FROM
    railway_text_stations
  WHERE
    railway = 'station'
    AND (station IS NULL OR station NOT IN ('light_rail', 'monorail', 'subway'))
    AND railway_ref IS NOT NULL
    AND route_count >= 20;

CREATE OR REPLACE VIEW standard_railway_text_stations_med AS
  SELECT
    way,
    id,
    osm_id,
    railway,
    station,
    station_size,
    railway_ref as label,
    name,
    uic_ref,
    wikidata,
    wikimedia_commons,
    image,
    mapillary,
    wikipedia,
    note,
    description
  FROM
    railway_text_stations
  WHERE
    railway = 'station'
    AND (station IS NULL OR station NOT IN ('light_rail', 'monorail', 'subway'))
    AND railway_ref IS NOT NULL
    AND route_count >= 8
  ORDER BY
    route_count DESC NULLS LAST;

CREATE OR REPLACE VIEW standard_railway_text_stations AS
  SELECT
    way,
    id,
    osm_id,
    railway,
    station,
    station_size,
    railway_ref as label,
    name,
    count,
    uic_ref,
    wikidata,
    wikimedia_commons,
    image,
    mapillary,
    wikipedia,
    note,
    description
  FROM
    railway_text_stations
  WHERE
    name IS NOT NULL;

CREATE OR REPLACE VIEW standard_railway_grouped_stations AS
  SELECT
    id,
    nullif(array_to_string(osm_ids, U&'\001E'), '') as osm_id,
    buffered as way,
    railway,
    station,
    railway_ref as label,
    name,
    uic_ref,
    nullif(array_to_string(wikidata, U&'\001E'), '') as wikidata,
    nullif(array_to_string(wikimedia_commons, U&'\001E'), '') as wikimedia_commons,
    nullif(array_to_string(image, U&'\001E'), '') as image,
    nullif(array_to_string(mapillary, U&'\001E'), '') as mapillary,
    nullif(array_to_string(wikipedia, U&'\001E'), '') as wikipedia,
    nullif(array_to_string(note, U&'\001E'), '') as note,
    nullif(array_to_string(description, U&'\001E'), '') as description
  FROM
    grouped_stations_with_route_count;

CREATE OR REPLACE VIEW standard_railway_symbols AS
  SELECT
    id,
    osm_id,
    osm_type,
    way,
    CASE
      WHEN railway = 'crossing' THEN 'general/crossing'
      WHEN railway = 'level_crossing' THEN
        CASE
          WHEN crossing_barrier AND crossing_light THEN 'general/level-crossing-light-barrier'
          WHEN crossing_barrier THEN 'general/level-crossing-barrier'
          WHEN crossing_light THEN 'general/level-crossing-light'
          ELSE 'general/level-crossing'
        END
      WHEN railway = 'phone' THEN 'general/phone'
      WHEN railway = 'border' THEN 'general/border'
      WHEN railway = 'owner_change' THEN 'general/owner-change'
      WHEN railway = 'lubricator' THEN 'general/lubricator'
      WHEN railway = 'fuel' THEN 'general/fuel'
      WHEN railway = 'sand_store' THEN 'general/sand_store'
      WHEN railway = 'aei' THEN 'general/aei'
      WHEN railway = 'buffer_stop' THEN 'general/buffer_stop'
      WHEN railway = 'derail' THEN 'general/derail'
      WHEN railway = 'defect_detector' THEN 'general/defect_detector'
      WHEN railway = 'hump_yard' THEN 'general/hump_yard'
      WHEN railway = 'loading_gauge' THEN 'general/loading_gauge'
      WHEN railway = 'preheating' THEN 'general/preheating'
      WHEN railway = 'compressed_air_supply' THEN 'general/compressed_air_supply'
      WHEN railway = 'waste_disposal' THEN 'general/waste_disposal'
      WHEN railway = 'coaling_facility' THEN 'general/coaling_facility'
      WHEN railway = 'wash' THEN 'general/wash'
      WHEN railway = 'water_tower' THEN 'general/water_tower'
      WHEN railway = 'water_crane' THEN 'general/water_crane'
      WHEN railway = 'workshop' THEN 'general/workshop'
      WHEN railway = 'engine_shed' THEN 'general/engine_shed'
      WHEN railway = 'museum' THEN 'general/museum'
      WHEN railway = 'power_supply' THEN 'general/power_supply'
      WHEN railway = 'rolling_highway' THEN 'general/rolling_highway'
      WHEN railway = 'radio' THEN
        CASE
          WHEN man_made IN ('mast', 'tower') THEN 'general/radio-mast'
          WHEN man_made = 'antenna' THEN 'general/radio-antenna'
        END
    END AS feature,
    CASE
      WHEN railway = 'crossing' THEN -1::int
      WHEN railway = 'tram_stop' THEN 1::int
      ELSE 0
    END AS priority,
    ref,
    wikidata,
    wikimedia_commons,
    image,
    mapillary,
    wikipedia,
    note,
    description
  FROM pois
  WHERE railway IN ('crossing', 'level_crossing', 'phone', 'border', 'owner_change', 'radio', 'lubricator', 'fuel', 'sand_store', 'coaling_facility', 'wash', 'water_tower', 'water_crane', 'waste_disposal', 'compressed_air_supply', 'preheating', 'loading_gauge', 'hump_yard', 'defect_detector', 'aei', 'buffer_stop', 'derail', 'workshop', 'engine_shed', 'museum', 'power_supply', 'rolling_highway')

  UNION ALL

  SELECT
    id,
    osm_id,
    osm_type,
    way,
    'general/subway-entrance' as feature,
    0 as priority,
    ref,
    wikidata,
    wikimedia_commons,
    image,
    mapillary,
    wikipedia,
    note,
    description
    FROM subway_entrances

  ORDER BY priority DESC;

CREATE OR REPLACE VIEW railway_text_km AS
  SELECT
    id,
    osm_id,
    way,
    railway,
    pos,
    (railway_pos_decimal(pos) = '0') as zero,
    railway_pos_round(pos, 0)::text as pos_int,
    wikidata,
    wikimedia_commons,
    image,
    mapillary,
    wikipedia,
    note,
    description
  FROM (
    SELECT
      id,
      osm_id,
      way,
      railway,
      COALESCE(railway_position, railway_pos_round(railway_position_exact, 1)::text) AS pos,
      wikidata,
      wikimedia_commons,
      image,
      mapillary,
      wikipedia,
      note,
      description
    FROM railway_positions
  ) AS r
  WHERE pos IS NOT NULL
  ORDER by zero;

CREATE OR REPLACE VIEW standard_railway_switch_ref AS
  SELECT
    id,
    osm_id,
    way,
    railway,
    ref,
    type,
    turnout_side,
    local_operated,
    resetting,
    wikidata,
    wikimedia_commons,
    image,
    mapillary,
    wikipedia,
    note,
    description
  FROM railway_switches
  ORDER by char_length(ref);


--- Speed ---

CREATE OR REPLACE VIEW speed_railway_signals AS
  SELECT
    id,
    osm_id,
    way,
    features[1] as feature0,
    features[2] as feature1,
    type,
    azimuth,
    (signal_direction = 'both') as direction_both,
    ref,
    caption,
    deactivated,
    replace(speed_limit_speed, ';', U&'\001E') as speed_limit_speed,
    replace(speed_limit_distant_speed, ';', U&'\001E') as speed_limit_distant_speed,
    wikidata,
    wikimedia_commons,
    image,
    mapillary,
    wikipedia,
    note,
    description
  FROM speed_railway_signal_features
  ORDER BY
    rank NULLS FIRST,
    dominant_speed DESC NULLS FIRST;


--- Signals ---

CREATE OR REPLACE FUNCTION signals_signal_boxes(z integer, x integer, y integer)
  RETURNS bytea
  LANGUAGE SQL
  IMMUTABLE
  STRICT
  PARALLEL SAFE
  RETURN (
    SELECT
      ST_AsMVT(tile, 'signals_signal_boxes', 4096, 'way')
    FROM (
      SELECT
        ST_AsMVTGeom(
          CASE
            WHEN z >= 14 THEN way
            ELSE center
          END,
          ST_TileEnvelope(z, x, y),
          4096, 64, true
        ) AS way,
        id,
        osm_id,
        osm_type,
        feature,
        ref,
        name,
        wikimedia_commons,
        image,
        mapillary,
        wikipedia,
        note,
        description
      FROM boxes
      WHERE way && ST_TileEnvelope(z, x, y)
    ) as tile
    WHERE way IS NOT NULL
  );

-- Function metadata
DO $do$ BEGIN
  EXECUTE 'COMMENT ON FUNCTION signals_signal_boxes IS $tj$' || $$
  {
    "vector_layers": [
      {
        "id": "signals_signal_boxes",
        "fields": {
          "id": "integer",
          "osm_id": "integer",
          "osm_type": "string",
          "feature": "string",
          "ref": "string",
          "name": "string",
          "wikidata": "string",
          "wikimedia_commons": "string",
          "image": "string",
          "mapillary": "string",
          "wikipedia": "string",
          "note": "string",
          "description": "string"
        }
      }
    ]
  }
  $$::json || '$tj$';
END $do$;

CREATE OR REPLACE VIEW signals_railway_signals AS
  SELECT
    id,
    osm_id,
    way,
    features[1] as feature0,
    features[2] as feature1,
    features[3] as feature2,
    features[4] as feature3,
    features[5] as feature4,
    railway,
    ref,
    ref_multiline,
    caption,
    deactivated,
    azimuth,
    (signal_direction = 'both') as direction_both,
    wikidata,
    wikimedia_commons,
    image,
    mapillary,
    wikipedia,
    note,
    description
  FROM signals_railway_signal_features
  ORDER BY rank NULLS FIRST;

--- Electrification ---

CREATE OR REPLACE VIEW electrification_signals AS
  SELECT
    id,
    osm_id,
    way,
    feature_electricity as feature,
    azimuth,
    (signal_direction = 'both') as direction_both,
    ref,
    caption,
    deactivated,
    voltage,
    frequency,
    wikidata,
    wikimedia_commons,
    image,
    mapillary,
    wikipedia,
    note,
    description
  FROM electricity_railway_signal_features
  ORDER BY rank NULLS FIRST;
