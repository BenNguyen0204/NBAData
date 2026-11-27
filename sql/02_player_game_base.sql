-- Game Score (plus counting columns, team-level totals for Usage, excluding games with 0 minutes played)

DROP VIEW IF EXISTS player_game_base;

CREATE VIEW player_game_base AS
SELECT
    p.game_id,
    p.game_date::date AS game_date,
    p.player_id,
    p.player_name,
    p.team_abbreviation AS team,
    p.min,
    p.pts, p.reb, p.ast, p.stl, p.blk, p.tov,
    p.fgm, p.fga, p.fg3m, p.ftm, p.fta, p.oreb, p.dreb, p.pf,

    -- Team totals for the same game (for Usage %)
    t.min AS tm_min,
    t.fga AS tm_fga,
    t.fta AS tm_fta,
    t.tov AS tm_tov,

    -- Hollinger's single-game productivity score
    p.pts + 0.4*p.fgm - 0.7*p.fga - 0.4*(p.fta - p.ftm) + 0.7*p.oreb + 0.3*p.dreb + p.stl + 0.7*p.ast + 0.7*p.blk - 0.4*p.pf - p.tov AS game_score

FROM player_games AS p
JOIN team_games AS t
  ON t.game_id = p.game_id
 AND t.team_id = p.team_id
WHERE p.min > 0;