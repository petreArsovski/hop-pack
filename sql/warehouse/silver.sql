-- Silver: owned copy inside Postgres (like BigQuery CREATE TABLE, not EXTERNAL).

CREATE TABLE IF NOT EXISTS silver.customers (
  customer_id INT,
  name TEXT,
  email TEXT,
  updated_at TEXT,
  is_quarantined BOOLEAN,
  effective_start_date TIMESTAMP,
  effective_end_date TIMESTAMP,
  is_active BOOLEAN
);

-- MERGE 1: close the current version when bronze changed.
MERGE INTO silver.customers AS target
USING (
  SELECT DISTINCT
    customer_id,
    name,
    email,
    updated_at,
    (customer_id IS NULL OR email IS NULL OR name IS NULL) AS is_quarantined
  FROM bronze.customers
) AS source
ON target.customer_id = source.customer_id AND target.is_active = TRUE
WHEN MATCHED AND (
  target.name IS DISTINCT FROM source.name
  OR target.email IS DISTINCT FROM source.email
  OR target.updated_at IS DISTINCT FROM source.updated_at
) THEN UPDATE SET
  is_active = FALSE,
  effective_end_date = NOW();

-- MERGE 2: insert when there is no active row (new customer or new version).
MERGE INTO silver.customers AS target
USING (
  SELECT DISTINCT
    customer_id,
    name,
    email,
    updated_at,
    (customer_id IS NULL OR email IS NULL OR name IS NULL) AS is_quarantined
  FROM bronze.customers
) AS source
ON target.customer_id = source.customer_id AND target.is_active = TRUE
WHEN NOT MATCHED THEN INSERT (
  customer_id, name, email, updated_at, is_quarantined,
  effective_start_date, effective_end_date, is_active
) VALUES (
  source.customer_id, source.name, source.email, source.updated_at, source.is_quarantined,
  NOW(), NULL, TRUE
);

CREATE TABLE IF NOT EXISTS silver.orders (
  order_id INT,
  customer_id INT,
  order_date TEXT,
  total_amount NUMERIC,
  updated_at TEXT,
  effective_start_date TIMESTAMP,
  effective_end_date TIMESTAMP,
  is_active BOOLEAN
);

MERGE INTO silver.orders AS target
USING (
  SELECT DISTINCT *, TRUE AS is_active FROM bronze.orders
) AS source
ON target.order_id = source.order_id AND target.is_active = TRUE
WHEN MATCHED AND (
  target.customer_id IS DISTINCT FROM source.customer_id
  OR target.order_date IS DISTINCT FROM source.order_date
  OR target.total_amount IS DISTINCT FROM source.total_amount
  OR target.updated_at IS DISTINCT FROM source.updated_at
) THEN UPDATE SET
  is_active = FALSE,
  effective_end_date = NOW();

MERGE INTO silver.orders AS target
USING (
  SELECT DISTINCT * FROM bronze.orders
) AS source
ON target.order_id = source.order_id AND target.is_active = TRUE
WHEN NOT MATCHED THEN INSERT (
  order_id, customer_id, order_date, total_amount, updated_at,
  effective_start_date, effective_end_date, is_active
) VALUES (
  source.order_id, source.customer_id, source.order_date, source.total_amount, source.updated_at,
  NOW(), NULL, TRUE
);

CREATE TABLE IF NOT EXISTS silver.order_items (
  order_item_id INT,
  order_id INT,
  beer_id INT,
  quantity INT,
  price NUMERIC,
  updated_at TEXT,
  effective_start_date TIMESTAMP,
  effective_end_date TIMESTAMP,
  is_active BOOLEAN
);

MERGE INTO silver.order_items AS target
USING (SELECT DISTINCT * FROM bronze.order_items) AS source
ON target.order_item_id = source.order_item_id AND target.is_active = TRUE
WHEN MATCHED AND (
  target.order_id IS DISTINCT FROM source.order_id
  OR target.beer_id IS DISTINCT FROM source.beer_id
  OR target.quantity IS DISTINCT FROM source.quantity
  OR target.price IS DISTINCT FROM source.price
  OR target.updated_at IS DISTINCT FROM source.updated_at
) THEN UPDATE SET
  is_active = FALSE,
  effective_end_date = NOW();

MERGE INTO silver.order_items AS target
USING (SELECT DISTINCT * FROM bronze.order_items) AS source
ON target.order_item_id = source.order_item_id AND target.is_active = TRUE
WHEN NOT MATCHED THEN INSERT (
  order_item_id, order_id, beer_id, quantity, price, updated_at,
  effective_start_date, effective_end_date, is_active
) VALUES (
  source.order_item_id, source.order_id, source.beer_id, source.quantity, source.price, source.updated_at,
  NOW(), NULL, TRUE
);

