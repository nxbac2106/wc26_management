use WorldCup26_db
go

-- FROM/JOIN → WHERE → GROUP BY → HAVING → SELECT → ORDER BY

/* 1. TRUY VẤN VỀ LỊCH THI ĐẤU VÀ SÂN VẬN ĐỘNG VÀ TRỌNG TÀI */

-- 1.1. Hiển thị lịch thi đấu của các trận đấu (ngày, giờ, SVĐ, Vòng đấu, Trọng tài, Đội 1, Đội 2, POM, trạng thái)
select matches_detailed.datee, matches_detailed.kickoff_time_utc, matches_detailed.stadium_name, stadiums.country, tournament_stages.stage_name, 
	case when tournament_stages.stage_name = 'Group Stage' then teams.groupp else null end as groupp, 
	matches_detailed.referee_name , matches_detailed.home_team_name, matches_detailed.home_score, matches_detailed.away_score, matches_detailed.away_team_name, 
	matches_detailed.player_of_the_match_name ,matches_detailed.statuss
from matches
join matches_detailed on matches_detailed.match_id = matches.match_id
join tournament_stages on matches.stage_id = tournament_stages.stage_id
join teams on matches.home_team_id = teams.team_id
join stadiums on matches.stadium_id = stadiums.stadium_id
order by matches.datee asc, matches_detailed.kickoff_time_utc asc;

-- 1.2. Trọng tài vừa điều khiển trận vòng bảng, vừa điều khiển trận vòng loại
select r.referee_id, r.referee_name
from referees r
join matches m on m.referee_id = r.referee_id
join tournament_stages ts on ts.stage_id = m.stage_id
where ts.is_knockout = 1
intersect 
select r.referee_id, r.referee_name
from referees r
join matches m on m.referee_id = r.referee_id
join tournament_stages ts on ts.stage_id = m.stage_id
where ts.is_knockout = 0

-- 1.3. Số thẻ mà trọng tài rút
select referees.referee_name, referees.country, referees.avg_cards_per_match, 
	sum(case when match_events.event_type = 'Yellow Card' then 1 else 0 end) as total_Yellow_cards,
	sum(case when match_events.event_type = 'Red Card' then 1 else 0 end) as total_Red_cards
from matches
join referees on referees.referee_id = matches.referee_id
join match_events on matches.match_id = match_events.match_id
group by referees.referee_name, referees.country, referees.avg_cards_per_match
order by referees.avg_cards_per_match desc


/* 2. TRUY VẤN VỀ CÁC TRẬN ĐẤU  */

-- 2.1 Thống kê các trận có nhiều bàn thắng nhất (lấy 5% tổng số trận đấu - cả những trận có cùng số bàn (with ties))
select top 5 percent with ties matches_detailed.stage_name, matches_detailed.home_team_name, matches_detailed.away_team_name, matches_detailed.home_score, matches_detailed.away_score, max(matches_detailed.home_score + matches_detailed.away_score) as total_goals_match
from matches_detailed
group by matches_detailed.stage_name, matches_detailed.match_id, matches_detailed.home_team_name, matches_detailed.away_team_name, matches_detailed.home_score, matches_detailed.away_score
order by total_goals_match desc

-- 2.2 Thống kê các trận có nhiều thẻ vàng - thẻ đỏ nhất
select match_events.match_id, matches_detailed.home_team_name, matches_detailed.away_team_name, matches_detailed.stage_name , count(match_events.event_type) as total_yellow_cards
from match_events
join matches_detailed on match_events.match_id = matches_detailed.match_id
where match_events.event_type='Yellow Card'
group by match_events.match_id, matches_detailed.home_team_name, matches_detailed.away_team_name, matches_detailed.stage_name
order by total_yellow_cards desc

select match_events.match_id, matches_detailed.home_team_name, matches_detailed.away_team_name, matches_detailed.stage_name, count(match_events.event_type) as total_red_cards
from match_events
join matches_detailed on match_events.match_id = matches_detailed.match_id
where match_events.event_type='Red Card'
group by match_events.match_id, matches_detailed.home_team_name, matches_detailed.away_team_name, matches_detailed.stage_name
order by total_red_cards desc

-- 2.3 Thống kê các trận không có thẻ phạt nào
select d.match_id, d.datee, d.stage_name, d.home_team_name, d.away_team_name
from matches_detailed d
where not exists (select 1
                  from match_events e
                  where e.match_id = d.match_id and e.event_type in ('Yellow Card', 'Red Card'));

/* 3. TRUY VẤN VỀ THÔNG SỐ CÁC ĐỘI  */

