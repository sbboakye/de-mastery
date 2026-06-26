-- Runs automatically the first time the postgres volume is created.
-- A tiny "store" schema to practice JOINs, aggregations, window functions, etc.

CREATE TABLE customers (
    customer_id   SERIAL PRIMARY KEY,
    name          TEXT        NOT NULL,
    country       TEXT        NOT NULL,
    signed_up_at  DATE        NOT NULL
);

CREATE TABLE products (
    product_id    SERIAL PRIMARY KEY,
    name          TEXT        NOT NULL,
    category      TEXT        NOT NULL,
    unit_price    NUMERIC(10,2) NOT NULL
);

CREATE TABLE orders (
    order_id      SERIAL PRIMARY KEY,
    customer_id   INT         NOT NULL REFERENCES customers(customer_id),
    ordered_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE order_items (
    order_id      INT         NOT NULL REFERENCES orders(order_id),
    product_id    INT         NOT NULL REFERENCES products(product_id),
    quantity      INT         NOT NULL CHECK (quantity > 0),
    PRIMARY KEY (order_id, product_id)
);
