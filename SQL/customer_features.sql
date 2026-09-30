# ============================================================
# UCI ONLINE RETAIL - CUSTOMER FEATURES
# ============================================================

# EXECUTION ORDER: 8 OF 10
# RUN AFTER: analytical_views.sql
# RUN NEXT: duplicate_sensitivity.sql

# PREREQUISITES:
# BOTH ANALYTICAL VIEWS MUST EXIST AND THEIR VALIDATIONS MUST MATCH.
# THE CUSTOMER TABLE MUST EXIST.
# CUSTOMER_FEATURES MUST NOT ALREADY EXIST.

# PURPOSE:
# BUILD ONE FEATURE ROW PER QUALIFYING PURCHASING CUSTOMER.
# AGGREGATE PURCHASES AND CANCELLATIONS SEPARATELY BEFORE JOINING.

# THIS SCRIPT:
# PREVIEWS AND VALIDATES CUSTOMER SUMMARIES.
# CREATES AND POPULATES THE CUSTOMER_FEATURES TABLE.
# VALIDATES THE STORED SNAPSHOT AND SELECTS IT FOR CSV EXPORT.

# FRESH BUILD ONLY:
# DO NOT RERUN CREATE OR INSERT AGAINST AN EXISTING POPULATED TABLE.
# IF A STEP FAILS, CHECK WHAT COMPLETED BEFORE RETRYING.
# REVIEW PREVIEW VALIDATIONS BEFORE CREATING AND POPULATING THE TABLE.
# VALIDATION QUERIES DISPLAY RESULTS; THEY DO NOT STOP EXECUTION.

# SOURCE AND MODELED TRANSACTION RECORDS REMAIN UNCHANGED.
# THE FEATURE TABLE STORES A SNAPSHOT OF THE VIEWS WHEN POPULATED.
# LATER VIEW CHANGES DO NOT AUTOMATICALLY UPDATE THAT SNAPSHOT.

# REFERENCE DATE: 2011-12-10.
# RECENCY IS MEASURED IN CALENDAR DAYS.
# REVIEW THE REFERENCE DATE IF THE OBSERVATION PERIOD CHANGES.

# REFERENCE COUNTS DESCRIBE THE PREVIOUSLY VALIDATED DATASET.
# REVIEW DIFFERENCES IF THE DATA OR ANALYTICAL RULES CHANGE.

# THESE ARE CANDIDATE FEATURES.
# NOT EVERY COLUMN NEEDS TO BE USED AS A CLUSTERING INPUT.

USE uci;


# PREVIEW CUSTOMER PURCHASE FEATURES
# USE ALL QUALIFYING PURCHASE OCCURRENCES.
# FREQUENCY COUNTS DISTINCT INVOICES.
# PURCHASE VALUE DOES NOT SUBTRACT CANCELLATIONS.
# AVERAGE ORDER VALUE IS PURCHASE VALUE PER QUALIFYING INVOICE.

SELECT
    customer_id,
    MIN(invoice_date) AS first_purchase_date,
    MAX(invoice_date) AS last_purchase_date,
    DATEDIFF(
        '2011-12-10',
        MAX(invoice_date)
    ) AS recency_days,
    COUNT(DISTINCT invoice_no) AS purchase_frequency,
    COUNT(*) AS purchase_line_count,
    COUNT(DISTINCT stock_code) AS distinct_products,
    SUM(quantity) AS purchase_quantity,
    SUM(line_value) AS purchase_value,
    ROUND(
        SUM(line_value) / COUNT(DISTINCT invoice_no),
        4
    ) AS average_order_value
FROM merchandise_purchase
GROUP BY customer_id
ORDER BY customer_id;

# REFERENCE DATASET: 4334 CUSTOMER ROWS.
# RECENCY SHOULD BE AT LEAST 1 DAY FOR THIS REFERENCE DATE.
# PURCHASE FREQUENCY, QUANTITY, AND VALUE SHOULD BE POSITIVE.


# VALIDATE THE CUSTOMER PURCHASE SUMMARY
# AGGREGATE PURCHASES BY CUSTOMER, THEN RECONCILE THE TOTALS.
# THE CTE EXISTS ONLY FOR THIS STATEMENT.
# NO TABLE OR VIEW IS CREATED.

