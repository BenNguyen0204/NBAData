-- ORtg, DRtg, NetRtg, Pace, Win%, eFG%, TOV%, ORB%, FTr, League Rank (+ Expected Win%)

DROP VIEW IF EXISTS team_season_kpis CASCADE;

CREATE VIEW team_season_kpis AS
WITH totals AS (
    SELECT
        team,
        COUNT(*)          AS games,
        SUM(is_win::int)  AS wins,
        SUM(min)          AS min,
        SUM(pts)          AS pts,
        SUM(opp_pts)      AS opp_pts,
        SUM(fgm)          AS fgm,
        SUM(fga)          AS fga,
        SUM(fg3m)         AS fg3m,
        SUM(fta)          AS fta,
        SUM(oreb)         AS oreb,
        SUM(tov)          AS tov,
        SUM(opp_dreb)     AS opp_dreb,
        SUM(poss)         AS poss   -- poss = (Poss + Opp_Poss) / 2
    FROM team_game_base
    GROUP BY team
),

kpis AS (
    SELECT
        team,
        games,
        wins,
        games - wins AS losses,

        -- Win%
        ROUND(wins::numeric / games, 3) AS win_pct,

        -- Offensive Rating (ORtg): points scored per 100 possessions
        ROUND(100 * pts / poss, 1) AS ortg,

        -- Defensive Rating (DRtg): points allowed per 100 possessions (lower is better)
        ROUND(100 * opp_pts / poss, 1) AS drtg,

        -- Net Rating (NetRtg) = ORtg - DRtg
        ROUND(100 * (pts - opp_pts) / poss, 1) AS net_rtg,

        -- Pace: possessions per 48 minutes (adjusts for OT)
        ROUND(48 * poss / (min / 5.0), 1) AS pace,

        -- Effective FG% (eFG%)
        ROUND((fgm + 0.5 * fg3m) / fga, 3) AS efg_pct,

        -- Turnover % (TOV%) (lower is better)
        ROUND(tov / (fga + 0.44 * fta + tov), 3) AS tov_pct,

        -- Offensive Rebound % (ORB%)
        ROUND(oreb::numeric / (oreb + opp_dreb), 3) AS orb_pct,

        -- Free Throw Rate (FTr)
        ROUND(fta::numeric / fga, 3) AS ftr,

        -- Expected Win%: win% the team "should" have from points scored and allowed
        ROUND(1 / (1 + POWER(opp_pts::numeric / pts, 14)), 3) AS expected_win_pct
    FROM totals
)

SELECT
    *,
    -- Positive = winning more than their points suggest (clutch or lucky)
    win_pct - expected_win_pct AS win_pct_vs_expected,

    -- League ranks (1 = best)
    RANK() OVER (ORDER BY net_rtg DESC) AS net_rtg_rank,
    RANK() OVER (ORDER BY ortg DESC)    AS ortg_rank,
    RANK() OVER (ORDER BY drtg ASC)     AS drtg_rank   -- lowest is best
FROM kpis;