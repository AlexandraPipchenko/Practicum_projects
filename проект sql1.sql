/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Пипченко Александра Сергеевна
 * Дата: 07.01.2025
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:

with total_users as (
     select count(id) as count_users
     from fantasy.users),
paying_users as (
     select count(id) as count_paying_users
     from fantasy.users
     where payer = 1
)
select count_users,
       (select count_paying_users from paying_users),
       (select count_paying_users from paying_users)/count_users::real as share_paying_users
from total_users


-- 1.2. Доля платящих пользователей в разрезе расы персонажа:

with paying_users as (
select race, count(id) as count_paying_users
from fantasy.users
left join fantasy.race using(race_id)
where payer = 1
group by race
),
total_users as (
select race, count(id) as count_users
from fantasy.users
left join fantasy.race using(race_id)
group by race
)
select race,
       count_paying_users,
       count_users,
       count_paying_users/count_users::real as share_paying_race
from total_users
join paying_users using(race)

-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:

select count(transaction_id) as total_events,
sum(amount) as total_amount,
min(amount) as min_amount,
max(amount) as max_amount,
avg(amount) as avg_amount,
percentile_disc(0.5) within group (order by amount) as mediana_amount,
stddev(amount) as stddev_amount
from fantasy.events       
union all
select count(transaction_id) as total_events,
sum(amount) as total_amount,
min(amount) as min_amount,
max(amount) as max_amount,
avg(amount) as avg_amount,
percentile_disc(0.5) within group (order by amount) as mediana_amount,
stddev(amount) as stddev_amount
from fantasy.events 
where amount <> 0


-- 2.2: Аномальные нулевые покупки:

with count_zero_amount as (
select count(amount) as zero_amount
from fantasy.events
where amount = 0
)
select (select zero_amount from count_zero_amount) as count_zero,
(select zero_amount from count_zero_amount)/count(amount)::real as share_zero_amount
from fantasy.events

-- 2.3: Сравнительный анализ активности платящих и неплатящих игроков:

select count(distinct id)
from fantasy.events

select payer,
       count(distinct id) as count_users,
       count(transaction_id)/count(distinct id)::real as avg_event,
       sum(amount)/count(distinct id)::real as avg_total_amount
from fantasy.events as e 
left join fantasy.users as u using (id)
where payer = 1 and amount <> 0
group by payer
union all
select payer,
       count(distinct id) as count_users,
       count(transaction_id)/count(distinct id)::real as avg_event,
       sum(amount)/count(distinct id)::real as total_amount
from fantasy.events as e
left join fantasy.users as u using (id)
where payer = 0 and amount <> 0
group by payer

-- 2.4: Популярные эпические предметы:

with buy_item_code as (
select  item_code, count(distinct id) as users_more_one_buy
from fantasy.events
left join fantasy.users using (id)
where amount <> 0
group by item_code
),
count_events_abs as (
select count(transaction_id) as count_events_item
from fantasy.events 
),
counts_all_users as (
select count(distinct id) as total_users
from fantasy.events
)
select item_code,
       game_items,
       count(transaction_id) as counts_events_items,
       count(transaction_id)/(select count_events_item from count_events_abs)::real as share_count_events,
       users_more_one_buy/(select total_users from counts_all_users)::real as share_one_more_event
from fantasy.events 
left join fantasy.items using(item_code)
left join buy_item_code using(item_code)
group by item_code, game_items, users_more_one_buy
order by counts_events_items desc

-- Часть 2. Решение ad hoc-задач
-- Задача 1. Зависимость активности игроков от расы персонажа:

with paying_users as (
select race_id,
       count(id) as counts_paying_users
from fantasy.users 
where payer = 1 and id IN (SELECT id FROM fantasy.events WHERE amount > 0)
group by race_id
),
counts_all_users as (
select race_id,
       count(u.id) as total_users
from fantasy.users as u    
group by race_id
)
select race_id, race, 
       total_users,
       count(distinct e.id) as counts_users_events,
       count(distinct e.id)/total_users::real as share_users_events,
       max(counts_paying_users)/count(distinct e.id)::real as share_paying_users,
       count(transaction_id)/count(distinct e.id)::real as avg_count_events,
       avg(amount) as avg_amount_oneuser,
       sum(amount)/count(distinct e.id)::real as avg_sum_amount_oneuser
from fantasy.users as u
left join fantasy.race using(race_id)
left join fantasy.events as e using(id)
left join counts_all_users using(race_id)
left join paying_users using(race_id)
where amount<>0
group by race_id, race,  total_users

-- Задача 2: Частота покупок

with cte as (
select id,
       transaction_id,
       date::date - (lag(date) over(partition by id order by date))::date as count_days
from fantasy.events
where amount > 0
),
cte2 as (
select e.id, 
       payer,
       count(transaction_id) as counts_transaction,
       avg(count_days) as avg_days
from cte as e
left join fantasy.users using(id)
group by id, payer
having count(e.transaction_id) >= 25
order by avg_days
),
cte3 as (
select *,
       ntile(3) over (order by avg_days) as rating
from cte2      
),
cte4 as (
select count(distinct id) as counts_paying_users
from fantasy.events
left join fantasy.users using(id)
where payer=1
),
cte5 as (
select *,
case 
	when rating = 1
	then 'высокая частота'
	when rating = 2
	then 'умеренная частота'
	when rating = 3
	then 'низкая частота'
end as frequency_events
from cte3
)
select frequency_events,
       count(id) as counts_users_buyers,
       (select counts_paying_users from cte4) as counts_paying,
       (select counts_paying_users from cte4)/count(id)::real as share_counts_paying,
       avg(counts_transaction) as avg_counts_transaction,
       sum(avg_days)/count(id)::real as avg_counts_days_between
from cte5
group by frequency_events

--не совсем понимаю полученные результаты. во втором столбце количество игроков одинаковое, 
--потому что было выделено 3 группы с равным количеством строк, а почему в 3-4 столбцах одинаковые значения неясно
       