WITH purchase_summary AS (
    SELECT
        customer_id,
        MIN(invoice_date) AS first_purchase_date,
        MAX(invoice_date) AS last_purchase_date,
        DATEDIFF(
            '2011-12-10',
            MAX(invoice_date)
        ) AS recency_days,
        COUNT(DISTINCT invoice_no) AS purchase_frequency,
        COUNT(*) AS purchase_line_count,
        COUNT(DISTINCT stock_code) AS distinct_products,
        SUM(quantity) AS purchase_quantity,
        SUM(line_value) AS purchase_value,
        ROUND(
            SUM(line_value) / COUNT(DISTINCT invoice_no),
            4
        ) AS average_order_value
    FROM merchandise_purchase
    GROUP BY customer_id
)
SELECT
    COUNT(*) AS customer_count,
    SUM(purchase_frequency) AS purchase_invoice_count,
    SUM(purchase_line_count) AS purchase_line_count,
    SUM(purchase_quantity) AS purchase_quantity,
    SUM(purchase_value) AS purchase_value,
    MIN(first_purchase_date) AS first_purchase_date,
    MAX(last_purchase_date) AS last_purchase_date,
    MIN(recency_days) AS minimum_recency_days,
    MAX(recency_days) AS maximum_recency_days,
    COALESCE(
        SUM(
            CASE
                WHEN customer_id IS NULL
                    OR TRIM(customer_id) = ''
                    OR first_purchase_date IS NULL
                    OR last_purchase_date IS NULL
                    OR first_purchase_date > last_purchase_date
                    OR recency_days IS NULL
                    OR recency_days < 1
                    OR purchase_frequency < 1
                    OR purchase_line_count < purchase_frequency
                    OR distinct_products < 1
                    OR distinct_products > purchase_line_count
                    OR purchase_quantity IS NULL
                    OR purchase_quantity <= 0
                    OR purchase_value IS NULL
                    OR purchase_value <= 0
                    OR average_order_value IS NULL
                    OR average_order_value <> ROUND(
                        purchase_value / NULLIF(purchase_frequency, 0),
                        4
                    )
                THEN 1 ELSE 0
            END
        ),
        0
    ) AS invalid_customer_rows
FROM purchase_summary;

# REFERENCE DATASET:
# CUSTOMERS: 4334.
# PURCHASE INVOICES: 18402.
# PURCHASE LINES: 396244.
# PURCHASE QUANTITY: 5157261.
# PURCHASE VALUE: 8759761.6500.
# FIRST PURCHASE: 2010-12-01 08:26:00.
# LAST PURCHASE: 2011-12-09 12:50:00.
# RECENCY RANGE: 1 TO 374 CALENDAR DAYS.

# VALIDATION:
# TOTALS SHOULD MATCH THE MERCHANDISE PURCHASE VIEW.
# INVALID_CUSTOMER_ROWS SHOULD BE ZERO.

# INVOICE COUNTS CAN BE SUMMED BECAUSE EACH MODELED INVOICE
# BELONGS TO ONE CUSTOMER.
# DISTINCT PRODUCT COUNTS ARE NOT SUMMED BECAUSE THE SAME
# PRODUCT MAY HAVE BEEN PURCHASED BY MULTIPLE CUSTOMERS.


# PREVIEW CUSTOMER MERCHANDISE CANCELLATION FEATURES
# RETAIN ALL QUALIFYING RECORDED OCCURRENCES.
# FREQUENCY COUNTS DISTINCT CANCELLATION INVOICES.
# QUANTITY AND VALUE ARE POSITIVE MAGNITUDES.

# INCLUDE ALL CUSTOMERS IN THE CANCELLATION VIEW AT THIS STAGE.
# THE PURCHASE COHORT WILL DETERMINE WHICH CUSTOMERS
# ENTER THE COMBINED RESULT.

# THESE MEASURES DESCRIBE OBSERVED CANCELLATION ACTIVITY.
# THEY DO NOT ESTABLISH MATCHED RETURNS OR CASH REFUNDS.

