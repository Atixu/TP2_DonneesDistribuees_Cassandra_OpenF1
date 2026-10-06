import argparse
import time
from datetime import datetime
from pathlib import Path

import requests
from cassandra.cluster import Cluster
from cassandra.concurrent import execute_concurrent_with_args


API_URL = "https://api.openf1.org/v1"
SCHEMA_FILE = Path(__file__).with_name("schema.cql")
# L'API OpenF1 limite à 3 requêtes par seconde
PAUSE = 0.4


def get(endpoint, **params):
    for attempt in range(8):
        time.sleep(PAUSE)
        response = requests.get(f"{API_URL}/{endpoint}", params=params, timeout=60)
        if response.status_code == 429:
            # Limite aussi appliquée par minute : on attend de plus en plus longtemps
            time.sleep(min(2 ** attempt, 60))
            continue
        response.raise_for_status()
        return response.json()
    raise RuntimeError(f"Trop de requêtes refusées sur {endpoint}")


def to_datetime(value):
    return datetime.fromisoformat(value) if value else None


def create_schema(session):
    lines = [l for l in SCHEMA_FILE.read_text().splitlines() if not l.strip().startswith("--")]
    for statement in "\n".join(lines).split(";"):
        if statement.strip():
            session.execute(statement)


def result_status(result):
    for flag in ("dsq", "dns", "dnf"):
        if result.get(flag):
            return flag.upper()
    return "FINISHED"


def import_race(session, stmts, race, year):
    key = race["session_key"]

    drivers = {d["driver_number"]: d for d in get("drivers", session_key=key)}
    for d in drivers.values():
        session.execute(stmts["driver"], (
            key, d["driver_number"], d.get("full_name"), d.get("name_acronym"),
            d.get("team_name"), d.get("country_code"),
        ))

    results = get("session_result", session_key=key)
    for i, r in enumerate(results):
        d = drivers.get(r["driver_number"], {})
        # Un pilote non classé n'a pas de position : on le place en fin de classement
        # (la position est une colonne de clustering, elle ne peut pas être nulle)
        position = r.get("position") or 100 + i
        gap = r.get("gap_to_leader")
        status = result_status(r)
        session.execute(stmts["result"], (
            key, position, r["driver_number"], d.get("full_name"), d.get("team_name"),
            r.get("number_of_laps"), r.get("points"), None if gap is None else str(gap), status,
        ))
        session.execute(stmts["result_driver"], (
            r["driver_number"], year, to_datetime(race["date_start"]), key,
            d.get("full_name"), d.get("team_name"), race.get("location"),
            position, r.get("points"), status,
        ))

    laps = get("laps", session_key=key)
    execute_concurrent_with_args(session, stmts["lap"], [(
        key, l["driver_number"], l["lap_number"], l.get("lap_duration"),
        l.get("duration_sector_1"), l.get("duration_sector_2"), l.get("duration_sector_3"),
        l.get("st_speed"), l.get("is_pit_out_lap"),
    ) for l in laps])
    execute_concurrent_with_args(session, stmts["fastest"], [(
        key, l["lap_duration"], l["driver_number"], l["lap_number"],
        drivers.get(l["driver_number"], {}).get("name_acronym"),
        drivers.get(l["driver_number"], {}).get("team_name"),
    ) for l in laps if l.get("lap_duration")])

    pits = get("pit", session_key=key)
    for p in pits:
        session.execute(stmts["pit"], (
            key, p["lap_number"], p["driver_number"],
            drivers.get(p["driver_number"], {}).get("name_acronym"),
            p.get("pit_duration"), to_datetime(p.get("date")),
        ))

    stints = get("stints", session_key=key)
    for s in stints:
        session.execute(stmts["stint"], (
            key, s["driver_number"], s["stint_number"], s.get("compound"),
            s.get("lap_start"), s.get("lap_end"), s.get("tyre_age_at_start"),
        ))

    return len(drivers), len(results), len(laps), len(pits), len(stints)


def main():
    parser = argparse.ArgumentParser(description="Import OpenF1 -> Cassandra")
    parser.add_argument("--year", type=int, default=2024)
    args = parser.parse_args()

    cluster = Cluster(["127.0.0.1"], port=9042)
    session = cluster.connect()
    create_schema(session)
    session.set_keyspace("f1")

    stmts = {name: session.prepare(cql) for name, cql in {
        "race": "INSERT INTO races_by_year (year, date_start, session_key, meeting_key, "
                "country_name, location, circuit) VALUES (?, ?, ?, ?, ?, ?, ?)",
        "driver": "INSERT INTO drivers_by_session (session_key, driver_number, full_name, "
                  "name_acronym, team_name, country_code) VALUES (?, ?, ?, ?, ?, ?)",
        "result": "INSERT INTO results_by_session (session_key, position, driver_number, "
                  "full_name, team_name, number_of_laps, points, gap_to_leader, status) "
                  "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
        "result_driver": "INSERT INTO results_by_driver (driver_number, year, date_start, "
                         "session_key, full_name, team_name, location, position, points, status) "
                         "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        "lap": "INSERT INTO laps_by_driver (session_key, driver_number, lap_number, lap_duration, "
               "duration_sector_1, duration_sector_2, duration_sector_3, st_speed, is_pit_out_lap) "
               "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
        "fastest": "INSERT INTO fastest_laps_by_session (session_key, lap_duration, driver_number, "
                   "lap_number, name_acronym, team_name) VALUES (?, ?, ?, ?, ?, ?)",
        "pit": "INSERT INTO pit_stops_by_session (session_key, lap_number, driver_number, "
               "name_acronym, pit_duration, date) VALUES (?, ?, ?, ?, ?, ?)",
        "stint": "INSERT INTO stints_by_driver (session_key, driver_number, stint_number, compound, "
                 "lap_start, lap_end, tyre_age_at_start) VALUES (?, ?, ?, ?, ?, ?, ?)",
    }.items()}

    print(f"Récupération des courses {args.year} depuis OpenF1...")
    races = [r for r in get("sessions", year=args.year, session_name="Race")
             if not r.get("is_cancelled")]
    print(f"{len(races)} courses récupérées.")

    for race in races:
        session.execute(stmts["race"], (
            args.year, to_datetime(race["date_start"]), race["session_key"], race["meeting_key"],
            race.get("country_name"), race.get("location"), race.get("circuit_short_name"),
        ))
        counts = import_race(session, stmts, race, args.year)
        print(f"Course importée : {race['session_key']} - {race.get('location')} "
              "({} pilotes, {} résultats, {} tours, {} pit stops, {} relais)".format(*counts))

    cluster.shutdown()
    print("Import terminé.")


if __name__ == "__main__":
    main()
