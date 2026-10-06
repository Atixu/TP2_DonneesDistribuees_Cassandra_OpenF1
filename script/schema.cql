-- Keyspace et tables du projet F1 (API OpenF1)
-- Chaque table est conçue pour répondre à une requête métier précise (query-driven design).

CREATE KEYSPACE IF NOT EXISTS f1
WITH replication = {
    'class': 'SimpleStrategy',
    'replication_factor': 1
};

USE f1;

-- REQ-01 : calendrier des courses d'une saison, trié par date
CREATE TABLE IF NOT EXISTS races_by_year (
    year          int,
    date_start    timestamp,
    session_key   int,
    meeting_key   int,
    country_name  text,
    location      text,
    circuit       text,
    PRIMARY KEY ((year), date_start, session_key)
) WITH CLUSTERING ORDER BY (date_start ASC, session_key ASC);

-- Pilotes engagés sur une course
CREATE TABLE IF NOT EXISTS drivers_by_session (
    session_key    int,
    driver_number  int,
    full_name      text,
    name_acronym   text,
    team_name      text,
    country_code   text,
    PRIMARY KEY ((session_key), driver_number)
);

-- REQ-02 : classement final d'une course (podium = LIMIT 3)
CREATE TABLE IF NOT EXISTS results_by_session (
    session_key     int,
    position        int,
    driver_number   int,
    full_name       text,
    team_name       text,
    number_of_laps  int,
    points          double,
    gap_to_leader   text,
    status          text,
    PRIMARY KEY ((session_key), position, driver_number)
) WITH CLUSTERING ORDER BY (position ASC, driver_number ASC);

-- REQ-03 : résultats d'un pilote sur une saison
CREATE TABLE IF NOT EXISTS results_by_driver (
    driver_number  int,
    year           int,
    date_start     timestamp,
    session_key    int,
    full_name      text,
    team_name      text,
    location       text,
    position       int,
    points         double,
    status         text,
    PRIMARY KEY ((driver_number, year), date_start, session_key)
) WITH CLUSTERING ORDER BY (date_start ASC, session_key ASC);

-- REQ-05 : temps au tour d'un pilote sur une course
CREATE TABLE IF NOT EXISTS laps_by_driver (
    session_key        int,
    driver_number      int,
    lap_number         int,
    lap_duration       double,
    duration_sector_1  double,
    duration_sector_2  double,
    duration_sector_3  double,
    st_speed           int,
    is_pit_out_lap     boolean,
    PRIMARY KEY ((session_key, driver_number), lap_number)
) WITH CLUSTERING ORDER BY (lap_number ASC);

-- REQ-04 : meilleurs tours d'une course (triés du plus rapide au plus lent)
CREATE TABLE IF NOT EXISTS fastest_laps_by_session (
    session_key    int,
    lap_duration   double,
    driver_number  int,
    lap_number     int,
    name_acronym   text,
    team_name      text,
    PRIMARY KEY ((session_key), lap_duration, driver_number, lap_number)
) WITH CLUSTERING ORDER BY (lap_duration ASC, driver_number ASC, lap_number ASC);

-- REQ-06 : arrêts aux stands d'une course
CREATE TABLE IF NOT EXISTS pit_stops_by_session (
    session_key    int,
    lap_number     int,
    driver_number  int,
    name_acronym   text,
    pit_duration   double,
    date           timestamp,
    PRIMARY KEY ((session_key), lap_number, driver_number)
) WITH CLUSTERING ORDER BY (lap_number ASC, driver_number ASC);

-- REQ-07 : stratégie pneus d'un pilote sur une course
CREATE TABLE IF NOT EXISTS stints_by_driver (
    session_key        int,
    driver_number      int,
    stint_number       int,
    compound           text,
    lap_start          int,
    lap_end            int,
    tyre_age_at_start  int,
    PRIMARY KEY ((session_key, driver_number), stint_number)
) WITH CLUSTERING ORDER BY (stint_number ASC);
