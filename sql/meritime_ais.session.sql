CREATE TABLE ais_data (
    id SERIAL PRIMARY KEY,
    mmsi BIGINT,
    base_datetime TIMESTAMP,
    lat DOUBLE PRECISION,
    lon DOUBLE PRECISION,
    sog DOUBLE PRECISION,
    cog DOUBLE PRECISION,
    heading DOUBLE PRECISION
);