SELECT
    customer_id,
    MIN(invoice_date) AS first_cancellation_date,
    MAX(invoice_date) AS last_cancellation_date,
    COUNT(DISTINCT invoice_no) AS cancellation_frequency,
    COUNT(*) AS cancellation_line_count,
    COUNT(DISTINCT stock_code) AS distinct_cancelled_products,
    SUM(cancelled_quantity) AS cancelled_quantity,
    SUM(cancellation_value) AS cancellation_value
FROM merchandise_cancellation
GROUP BY customer_id
ORDER BY customer_id;

# REFERENCE DATASET: 1540 CUSTOMER ROWS.
# CANCELLATION FREQUENCY, QUANTITY, AND VALUE SHOULD BE POSITIVE.

# OF THESE CUSTOMERS, 1512 HAVE QUALIFYING MERCHANDISE PURCHASES.
# THE OTHER 28 REMAIN OUTSIDE THE PURCHASE-BASED FEATURE COHORT.


# VALIDATE THE CUSTOMER CANCELLATION SUMMARY
# AGGREGATE CANCELLATIONS BY CUSTOMER, THEN RECONCILE THE TOTALS.
# INCLUDE ALL CUSTOMERS IN THE CANCELLATION VIEW.
# THE CTE EXISTS ONLY FOR THIS STATEMENT.

WITH cancellation_summary AS (
    SELECT
        customer_id,
        MIN(invoice_date) AS first_cancellation_date,
        MAX(invoice_date) AS last_cancellation_date,
        COUNT(DISTINCT invoice_no) AS cancellation_frequency,
        COUNT(*) AS cancellation_line_count,
        COUNT(DISTINCT stock_code) AS distinct_cancelled_products,
        SUM(cancelled_quantity) AS cancelled_quantity,
        SUM(cancellation_value) AS cancellation_value
    FROM merchandise_cancellation
    GROUP BY customer_id
)
SELECT
    COUNT(*) AS customer_count,
    SUM(cancellation_frequency) AS cancellation_invoice_count,
    SUM(cancellation_line_count) AS cancellation_line_count,
    SUM(cancelled_quantity) AS cancelled_quantity,
    SUM(cancellation_value) AS cancellation_value,
    MIN(first_cancellation_date) AS first_cancellation_date,
    MAX(last_cancellation_date) AS last_cancellation_date,
    COALESCE(
        SUM(
            CASE
                WHEN customer_id IS NULL
                    OR TRIM(customer_id) = ''
                    OR first_cancellation_date IS NULL
                    OR last_cancellation_date IS NULL
                    OR first_cancellation_date > last_cancellation_date
                    OR cancellation_frequency < 1
                    OR cancellation_line_count < cancellation_frequency
                    OR distinct_cancelled_products < 1
                    OR distinct_cancelled_products > cancellation_line_count
                    OR cancelled_quantity IS NULL
                    OR cancelled_quantity <= 0
                    OR cancellation_value IS NULL
                    OR cancellation_value <= 0
                THEN 1 ELSE 0
            END
        ),
        0
    ) AS invalid_customer_rows
FROM cancellation_summary;

# REFERENCE DATASET:
# CUSTOMERS: 1540.
# CANCELLATION INVOICES: 3462.
# CANCELLATION LINES: 8629.
# CANCELLED QUANTITY: 270691.
# CANCELLATION VALUE: 488002.9800.
# FIRST CANCELLATION: 2010-12-01 09:41:00.
# LAST CANCELLATION: 2011-12-09 11:58:00.

# VALIDATION:
# TOTALS SHOULD MATCH THE MERCHANDISE CANCELLATION VIEW.
# INVALID_CUSTOMER_ROWS SHOULD BE ZERO.

# DISTINCT PRODUCT COUNTS ARE NOT SUMMED BECAUSE CUSTOMERS
# MAY HAVE CANCELLED THE SAME PRODUCTS.

# THESE TOTALS INCLUDE THE 28 CUSTOMERS WITHOUT QUALIFYING PURCHASES.
# THEIR CANCELLATIONS WILL BE OUTSIDE THE PURCHASE-BASED FEATURE TABLE.


