-- 01 — Vérification de l'import OpenF1 dans Cassandra
-- Exécution : docker exec -i cassandra cqlsh < queries/01_verification.sql

DESCRIBE KEYSPACES;

USE f1;

DESCRIBE TABLES;

DESCRIBE TABLE results_by_session;

-- Nombre de courses importées pour 2024 (partition year = 2024)
SELECT COUNT(*) FROM races_by_year WHERE year = 2024;

-- Pilotes engagés au GP de Bahreïn 2024 (session 9472)
SELECT COUNT(*) FROM drivers_by_session WHERE session_key = 9472;
SELECT driver_number, name_acronym, full_name, team_name
FROM drivers_by_session
WHERE session_key = 9472;

-- Tours de Max Verstappen (#1) à Bahreïn
SELECT COUNT(*) FROM laps_by_driver WHERE session_key = 9472 AND driver_number = 1;

-- Aperçu des données de chaque table
SELECT * FROM races_by_year LIMIT 5;
SELECT * FROM results_by_session LIMIT 5;
SELECT * FROM results_by_driver LIMIT 5;
SELECT * FROM laps_by_driver LIMIT 5;
SELECT * FROM fastest_laps_by_session LIMIT 5;
SELECT * FROM pit_stops_by_session LIMIT 5;
SELECT * FROM stints_by_driver LIMIT 5;
