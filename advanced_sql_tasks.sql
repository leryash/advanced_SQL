---Кол-во вопросов, набравших больше 300 очков
---добавлены в закладки минимум 100 раз
SELECT COUNT(id) 
FROM stackoverflow.posts 
WHERE post_type_id = 1
   AND (score > 300
   OR favorites_count >= 100);

---Сколько вопросов в день задавали с 1 по 18 число
WITH avg_per_day AS (
    SELECT creation_date::date AS by_day,
           COUNT(id) AS cnt_days
    FROM stackoverflow.posts
    WHERE post_type_id = 1
      AND (creation_date::date BETWEEN '2008-11-01' AND '2008-11-18')
    GROUP BY by_day
)
SELECT ROUND(AVG(cnt_days))
FROM avg_per_day;

---Сколько пользователей получили значки в день регистрации
SELECT COUNT(DISTINCT u.id) AS cnt_users
FROM stackoverflow.users AS u
JOIN stackoverflow.badges AS b ON u.id = b.user_id
WHERE u.creation_date::date = b.creation_date::date;

---Сколько уникальных постов пользователя получили минимум 1 голос
SELECT COUNT(DISTINCT p.id)
FROM stackoverflow.users AS u
JOIN stackoverflow.posts AS p ON u.id = p.user_id
JOIN stackoverflow.votes AS v ON p.id = v.post_id
WHERE u.display_name = 'Joel Coehoorn'
HAVING COUNT(v.id) >= 1;

---Добавим поле rank с номерами записей в обратном порядке
SELECT *,
       ROW_NUMBER() OVER(ORDER BY id DESC) AS rank
FROM stackoverflow.vote_types
ORDER BY id;

---10 пользователей, которые поставили больше всего голосов типа close
SELECT u.id,
       COUNT(vt.id) AS cnt_votes
FROM stackoverflow.users AS u
JOIN stackoverflow.votes AS v ON u.id = v.user_id
JOIN stackoverflow.vote_types AS vt ON v.vote_type_id = vt.id
WHERE vt.name = 'Close'
GROUP BY u.id
ORDER BY cnt_votes DESC
LIMIT 10;

---10 пользователей отобранных по кол-ву значков, полученных с 15.11 по 15.12
SELECT u.id,
       COUNT(b.id),
       DENSE_RANK()OVER(ORDER BY COUNT(b.id) DESC) dence
FROM stackoverflow.badges b
JOIN stackoverflow.users u ON b.user_id = u.id
WHERE DATE_TRUNC('day', b.creation_date) BETWEEN '2008-11-15' AND '2008-12-15'
GROUP BY u.id
ORDER BY COUNT(b.id) DESC, u.id
LIMIT 10;

---Среднее кол-во очков, которые получает пост каждого пользователя
SELECT p.title,
       u.id,
       p.score,
       ROUND(AVG(p.score) OVER (PARTITION BY u.id)) AS cnt_score
    FROM stackoverflow.posts AS p
    JOIN stackoverflow.users AS u ON p.user_id = u.id
    WHERE score != 0 AND title IS NOT NULL;

---Заголовки постов пользователей, получивших более 1000 значков
SELECT p.title
FROM stackoverflow.posts AS p
JOIN stackoverflow.users AS u ON p.user_id = u.id
JOIN stackoverflow.badges AS b ON u.id = b.user_id
GROUP BY p.title
HAVING COUNT(p.id) > 1000 AND p.title IS NOT NULL;

---Данные пользователей из Канады по категориям
SELECT id,
       views,
       CASE
           WHEN views >= 350 THEN 1
           WHEN views >= 100 THEN 2
           ELSE 3
       END AS view_group
FROM stackoverflow.users AS u 
WHERE location LIKE '%Canada%' AND views > 0;

---Лидеры каждой группы пользователей, набравших макс число просмотров в своей группе
SELECT id,
       group_number,
       views
FROM (SELECT *,
             MAX(views) OVER (PARTITION BY group_number) AS max_value
      FROM (SELECT id,
                   views,
                   CASE 
                       WHEN views >= 350 THEN 1
                       WHEN views >= 100 THEN 2
                       ELSE 3
                   END AS group_number
            FROM stackoverflow.users AS u 
            WHERE location LIKE '%Canada%' AND views > 0) AS a) AS foo
WHERE max_value = views
ORDER BY views DESC, id;

---Ежедневный прирост новых пользователей в ноябре 2008
SELECT EXTRACT(DAY FROM CAST(creation_date AS date)) AS n_day,
       COUNT(id),
       SUM(COUNT(id)) OVER(ORDER BY EXTRACT(DAY FROM CAST(creation_date AS date)))
