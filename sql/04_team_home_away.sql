-- Home/Away Δ NetRtg

DROP VIEW IF EXISTS team_home_away CASCADE;

CREATE VIEW team_home_away AS
WITH totals AS (
    SELECT
        team,

        -- Home
        COUNT(*) FILTER (WHERE is_home) AS home_games,
        SUM(is_win::int) FILTER (WHERE is_home) AS home_wins,
        SUM(pts) FILTER (WHERE is_home) AS home_pts,
        SUM(opp_pts) FILTER (WHERE is_home) AS home_opp_pts,
        SUM(poss) FILTER (WHERE is_home) AS home_poss,


        -- Away
        COUNT(*) FILTER (WHERE not is_home) AS away_games,
        SUM(is_win::int) FILTER (WHERE not is_home) AS away_wins,
        SUM(pts) FILTER (WHERE not is_home) AS away_pts,
        SUM(opp_pts) FILTER (WHERE not is_home) AS away_opp_pts,
        SUM(poss) FILTER (WHERE not is_home) AS away_poss

    FROM team_game_base
    GROUP BY team
),

kpis AS (
    SELECT
        team,
        home_games,
        away_games,

        -- Win %
        ROUND(home_wins::numeric / home_games, 3) as home_win_pct,
        ROUND(away_wins::numeric / away_games, 3) as away_win_pct,

        ROUND(100 * away_pts / away_poss, 1) AS  away_ortg,
        ROUND(100 * away_opp_pts / away_poss, 1) AS away_drtg,
        

        ROUND(100 * home_pts / home_poss, 1) AS home_ortg,
        ROUND(100 * home_opp_pts / home_poss , 1) AS home_drtg
    FROM totals
),

net AS (
    SELECT
        *,
        (away_ortg - away_drtg) AS away_net_rtg,
        (home_ortg - home_drtg) AS home_net_rtg
    FROM kpis
)

SELECT 
    *,
    home_win_pct - away_win_pct AS home_away_win_pct,
    home_net_rtg - away_net_rtg AS home_away_net_rtg
FROM net;