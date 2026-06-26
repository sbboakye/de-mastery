-- Sample rows so there's something to query right away.

INSERT INTO customers (name, country, signed_up_at) VALUES
    ('Ama Mensah',      'Ghana',   '2024-01-15'),
    ('Kofi Owusu',      'Ghana',   '2024-02-03'),
    ('Lena Schmidt',    'Germany', '2024-02-20'),
    ('Diego Alvarez',   'Spain',   '2024-03-11'),
    ('Yuki Tanaka',     'Japan',   '2024-04-07');

INSERT INTO products (name, category, unit_price) VALUES
    ('Mechanical Keyboard', 'Electronics', 89.99),
    ('USB-C Hub',           'Electronics', 39.50),
    ('Notebook',            'Stationery',   4.25),
    ('Espresso Beans 1kg',  'Grocery',     18.00),
    ('Water Bottle',        'Lifestyle',   12.75);

INSERT INTO orders (customer_id, ordered_at) VALUES
    (1, '2024-05-01 09:30:00+00'),
    (1, '2024-05-09 14:10:00+00'),
    (2, '2024-05-12 11:00:00+00'),
    (3, '2024-05-15 16:45:00+00'),
    (5, '2024-06-02 08:20:00+00');

INSERT INTO order_items (order_id, product_id, quantity) VALUES
    (1, 1, 1),
    (1, 3, 4),
    (2, 4, 2),
    (3, 2, 1),
    (3, 5, 3),
    (4, 1, 1),
    (5, 4, 1),
    (5, 3, 10);
