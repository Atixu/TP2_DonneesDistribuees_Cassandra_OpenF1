# Modélisation Cassandra — Saison F1 2024 (API OpenF1)

## 1. Démarche

Avec Cassandra, on part des **requêtes** que l'application doit exécuter, puis on construit **une table par requête** :

```text
Besoin métier → Requête → Données nécessaires → Partition key → Clustering key → Table
```

Conséquences assumées :

- **dénormalisation** : le nom du pilote, son équipe ou le lieu de la course sont recopiés dans plusieurs tables, pour qu'une requête n'ait jamais besoin de jointure ;
- **une même donnée dans plusieurs tables** : un tour est écrit dans `laps_by_driver` *et* dans `fastest_laps_by_session`, car ces deux requêtes ne trient pas les tours de la même façon ;
- **pas de `ALLOW FILTERING`** : chaque requête métier cible une partition connue.

Keyspace :

```sql
CREATE KEYSPACE f1
WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1};
```

(RF = 1 car nous travaillons sur un seul nœud. Le RF sera revu au TP cluster.)

---

## 2. Tables

Le schéma complet se trouve dans [`script/schema.cql`](../script/schema.cql).

| Table | Partition key | Clustering key | Lignes (2024) |
|---|---|---|---|
| `races_by_year` | `year` | `date_start` ASC, `session_key` | 24 |
| `drivers_by_session` | `session_key` | `driver_number` | 479 |
| `results_by_session` | `session_key` | `position` ASC, `driver_number` | 479 |
| `results_by_driver` | `(driver_number, year)` | `date_start` ASC, `session_key` | 479 |
| `laps_by_driver` | `(session_key, driver_number)` | `lap_number` ASC | ≈ 26 600 |
| `fastest_laps_by_session` | `session_key` | `lap_duration` ASC, `driver_number`, `lap_number` | ≈ 26 500 |
| `pit_stops_by_session` | `session_key` | `lap_number` ASC, `driver_number` | 825 |
| `stints_by_driver` | `(session_key, driver_number)` | `stint_number` ASC | ≈ 1 300 |

### `races_by_year`

```text
year (PK) | date_start (CK) | session_key (CK) | meeting_key | country_name | location | circuit
```

- **Partition key `year`** : on consulte toujours le calendrier d'une saison. Une saison = une partition de ~24 lignes, très petite.
- **Clustering `date_start` ASC** : les courses sortent directement dans l'ordre chronologique. `session_key` est ajouté pour garantir l'unicité si deux sessions démarraient à la même heure.

### `drivers_by_session`

- **Partition key `session_key`** : on liste les pilotes engagés sur une course donnée (la composition des équipes change en cours de saison, ex. Bearman, Colapinto, Lawson).
- **Clustering `driver_number`** : rend chaque pilote unique dans la partition et permet l'accès direct à un pilote (`WHERE session_key = ? AND driver_number = ?`), utilisé pour le CRUD.

### `results_by_session`

- **Partition key `session_key`** : un classement = une course.
- **Clustering `position` ASC** : le classement est déjà trié, donc `LIMIT 3` donne le podium sans aucun tri côté client.
- `driver_number` en dernière clustering key garantit l'unicité.
- **Cas des pilotes non classés** : l'API renvoie `position = null` pour un abandon. Une colonne de clustering ne pouvant pas être nulle, le script attribue `100 + rang dans la réponse` et renseigne la colonne `status` (`DNF`, `DNS`, `DSQ`, `FINISHED`). Cela permet aussi une requête par plage : `position >= 100` = pilotes non classés.
- `gap_to_leader` est stocké en `text` car l'API renvoie soit un nombre (secondes), soit une chaîne (`+1 LAP`).

### `results_by_driver`

- **Partition key composite `(driver_number, year)`** : on consulte la saison d'un pilote. Mettre l'année dans la clé évite qu'une partition grossisse indéfiniment au fil des saisons, et les numéros de pilotes peuvent être réattribués d'une année à l'autre.
- **Clustering `date_start` ASC** : résultats dans l'ordre du calendrier.
- Comme toute la saison du pilote est dans **une seule partition**, `SUM(points)` est efficace (agrégat local, pas de scan du cluster).

### `laps_by_driver`

- **Partition key composite `(session_key, driver_number)`** : on analyse le rythme d'un pilote sur une course. Une partition ≈ 50-78 lignes. Si l'on partitionnait uniquement par `session_key`, la partition contiendrait ~1 300 tours de tous les pilotes, et filtrer un pilote nécessiterait `ALLOW FILTERING` ou une clustering key mal ordonnée.
- **Clustering `lap_number` ASC** : permet les requêtes par plage de tours (`lap_number >= 10 AND lap_number <= 20`).

### `fastest_laps_by_session`

- **Partition key `session_key`** : on compare tous les pilotes d'une même course.
- **Clustering `lap_duration` ASC** : Cassandra ne sait trier que sur les clustering keys ; on stocke donc les tours *déjà triés par temps*. `LIMIT 10` = les 10 meilleurs tours.
- `driver_number` et `lap_number` complètent la clé pour l'unicité (deux tours peuvent avoir le même temps).
- Les tours sans temps (`lap_duration = null`, ex. 1er tour, tour interrompu) ne sont pas insérés dans cette table.

### `pit_stops_by_session`

- **Partition key `session_key`** : tous les arrêts d'une course.
- **Clustering `lap_number` ASC, `driver_number`** : déroulé chronologique de la course ; un même pilote ne peut s'arrêter qu'une fois par tour.
- `pit_duration` = temps passé dans la voie des stands (entrée → sortie), en secondes.

