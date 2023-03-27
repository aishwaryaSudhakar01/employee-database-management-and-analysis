USE dannys_diner;

-- total amount spent by each customer
SELECT
  s.customer_id,
  SUM(m.price) AS total_amount
FROM sales s
  JOIN menu m
    ON s.product_id = m.product_id
GROUP BY s.customer_id
ORDER BY s.customer_id;

-- number of days visited by each customer
SELECT
  customer_id,
  COUNT(DISTINCT order_date) AS visited_days
FROM sales
GROUP BY customer_id
ORDER BY customer_id;

-- first item purchased by each customer
WITH CTE AS (
SELECT
  s.customer_id,
  m.product_name,
  RANK() OVER (PARTITION BY s.customer_id ORDER BY s.order_date) AS row_num
FROM sales s
  JOIN menu m
    ON s.product_id = m.product_id )
    
SELECT
  customer_id,
  product_name
FROM CTE
WHERE row_num = 1;

-- most purchased item and total number of its purchases
SELECT
  m.product_name,
  COUNT(s.product_id) AS order_count
FROM sales s
  JOIN menu m
    ON s.product_id = m.product_id
GROUP BY m.product_name
ORDER BY order_count DESC
LIMIT 1;

-- most popular item for each customer
WITH CTE AS
(SELECT
  s.customer_id,
  m.product_name,
  COUNT(s.product_id) AS order_count
FROM sales s
  JOIN menu m
    ON s.product_id = m.product_id
GROUP BY s.customer_id, m.product_name
ORDER BY order_count DESC),

CTE1 AS (
SELECT
  customer_id,
  product_name,
  order_count,
  RANK() OVER (PARTITION BY customer_id ORDER BY order_count DESC) AS row_num
FROM CTE)

SELECT
  customer_id,
  product_name,
  order_count
FROM CTE1
WHERE row_num = 1;

-- first item purchased after they became a member
WITH CTE AS (
SELECT
  s.customer_id,
  m.product_name,
  s.order_date,
  RANK() OVER (PARTITION BY s.customer_id ORDER BY s.order_date) AS row_num
FROM sales s
  JOIN menu m ON s.product_id = m.product_id
    JOIN members mem ON s.customer_id = mem.customer_id
WHERE s.order_date >= mem.join_date)

SELECT
  customer_id,
  product_name,
  order_date
FROM CTE
WHERE row_num = 1;

-- item purchased just before they became a member
WITH CTE AS (
SELECT
  s.customer_id,
  m.product_name,
  s.order_date,
  RANK() OVER (PARTITION BY s.customer_id ORDER BY s.order_date DESC) AS row_num
FROM sales s
  JOIN menu m ON s.product_id = m.product_id
    JOIN members mem ON s.customer_id = mem.customer_id
WHERE s.order_date < mem.join_date)

SELECT
  customer_id,
  product_name,
  order_date
FROM CTE
WHERE row_num = 1;

-- total items and amount spent by each member before they became a customer
SELECT
  s.customer_id,
  COUNT(s.product_id) AS total_items,
  SUM(m.price) AS total_amount
FROM sales s 
  JOIN members mem ON s.customer_id = mem.customer_id
    JOIN menu m ON s.product_id = m.product_id
WHERE s.order_date < mem.join_date
GROUP BY s.customer_id
ORDER BY s.customer_id;

-- points each customer would have if each $1 spent equates to 10 points and sushi has a 2x points multiplier
SELECT
  s.customer_id,
  SUM(CASE WHEN product_name = 'sushi' THEN (20*price) ELSE (10*price) END) AS total_points    
FROM sales s
  JOIN members mem ON mem.customer_id = s.customer_id
    JOIN menu m ON m.product_id = s.product_id
GROUP BY s.customer_id
ORDER BY s.customer_id;

-- points customer A and B will have at the end of January if in the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi
WITH CTE AS (
   SELECT *, 
      DATE_ADD(join_date, INTERVAL 6 DAY) AS valid_date, 
      DATE_FORMAT(DATE_ADD(LAST_DAY('2021-01-31'), INTERVAL 1 DAY), '%Y-%m-%d') AS last_date
   FROM members )

SELECT
  s.customer_id,
  SUM(CASE 
    WHEN m.product_name = 'sushi' THEN (m.price*20) 
    WHEN s.order_date BETWEEN join_date AND valid_date THEN (m.price*20)
    ELSE (m.price*10) 
    END) AS total_points
FROM CTE c
  JOIN sales s
    ON c.customer_id = s.customer_id
      JOIN menu m
        ON s.product_id = m.product_id
WHERE s.order_date < c.last_date
GROUP BY s.customer_id
ORDER BY total_points DESC;

-- table with all relevent information
SELECT
  s.customer_id,
  s.order_date,
  m.product_name,
  m.price,
  (CASE WHEN s.customer_id = mem.customer_id 
    AND mem.join_date <= s.order_date THEN 'Y' ELSE 'N' END) AS member
FROM sales s
  LEFT JOIN menu m ON s.product_id = m.product_id
    LEFT JOIN members mem ON mem.customer_id = s.customer_id
ORDER BY s.customer_id, s.order_date;

-- ranking of products by members
WITH CTE AS (
SELECT
  s.customer_id,
  s.order_date,
  m.product_name,
  m.price,
  (CASE WHEN s.customer_id = mem.customer_id 
    AND s.order_date >= mem.join_date THEN 'Y' ELSE 'N' END) AS member
FROM sales s
  LEFT JOIN menu m ON s.product_id = m.product_id
    LEFT JOIN members mem ON mem.customer_id = s.customer_id
ORDER BY s.customer_id, s.order_date)

SELECT
  *,
  (CASE WHEN member = 'Y' 
    THEN RANK() OVER (PARTITION BY customer_id, member ORDER BY order_date) 
      ELSE 'null' END) AS ranking
FROM CTE;