# PREVIEW COMBINED CUSTOMER FEATURES
# AGGREGATE PURCHASES AND CANCELLATIONS SEPARATELY BY CUSTOMER.
# LEFT JOIN FROM PURCHASES TO PRESERVE THE PURCHASE COHORT.

# USE ZERO FOR CANCELLATION COUNTS, QUANTITY, AND VALUE
# WHEN NO QUALIFYING CANCELLATIONS EXIST.
# LEAVE MISSING CANCELLATION DATES AS NULL.
# PURCHASE VALUE DOES NOT SUBTRACT CANCELLATIONS.

WITH purchase_summary AS (
    SELECT
        customer_id,
        MIN(invoice_date) AS first_purchase_date,
        MAX(invoice_date) AS last_purchase_date,
        DATEDIFF(
            '2011-12-10',
            MAX(invoice_date)
        ) AS recency_days,
        COUNT(DISTINCT invoice_no) AS purchase_frequency,
        COUNT(*) AS purchase_line_count,
        COUNT(DISTINCT stock_code) AS distinct_products,
        SUM(quantity) AS purchase_quantity,
        SUM(line_value) AS purchase_value,
        ROUND(
            SUM(line_value) / COUNT(DISTINCT invoice_no),
            4
        ) AS average_order_value
    FROM merchandise_purchase
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
        SUM(cancelled_quantity) AS cancelled_quantity,
        SUM(cancellation_value) AS cancellation_value
    FROM merchandise_cancellation
    GROUP BY customer_id
)
SELECT
    p.customer_id,
    p.first_purchase_date,
    p.last_purchase_date,
    p.recency_days,
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
    COALESCE(c.distinct_cancelled_products, 0) AS distinct_cancelled_products,
    COALESCE(c.cancelled_quantity, 0) AS cancelled_quantity,
    COALESCE(c.cancellation_value, 0) AS cancellation_value
FROM purchase_summary p
LEFT JOIN cancellation_summary c
    ON p.customer_id = c.customer_id
ORDER BY p.customer_id;

# REFERENCE DATASET:
# 4334 ROWS WITH 4334 DISTINCT CUSTOMER IDS.
# 1512 CUSTOMERS WITH QUALIFYING CANCELLATIONS.
# 2822 CUSTOMERS WITHOUT QUALIFYING CANCELLATIONS.

# PURCHASE TOTALS SHOULD REMAIN UNCHANGED AFTER THE JOIN.
# THE 28 CANCELLATION-ONLY CUSTOMERS ARE OUTSIDE THIS RESULT.

# PREVIOUSLY OBSERVED FOR THOSE 28 EXCLUDED CUSTOMERS:
# 31 CANCELLATION INVOICES, 99 LINES, AND 1337 UNITS.
# CANCELLATION VALUE: 3922.9800.

# NO FEATURE TABLE HAS BEEN CREATED BY THIS STATEMENT.


# VALIDATE THE COMBINED CUSTOMER FEATURE PREVIEW
# CHECK COHORT COUNTS, TOTALS, AND FEATURE CONSISTENCY.
# CHECK ZERO VALUES AND NULL DATES FOR CUSTOMERS WITHOUT CANCELLATIONS.
# THIS QUERY DOES NOT CREATE A TABLE.

