-- 02 — Manipulation CRUD sur les données F1
-- Exécution : docker exec -i cassandra cqlsh < queries/02_crud.sql

USE f1;

-- ========== CREATE : ajout d'un pilote de réserve fictif au GP de Bahreïn ==========
INSERT INTO drivers_by_session (session_key, driver_number, full_name, name_acronym, team_name, country_code)
VALUES (9472, 99, 'Test DRIVER', 'TST', 'Équipe Test', 'FRA');

-- ========== READ : lecture du pilote ajouté (accès direct par la clé primaire) ==========
SELECT * FROM drivers_by_session
WHERE session_key = 9472 AND driver_number = 99;

-- ========== UPDATE : le pilote change d'équipe ==========
UPDATE drivers_by_session
SET team_name = 'Alpine'
WHERE session_key = 9472 AND driver_number = 99;

SELECT * FROM drivers_by_session
WHERE session_key = 9472 AND driver_number = 99;

-- ========== CREATE / UPDATE sur un arrêt aux stands ==========
INSERT INTO pit_stops_by_session (session_key, lap_number, driver_number, name_acronym, pit_duration, date)
VALUES (9472, 30, 99, 'TST', 25.0, '2024-03-02 16:00:00+0000');

-- Correction de la durée de l'arrêt
UPDATE pit_stops_by_session
SET pit_duration = 23.4
WHERE session_key = 9472 AND lap_number = 30 AND driver_number = 99;

SELECT * FROM pit_stops_by_session
WHERE session_key = 9472 AND lap_number = 30;

-- ========== DELETE : suppression d'une colonne puis des lignes ==========
DELETE pit_duration FROM pit_stops_by_session
WHERE session_key = 9472 AND lap_number = 30 AND driver_number = 99;

DELETE FROM pit_stops_by_session
WHERE session_key = 9472 AND lap_number = 30 AND driver_number = 99;

DELETE FROM drivers_by_session
WHERE session_key = 9472 AND driver_number = 99;

-- Vérification : les lignes ont disparu
SELECT * FROM drivers_by_session
WHERE session_key = 9472 AND driver_number = 99;

SELECT * FROM pit_stops_by_session
WHERE session_key = 9472 AND lap_number = 30;