CREATE TABLE IF NOT EXISTS silver.styles (
  style_id INT,
  name TEXT,
  updated_at TEXT,
  is_quarantined BOOLEAN
);

TRUNCATE TABLE silver.styles;

INSERT INTO silver.styles
SELECT
  style_id,
  name,
  updated_at,
  (style_id IS NULL OR name IS NULL)
FROM bronze.styles;

CREATE TABLE IF NOT EXISTS silver.beers (
  beer_id INT,
  name TEXT,
  style_id INT,
  abv NUMERIC,
  price NUMERIC,
  updated_at TEXT,
  is_quarantined BOOLEAN
);

TRUNCATE TABLE silver.beers;

INSERT INTO silver.beers
SELECT
  beer_id,
  name,
  style_id,
  abv,
  price,
  updated_at,
  (beer_id IS NULL OR name IS NULL OR style_id IS NULL)
FROM bronze.beers;

CREATE TABLE IF NOT EXISTS silver.distributors (
  distributor_id INT,
  distributor_name TEXT,
  contact_name TEXT,
  city TEXT,
  country TEXT,
  created_at TEXT,
  is_quarantined BOOLEAN
);

TRUNCATE TABLE silver.distributors;

INSERT INTO silver.distributors
SELECT
  distributor_id,
  distributor_name,
  contact_name,
  city,
  country,
  created_at,
  (distributor_id IS NULL OR distributor_name IS NULL)
FROM bronze.distributors;

CREATE TABLE IF NOT EXISTS silver.beer_distributors (
  distributor_id INT,
  beer_id INT,
  supply_price NUMERIC,
  last_updated TEXT,
  effective_start_date TIMESTAMP,
  effective_end_date TIMESTAMP,
  is_active BOOLEAN
);

MERGE INTO silver.beer_distributors AS target
USING (SELECT * FROM bronze.beer_distributors) AS source
ON target.distributor_id = source.distributor_id
  AND target.beer_id = source.beer_id
  AND target.is_active = TRUE
WHEN MATCHED AND (
  target.supply_price IS DISTINCT FROM source.supply_price
  OR target.last_updated IS DISTINCT FROM source.last_updated
) THEN UPDATE SET
  is_active = FALSE,
  effective_end_date = NOW();

MERGE INTO silver.beer_distributors AS target
USING (SELECT * FROM bronze.beer_distributors) AS source
ON target.distributor_id = source.distributor_id
  AND target.beer_id = source.beer_id
  AND target.is_active = TRUE
WHEN NOT MATCHED THEN INSERT (
  distributor_id, beer_id, supply_price, last_updated,
  effective_start_date, effective_end_date, is_active
) VALUES (
  source.distributor_id, source.beer_id, source.supply_price, source.last_updated,
  NOW(), NULL, TRUE
);

CREATE TABLE IF NOT EXISTS silver.taproom_reviews (
  review_id TEXT,
  customer_id INT,
  beer_id INT,
  rating INT,
  review_text TEXT,
  review_date TEXT,
  effective_start_date TIMESTAMP,
  effective_end_date TIMESTAMP,
  is_active BOOLEAN
);

MERGE INTO silver.taproom_reviews AS target
USING (SELECT * FROM bronze.taproom_reviews) AS source
ON target.review_id = source.review_id AND target.is_active = TRUE
WHEN MATCHED AND (
  target.customer_id IS DISTINCT FROM source.customer_id
  OR target.beer_id IS DISTINCT FROM source.beer_id
  OR target.rating IS DISTINCT FROM source.rating
  OR target.review_text IS DISTINCT FROM source.review_text
  OR target.review_date IS DISTINCT FROM source.review_date
) THEN UPDATE SET
  is_active = FALSE,
  effective_end_date = NOW();

MERGE INTO silver.taproom_reviews AS target
USING (SELECT * FROM bronze.taproom_reviews) AS source
ON target.review_id = source.review_id AND target.is_active = TRUE
WHEN NOT MATCHED THEN INSERT (
  review_id, customer_id, beer_id, rating, review_text, review_date,
  effective_start_date, effective_end_date, is_active
) VALUES (
  source.review_id, source.customer_id, source.beer_id, source.rating, source.review_text, source.review_date,
  NOW(), NULL, TRUE
);