WITH purchase_summary AS (
    SELECT
        customer_id,
        MIN(invoice_date) AS first_purchase_date,
        MAX(invoice_date) AS last_purchase_date,
        DATEDIFF(
            '2011-12-10',
            MAX(invoice_date)
        ) AS recency_days,
        COUNT(DISTINCT invoice_no) AS purchase_frequency,
        COUNT(*) AS purchase_line_count,
        COUNT(DISTINCT stock_code) AS distinct_products,
        SUM(quantity) AS purchase_quantity,
        SUM(line_value) AS purchase_value,
        ROUND(
            SUM(line_value) / COUNT(DISTINCT invoice_no),
            4
        ) AS average_order_value
    FROM merchandise_purchase
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
        SUM(cancelled_quantity) AS cancelled_quantity,
        SUM(cancellation_value) AS cancellation_value
    FROM merchandise_cancellation
    GROUP BY customer_id
),
combined_features AS (
    SELECT
        p.customer_id,
        p.first_purchase_date,
        p.last_purchase_date,
        p.recency_days,
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
        COALESCE(c.distinct_cancelled_products, 0) AS distinct_cancelled_products,
        COALESCE(c.cancelled_quantity, 0) AS cancelled_quantity,
        COALESCE(c.cancellation_value, 0) AS cancellation_value
    FROM purchase_summary p
    LEFT JOIN cancellation_summary c
        ON p.customer_id = c.customer_id
)
SELECT
    COUNT(*) AS customer_rows,
    COUNT(DISTINCT customer_id) AS distinct_customers,
    COALESCE(
        SUM(
            CASE WHEN cancellation_frequency > 0
                 THEN 1 ELSE 0 END
        ),
        0
    ) AS customers_with_cancellations,
    COALESCE(
        SUM(
            CASE WHEN cancellation_frequency = 0
                 THEN 1 ELSE 0 END
        ),
        0
    ) AS customers_without_cancellations,
    SUM(purchase_frequency) AS purchase_invoice_count,
    SUM(purchase_line_count) AS purchase_line_count,
    SUM(purchase_quantity) AS purchase_quantity,
    SUM(purchase_value) AS purchase_value,
    SUM(cancellation_frequency) AS cancellation_invoice_count,
    SUM(cancellation_line_count) AS cancellation_line_count,
    SUM(cancelled_quantity) AS cancelled_quantity,
    SUM(cancellation_value) AS cancellation_value,
    COALESCE(
        SUM(
            CASE
                WHEN customer_id IS NULL
                    OR TRIM(customer_id) = ''
                    OR first_purchase_date IS NULL
                    OR last_purchase_date IS NULL
                    OR first_purchase_date > last_purchase_date
                    OR recency_days IS NULL
                    OR recency_days < 1
                    OR purchase_frequency < 1
                    OR purchase_line_count < purchase_frequency
                    OR distinct_products < 1
                    OR distinct_products > purchase_line_count
                    OR purchase_quantity IS NULL
                    OR purchase_quantity <= 0
                    OR purchase_value IS NULL
                    OR purchase_value <= 0
                    OR average_order_value IS NULL
                    OR average_order_value <> ROUND(
                        purchase_value / NULLIF(purchase_frequency, 0),
                        4
                    )
                THEN 1 ELSE 0
            END
        ),
        0
    ) AS invalid_purchase_rows,
    COALESCE(
        SUM(
            CASE
                WHEN cancellation_frequency IS NULL
                    OR cancellation_line_count IS NULL
                    OR distinct_cancelled_products IS NULL
                    OR cancelled_quantity IS NULL
                    OR cancellation_value IS NULL
                    OR cancellation_frequency < 0
                    OR (
                        cancellation_frequency = 0
                        AND (
                            first_cancellation_date IS NOT NULL
                            OR last_cancellation_date IS NOT NULL
                            OR cancellation_line_count <> 0
                            OR distinct_cancelled_products <> 0
                            OR cancelled_quantity <> 0
                            OR cancellation_value <> 0
                        )
                    )
                    OR (
                        cancellation_frequency > 0
                        AND (
                            first_cancellation_date IS NULL
                            OR last_cancellation_date IS NULL
                            OR first_cancellation_date > last_cancellation_date
                            OR cancellation_line_count < cancellation_frequency
                            OR distinct_cancelled_products < 1
                            OR distinct_cancelled_products > cancellation_line_count
                            OR cancelled_quantity <= 0
                            OR cancellation_value <= 0
                        )
                    )
                THEN 1 ELSE 0
            END
        ),
        0
    ) AS invalid_cancellation_rows
FROM combined_features;

# REFERENCE DATASET:
# CUSTOMER ROWS AND DISTINCT CUSTOMERS: 4334.
# CUSTOMERS WITH CANCELLATIONS: 1512.
# CUSTOMERS WITHOUT CANCELLATIONS: 2822.

