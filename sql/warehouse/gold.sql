-- Gold: dashboard-shaped. Reads silver only.

DROP TABLE IF EXISTS gold.sales_by_style_day;
CREATE TABLE gold.sales_by_style_day AS
SELECT
  o.order_date,
  s.style_id,
  s.name AS style_name,
  b.beer_id,
  b.name AS beer_name,
  SUM(oi.quantity) AS total_units_sold,
  SUM(oi.price * oi.quantity) AS total_sales,
  COUNT(DISTINCT o.customer_id) AS unique_customers
FROM silver.orders o
JOIN silver.order_items oi ON o.order_id = oi.order_id AND oi.is_active = TRUE
JOIN silver.beers b ON oi.beer_id = b.beer_id
JOIN silver.styles s ON b.style_id = s.style_id
WHERE o.is_active = TRUE
  AND b.is_quarantined = FALSE
  AND s.is_quarantined = FALSE
GROUP BY 1, 2, 3, 4, 5;

DROP TABLE IF EXISTS gold.beer_performance;
CREATE TABLE gold.beer_performance AS
SELECT
  b.beer_id,
  b.name AS beer_name,
  s.name AS style_name,
  bd.distributor_id,
  d.distributor_name,
  SUM(oi.quantity) AS total_units_sold,
  SUM(oi.price * oi.quantity) AS total_revenue,
  AVG(oi.price - bd.supply_price) AS avg_margin_per_unit,
  AVG(r.rating) AS avg_rating,
  COUNT(r.review_text) AS total_reviews
FROM silver.beers b
LEFT JOIN silver.styles s ON b.style_id = s.style_id
LEFT JOIN silver.beer_distributors bd
  ON b.beer_id = bd.beer_id AND bd.is_active = TRUE
LEFT JOIN silver.distributors d
  ON bd.distributor_id = d.distributor_id AND d.is_quarantined = FALSE
LEFT JOIN silver.order_items oi
  ON b.beer_id = oi.beer_id AND oi.is_active = TRUE
LEFT JOIN silver.taproom_reviews r
  ON b.beer_id = r.beer_id AND r.is_active = TRUE
WHERE b.is_quarantined = FALSE
GROUP BY 1, 2, 3, 4, 5;

DROP TABLE IF EXISTS gold.customer_engagement;
CREATE TABLE gold.customer_engagement AS
SELECT
  c.customer_id,
  c.name AS customer_name,
  COUNT(DISTINCT o.order_id) AS total_orders,
  COALESCE(SUM(oi.price * oi.quantity), 0) AS total_spent,
  MAX(o.order_date) AS last_order_date
FROM silver.customers c
LEFT JOIN silver.orders o
  ON c.customer_id = o.customer_id AND o.is_active = TRUE
LEFT JOIN silver.order_items oi
  ON o.order_id = oi.order_id AND oi.is_active = TRUE
WHERE c.is_active = TRUE
  AND c.is_quarantined = FALSE
GROUP BY 1, 2;

DROP TABLE IF EXISTS gold.distributor_analysis;
CREATE TABLE gold.distributor_analysis AS
SELECT
  d.distributor_id,
  d.distributor_name,
  COUNT(DISTINCT bd.beer_id) AS beers_supplied,
  COALESCE(SUM(oi.quantity), 0) AS total_units_sold,
  COALESCE(SUM(oi.price * oi.quantity), 0) AS total_revenue
FROM silver.distributors d
LEFT JOIN silver.beer_distributors bd
  ON d.distributor_id = bd.distributor_id AND bd.is_active = TRUE
LEFT JOIN silver.order_items oi
  ON bd.beer_id = oi.beer_id AND oi.is_active = TRUE
WHERE d.is_quarantined = FALSE
GROUP BY 1, 2;

DROP TABLE IF EXISTS gold.reviews_summary;
CREATE TABLE gold.reviews_summary AS
SELECT
  b.beer_id,
  b.name AS beer_name,
  AVG(r.rating) AS avg_rating,
  COUNT(r.review_text) AS total_reviews,
  COUNT(*) FILTER (WHERE r.rating >= 4) AS positive_reviews,
  COUNT(*) FILTER (WHERE r.rating < 3) AS negative_reviews
FROM silver.beers b
LEFT JOIN silver.taproom_reviews r
  ON b.beer_id = r.beer_id AND r.is_active = TRUE
WHERE b.is_quarantined = FALSE
GROUP BY 1, 2;
