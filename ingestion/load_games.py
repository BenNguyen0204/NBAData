# Load NBA regular-season game logs into PostgreSQL
# Usage: python ingestion/load_games.py --season 2025-26
# Safe to re-run: only the given season is replaced, other seasons are kept.
import argparse
import os

import pandas as pd
from dotenv import load_dotenv
from nba_api.stats.endpoints import leaguegamelog
from sqlalchemy import create_engine, inspect, text


def fetch(season, kind):
    # kind: "T" = team, "P" = player
    df = leaguegamelog.LeagueGameLog(
        season=season,
        season_type_all_star="Regular Season",
        player_or_team_abbreviation=kind,
    ).get_data_frames()[0]

    # Stop here if the API returns nothing, before any data is deleted
    if df.empty:
        raise SystemExit(f"No data returned for season {season}")

    df = df.drop_duplicates()
    df["GAME_DATE"] = pd.to_datetime(df["GAME_DATE"])

    # Neutral-site games list both teams as "@", so neither is home -> NULL
    is_home = df["MATCHUP"].str.contains("vs.", regex=False).astype("boolean")
    has_home_team = is_home.groupby(df["GAME_ID"]).transform("any")
    df["IS_HOME"] = is_home.where(has_home_team)
    return df


def save(df, table, conn):
    # Delete this season's rows, then append. The table itself is never dropped,
    # so SQL views built on top of it keep working.
    if inspect(conn).has_table(table):
        conn.execute(
            text(f"DELETE FROM {table} WHERE season_id = :season_id"),
            {"season_id": df["season_id"].iloc[0]},
        )
    df.to_sql(table, conn, if_exists="append", index=False)


def main():
    # Season getter
    parser = argparse.ArgumentParser()
    parser.add_argument("--season", required=True)
    season = parser.parse_args().season

    team = fetch(season, "T")
    player = fetch(season, "P")

    assert (team.groupby("GAME_ID").size() == 2).all(), "Some GAME_IDs don't have 2 rows"
    team["OPP_PTS"] = team.groupby("GAME_ID")["PTS"].transform("sum") - team["PTS"]

    team.columns = team.columns.str.lower()
    player.columns = player.columns.str.lower()

    load_dotenv(".env", override=True)
    engine = create_engine(os.getenv("DATABASE_URL"))

    # One transaction: if anything fails, the old data stays as it was
    with engine.begin() as conn:
        save(team, "team_games", conn)
        save(player, "player_games", conn)

    print(f"Done: {season}, {len(team)} team rows, {len(player)} player rows")


if __name__ == "__main__":
    main()
