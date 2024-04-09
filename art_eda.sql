/*
Paintings Exploratory Data Analysis with Postgres.

Skills used: Joins, Subqueries, Regular Expressions (Regex), Common Table Expressions (CTE), CTID, Window and Aggregate Functions.

*/


-- Shows table names: artist, canvas_size, subject, museum, image_link, museum_hours, work, product_size.

SELECT table_name FROM information_schema.tables WHERE table_schema = 'public';

/*
Fetches all the paintings not displayed in any museum.
Total: 10,223 paintings.

*/

SELECT name
FROM work
WHERE museum_id IS NULL;


/*
Returns museums without any paintings.
There are no museums without paintings.

*/
	
SELECT SUM(w.work_id)
FROM museum AS m
JOIN work AS w
	ON m.museum_id = w.museum_id
GROUP BY m.museum_id
HAVING SUM(w.work_id) = 0;

/*
Shows paintings with an asking price higher than its regular price.
Total = 0 paintings.

*/

SELECT *
FROM product_size
WHERE sale_price > regular_price;

-- Apparently, all the paintings where sold either lower than or equal to their regular price.
-- To double-check this affirmation, I used the queries found below.

SELECT *
FROM product_size
WHERE sale_price < regular_price;

SELECT *
FROM product_size
WHERE sale_price = regular_price;

/*
Identifies the paintings whose asking price is less than 50% of its regular price.
Total = 58 paintings.

*/

SELECT *
FROM product_size
WHERE sale_price < regular_price / 2;

/*
Selects the most expensive canva size.
48" x 96"(122 cm x 244 cm)
*/

SELECT
	c.label AS size,
	sale_price AS price,
	RANK() OVER (ORDER BY p.sale_price DESC) AS rank
FROM product_size AS p
JOIN canvas_size AS c
	ON p.size_id = c.size_id::text
LIMIT 1;

/*
Deletes duplicate records from the work, product_size, subject and image_link tables.
I used the ctid to delete rows using their physical location

*/

DELETE FROM work 
	WHERE ctid NOT IN (SELECT MIN(ctid)
						FROM work
						GROUP BY work_id );

DELETE FROM product_size 
	WHERE ctid NOT IN (SELECT MIN(ctid)
						FROM product_size
						GROUP BY work_id, size_id);				

DELETE FROM image_link 
	WHERE ctid NOT IN (SELECT MIN(ctid)
						FROM image_link
						GROUP BY work_id );

/*
Shows the museums with invalid city information.
Out of the 57 museums, 6 have digits as the name of the city.

*/

SELECT name, city
FROM museum
WHERE city ~ '^[0-9]';

/*
I noticed that the museum_hours table has 1 invalid entry. This query identifies it and removes it.
*/
DELETE FROM museum_hours 
WHERE ctid NOT IN (SELECT MIN(ctid)
					FROM museum_hours
					GROUP BY museum_id, day);

/*
Fetches the top 10 most famous painting subject.
1. Portraits, 2. Nude, 3. Landscape Art, 4. Rivers/Lakes, 5. Abstract/Modern Art,
6. Flowers, 7. Still-Life, 8. Seascapes, 9. Marine Art/Maritime, 10. Horses

*/

SELECT 
	subject,
	RANK() OVER (ORDER BY COUNT(subject) DESC) AS rank,
	COUNT(subject) AS total_paintings
FROM subject
GROUP BY subject
LIMIT 10;

/*
10) Identifies the museums open on both Sunday and Monday. Displays the museum name and the city.
There are 28 museums open on both days.

*/

SELECT
	m.name as museum_name,
	m.city,
	m.country
FROM museum_hours AS mh
JOIN museum AS m
	ON m.museum_id = mh.museum_id
WHERE mh.day = 'Sunday'
	AND EXISTS (
				SELECT 1
				FROM museum_hours AS mh2
				WHERE mh2.museum_id = mh.museum_id
				AND mh2.day = 'Monday'
				);

/*
Counts the amount of museums open every day.
17 museums are open every day.

*/


SELECT COUNT(museum_id) AS total_museums
FROM (
		SELECT 
			museum_id,
			COUNT(day) AS days_open
		FROM museum_hours
		GROUP BY museum_id
		HAVING COUNT(day) = 7
	) AS museums;

/*
Returns the 5 museums with the highest amount of paintings.
1. The Metropolitan Museum of Art in New York
2. Rijksmuseum in Amsterdam
3. National Gallery in London
4. National Gallery of Art in Washintong
5. The Barnes Foundation in Philadelphia

*/

SELECT
	m.name,
	m.city,
	m.country,
	COUNT(w.work_id) AS total_paintings
FROM work AS w
JOIN museum AS m
	ON m.museum_id = w.museum_id
GROUP BY m.name, m.city, m.country
ORDER BY COUNT(w.work_id) DESC
LIMIT 5;

