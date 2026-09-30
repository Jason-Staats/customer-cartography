# ============================================================
# UCI ONLINE RETAIL - ANALYTICAL TRANSACTION VIEWS
# ============================================================

# EXECUTION ORDER: 7 OF 10
# RUN AFTER: transaction_cleaning.sql
# RUN NEXT: customer_features.sql

# PREREQUISITES:
# THE RELATIONAL DATABASE BUILD MUST BE COMPLETE AND VALIDATED.
# TRANSACTION-CLEANING FINDINGS AND ANALYTICAL RULES MUST BE REVIEWED.
# THE ANALYTICAL VIEWS CREATED BELOW MUST NOT ALREADY EXIST.

# PURPOSE:
# CREATE SEPARATE MERCHANDISE PURCHASE AND CANCELLATION VIEWS.
# APPLY THE ANALYTICAL RULES DOCUMENTED IN transaction_cleaning.sql.
# RETAIN ALL RECORDED OCCURRENCES UNDER THE PRIMARY DUPLICATE POLICY.

# SOURCE AND MODELED RECORDS REMAIN UNCHANGED.
# VIEWS READ THE CURRENT MODELED TABLES; THEY ARE NOT FROZEN SNAPSHOTS.

# IF A STEP FAILS, CHECK WHAT COMPLETED BEFORE RETRYING.
# VALIDATION QUERIES DISPLAY RESULTS; THEY DO NOT STOP EXECUTION.

USE uci;

# CREATE THE ANALYTICAL MERCHANDISE PURCHASE VIEW
# PREREQUISITE: MERCHANDISE_PURCHASE MUST NOT ALREADY EXIST.
# APPLY THE RECONCILED PURCHASE RULES.
# RETAIN ALL RECORDED OCCURRENCES.

# THIS VIEW READS THE CURRENT MODELED TABLES.
# IT IS NOT A FROZEN SNAPSHOT OF THE DATA.
# PRODUCT_DESCRIPTION IS THE SELECTED MODELED DESCRIPTION.

CREATE VIEW merchandise_purchase AS
SELECT
    il.invoice_line_id,
    i.invoice_no,
    i.invoice_date,
    i.customer_id,
    i.country,
    il.stock_code,
    p.product_description,
    il.quantity,
    il.unit_price,
    il.quantity * il.unit_price AS line_value
FROM invoice_line il
JOIN invoice i
    ON il.invoice_no = i.invoice_no
JOIN product p
    ON il.stock_code = p.stock_code
WHERE i.invoice_no NOT LIKE 'C%'
    AND il.quantity > 0
    AND il.unit_price > 0
    AND i.customer_id IS NOT NULL
    AND il.stock_code NOT IN (
        'POST',
        'DOT',
        'M',
        'BANK CHARGES',
        'PADS',
        'C2',
        '23444',
        '23574'
    );


# VALIDATE THE MERCHANDISE PURCHASE VIEW
# COMPARE WITH THE MODELED PURCHASE RECONCILIATION
# IN transaction_cleaning.sql.

# REFERENCE DATASET:
# 396244 LINES, 18402 INVOICES, AND 4334 CUSTOMERS.
# PURCHASE QUANTITY: 5157261.
# PURCHASE VALUE: 8759761.6500.
# FIRST PURCHASE: 2010-12-01 08:26:00.
# LAST PURCHASE: 2011-12-09 12:50:00.

SELECT
    COUNT(*) AS purchase_line_count,
    COUNT(DISTINCT invoice_no) AS purchase_invoice_count,
    COUNT(DISTINCT customer_id) AS purchasing_customer_count,
    COALESCE(SUM(quantity), 0) AS purchase_quantity,
    COALESCE(SUM(line_value), 0) AS purchase_value,
    MIN(invoice_date) AS first_purchase_date,
    MAX(invoice_date) AS last_purchase_date
FROM merchandise_purchase;


# CREATE THE ANALYTICAL MERCHANDISE CANCELLATION VIEW
# PREREQUISITE: MERCHANDISE_CANCELLATION MUST NOT ALREADY EXIST.
# APPLY THE SAME STOCK-CODE EXCLUSIONS AS THE PURCHASE VIEW.
# RETAIN ALL RECORDED OCCURRENCES.

# INCLUDE IDENTIFIED CUSTOMERS EVEN IF THEY HAVE NO QUALIFYING PURCHASES.
# PURCHASE-COHORT RESTRICTIONS WILL BE APPLIED WHEN BUILDING FEATURES.

# PRESERVE THE ORIGINAL NEGATIVE QUANTITY AND SIGNED LINE VALUE.
# PROVIDE POSITIVE MAGNITUDES FOR CANCELLATION FEATURE CALCULATIONS.
# THESE RECORDS DO NOT ESTABLISH MATCHED RETURNS OR CASH REFUNDS.

