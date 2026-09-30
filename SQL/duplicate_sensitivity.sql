# ============================================================
# UCI ONLINE RETAIL - DUPLICATE SENSITIVITY
# ============================================================

# DUPLICATE-POLICY SENSITIVITY
# EXECUTION ORDER: 9 OF 10
# RUN AFTER: customer_features.sql
# RUN NEXT: final_validation.sql

# PREREQUISITES:
# The primary database build must be complete and validated.
# MySQL 8.0 or later is required for common table expressions.

# Compare all recorded occurrences with one occurrence
# per exact group across the eight loaded source columns.
# Text comparisons are binary and preserve case and trailing spaces.
# Exact groups refer to loaded values, not original CSV formatting.

# This is a sensitivity alternative, not verified corrected data.
# Repeated records are not assumed to be errors.
# Read-only: no records are changed.

USE uci;

# This comparison includes all eligible identified customers.
# Cancellation totals include customers without qualifying purchases.
# The alternative feature query below retains only purchasing customers.
# Its cancellation totals therefore cover a narrower customer cohort.

WITH exact_groups AS (
    SELECT
        CASE
            WHEN MIN(r.invoice_no) LIKE 'C%' THEN 'Cancellation'
            ELSE 'Purchase'
        END AS transaction_type,
        r.quantity,
        r.unit_price,
        COUNT(*) AS occurrences
    FROM retail_stg r
    WHERE NULLIF(TRIM(r.customer_id), '') IS NOT NULL
        AND r.unit_price > 0
        AND (
            (r.invoice_no NOT LIKE 'C%' AND r.quantity > 0)
            OR
            (r.invoice_no LIKE 'C%' AND r.quantity < 0)
        )
        AND r.stock_code NOT IN (
            'POST', 'DOT', 'M', 'BANK CHARGES',
            'PADS', 'C2', '23444', '23574'
        )
        AND EXISTS (
            SELECT 1
            FROM product p
            WHERE p.stock_code = r.stock_code
        )
    GROUP BY
        CAST(r.invoice_no AS BINARY),
        CAST(r.stock_code AS BINARY),
        CAST(r.product_description AS BINARY),
        r.quantity,
        r.invoice_date,
        r.unit_price,
        CAST(r.customer_id AS BINARY),
        CAST(r.country AS BINARY)
)
SELECT
    transaction_type,
    SUM(occurrences) AS lines_all_occurrences,
    COUNT(*) AS lines_one_per_group,
    SUM(occurrences - 1) AS excess_lines,
    SUM(
        CASE WHEN occurrences > 1 THEN 1 ELSE 0 END
    ) AS repeated_groups,
    SUM(
        occurrences * ABS(quantity) * unit_price
    ) AS value_all_occurrences,
    SUM(
        ABS(quantity) * unit_price
    ) AS value_one_per_group,
    SUM(
        (occurrences - 1) * ABS(quantity) * unit_price
    ) AS value_difference
FROM exact_groups
GROUP BY transaction_type
ORDER BY transaction_type;


# Build alternative customer features using one occurrence
# per exact group of the eight loaded source fields.
# This SELECT does not create or modify any tables.

# Run after the primary database build is complete.
# Set MySQL Workbench's result-row limit to Don't Limit.
# Expected result: 4334 customers and 18 columns.
# Export the result grid with headers as:
# customer_features_one_per_group.csv
# Save in the project folder beside the notebook.
# Preserve missing cancellation dates as missing values.
# Keep customers 12346 and 16446 here; the notebook excludes them.
# This SELECT displays results; it does not write the CSV automatically.

WITH exact_source_groups AS (
    SELECT
        MIN(invoice_no) AS invoice_no,
        MIN(stock_code) AS stock_code,
        quantity,
        unit_price
    FROM retail_stg
    GROUP BY
        CAST(invoice_no AS BINARY),
        CAST(stock_code AS BINARY),
        CAST(product_description AS BINARY),
        quantity,
        invoice_date,
        unit_price,
        CAST(customer_id AS BINARY),
        CAST(country AS BINARY)
),

# Use the same invoice headers and product membership
# as the primary analytical views.
eligible_lines AS (
    SELECT
        i.customer_id,
        i.invoice_no,
        i.invoice_date,
        g.stock_code,
        g.quantity,
        g.unit_price
    FROM exact_source_groups g
    JOIN invoice i
        ON g.invoice_no = i.invoice_no
    JOIN product p
        ON g.stock_code = p.stock_code
    WHERE i.customer_id IS NOT NULL
        AND g.unit_price > 0
        AND g.stock_code NOT IN (
            'POST', 'DOT', 'M', 'BANK CHARGES',
            'PADS', 'C2', '23444', '23574'
        )
),

purchase_summary AS (
    SELECT
        customer_id,
        MIN(invoice_date) AS first_purchase_date,
        MAX(invoice_date) AS last_purchase_date,
        COUNT(DISTINCT invoice_no) AS purchase_frequency,
        COUNT(*) AS purchase_line_count,
        COUNT(DISTINCT stock_code) AS distinct_products,
        SUM(quantity) AS purchase_quantity,
        SUM(quantity * unit_price) AS purchase_value,
        ROUND(
            SUM(quantity * unit_price)
                / COUNT(DISTINCT invoice_no),
            4
        ) AS average_order_value
    FROM eligible_lines
    WHERE invoice_no NOT LIKE 'C%'
        AND quantity > 0
    GROUP BY customer_id
),

cancellation_summary AS (
    SELECT
        customer_id,
        MIN(invoice_date) AS first_cancellation_date,
        MAX(invoice_date) AS last_cancellation_date,
        COUNT(DISTINCT invoice_no) AS cancellation_frequency,
        COUNT(*) AS cancellation_line_count,
        COUNT(DISTINCT stock_code) AS distinct_cancelled_products,
        SUM(-quantity) AS cancelled_quantity,
        SUM(-quantity * unit_price) AS cancellation_value
    FROM eligible_lines
    WHERE invoice_no LIKE 'C%'
        AND quantity < 0
    GROUP BY customer_id
)

SELECT
    p.customer_id,
    CAST('2011-12-10' AS DATE) AS reference_date,
    p.first_purchase_date,
    p.last_purchase_date,
    DATEDIFF('2011-12-10', p.last_purchase_date) AS recency_days,
    p.purchase_frequency,
    p.purchase_line_count,
    p.distinct_products,
    p.purchase_quantity,
    p.purchase_value,
    p.average_order_value,
    c.first_cancellation_date,
    c.last_cancellation_date,
    COALESCE(c.cancellation_frequency, 0) AS cancellation_frequency,
    COALESCE(c.cancellation_line_count, 0) AS cancellation_line_count,
    COALESCE(c.distinct_cancelled_products, 0)
        AS distinct_cancelled_products,
    COALESCE(c.cancelled_quantity, 0) AS cancelled_quantity,
    COALESCE(c.cancellation_value, 0) AS cancellation_value
FROM purchase_summary p
LEFT JOIN cancellation_summary c
    ON p.customer_id = c.customer_id
ORDER BY p.customer_id;