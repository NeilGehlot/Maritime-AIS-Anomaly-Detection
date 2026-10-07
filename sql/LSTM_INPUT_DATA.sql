with datestamps as (
    select  id,
            mmsi,
            row_number() over(PARTITION BY mmsi order by base_datetime) as ping_sequence,
            base_datetime,
            LAG(base_datetime) over (partition by mmsi order by base_datetime) as previos_ping_time, lat,
            LAG(lat) over (PARTITION BY mmsi order by base_datetime) as prev_lat, lon,
            LAG(lon) over (PARTITION BY mmsi order by base_datetime) as prev_lon,
            sog
    from ais_data
),

time_diff as (
    select id, mmsi,
    (extract(epoch from (base_datetime - previos_ping_time))/60) as time_difference
    from datestamps
),

A_HD AS(
    select MMSI, ID, power(sin((radians(lat)-radians(prev_lat))/2),2) + cos(radians(lat)) * cos(radians(prev_lat)) * 
    power(SIN((RADIANS(LON)-RADIANS(PREV_LON))/2),2) AS a_value
    FROM DATESTAMPS
),

C_HD AS (
    SELECT ID, MMSI, 2*(ATAN2(SQRT(A_VALUE), SQRT(1-A_VALUE))) AS C_VALUE
    FROM A_HD
),

distances as (
    SELECT DT.ID, DT.MMSI, 6371*C_VALUE as dist
    FROM C_HD C JOIN DATESTAMPS DT ON C.ID = DT.ID
)

select 
    dt.mmsi,
    dt.base_datetime,
    dt.ping_sequence,
    dt.lat,
    dt.lon,
    a.cog,
    a.heading,
    dt.sog,
    td.time_difference as time_differ,
    d.dist
from datestamps dt
join time_diff td on dt.id = td.id
join distances d on dt.id = d.id
join ais_data a on dt.id = a.id

order by dt.mmsi, dt.base_datetime;