# PURCHASE TOTALS:
# INVOICES: 18402.
# LINES: 396244.
# QUANTITY: 5157261.
# VALUE: 8759761.6500.

# CANCELLATION TOTALS WITHIN THE PURCHASE COHORT:
# INVOICES: 3431.
# LINES: 8530.
# QUANTITY: 269354.
# VALUE: 484080.0000.

# VALIDATION:
# CUSTOMER_ROWS MUST EQUAL DISTINCT_CUSTOMERS.
# THE TWO CANCELLATION-STATUS COUNTS MUST SUM TO CUSTOMER_ROWS.
# PURCHASE TOTALS MUST MATCH THE PURCHASE-SUMMARY VALIDATION.
# BOTH INVALID-ROW COUNTS SHOULD BE ZERO.

# REVIEW THESE RESULTS BEFORE CREATING THE TABLE.
# THIS VALIDATES THE PREVIEW ONLY.
# THE STORED FEATURE TABLE MUST ALSO BE VALIDATED AFTER POPULATION.


# CREATE THE CUSTOMER FEATURE TABLE
# PREREQUISITE: CUSTOMER_FEATURES MUST NOT ALREADY EXIST.
# THE PRIMARY KEY ALLOWS ONE ROW PER CUSTOMER.

# CANCELLATION DATES MAY BE NULL WHEN NO CANCELLATIONS EXIST.
# THE INSERT STATEMENT MUST SUPPLY ZERO FOR CANCELLATION COUNTS,
# QUANTITY, AND VALUE FOR THOSE CUSTOMERS.

# AGGREGATED VALUES USE WIDER TYPES THAN INDIVIDUAL TRANSACTION LINES.
# REFERENCE_DATE WILL RECORD THE DATE USED TO CALCULATE RECENCY.
# THE TABLE WILL HOLD A SNAPSHOT WHEN POPULATED.
# CHANGES TO THE VIEWS WILL NOT AUTOMATICALLY UPDATE THAT SNAPSHOT.

CREATE TABLE customer_features (
    customer_id VARCHAR(20) NOT NULL,
    reference_date DATE NOT NULL,

    first_purchase_date DATETIME NOT NULL,
    last_purchase_date DATETIME NOT NULL,
    recency_days INT NOT NULL,
    purchase_frequency BIGINT NOT NULL,
    purchase_line_count BIGINT NOT NULL,
    distinct_products BIGINT NOT NULL,
    purchase_quantity BIGINT NOT NULL,
    purchase_value DECIMAL(20,4) NOT NULL,
    average_order_value DECIMAL(20,4) NOT NULL,

    first_cancellation_date DATETIME NULL,
    last_cancellation_date DATETIME NULL,
    cancellation_frequency BIGINT NOT NULL,
    cancellation_line_count BIGINT NOT NULL,
    distinct_cancelled_products BIGINT NOT NULL,
    cancelled_quantity BIGINT NOT NULL,
    cancellation_value DECIMAL(20,4) NOT NULL,

    PRIMARY KEY (customer_id),
    CONSTRAINT fk_customer_features_customer
        FOREIGN KEY (customer_id)
        REFERENCES customer(customer_id)
);


# POPULATE THE CUSTOMER FEATURE TABLE
# PREREQUISITE: CUSTOMER_FEATURES MUST EXIST AND BE EMPTY.
# AGGREGATE PURCHASES AND CANCELLATIONS SEPARATELY BEFORE JOINING.
# INCLUDE ONLY QUALIFYING PURCHASING CUSTOMERS.
# RETAIN ALL QUALIFYING RECORDED OCCURRENCES.

# STORE ZERO CANCELLATION COUNTS, QUANTITY, AND VALUE
# WHEN NO QUALIFYING CANCELLATIONS EXIST.
# LEAVE CANCELLATION DATES AS NULL FOR THOSE CUSTOMERS.

# REFERENCE DATE: 2011-12-10.
# THE INSERT CREATES A SNAPSHOT OF THE CURRENT VIEW RESULTS.