### `stints_by_driver`

- **Partition key composite `(session_key, driver_number)`** : stratégie d'un pilote donné sur une course.
- **Clustering `stint_number` ASC** : les relais sortent dans l'ordre (pneus utilisés, tours de début et de fin).

---

## 3. Besoins métier et requêtes

Toutes les requêtes sont dans [`queries/03_requetes_metier.sql`](../queries/03_requetes_metier.sql), les résultats dans [`captures/03_requetes_metier.txt`](../captures/03_requetes_metier.txt).

### REQ-01

**Besoin métier :** afficher le calendrier des courses d'une saison, dans l'ordre chronologique.

**Requête CQL :**
```sql
SELECT date_start, session_key, country_name, location, circuit
FROM races_by_year
WHERE year = 2024;
```

**Clé de partition utilisée :** `year`

**Justification :** une seule partition est lue ; l'ordre chronologique est garanti par la clustering key `date_start` ASC, sans `ORDER BY`. Le `session_key` retourné sert ensuite de point d'entrée pour toutes les autres requêtes.

### REQ-02

**Besoin métier :** connaître le podium d'un Grand Prix (ici Bahreïn 2024).

**Requête CQL :**
```sql
SELECT position, full_name, team_name, points, gap_to_leader
FROM results_by_session
WHERE session_key = 9472
LIMIT 3;
```

**Clé de partition utilisée :** `session_key`

**Justification :** les lignes sont stockées triées par `position` ; Cassandra lit seulement les 3 premières lignes de la partition. Résultat : Verstappen, Pérez, Sainz.

Variante (pilotes non classés au GP de Monaco) : `WHERE session_key = 9523 AND position >= 100` — requête par plage sur la clustering key.

### REQ-03

**Besoin métier :** suivre les résultats d'un pilote sur toute la saison et calculer son total de points (ici Max Verstappen, n° 1).

**Requête CQL :**
```sql
SELECT date_start, location, position, points, status
FROM results_by_driver
WHERE driver_number = 1 AND year = 2024;

SELECT full_name, SUM(points) AS total_points, COUNT(*) AS nb_courses
FROM results_by_driver
WHERE driver_number = 1 AND year = 2024;
```

**Clé de partition utilisée :** `(driver_number, year)`

**Justification :** la partition contient exactement les 24 courses du pilote, dans l'ordre du calendrier. L'agrégat `SUM` est calculé sur une seule partition (399 points en course ; les points des sprints ne sont pas inclus car seules les sessions `Race` sont importées).

### REQ-04

**Besoin métier :** identifier les 10 meilleurs tours en course d'un Grand Prix (ici Monza).

**Requête CQL :**
```sql
SELECT lap_duration, name_acronym, team_name, lap_number
FROM fastest_laps_by_session
WHERE session_key = 9590
LIMIT 10;
```

**Clé de partition utilisée :** `session_key`

**Justification :** `ORDER BY lap_duration` est impossible sur une table où `lap_duration` n'est pas une clustering key. La table dédiée stocke les tours déjà triés par temps : la requête lit simplement le début de la partition. Meilleur tour : Norris, 1:21.432 (tour 53).

### REQ-05

**Besoin métier :** analyser le rythme d'un pilote sur une portion de course (ici Leclerc à Monza, tours 10 à 20 — on y voit son arrêt au tour 15-16).

**Requête CQL :**
```sql
SELECT lap_number, lap_duration, duration_sector_1, duration_sector_2, duration_sector_3, st_speed
FROM laps_by_driver
WHERE session_key = 9590 AND driver_number = 16
  AND lap_number >= 10 AND lap_number <= 20;
```

**Clé de partition utilisée :** `(session_key, driver_number)`

**Justification :** la partition est petite (un pilote, une course) et la plage sur `lap_number` est autorisée car c'est la clustering key.

### REQ-06

**Besoin métier :** voir le déroulé des arrêts aux stands d'une course (ici Monza).

**Requête CQL :**
```sql
SELECT lap_number, name_acronym, pit_duration
FROM pit_stops_by_session
WHERE session_key = 9590;
```

**Clé de partition utilisée :** `session_key`

**Justification :** une partition par course, arrêts triés par tour grâce à la clustering key `lap_number`.

### REQ-07

**Besoin métier :** connaître la stratégie pneus d'un pilote sur une course (ici Norris à Monza).

**Requête CQL :**
```sql
SELECT stint_number, compound, lap_start, lap_end, tyre_age_at_start
FROM stints_by_driver
WHERE session_key = 9590 AND driver_number = 4;
```

**Clé de partition utilisée :** `(session_key, driver_number)`

**Justification :** la partition contient uniquement les relais du pilote, triés par `stint_number`. Résultat : MEDIUM (1-14) → HARD (15-32) → HARD (33-53), soit une stratégie à 2 arrêts.

---

## 4. Limites et pistes

- Un classement général des pilotes **toutes équipes confondues** (« qui a le plus de points en 2024 ? ») nécessiterait de lire toutes les partitions de `results_by_driver`. Avec Cassandra, la bonne solution serait une table `standings_by_year ((year), points DESC, driver_number)` alimentée par l'application, ou une colonne `counter`.
- Les tables qui partitionnent par `session_key` seule (`fastest_laps_by_session`, ~1 300 lignes) restent de taille raisonnable ; on éviterait en revanche d'y mettre la télémétrie `car_data` (plusieurs millions de points par course), qu'il faudrait partitionner par `(session_key, driver_number, tranche de temps)`.
