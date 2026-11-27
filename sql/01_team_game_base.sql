-- Possessions, Rest Days, B2B flag

CREATE OR REPLACE VIEW team_game_base AS
SELECT
    t.game_id,
    t.game_date::date AS game_date,
    t.team_abbreviation AS team,
    o.team_abbreviation AS opp,
    t.matchup LIKE '%vs.%' AS is_home,
    t.wl = 'W' AS is_win,

    --Days of rest since last game (0 = back-to-backk, NULL = first game)
    t.game_date::date
        - LAG(t.game_date::date) OVER  (PARTITION BY t.team_id ORDER BY t.game_date)
        - 1 AS rest_days,

    -- Stats needed for KPIs
    t.min,
    t.pts,
    o.pts AS opp_pts,
    t.fgm, 
    t.fga,
    t.fg3m,
    t.fta,
    t.oreb,
    t.tov,
    o.dreb AS opp_dreb,

    -- Possessions: average of both teams
    (t.fga + 0.44 * t.fta - t.oreb + t.tov + o.fga + 0.44 * o.fta - o.oreb + o.tov) / 2 AS poss

FROM team_games AS t
JOIN team_games AS o
ON o.game_id = t.game_id
AND o.team_id <> t.team_id;