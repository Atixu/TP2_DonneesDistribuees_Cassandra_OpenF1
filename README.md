# TP Cassandra — Exploitation de l'API OpenF1

M2 Big Data & IA — Données distribuées

## Sujet

**Analyse de la saison 2024 de Formule 1** : calendrier, pilotes engagés, classements, temps au tour, arrêts aux stands et stratégies pneus de chaque Grand Prix.

## API utilisée

[OpenF1](https://openf1.org/docs/#api-endpoints) — API REST gratuite et sans clé, base URL `https://api.openf1.org/v1`. Limite : 3 requêtes/seconde (le script fait une pause entre les appels et réessaie en cas de refus `429`).

| Endpoint | Paramètres | Données récupérées | Principaux champs |
|---|---|---|---|
| `/sessions` | `year=2024&session_name=Race` | les 24 courses de la saison | `session_key`, `meeting_key`, `date_start`, `country_name`, `location`, `circuit_short_name` |
| `/drivers` | `session_key` | pilotes engagés sur une course | `driver_number`, `full_name`, `name_acronym`, `team_name`, `country_code` |
| `/session_result` | `session_key` | classement final | `position`, `driver_number`, `points`, `number_of_laps`, `gap_to_leader`, `dnf`/`dns`/`dsq` |
| `/laps` | `session_key` | tous les tours de tous les pilotes | `lap_number`, `lap_duration`, `duration_sector_1/2/3`, `st_speed`, `is_pit_out_lap` |
| `/pit` | `session_key` | arrêts aux stands | `lap_number`, `driver_number`, `pit_duration`, `date` |
| `/stints` | `session_key` | relais / pneus | `stint_number`, `compound`, `lap_start`, `lap_end`, `tyre_age_at_start` |

Volume importé : 24 courses, 479 résultats, ≈ 26 600 tours, 825 arrêts, ≈ 1 300 relais.

## Modèle Cassandra

Keyspace `f1` (`SimpleStrategy`, RF = 1, un seul nœud). Une table par besoin métier :

| Table | PRIMARY KEY | Sert à |
|---|---|---|
| `races_by_year` | `((year), date_start, session_key)` | calendrier d'une saison |
| `drivers_by_session` | `((session_key), driver_number)` | pilotes d'une course |
| `results_by_session` | `((session_key), position, driver_number)` | classement / podium |
| `results_by_driver` | `((driver_number, year), date_start, session_key)` | saison d'un pilote |
| `laps_by_driver` | `((session_key, driver_number), lap_number)` | rythme d'un pilote |
| `fastest_laps_by_session` | `((session_key), lap_duration, driver_number, lap_number)` | meilleurs tours |
| `pit_stops_by_session` | `((session_key), lap_number, driver_number)` | arrêts aux stands |
| `stints_by_driver` | `((session_key, driver_number), stint_number)` | stratégie pneus |

Les choix de clés sont justifiés dans [documentation/modelisation.md](documentation/modelisation.md).

## Requêtes métier principales

| Réf. | Besoin | Table |
|---|---|---|
| REQ-01 | Calendrier 2024 dans l'ordre chronologique | `races_by_year` |
| REQ-02 | Podium d'un Grand Prix (+ pilotes non classés) | `results_by_session` |
| REQ-03 | Résultats et total de points d'un pilote sur la saison | `results_by_driver` |
| REQ-04 | Top 10 des meilleurs tours d'une course | `fastest_laps_by_session` |
| REQ-05 | Temps au tour d'un pilote sur une plage de tours | `laps_by_driver` |
| REQ-06 | Arrêts aux stands d'une course | `pit_stops_by_session` |
| REQ-07 | Stratégie pneus d'un pilote | `stints_by_driver` |

Aucune requête n'utilise `ALLOW FILTERING`.

## Organisation du dépôt

```text
TP-Cassandra-OpenF1/
├── README.md
├── docker-compose.yml          Cassandra 4.1, un nœud
├── requirements.txt
├── script/
│   ├── schema.cql              keyspace + tables
│   └── getapi.py               import OpenF1 → Cassandra
├── queries/
│   ├── 01_verification.sql
│   ├── 02_crud.sql
│   └── 03_requetes_metier.sql
├── documentation/
│   └── modelisation.md
└── captures/                   résultats cqlsh de chaque fichier de requêtes
```

## Lancer le projet

```bash
# 1. Démarrer Cassandra
docker compose up -d
docker exec cassandra nodetool status        # attendre l'état UN

# 2. Installer les dépendances Python
pip3 install -r requirements.txt

# 3. Créer le schéma et importer les données (≈ 2-3 min à cause de la limite de l'API)
python3 script/getapi.py                     # option : --year 2023

# 4. Exécuter les requêtes
docker exec -i cassandra cqlsh < queries/01_verification.sql
docker exec -i cassandra cqlsh < queries/02_crud.sql
docker exec -i cassandra cqlsh < queries/03_requetes_metier.sql
```

Le script `getapi.py` exécute lui-même `schema.cql` (`CREATE ... IF NOT EXISTS`) : il peut être relancé sans erreur, les `INSERT` Cassandra étant des upserts.

## Captures

Les journaux d'exécution du terminal (commandes + résultats) sont dans [captures/](captures/) :

- [00_etat_cassandra.log](captures/00_etat_cassandra.log) — conteneur, `nodetool status` (nœud `UN`), version
- [01_import_openf1.log](captures/01_import_openf1.log) — exécution de `getapi.py` (24 courses importées)
- [02_verification.log](captures/02_verification.log) — schéma et comptages (24 courses, 20 pilotes, 57 tours de VER à Bahreïn)
- [03_crud.log](captures/03_crud.log) — INSERT / SELECT / UPDATE / DELETE
- [04_requetes_metier.log](captures/04_requetes_metier.log) — les 7 requêtes métier dans cqlsh

Les fichiers `.txt` contiennent les sorties brutes de `cqlsh < queries/xx.sql`.

Extrait (REQ-02, podium de Bahreïn 2024) :

```text
 position | full_name      | team_name       | points | gap_to_leader
----------+----------------+-----------------+--------+---------------
        1 | Max VERSTAPPEN | Red Bull Racing |     26 |             0
        2 |   Sergio PEREZ | Red Bull Racing |     18 |        22.457
        3 |   Carlos SAINZ |         Ferrari |     15 |         25.11
```
