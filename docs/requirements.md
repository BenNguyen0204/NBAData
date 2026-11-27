# Triple Double — Requirements Document

| | |
|---|---|
| **Project** | Triple Double: NBA team and player performance analytics |
| **Version** | 1.0 (draft) |
| **Author** | Ben Nguyen |
| **Last updated** | 2026-11-18 |
| **Data source** | NBA Stats via `nba_api` (game logs and box scores) |

## 0. Purpose and scope

Triple Double turns raw NBA box-score data into answers to business questions that coaches, front-office staff and analysts ask during a season. This document defines **who** the product is for, **what** they need to know, **how** each metric is calculated and **how we will know** the product meets those needs.

**In scope**
- Regular-season games, seasons 2023-24 to 2025-26
- Team-level and player-level metrics derived from box scores
- An interactive dashboard with filters and a downloadable data export

**Out of scope (v1)**
- Play-by-play and tracking data (for example shot location or clutch-only splits)
- Playoff games
- Predictive models (win probability, player projections)

---

## 1. Stakeholders

| Stakeholder | Who they are | Primary goal | Key decisions supported | Success looks like |
|---|---|---|---|---|
| **Coaching staff** | Head coach, assistant coaches, player-development staff | Win more games by managing rotations, rest and matchups | Rest days, minutes distribution, lineup and rotation changes | Can see in under a minute how the team performs under fatigue, at home and away, and which players are trending up or down |
| **Front office** | General manager, assistant GM, scouting/pro personnel | Build a roster that delivers the most wins for the budget | Trades, signings, contract extensions, roster spots | Can compare a player's efficiency and role against league peers and track whether the team is improving over the season |
| **Analytics team** | Data analysts and data engineers supporting the above | Provide trusted, consistent numbers to the other two groups | Metric definitions, data refresh, ad-hoc analysis | One agreed definition per KPI, reproducible numbers, data that can be exported for deeper analysis |

**Stakeholder priority:** Coaching staff (P1) → Front office (P1) → Analytics team (P2, internal user).

---

## 2. User stories

Format: *As a [role], I want [capability], so that [business value].*
Priority uses MoSCoW: **M** = Must, **S** = Should, **C** = Could.

### 2.1 Coaching staff

| ID | User story | KPIs used | Priority |
|---|---|---|---|
| US-01 | As a **coach**, I want to see how my team's net rating changes on back-to-backs, so I can plan rest days. | NetRtg, B2B Δ NetRtg, Rest Days | M |
| US-02 | As a **coach**, I want to compare my team's performance at home and on the road, so I can adjust preparation for road trips. | NetRtg, Win%, Home/Away Δ | M |
| US-03 | As a **coach**, I want to see which players are in good or bad form over their last 10 games, so I can adjust minutes and rotations. | Rolling Game Score, Rolling TS% | M |
| US-04 | As a **coach**, I want to see how our pace and efficiency change against fast versus slow opponents, so I can choose a game plan. | Pace, ORtg, DRtg | S |
| US-05 | As a **player-development coach**, I want to track a player's shooting efficiency over the season, so I can measure whether training changes are working. | TS%, eFG%, FTr | S |

### 2.2 Front office

| ID | User story | KPIs used | Priority |
|---|---|---|---|
| US-06 | As a **GM**, I want to compare a player's efficiency and usage with league players at the same position, so I can judge whether a contract or trade is good value. | TS%, USG%, Game Score, Percentile Rank | M |
| US-07 | As a **GM**, I want to see our team's ranking on the Four Factors against the league, so I can identify which roster weakness to fix first. | eFG%, TOV%, ORB%, FTr, League Rank | M |
| US-08 | As an **assistant GM**, I want to see the team's net rating trend month by month, so I can report whether the team is improving to ownership. | NetRtg (monthly), Win% | S |

### 2.3 Analytics team

| ID | User story | KPIs used | Priority |
|---|---|---|---|
| US-09 | As an **analyst**, I want every KPI to have one documented formula, so that all stakeholders see the same numbers. | All | M |
| US-10 | As an **analyst**, I want to export the filtered data to CSV, so I can do ad-hoc analysis outside the dashboard. | All | S |
| US-11 | As an **analyst**, I want to know when the data was last updated, so I can tell stakeholders how current the numbers are. | — | S |
| US-12 | As an **analyst**, I want to see players' minutes load over the last 7 days, so I can flag fatigue risk to the coaching staff. | Minutes (7-day sum) | C |

