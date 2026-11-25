# Load NBA game logs into PostgreSQL
# Usage: python ingestion/load_games.py --season 2025-26
import argparse
import os

import pandas as pd
from dotenv import load_dotenv
from nba_api.stats.endpoints import leaguegamelog
from sqlalchemy import create_engine

def fetch(season, kind):
    # kind: "T" = team, "P" = player
    df = leaguegamelog.LeagueGameLog(
        season=season, player_or_team_abbreviation=kind
    ).get_data_frames()[0]

    df = df.drop_duplicates()
    df["GAME_DATE"] = pd.to_datetime(df["GAME_DATE"])
    df["IS_HOME"] = df["MATCHUP"].str.contains("vs.")
    return df


def main():
    # Season getter
    parser = argparse.ArgumentParser()
    parser.add_argument("--season", required=True)
    season = parser.parse_args().season

    team = fetch(season, "T")
    player = fetch(season, "P")

    team["OPP_PTS"] = team.groupby("GAME_ID")["PTS"].transform("sum") - team["PTS"]
    assert (team.groupby("GAME_ID").size() == 2).all(), "Some GAME_IDs don't have 2 rows"

    team.columns = team.columns.str.lower()
    player.columns = player.columns.str.lower()

    load_dotenv(".env", override=True)
    engine = create_engine(os.getenv("DATABASE_URL"))
    team.to_sql("team_games", engine, if_exists="replace", index=False)
    player.to_sql("player_games", engine, if_exists="replace", index=False)

    print(f"Done: {len(team)} team rows, {len(player)} player rows")


if __name__ == "__main__":
    main()