INSERT INTO customer_features (
    customer_id,
    reference_date,
    first_purchase_date,
    last_purchase_date,
    recency_days,
    purchase_frequency,
    purchase_line_count,
    distinct_products,
    purchase_quantity,
    purchase_value,
    average_order_value,
    first_cancellation_date,
    last_cancellation_date,
    cancellation_frequency,
    cancellation_line_count,
    distinct_cancelled_products,
    cancelled_quantity,
    cancellation_value
)
WITH purchase_summary AS (
    SELECT
        customer_id,
        MIN(invoice_date) AS first_purchase_date,
        MAX(invoice_date) AS last_purchase_date,
        COUNT(DISTINCT invoice_no) AS purchase_frequency,
        COUNT(*) AS purchase_line_count,
        COUNT(DISTINCT stock_code) AS distinct_products,
        SUM(quantity) AS purchase_quantity,
        SUM(line_value) AS purchase_value,
        ROUND(
            SUM(line_value) / COUNT(DISTINCT invoice_no),
            4
        ) AS average_order_value
    FROM merchandise_purchase
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
        SUM(cancelled_quantity) AS cancelled_quantity,
        SUM(cancellation_value) AS cancellation_value
    FROM merchandise_cancellation
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
    COALESCE(c.cancellation_frequency, 0),
    COALESCE(c.cancellation_line_count, 0),
    COALESCE(c.distinct_cancelled_products, 0),
    COALESCE(c.cancelled_quantity, 0),
    COALESCE(c.cancellation_value, 0)
FROM purchase_summary p
LEFT JOIN cancellation_summary c
    ON p.customer_id = c.customer_id;

# REFERENCE DATASET: 4334 ROWS INSERTED.
# REVIEW THE ACTION OUTPUT FOR ERRORS OR WARNINGS.
# VALIDATE THE STORED TABLE BEFORE EXPORTING OR USING ITS FEATURES.


# VALIDATE THE STORED CUSTOMER FEATURE TABLE
# COMPARE TOTALS WITH THE VALIDATED COMBINED PREVIEW.
# CHECK THE STORED REFERENCE DATE AND DERIVED FEATURES.
# THIS QUERY DOES NOT CHANGE RECORDS.

SELECT
    COUNT(*) AS customer_rows,
    COUNT(DISTINCT customer_id) AS distinct_customers,
    SUM(
        CASE WHEN cancellation_frequency > 0
             THEN 1 ELSE 0 END
    ) AS customers_with_cancellations,
    SUM(
        CASE WHEN cancellation_frequency = 0
             THEN 1 ELSE 0 END
    ) AS customers_without_cancellations,

    SUM(purchase_frequency) AS purchase_invoice_count,
    SUM(purchase_line_count) AS purchase_line_count,
    SUM(purchase_quantity) AS purchase_quantity,
    SUM(purchase_value) AS purchase_value,

    SUM(cancellation_frequency) AS cancellation_invoice_count,
    SUM(cancellation_line_count) AS cancellation_line_count,
    SUM(cancelled_quantity) AS cancelled_quantity,
    SUM(cancellation_value) AS cancellation_value,

    MIN(reference_date) AS minimum_reference_date,
    MAX(reference_date) AS maximum_reference_date,
    MIN(first_purchase_date) AS first_purchase_date,
    MAX(last_purchase_date) AS last_purchase_date,
    MIN(recency_days) AS minimum_recency_days,
    MAX(recency_days) AS maximum_recency_days,

    COALESCE(SUM(
        CASE
            WHEN reference_date <> '2011-12-10'
                OR recency_days <> DATEDIFF(
                    reference_date,
                    last_purchase_date
                )
                OR recency_days < 1
            THEN 1 ELSE 0
        END
    ), 0) AS invalid_reference_or_recency_rows,

    COALESCE(SUM(
        CASE
            WHEN TRIM(customer_id) = ''
                OR first_purchase_date > last_purchase_date
                OR purchase_frequency < 1
                OR purchase_line_count < purchase_frequency
                OR distinct_products < 1
                OR distinct_products > purchase_line_count
                OR purchase_quantity <= 0
                OR purchase_value <= 0
                OR average_order_value <> ROUND(
                    purchase_value / NULLIF(purchase_frequency, 0),
                    4
                )
            THEN 1 ELSE 0
        END
    ), 0) AS invalid_purchase_rows,

    COALESCE(SUM(
        CASE
            WHEN cancellation_frequency < 0
                OR (
                    cancellation_frequency = 0
                    AND (
                        first_cancellation_date IS NOT NULL
                        OR last_cancellation_date IS NOT NULL
                        OR cancellation_line_count <> 0
                        OR distinct_cancelled_products <> 0
                        OR cancelled_quantity <> 0
                        OR cancellation_value <> 0
                    )
                )
                OR (
                    cancellation_frequency > 0
                    AND (
                        first_cancellation_date IS NULL
                        OR last_cancellation_date IS NULL
                        OR first_cancellation_date > last_cancellation_date
                        OR last_cancellation_date >= reference_date
                        OR cancellation_line_count < cancellation_frequency
                        OR distinct_cancelled_products < 1
                        OR distinct_cancelled_products > cancellation_line_count
                        OR cancelled_quantity <= 0
                        OR cancellation_value <= 0
                    )
                )
            THEN 1 ELSE 0
        END
    ), 0) AS invalid_cancellation_rows
FROM customer_features;

# REFERENCE DATASET:
# CUSTOMER ROWS AND DISTINCT CUSTOMERS: 4334.
# CUSTOMERS WITH CANCELLATIONS: 1512.
# CUSTOMERS WITHOUT CANCELLATIONS: 2822.

# PURCHASE TOTALS:
# INVOICES: 18402.
# LINES: 396244.
# QUANTITY: 5157261.
# VALUE: 8759761.6500.

# CANCELLATION TOTALS WITHIN THE PURCHASE COHORT:
# INVOICES: 3431.
# LINES: 8530.
# QUANTITY: 269354.
# VALUE: 484080.0000.

# MINIMUM AND MAXIMUM REFERENCE DATE: 2011-12-10.
# FIRST PURCHASE: 2010-12-01 08:26:00.
# LAST PURCHASE: 2011-12-09 12:50:00.
# RECENCY RANGE: 1 TO 374 DAYS.

# VALIDATION:
# ALL THREE INVALID-ROW COUNTS SHOULD BE ZERO.
# CUSTOMER_ROWS MUST EQUAL DISTINCT_CUSTOMERS.
# THE TWO CANCELLATION-STATUS COUNTS MUST SUM TO CUSTOMER_ROWS.

# REQUIRED NON-NULL FIELDS ARE ENFORCED BY THE TABLE DEFINITION.
# THESE CHECKS VALIDATE TOTALS AND INTERNAL CONSISTENCY;
# THEY DO NOT COMPARE EVERY CUSTOMER VALUE WITH THE SOURCE VIEWS.


# SELECT THE VALIDATED CUSTOMER FEATURES FOR CSV EXPORT
# RUN AFTER REVIEWING THE STORED-TABLE VALIDATION.

# DISABLE OR INCREASE MYSQL WORKBENCH'S RESULT ROW LIMIT.
# CONFIRM ALL 4334 REFERENCE-DATA ROWS ARE RETURNED.
# EXPORT THE RESULT GRID AS customer_features.csv.
# INCLUDE COLUMN HEADERS AND ALL FEATURE COLUMNS.
# PRESERVE MISSING CANCELLATION DATES AS MISSING VALUES, NOT ZERO.

# CHECK DATE FORMATTING AFTER EXPORT.
# THE CURRENT NOTEBOOK EXPECTS reference_date AS MONTH/DAY/YEAR
# AND TRANSACTION DATES AS MONTH/DAY/YEAR HOUR:MINUTE.
# IF THE CSV USES ISO DATES, UPDATE THE NOTEBOOK'S DATE PARSING
# TO MATCH BEFORE RUNNING ITS FINAL EXPORT CELL.

# THIS SELECT DISPLAYS THE DATA; IT DOES NOT WRITE THE CSV AUTOMATICALLY.


SELECT *
FROM customer_features
ORDER BY customer_id;