---

## 3. KPI definitions

### 3.1 Base variables

| Symbol | Meaning |
|---|---|
| PTS, FGM, FGA, 3PM, FTM, FTA | Points, field goals made/attempted, three-pointers made, free throws made/attempted |
| ORB, DRB, AST, STL, BLK, TOV, PF | Offensive/defensive rebounds, assists, steals, blocks, turnovers, personal fouls |
| MIN | Minutes played (team total = 240 for a regulation game, 5 players × 48) |
| Opp_ | Same stat for the opponent in that game |
| Tm_ | Same stat for the player's team in that game |

### 3.2 Team KPIs

| KPI | Formula | Unit | Notes |
|---|---|---|---|
| **Possessions (Poss)** | `FGA + 0.44 × FTA − ORB + TOV` | count | Estimate. In `team_game_base`, `poss` is the average of team and opponent possessions, so both teams in a game share the same number. ORtg, DRtg and Pace all use this value. |
| **Offensive Rating (ORtg)** | `100 × PTS / Poss` | pts / 100 poss | Points scored per 100 possessions |
| **Defensive Rating (DRtg)** | `100 × Opp_PTS / Poss` | pts / 100 poss | Points allowed per 100 possessions. Lower is better. |
| **Net Rating (NetRtg)** | `ORtg − DRtg` | pts / 100 poss | Main measure of team strength |
| **Pace** | `48 × (Poss + Opp_Poss) / (2 × (Tm_MIN / 5))` | poss / 48 min | Adjusts for overtime. In SQL, `poss` already equals (Poss + Opp_Poss) / 2, so this is written as `48 × poss / (min / 5)`. |
| **Win%** | `Wins / Games` | % | |
| **Expected Win% (Pythagorean)** | `PTS^14 / (PTS^14 + Opp_PTS^14)` | % | The win % a team "should" have based on season points scored and allowed. Written in SQL as `1 / (1 + (Opp_PTS / PTS)^14)` (same result, avoids huge numbers). |
| **Win% vs Expected** | `Win% − Expected Win%` | % | Positive = winning more than the points suggest (clutch or lucky), negative = less. Answers "Which teams win more (or less) than their stats suggest?" |
| **Effective FG% (eFG%)** | `(FGM + 0.5 × 3PM) / FGA` | % | Four Factors: shooting |
| **Turnover % (TOV%)** | `TOV / (FGA + 0.44 × FTA + TOV)` | % | Four Factors: ball security. Lower is better. |
| **Offensive Rebound % (ORB%)** | `ORB / (ORB + Opp_DRB)` | % | Four Factors: rebounding |
| **Free Throw Rate (FTr)** | `FTA / FGA` | ratio | Four Factors: getting to the line |
| **Rest Days** | `Game date − previous game date − 1` | days | 0 = back-to-back. First game of the season = excluded. |
| **Back-to-back (B2B) flag** | `Rest Days = 0` | boolean | |
| **B2B Δ NetRtg** | `NetRtg(B2B games) − NetRtg(games with Rest Days ≥ 1)` | pts / 100 poss | Negative = team plays worse when tired. Calculated from summed possessions and points, not an average of game ratings. |
| **Home/Away Δ NetRtg** | `NetRtg(home) − NetRtg(away)` | pts / 100 poss | |
| **League Rank** | Rank of a KPI among the 30 teams for the selected season | 1–30 | 1 = best (for DRtg and TOV%, lowest is best) |

### 3.3 Player KPIs

| KPI | Formula | Unit | Notes |
|---|---|---|---|
| **True Shooting % (TS%)** | `PTS / (2 × (FGA + 0.44 × FTA))` | % | Shooting efficiency including 3s and free throws |
| **eFG%** | `(FGM + 0.5 × 3PM) / FGA` | % | |
| **Usage % (USG%)** | `100 × (FGA + 0.44 × FTA + TOV) × (Tm_MIN / 5) / (MIN × (Tm_FGA + 0.44 × Tm_FTA + Tm_TOV))` | % | Share of team possessions a player uses while on court |
| **Game Score** | `PTS + 0.4 × FGM − 0.7 × FGA − 0.4 × (FTA − FTM) + 0.7 × ORB + 0.3 × DRB + STL + 0.7 × AST + 0.7 × BLK − 0.4 × PF − TOV` | score | Hollinger's single-game productivity score. About 10 = average, 40+ = outstanding. |
| **Rolling form** | 10-game rolling mean of Game Score (and TS%) over the player's most recent games played | score / % | Only players with ≥ 10 games played in the selected season. Games with 0 minutes are excluded. |
| **Form trend** | `Rolling Game Score (last 10) − Season average Game Score` | score | Positive = in form, negative = out of form |
| **Percentile Rank** | Player's percentile for a KPI among players at the same position with ≥ 20 games and ≥ 15 MPG | 0–100 | |
| **Minutes load (7-day)** | Sum of MIN in the last 7 calendar days | minutes | |

