-- Bronze: raw copies of landing JSON. Not external (no GCS); still "as landed".
CREATE TABLE IF NOT EXISTS bronze.styles (
  style_id INT,
  name TEXT,
  updated_at TEXT
);

CREATE TABLE IF NOT EXISTS bronze.beers (
  beer_id INT,
  name TEXT,
  style_id INT,
  abv NUMERIC,
  price NUMERIC,
  updated_at TEXT
);

CREATE TABLE IF NOT EXISTS bronze.customers (
  customer_id INT,
  name TEXT,
  email TEXT,
  updated_at TEXT
);

CREATE TABLE IF NOT EXISTS bronze.orders (
  order_id INT,
  customer_id INT,
  order_date TEXT,
  total_amount NUMERIC,
  updated_at TEXT
);

CREATE TABLE IF NOT EXISTS bronze.order_items (
  order_item_id INT,
  order_id INT,
  beer_id INT,
  quantity INT,
  price NUMERIC,
  updated_at TEXT
);

CREATE TABLE IF NOT EXISTS bronze.distributors (
  distributor_id INT,
  distributor_name TEXT,
  contact_name TEXT,
  city TEXT,
  country TEXT,
  created_at TEXT
);

CREATE TABLE IF NOT EXISTS bronze.beer_distributors (
  distributor_id INT,
  beer_id INT,
  supply_price NUMERIC,
  last_updated TEXT
);

CREATE TABLE IF NOT EXISTS bronze.taproom_reviews (
  review_id TEXT,
  customer_id INT,
  beer_id INT,
  rating INT,
  review_text TEXT,
  review_date TEXT
);
