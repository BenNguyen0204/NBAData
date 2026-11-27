-- B2B Δ NetRtg, B2B by home/away, B2B type (league)

DROP VIEW IF EXISTS team_back_to_back;
DROP VIEW IF EXISTS league_back_to_back;

-- Per team
CREATE VIEW team_back_to_back AS
WITH games AS (
    SELECT
        team,
        is_home,
        is_win,
        pts - opp_pts AS pt_diff,
        poss,
        CASE WHEN rest_days = 0 THEN 'b2b' 
            WHEN rest_days >= 1 THEN 'rested' 
            END AS rest
    FROM team_game_base
),

totals AS (
    SELECT
        team,

        -- Games
        COUNT(*) FILTER (WHERE rest = 'b2b') AS b2b_games,
        COUNT(*) FILTER (WHERE rest = 'rested') AS rested_games,
        COUNT(*) FILTER (WHERE rest = 'b2b' AND is_home) AS b2b_home_games,
        COUNT(*) FILTER (WHERE rest = 'b2b' AND NOT is_home) AS b2b_away_games,

        -- Win %
        ROUND(AVG(is_win::int) FILTER (WHERE rest = 'b2b'), 3) AS b2b_win_pct,
        ROUND(AVG(is_win::int) FILTER (WHERE rest = 'rested'), 3) AS rested_win_pct,

        -- NetRtg
        ROUND(100 * SUM(pt_diff) FILTER (WHERE rest = 'b2b') / SUM(poss) FILTER (WHERE rest = 'b2b'), 1) AS b2b_net_rtg,
        ROUND(100 * SUM(pt_diff) FILTER (WHERE rest = 'rested') / SUM(poss) FILTER (WHERE rest = 'rested'), 1) AS rested_net_rtg,

        -- Home NetRtg
        ROUND(100 * SUM(pt_diff) FILTER (WHERE rest = 'b2b' AND is_home) / SUM(poss) FILTER (WHERE rest = 'b2b' AND is_home), 1) AS b2b_home_net_rtg,
        ROUND(100 * SUM(pt_diff) FILTER (WHERE rest = 'rested' AND is_home) / SUM(poss) FILTER (WHERE rest = 'rested' AND is_home), 1) AS rested_home_net_rtg,

        -- Away NetRtg
        ROUND(100 * SUM(pt_diff) FILTER (WHERE rest = 'b2b' AND NOT is_home) / SUM(poss) FILTER (WHERE rest = 'b2b' AND NOT is_home), 1) AS b2b_away_net_rtg,
        ROUND(100 * SUM(pt_diff) FILTER (WHERE rest = 'rested' AND NOT is_home) / SUM(poss) FILTER (WHERE rest = 'rested' AND NOT is_home), 1) AS rested_away_net_rtg

    FROM games
    GROUP BY team
)

-- B2B Δ (negative = worse on B2B)
SELECT
    *,
    b2b_win_pct - rested_win_pct AS b2b_win_pct_diff,
    b2b_net_rtg - rested_net_rtg AS b2b_net_rtg_diff,
    b2b_home_net_rtg - rested_home_net_rtg AS b2b_home_net_rtg_diff,
    b2b_away_net_rtg - rested_away_net_rtg AS b2b_away_net_rtg_diff
FROM totals;

-- League, by B2B type: Home/Away yesterday -> Home/Away today (4 combos), vs rested home/away
CREATE VIEW league_back_to_back AS
WITH games AS (
    SELECT
        *,

        -- Check if the previous game is home or away, return null
        LAG(is_home) OVER (PARTITION BY team ORDER BY game_date) AS prev_is_home
    FROM team_game_base
)

SELECT
    CASE
        WHEN rest_days >= 1 THEN 'Rested: ' || CASE WHEN is_home THEN 'Home' ELSE 'Away' END
        ELSE 'B2B: ' || CASE WHEN prev_is_home THEN 'Home' ELSE 'Away' END || ' -> ' || CASE WHEN is_home THEN 'Home' ELSE 'Away' END
    END AS b2b_type,
    COUNT(*) AS games,
    ROUND(AVG(is_win::int), 3) AS win_pct,
    ROUND(100 * SUM(pts - opp_pts) / SUM(poss), 1) AS net_rtg
FROM games
WHERE rest_days IS NOT NULL
GROUP BY 1;