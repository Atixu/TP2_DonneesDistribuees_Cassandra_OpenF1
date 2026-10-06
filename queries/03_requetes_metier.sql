-- 03 — Requêtes métier : analyse de la saison F1 2024
-- Exécution : docker exec -i cassandra cqlsh < queries/03_requetes_metier.sql
-- Aucune requête n'utilise ALLOW FILTERING : chacune cible une partition.

USE f1;

-- REQ-01 : Calendrier des courses de la saison 2024, dans l'ordre chronologique
SELECT date_start, session_key, country_name, location, circuit
FROM races_by_year
WHERE year = 2024;

-- REQ-02 : Podium du Grand Prix de Bahreïn 2024 (session 9472)
SELECT position, full_name, team_name, points, gap_to_leader
FROM results_by_session
WHERE session_key = 9472
LIMIT 3;

-- REQ-02 bis : Pilotes non classés (abandons) au GP de Monaco 2024 (session 9523)
SELECT position, full_name, team_name, number_of_laps, status
FROM results_by_session
WHERE session_key = 9523 AND position >= 100;

-- REQ-03 : Résultats de Max Verstappen (#1) sur la saison 2024, course par course
SELECT date_start, location, position, points, status
FROM results_by_driver
WHERE driver_number = 1 AND year = 2024;

-- REQ-03 bis : Total des points de Max Verstappen en 2024 (agrégat dans une seule partition)
SELECT full_name, SUM(points) AS total_points, COUNT(*) AS nb_courses
FROM results_by_driver
WHERE driver_number = 1 AND year = 2024;

-- REQ-04 : Top 10 des meilleurs tours en course au GP d'Italie (Monza, session 9590)
SELECT lap_duration, name_acronym, team_name, lap_number
FROM fastest_laps_by_session
WHERE session_key = 9590
LIMIT 10;

-- REQ-05 : Temps au tour de Charles Leclerc (#16) à Monza, du tour 10 au tour 20
SELECT lap_number, lap_duration, duration_sector_1, duration_sector_2, duration_sector_3, st_speed
FROM laps_by_driver
WHERE session_key = 9590 AND driver_number = 16
  AND lap_number >= 10 AND lap_number <= 20;

-- REQ-06 : Arrêts aux stands du GP d'Italie, dans l'ordre des tours
SELECT lap_number, name_acronym, pit_duration
FROM pit_stops_by_session
WHERE session_key = 9590;

-- REQ-07 : Stratégie pneus de Lando Norris (#4) au GP d'Italie
SELECT stint_number, compound, lap_start, lap_end, tyre_age_at_start
FROM stints_by_driver
WHERE session_key = 9590 AND driver_number = 4;