CREATE VIEW merchandise_cancellation AS
SELECT
    il.invoice_line_id,
    i.invoice_no,
    i.invoice_date,
    i.customer_id,
    i.country,
    il.stock_code,
    p.product_description,
    il.quantity,
    il.unit_price,
    il.quantity * il.unit_price AS line_value,
    -il.quantity AS cancelled_quantity,
    -il.quantity * il.unit_price AS cancellation_value
FROM invoice_line il
JOIN invoice i
    ON il.invoice_no = i.invoice_no
JOIN product p
    ON il.stock_code = p.stock_code
WHERE i.invoice_no LIKE 'C%'
    AND il.quantity < 0
    AND il.unit_price > 0
    AND i.customer_id IS NOT NULL
    AND il.stock_code NOT IN (
        'POST',
        'DOT',
        'M',
        'BANK CHARGES',
        'PADS',
        'C2',
        '23444',
        '23574'
    );


# VALIDATE THE MERCHANDISE CANCELLATION VIEW
# COMPARE WITH THE MERCHANDISE CANCELLATION PROFILE
# IN transaction_cleaning.sql.

# REFERENCE DATASET:
# 8629 LINES, 3462 INVOICES, AND 1540 CUSTOMERS.
# CANCELLED QUANTITY MAGNITUDE: 270691.
# CANCELLATION VALUE MAGNITUDE: 488002.9800.
# SIGNED LINE VALUE: -488002.9800.
# FIRST CANCELLATION: 2010-12-01 09:41:00.
# LAST CANCELLATION: 2011-12-09 11:58:00.

SELECT
    COUNT(*) AS cancellation_line_count,
    COUNT(DISTINCT invoice_no) AS cancellation_invoice_count,
    COUNT(DISTINCT customer_id) AS cancelling_customer_count,
    COALESCE(SUM(cancelled_quantity), 0) AS cancelled_quantity,
    COALESCE(SUM(cancellation_value), 0) AS cancellation_value,
    COALESCE(SUM(line_value), 0) AS signed_line_value,
    MIN(invoice_date) AS first_cancellation_date,
    MAX(invoice_date) AS last_cancellation_date
FROM merchandise_cancellation;


# PREVIOUSLY OBSERVED IN transaction_cleaning.sql:
# 1124 MERCHANDISE CANCELLATION LINES HAD NO EARLIER
# QUALIFYING SAME-CUSTOMER, SAME-STOCK PURCHASE OBSERVED.
# THESE LINES REMAIN IN THIS VIEW.
# THAT FINDING DOES NOT ESTABLISH INVALID CANCELLATIONS.


# VERIFY PURCHASE ELIGIBILITY FOR CUSTOMERS IN THE CANCELLATION VIEW
# COUNT EACH CANCELLING CUSTOMER ONCE.
# CHECK FOR ANY QUALIFYING PURCHASE IN THE PURCHASE VIEW.
# THIS DOES NOT MATCH CANCELLATIONS TO INDIVIDUAL PURCHASES.

WITH cancelling_customers AS (
    SELECT DISTINCT customer_id
    FROM merchandise_cancellation
),
customer_purchase_status AS (
    SELECT
        c.customer_id,
        CASE
            WHEN EXISTS (
                SELECT 1
                FROM merchandise_purchase p
                WHERE p.customer_id = c.customer_id
            ) THEN 1
            ELSE 0
        END AS has_merchandise_purchase
    FROM cancelling_customers c
)
SELECT
    CASE
        WHEN has_merchandise_purchase = 1
            THEN 'With qualifying merchandise purchases'
        ELSE 'Without qualifying merchandise purchases'
    END AS purchase_status,
    COUNT(*) AS customer_count
FROM customer_purchase_status
GROUP BY has_merchandise_purchase
ORDER BY has_merchandise_purchase DESC;

# VALIDATION:
# COMPARE WITH THE CUSTOMER ELIGIBILITY CHECK
# IN transaction_cleaning.sql.

# REFERENCE DATASET:
# WITH QUALIFYING MERCHANDISE PURCHASES: 1512 CUSTOMERS.
# WITHOUT QUALIFYING MERCHANDISE PURCHASES: 28 CUSTOMERS.
# THE COUNTS SHOULD SUM TO 1540 CANCELLING CUSTOMERS.

# THE 28 CUSTOMERS REMAIN IN THE CANCELLATION VIEW
# BUT WILL NOT ENTER THE PURCHASE-BASED FEATURE TABLE.


# BEFORE RUNNING customer_features.sql:
# CONFIRM PURCHASE AND CANCELLATION VIEW TOTALS MATCH
# THEIR REFERENCE VALUES.
# CONFIRM THE CUSTOMER OVERLAP CHECK RETURNS 1512 AND 28.