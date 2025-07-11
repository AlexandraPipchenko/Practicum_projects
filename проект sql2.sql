--Задача 1
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
regions as (
    SELECT *, case 
       	when city = 'Санкт-Петербург'
       	then 'СПБ'
       	else 'ЛенОбл'
       end as region,
       case 
       	when days_exposition <=30
       	then 'до месяца'
       	when days_exposition >= 31 and days_exposition <=90
       	then 'до трех месяцев'
       	when days_exposition >=91 and days_exposition <=180
       	then 'до полугода'
       	when days_exposition >=181
       	then 'более полугода'
       	when days_exposition is null
       	then 'не продано'
       end as activity     
FROM real_estate.flats
left join real_estate.advertisement using(id)
left join real_estate.city using(city_id)
WHERE id IN (SELECT * FROM filtered_id) 
)
select region, 
       activity, 
       count(id) as count_ad,
       avg(last_price/total_area::real) as avg_price_one_meter,
       avg(total_area) as avg_total_area,
       percentile_disc(0.5) within group(order by rooms) as avg_mediana_rooms,
       percentile_disc(0.5) within group(order by balcony) as avg_mediana_balcony
from regions
where type_id='F8EM'
group by region, activity
order by region desc, count_ad desc

--Задача 2
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
    years_and_months as (
select id, last_price, total_area, type_id, days_exposition, 
       extract(year from first_day_exposition) as years,
       extract(month from first_day_exposition) as months_publishing,
       extract(month from first_day_exposition + interval '1 day' * days_exposition) as months_removing
from real_estate.advertisement
left join real_estate.flats using(id)
WHERE id IN (SELECT * FROM filtered_id) and type_id='F8EM'
),
removing_ads as (
select months_removing,
       rank() over(order by count(id) desc) as rank_removing,
       count(id) as count_removing,
       avg(last_price/total_area::real) as avg_price_removing,
       avg(total_area) as avg_total_area_removing 
from years_and_months 
where days_exposition is not null and type_id='F8EM'
group by months_removing
)
select months_publishing,
       rank() over(order by count(id) desc) as rank_publishing,
       count(id) as count_publishing,
       avg(last_price/total_area::real) as avg_price_publishing,
       avg(total_area) as avg_total_area_publishing,
       ra.months_removing,
       rank_removing,
       count_removing,
       avg_price_removing,
       avg_total_area_removing
from years_and_months
join removing_ads as ra on ra.months_removing=years_and_months.months_publishing
where years in(2015,2016,2017,2018) and type_id='F8EM'
group by months_publishing, ra.months_removing, rank_removing, count_removing,
       avg_price_removing, avg_total_area_removing
order by months_publishing

--Задача 3
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
filtered_id as (
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    )
select city,
       count(a.id) as count_ads,
       count(a.id) filter (where days_exposition is not null) as count_removing_and_sold,
       count(a.id) filter (where days_exposition is not null)/
       count(a.id)::real as share_sold,
       avg(last_price/total_area::real) as avg_price_one_meter,
       avg(total_area) as avg_total_area,
       avg(days_exposition) as avg_days
from real_estate.flats  
left join real_estate.advertisement as a using(id)
left join real_estate.city using(city_id)
where city <> 'Санкт-Петербург' 
group by city
order by count_ads desc, share_sold desc
limit 15
