FROM stackoverflow.users
WHERE DATE_TRUNC('day', creation_date) BETWEEN '2008-11-1' AND '2008-11-30'
GROUP BY n_day;

---Интервал между регистрацией и временем создания первого поста для пользователей,
--- которые написали хотя бы 1 пост
WITH raw AS (SELECT user_id,
                    p.creation_date AS frst,
                    ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY p.creation_date) AS number_temp,
                    u.creation_date AS reg 
             FROM stackoverflow.posts AS p JOIN stackoverflow.users AS u ON p.user_id = u.id 
             ORDER BY user_id)
SELECT user_id,
       frst - reg
FROM raw
WHERE number_temp = 1;

---Общая сумма просмотров у постов, опубликованных в каждый месяц 2008г
SELECT DATE_TRUNC('month', creation_date)::date AS month_date,
       SUM(views_count) AS total_views
FROM stackoverflow.posts 
GROUP BY month_date
ORDER BY total_views DESC;

---Имена самых активных пользователей, давших более 100 ответов в первый месяц
SELECT u.display_name,
       COUNT(DISTINCT p.user_id)
FROM stackoverflow.users AS u
LEFT JOIN stackoverflow.posts AS p ON u.id = p.user_id
WHERE p.post_type_id = 2
AND p.creation_date BETWEEN u.creation_date::date AND u.creation_date::date + INTERVAL '1 month 1 day'
GROUP BY u.display_name
HAVING COUNT(p.id) > 100 
ORDER BY u.display_name; 

---Кол-во постов за 2008г по месяцам. 
---Посты пользователей зарегестрированных в сентябре и сделавших пост в декабре
WITH  september_users AS (
        SELECT distinct u.id
        FROM stackoverflow.users AS u
        WHERE EXTRACT(MONTH FROM CAST(u.creation_date AS date)) = '9'
),    current_users AS (
        SELECT distinct su.id
        FROM stackoverflow.posts AS p
        JOIN september_users AS su ON p.user_id = su.id
        WHERE 
          EXTRACT(MONTH FROM CAST(p.creation_date AS date)) = '12'
        GROUP BY su.id
)
SELECT 
       CAST(DATE_TRUNC('month', CAST(p.creation_date AS timestamp)) AS date) AS creation_month,
       COUNT(p.id)
FROM current_users AS cu 
JOIN stackoverflow.posts AS p ON cu.id = p.user_id
GROUP BY creation_month
ORDER BY creation_month DESC;

---Поля из данных о постах
SELECT p.user_id,
       p.creation_date,
       p.views_count,
       SUM(views_count) OVER(PARTITION BY p.user_id ORDER BY p.creation_date)
FROM stackoverflow.posts AS p
ORDER BY p.user_id, p.creation_date;

---Сколько в среднем взаимодействовали с платформой с 1 по 7 декабря 2008г
WITH users_use_pl AS(
    SELECT p.user_id,
           COUNT(u.last_access_date) AS cnt_use_pl
    FROM stackoverflow.users AS u
    JOIN stackoverflow.posts AS p ON u.id=p.user_id
    WHERE u.last_access_date BETWEEN '2008-12-01' AND '2008-12-08'
    GROUP BY p.user_id
)
SELECT ROUND(AVG(cnt_use_pl))
FROM users_use_pl;

---На сколько поменялось кол-во постов с 1 сентября по 31 декабря 2008г
WITH count_posts AS (
    SELECT EXTRACT(MONTH FROM CAST(p.creation_date AS date)) AS number_month,
           COUNT(p.id),
       ROUND(((COUNT(p.id))::numeric / LAG(COUNT(p.id))OVER (ORDER BY EXTRACT(MONTH FROM CAST(p.creation_date AS date)))*100) - 100, 2)
    FROM stackoverflow.posts AS p
    WHERE p.creation_date::date BETWEEN '2008-09-01' AND '2009-01-01'
    GROUP BY number_month
)
SELECT * 
FROM count_posts;

---Пользователь, опубликовавший больше всего постов за все время
WITH sq AS (SELECT DISTINCT ps.user_id AS user_id,
                   COUNT(ps.id) AS cnt_pst
            FROM stackoverflow.posts AS ps
            GROUP BY user_id
            ORDER BY cnt_pst DESC
            LIMIT 1)
 
SELECT DISTINCT EXTRACT(WEEK FROM ps.creation_date) AS wk,
       MAX(ps.creation_date) OVER(ORDER BY EXTRACT(WEEK FROM ps.creation_date)) AS lst_pst_dt
FROM stackoverflow.posts AS ps
RIGHT JOIN sq AS sq ON ps.user_id = sq.user_id
WHERE ps.creation_date::DATE BETWEEN '2008-10-01' AND '2008-10-31';