/*
Fetches the top 5 artists with the most number of paintings.
1. Pierre-August Renoir
2. Claude Monet
3. Vincent Van Gogh
4. Maurice Utrillo
5. Albert Marquet

*/

SELECT
	a.full_name,
	a.nationality,
	COUNT(w.work_id) AS total_paintings
FROM work AS w
JOIN artist AS a
	ON a.artist_id = w.artist_id
GROUP BY a.full_name, a.nationality
ORDER BY COUNT(w.work_id) DESC
LIMIT 5;

/*
Displays the 3 least popular canva sizes.
1. 8 canva sizes tied in the first position
2. 2 canva sizes tied in the second position
3. 56" Long Edge.

*/

SELECT label, total_paintings, rank
FROM (
		SELECT
			c.label,
			COUNT(w.work_id) AS total_paintings,
			DENSE_RANK() OVER (ORDER BY COUNT(w.work_id) ASC) AS rank
		FROM work AS w
			JOIN product_size AS p
				ON p.work_id = w.work_id::text
			JOIN canvas_size AS c
				ON c.size_id::text = p.size_id
		GROUP BY c.label
		) ranking
WHERE rank IN (1, 2, 3);


/*
Shows the museum open for the longest during a day. It displays: museum name, state and hours open and which day.
Musée du Louvre in Paris, which stays open for 12 hours 45 minutes on Fridays.

*/
	
SELECT
	museum,
	state,
	day,
	open,
	close,
	duration
FROM (SELECT m.name AS museum,
			 m.state,
			 day,
			 open,
			 close,
			 TO_TIMESTAMP(open, 'HH:MI AM') AS open_tstp,
			 TO_TIMESTAMP(close, 'HH:MI PM') AS close_tstp,
			 TO_TIMESTAMP(close, 'HH:MI PM') - to_timestamp(open, 'HH:MI AM') AS duration,
			 RANK() OVER (ORDER BY TO_TIMESTAMP(close, 'HH:MI PM') - to_timestamp(open, 'HH:MI AM') DESC) AS rank
		FROM museum_hours AS mh
		JOIN museum AS m
			ON m.museum_id = mh.museum_id) AS tstp
WHERE tstp.rank = 1;

/*
Selects the museum with the highest amount of the most popular painting style.
The Metropolitan Museum of Art has 244 paintings of Impressionism.

*/

SELECT 
	DISTINCT w.style,
	COUNT (w.work_id) OVER (PARTITION BY w.style) AS total_paintings
FROM work AS w
WHERE w.style IS NOT NULL
ORDER BY total_paintings DESC;

-- Most popular painting style is Impressionism with 3,078 paintings

SELECT 
	name,
	style,
	total_paintings,
	RANK() OVER (ORDER BY COUNT (total_paintings) DESC) AS rank
FROM (
	SELECT
		m.name,
		w.style,
		COUNT (w.work_id) OVER (PARTITION BY w.style, m.name) AS total_paintings
	FROM work AS w
	JOIN museum AS m
		ON m.museum_id = w.museum_id
	WHERE w.style IS NOT NULL) AS wdw
GROUP BY wdw.name, wdw.style, wdw.total_paintings
LIMIT 1;

/*
Identifies the artists whose paintings are displayed in multiple countries.
Total artists: 194

*/
		
SELECT 
full_name AS artist,
COUNT(country) AS countries
FROM (
		SELECT
			DISTINCT(a.full_name),
			m.country
		FROM artist AS a
			JOIN work AS w
				ON w.artist_id = a.artist_id
			JOIN museum AS m
				ON m.museum_id = w.museum_id
	  ) AS x
GROUP BY full_name
HAVING COUNT(country) > 1
ORDER BY countries DESC;
		

/*
Displays the country and the city with the most number of museums.
Output 2 seperate columns to mention the city and country. If there are multiple value, seperate them with comma.
*/

SELECT * FROM museum AS m;

WITH 
	cte_country AS (
				SELECT
					country,
					COUNT(museum_id) AS count,
					RANK() OVER (ORDER BY COUNT(museum_id) DESC) AS rank
				FROM museum
				GROUP BY country
				),
	cte_city AS    (
				SELECT
					city,
					COUNT(museum_id) AS count,
					RANK() OVER (ORDER BY COUNT(museum_id) DESC) AS rank
				FROM museum
				GROUP BY city
				)
SELECT
	STRING_AGG(DISTINCT country.country,', ') AS top_country,
	STRING_AGG(city.city,', ') AS top_cities
FROM cte_country AS country
	CROSS JOIN cte_city AS city
WHERE country.rank = 1
	AND city.rank = 1;


