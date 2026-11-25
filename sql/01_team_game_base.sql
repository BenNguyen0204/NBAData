-- 01_team_game_base
-- Grain: one row per team per game.
-- Base view for every team KPI. It holds counts only (no ratings), so later
-- views can sum first and divide after (requirements 3.4, rule 1).
-- Source: team_games

CREATE OR REPLACE VIEW team_game_base AS
WITH games AS (
    SELECT
        season_id,
        game_id,
        game_date::date AS game_date, -- works if the column is text or timestamp
        team_id,
        team_abbreviation,
        team_name,
        POSITION('vs.' IN matchup) > 0 AS is_home, -- 'LAL vs. BOS' = home, 'LAL @ BOS' = away
        wl = 'W' AS is_win,
        min,
        pts, fgm, fga, fg3m, fg3a, ftm, fta,
        oreb, dreb, ast, stl, blk, tov, pf,
        -- Possessions estimate for one team
        fga + 0.44 * fta - oreb + tov AS team_poss
    FROM team_games
),

rest AS (
    SELECT
        *,
        -- date - date = number of days. NULL for the first game of the season.
        game_date - LAG(game_date) OVER (
            PARTITION BY season_id, team_id
            ORDER BY game_date
        ) - 1 AS rest_days
    FROM games
)

SELECT
    t.season_id,
    t.game_id,
    t.game_date,
    t.team_id,
    t.team_abbreviation,
    t.team_name,
    o.team_id AS opp_team_id,
    o.team_abbreviation AS opp_abbreviation,
    -- Neutral site: both teams are listed as '@', so neither is home. NULL keeps
    -- these games out of home/away splits.
    CASE WHEN t.is_home <> o.is_home THEN t.is_home END AS is_home,
    t.is_win,

    -- Rest
    t.rest_days,
    t.rest_days = 0 AS is_b2b, -- NULL for the first game of the season

    -- Team stats
    t.min,
    t.pts, t.fgm, t.fga, t.fg3m, t.fg3a, t.ftm, t.fta,
    t.oreb, t.dreb, t.ast, t.stl, t.blk, t.tov, t.pf,

    -- Opponent stats
    o.pts AS opp_pts,
    o.dreb AS opp_dreb, -- needed for offensive rebound rate

    -- Possessions: average of the two teams, so both get the same number
    (t.team_poss + o.team_poss) / 2 AS poss
FROM rest t
JOIN rest o
  ON o.game_id = t.game_id
  AND o.team_id <> t.team_id;
