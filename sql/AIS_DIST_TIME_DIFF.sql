
with datestamps as (
    select  id,
            mmsi,
            row_number() over(PARTITION BY mmsi order by base_datetime) 
            as ping_sequence ,
            base_datetime,
            LAG(base_datetime) over (partition by mmsi order by base_datetime)
            as previos_ping_time,lat,
            LAG(lat) over (PARTITION BY mmsi order by base_datetime)
            as prev_lat,lon,
            LAG(lon) over (PARTITION BY mmsi order by base_datetime)
            as prev_lon,
            sog
    from ais_data
),

time_diff as
    (select a.id,a.mmsi,dt.ping_sequence,dt.previos_ping_time,a.base_datetime,
    (extract(epoch from (dt.base_datetime - dt.previos_ping_time))/60)
     as time_difference
    from ais_data a 
     join datestamps dt on a.id = dt.id
    ) ,

gap_fl as
    (select * ,
    case 
    when time_difference < 30 then 'Short Gap'
    when time_difference >= 30 AND time_difference < 120 then 'Moderate Gap'
    else 'Long Gap' END as Gap_flag 
    from time_diff
    ),

A_HD AS(
    select MMSI,ID,power(sin((radians(lat)-radians(prev_lat))/2),2) + cos(radians(lat)) * cos(radians(prev_lat)) * 
    power(SIN((RADIANS(LON)-RADIANS(PREV_LON))/2),2) AS a_value
    FROM DATESTAMPS
    ) ,

C_HD AS (
    SELECT ID,MMSI,2*(ATAN2(SQRT(A_VALUE),SQRT(1-A_VALUE))) AS C_VALUE
    FROM A_HD
    ),

distances as (
    SELECT DT.ID,DT.MMSI,6371*C_VALUE as dist, DT.sog  FROM C_HD C  JOIN DATESTAMPS DT
    ON C.ID = DT.ID JOIN ais_data a on c.id=a.id 
    ),

speed_knots as(
    select d.id,d.mmsi,d.sog, d.dist as dist ,t.time_difference as time_differ,
    ((d.dist/(t.time_difference/60))/1.852) as speed_in_knots
    from distances d join time_diff t
    on d.id = t.id 
    where t.time_difference >0 and t.time_difference is not NULL and d.dist >0 
    and d.dist is not NULL and t.time_difference >=1 ),

anomaly as (
    select id,mmsi,sog,speed_in_knots,dist,time_differ,
    ABS(sog-speed_in_knots) as speed_diff
    from speed_knots
    
),

speed_anomaly_flag as (
select * ,
case when speed_diff >5 then 'Anomaly'
    else 'normal' end as speed_anomaly
from anomaly
where  speed_diff >0 and speed_diff is not NULL and sog>5 
order by speed_diff DESC
),

count_speed_anomaly as(
    select mmsi,count(case when speed_anomaly = 'Anomaly' then 1 end ) as count_spd_anomaly
    from speed_anomaly_flag
    group by mmsi
),

count_gap_anomaly as (
    select mmsi,count(case when Gap_flag = 'Long Gap' then 1 end) as count_gp_anomaly
    from gap_fl
    group by mmsi
),

severity as (
    select mmsi,max(speed_diff) as max_speed_diff , avg(speed_diff) as avg_speed_diff
    from speed_anomaly_flag 
    where speed_anomaly = 'Anomaly'
    group by mmsi 
),

anomaly_table as(
select csa.mmsi ,count_spd_anomaly , count_gp_anomaly,max_speed_diff ,avg_speed_diff ,
(avg_speed_diff * LN(count_spd_anomaly)) as severity 
from count_speed_anomaly csa join count_gap_anomaly  cga on csa.mmsi = cga.mmsi 
join severity s on cga.mmsi = s.mmsi
 order by severity  desc )

select *, rank() over(order by severity desc) as ranking 
from anomaly_table;