/*
Identifies the artist and the museum with the most expensive and the least expensive paintings.
Least expensive: A tie
1. Portrait of Madame Labille-Guyard and Her Pupils by Adélaïde Labille-Guiard (30" Long Edge) at The Met in New York, with a price of $10.00
2. Portrait of Madame Labille-Guyard and Her Pupils by Adélaïde Labille-Guiard (36" Long Edge) at The Met in New York, with a price of $10.00

Most expensive: Fortuna by Peter Paul Rubens (48" x 96"), displayed in The Prado Museum in Madrid, with a price of $1,115.00

*/

SELECT 
	artist,
	price,
	painting,
	museum,
	city,
	label
	FROM (
			SELECT
				a.full_name AS artist,
				p.sale_price AS price,
				RANK() OVER (ORDER BY (p.sale_price)) AS rank_asc,
				RANK() OVER (ORDER BY (p.sale_price) DESC) AS rank_des,
				w.name AS painting,
				m.name AS museum,
				m.city,
				c.label
			FROM work AS w
				JOIN artist AS a
					ON a.artist_id = w.artist_id
				JOIN product_size AS p
					ON p.work_id = w.work_id::text
				JOIN museum AS m
					ON m.museum_id = w.museum_id
				JOIN canvas_size AS c
					ON p.size_id = c.size_id::text
			GROUP BY a.full_name, p.sale_price, w.name, m.name, m.city, c.label
		) AS rank
	WHERE rank_asc = 1 OR rank_des = 1;

/*
Fetches the country with the 5th highest number of paintings.
Spain with 196 paintings.

*/


SELECT country, total_paintings
FROM
	(SELECT 
		m.country,
		COUNT(w.work_id) AS total_paintings,
		RANK() OVER (ORDER BY COUNT(w.work_id) DESC) AS RANK
	FROM work AS w
		JOIN museum AS m
			ON m.museum_id = w.museum_id
	GROUP BY m.country) AS paintings
WHERE rank = 5;


/*
Returns the 3 most popular and the 3 least popular painting styles.
Most popular: Impressionism, Post-Impressionism and Realism.
Least popular: Avant-Garde, Art Nouveau and Japanese Art.

*/


SELECT
	rank,
	style,
	CASE 
		WHEN rank IN (1, 2, 3) THEN 'Most popular'
		WHEN rank IN (21, 22, 23) THEN 'Least popular'
	END AS popularity
FROM (
	SELECT 
		style,
		COUNT(*) AS total_paintings,
		RANK() OVER (ORDER BY COUNT(*) DESC) AS rank
	FROM work
	WHERE style IS NOT NULL
	GROUP BY style
	) AS rank
WHERE rank IN (1, 2, 3, 21, 22, 23);


/*
The following queries find the artist with the most number of 'Portraits' paintings outside USA.
Jan Willem Pieneman and Vicent Van Gogh are tied with 14 portraits.

*/

-- First, I glanced at each of the following tables to find relevant information to answer the question.

SELECT *
FROM artist AS a; -- Relevant columns: a.full_name, a.nationality, a.artist_id

SELECT *
FROM work AS w; -- Relevant columns: w.work_id, w.artist_id, w.museum_id

SELECT *
FROM museum AS m; -- Relevant columns: m.country, m.museum_id

SELECT *
FROM subject AS s
WHERE subject = 'Portraits'; -- Relevant columns: s.subject, s.work_id

/*
Then, I performed 3 JOINS and a RANK() function to see what the highest amount of portraits displayed outside of the U.S. done by a single artist is.
It is then when I realized two artists where tied on the first place, with a total of 14 portraits.

*/

SELECT 
	a.full_name,
	a.nationality,
	COUNT(w.work_id) AS total_portraits,
	RANK () OVER (ORDER BY COUNT(w.work_id) DESC) AS rank
FROM work AS w
	JOIN artist AS a
		ON a.artist_id = w.artist_id
	JOIN subject AS s
		ON s.work_id = w.work_id::text
	JOIN museum AS m
		ON m.museum_id = w.museum_id
WHERE s.subject = 'Portraits' AND m.country != 'USA'
GROUP BY a.full_name, a.nationality;

/* Then, I performed a subquery to retrieve the data I was interested on.
Jan Willem Pieneman and Vicent Van Gogh, both Dutch, are tied in the 1st position with a total of 14 portraits.

*/

SELECT full_name, nationality, total_portraits, rank
FROM (
		SELECT 
			a.full_name,
			a.nationality,
			COUNT(w.work_id) AS total_portraits,
			RANK () OVER (ORDER BY COUNT(w.work_id) DESC) AS rank
		FROM work AS w
			JOIN artist AS a
				ON a.artist_id = w.artist_id
			JOIN subject AS s
				ON s.work_id = w.work_id::text
			JOIN museum AS m
				ON m.museum_id = w.museum_id
		WHERE s.subject = 'Portraits' AND m.country != 'USA'
		GROUP BY a.full_name, a.nationality
	) portraits
WHERE rank = 1;