### 3.4 Calculation rules

1. **Aggregate, then calculate.** Season or split values for rating and percentage KPIs are computed from summed totals (for example total PTS / total Poss), not by averaging per-game values.
2. **Division by zero** returns empty (NULL), never 0.
3. Percentages are stored as decimals (0.567) and displayed with one decimal place (56.7%).
4. Ratings are displayed with one decimal place.

---

## 4. Acceptance criteria

### 4.1 Functional

| ID | Story | Acceptance criteria |
|---|---|---|
| AC-01 | US-01 | **Given** a team and season are selected, **when** the user opens the Rest & Fatigue view, **then** it shows NetRtg for B2B games, NetRtg for games with ≥ 1 rest day, the B2B Δ NetRtg and the number of games in each group. |
| AC-02 | US-01 | The first game of each season is not counted as a back-to-back. |
| AC-03 | US-02 | Home and away NetRtg and Win% are shown side by side with the difference highlighted. |
| AC-04 | US-03 | Rolling form only includes players with **≥ 10 games** played in the selected season; players below this threshold are hidden and not shown as 0. |
| AC-05 | US-03 | Players are sorted by Form trend, and the user can see the top 5 and bottom 5 for the selected team. |
| AC-06 | US-04 | Opponents are split into "fast" (top 10 Pace) and "slow" (bottom 10 Pace), and the team's ORtg and DRtg are shown for each group. |
| AC-07 | US-05 | A line chart shows a player's TS% and eFG% by game with a 10-game rolling line. |
| AC-08 | US-06 | The comparison view shows a player's TS%, USG% and Game Score with percentile ranks against same-position peers (≥ 20 games, ≥ 15 MPG). |
| AC-09 | US-07 | The Four Factors table shows the team's value and league rank (1–30) for eFG%, TOV%, ORB% and FTr. |
| AC-10 | US-08 | A monthly NetRtg trend chart covers every month of the selected season with games. |
| AC-11 | All | The dashboard can be filtered by **team**, **season** and **date range**; all charts and tables update together. |
| AC-12 | US-10 | The user can download the currently filtered table as a CSV file. |
| AC-13 | US-11 | The dashboard shows a "Data last updated" timestamp. |

### 4.2 Data quality

| ID | Acceptance criteria |
|---|---|
| DQ-01 | Every game appears exactly once per team (no duplicate game IDs per team). |
| DQ-02 | Team totals for PTS in each game match the sum of that team's player PTS. |
| DQ-03 | Calculated season ORtg, DRtg and Pace for 3 randomly chosen teams are within ± 1.0 of the values on NBA.com/stats. |
| DQ-04 | No KPI shows a value outside its valid range (for example percentages between 0 and 1). |
| DQ-05 | Every KPI in Section 3 has an automated test with a hand-calculated example. |

### 4.3 Non-functional

| ID | Acceptance criteria |
|---|---|
| NF-01 | The dashboard loads in under 3 seconds for a single team-season. |
| NF-02 | Data can be refreshed with one command, and re-running it does not create duplicates. |
| NF-03 | The README explains how to install, refresh the data and run the dashboard. |

---

## 5. Traceability

| Stakeholder | User stories | Acceptance criteria |
|---|---|---|
| Coaching staff | US-01 – US-05 | AC-01 – AC-07, AC-11 |
| Front office | US-06 – US-08 | AC-08 – AC-11 |
| Analytics team | US-09 – US-12 | AC-12, AC-13, DQ-01 – DQ-05, NF-01 – NF-03 |

## 6. Assumptions and open questions

- **Assumption:** Box-score data from `nba_api` is complete for the selected seasons.
- **Assumption:** Player position comes from the player's listed roster position (G / F / C).
- **Open question:** Should clutch performance (last 5 minutes, margin ≤ 5) be added in v2 using play-by-play data?
- **Open question:** Should the B2B analysis also separate "second game of B2B on the road" from "at home"?