-- 3.1. Tổng số bàn thắng, số kiến tạo mà đội ghi được 
select teams.team_name, sum(player_tournament_statistics.goals) as total_goals, sum(player_tournament_statistics.assists) as total_assists
from teams
join player_tournament_statistics on teams.team_id = player_tournament_statistics.team_id
group by team_name
order by total_goals desc, total_assists desc;

-- 3.2. Tổng số thẻ vàng, thẻ đỏ của đội
select teams.team_name, sum(player_tournament_statistics.yellow_cards) as total_yellow_cards, sum(player_tournament_statistics.red_cards) as total_red_cards
from teams
join player_tournament_statistics on teams.team_id = player_tournament_statistics.team_id
group by team_name
having sum(player_tournament_statistics.yellow_cards) > 0 or sum(player_tournament_statistics.red_cards) >0
order by total_yellow_cards desc, total_red_cards desc

-- hoặc
SELECT 
    t.team_name,
    SUM(CASE WHEN me.event_type = 'Yellow Card' THEN 1 ELSE 0 END) AS yellow_cards,
    SUM(CASE WHEN me.event_type = 'Red Card' THEN 1 ELSE 0 END) AS red_cards
FROM teams t
JOIN match_events me ON t.team_id = me.team_id
GROUP BY t.team_name
ORDER BY yellow_cards DESC;

-- 3.3 Tỉ lệ kiểm soát bóng
select teams.team_id, teams.team_name, count(match_team_statistics.match_id) as matches_played, 
	avg(cast(match_team_statistics.possession_pct as decimal(5,2)))   as avg_possession
from teams
join match_team_statistics on teams.team_id = match_team_statistics.team_id
group by teams.team_id, teams.team_name
order by avg_possession desc

-- 3.4 Đội không ghi được bàn nào
select teams.*from teams
except
select teams.* 
from teams 
join match_events on teams.team_id = match_events.team_id
where match_events.event_type like 'Goal'

-- hoặc
with teams_goals_for as
(
	select t.team_id, t.team_name, m.away_score as goals_for
	from matches m
	join teams t on m.away_team_id = t.team_id
	union all
	select t.team_id, t.team_name, m.home_score as goals_for
	from matches m
	join teams t on m.home_team_id = t.team_id
)
select t.team_id, t.team_name, sum(tga.goals_for) as total_goals_for
from teams t 
join teams_goals_for tga on t.team_id = tga.team_id
group by t.team_id, t.team_name
except 
select tga.team_id, tga.team_name, sum(tga.goals_for) as total_goals_for
from teams_goals_for tga
group by tga.team_id, tga.team_name
having sum(tga.goals_for) > 0

/* 4. TRUY VẤN VỀ CẦU THỦ  */
-- 4.1 BXH Vua phá lưới (ghi nhiều bàn thắng nhất, tiêu chí phụ là số kiến tạo)
select top 10 player_tournament_statistics.player_id, player_tournament_statistics.player_name, teams.team_name, 
	player_tournament_statistics.position, player_tournament_statistics.goals, player_tournament_statistics.assists  
from player_tournament_statistics
join teams on player_tournament_statistics.team_id = teams.team_id
order by player_tournament_statistics.goals desc, player_tournament_statistics.assists desc

-- 4.2 Cầu thủ đạt nhiều POM nhất
select top 1 player_tournament_statistics.player_id, player_tournament_statistics.player_name, teams.team_name, player_tournament_statistics.position, player_tournament_statistics.shirt_number, count(matches.player_of_the_match_id) as total_POMs
from player_tournament_statistics
join matches on player_tournament_statistics.player_id = matches.player_of_the_match_id
join teams on player_tournament_statistics.team_id = teams.team_id
group by player_tournament_statistics.player_id, player_tournament_statistics.player_name, teams.team_name, player_tournament_statistics.position, player_tournament_statistics.shirt_number
order by total_POMs desc

-- 4.3 Sắp xếp các cầu thủ có số phút thi đấu nhiều nhất
select player_tournament_statistics.player_name, teams.team_name, player_tournament_statistics.position, player_tournament_statistics.matches_played, player_tournament_statistics.matches_started, player_tournament_statistics.minutes_played, player_tournament_statistics.goals, player_tournament_statistics.assists 
from player_tournament_statistics
join teams on player_tournament_statistics.team_id = teams.team_id
order by minutes_played desc

-- 4.4 Sắp xếp các cầu thủ ghi bàn bằng pen
select player_squads.player_name, teams.team_name, player_squads.position, count(match_events.event_type) as total_pen_goals
from player_squads
join teams on player_squads.team_id = teams.team_id
join match_events on player_squads.player_id = match_events.player_id
where match_events.event_type = 'Penalty Shootout Goal'
group by player_squads.player_name, teams.team_name, player_squads.position
order by total_pen_goals desc
go

