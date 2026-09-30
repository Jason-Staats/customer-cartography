# Customer Cartography
### Retail Customer Segmentation by Purchase and Cancellation Activity

## Overview

Customers differ in how recently they purchase, how often they order, how much they spend, and how much cancellation activity they record. Understanding these differences can help a business identify where further investigation or targeted experiments may be useful.

This project examines those patterns using the UCI Online Retail dataset. The central question is how purchasing and cancellation behavior can define interpretable customer segments and inform proposed business actions.

The workflow uses **MySQL** to prepare customer features, **Python** to develop and evaluate segments, and **Power BI** to communicate the findings.

**[Explore the Interactive Power BI Report](https://app.powerbi.com/view?r=eyJrIjoiMjU1MjI3NjItNzM4Zi00NTg3LWE1ZGMtNDY1M2Y0OWJjMTZiIiwidCI6ImFjZmM5MDhlLTk0YWEtNDVkMi04OWE3LTcwMjg4MmYyMjc4MiJ9)**

[View the Report PDF](CustomerCartography.pdf) | [Read the Analysis Notebook](retail_pca.ipynb) | [Explore the SQL Workflow](SQL/)

## Report Guide

The Power BI report contains five pages:

| Page | Title | Purpose |
|---|---|---|
| 1 | Overview | Summarize the analyzed customers, purchase activity, and each segment's contribution to purchase value |
| 2 | Segment Profiles | Compare original-unit purchasing medians and cancellation participation |
| 3 | Evidence to Execution | Connect findings to proposed actions and evaluation approaches |
| 4 | Methods and Workflow | Explain the progression from source transactions to customer segments |
| 5 | Validation | Present model selection, consistency checks, and standardized feature profiles |

## Key Findings

The final analysis includes **4,332 customers**, **18,399 qualifying purchase invoices**, and **£8,514,105.55 in purchase value before cancellations**.

| Segment | Customers | Customer Proportion | Purchase Value Proportion |
|---|---:|---:|---:|
| High activity, frequent cancellations | 436 | 10.06% | 50.81% |
| Moderate purchases, minimal cancellations | 1,416 | 32.69% | 26.13% |
| Moderate purchases, some cancellations | 959 | 22.14% | 18.33% |
| Less recent, infrequent purchases | 1,521 | 35.11% | 4.73% |

- The high activity group represents approximately one in ten analyzed customers but accounts for just over half of qualifying purchase value.
- Less recent, infrequent purchasers form the largest segment. Their median purchase frequency is one invoice, and their median recency is 142 days.
- The moderate purchasing groups have similar median recency at 37 and 36 days. Their cancellation participation differs sharply, at 0.14% and 100%.
- High activity customers have a median purchase value of £4,611.36, compared with £226.78 for less recent, infrequent purchasers.

Cancellation measures contribute directly to the clustering. Differences in cancellation participation describe the resulting segments but are not independent validation of their usefulness.

## Proposed Business Actions

The report connects the findings to three proposals:

| Opportunity | Proposed Action | Evaluation |
|---|---|---|
| Increase purchase value among high activity customers | Randomly assign customers to reorder reminders or established communications | Compare purchase value per assigned customer over the same predefined period, supported by purchase frequency, cancellation activity, and campaign costs |
| Strengthen understanding of seasonal purchasing | Investigate purchase timing and product types, then collect additional transaction history | Compare purchasing across equivalent seasonal periods and measure returning customers while accounting for available follow-up time |
| Explore patterns associated with cancellations | Investigate product mix and order histories in the moderate purchasing groups | Assess whether those patterns provide information beyond the cancellation measures already used to define the segments |

These are proposed investigations and experiments. Their effects have not been tested.

## Data Source and Scope

- **Dataset:** [Online Retail](https://archive.ics.uci.edu/dataset/352/online+retail)
- **Provider:** UCI Machine Learning Repository
- **Context:** Transactions from a UK-based online retailer
- **Observation period:** December 1, 2010, through December 9, 2011
- **Recency reference date:** December 10, 2011
- **Currency:** GBP

The source contains **4,372 distinct identified customers**. Purchase eligibility rules produce a feature table for **4,334 purchasing customers**.

The notebook excludes customers `12346` and `16446` after reviewing their exceptionally large purchases and equal or nearly equal cancellation totals. This leaves **4,332 customers** for segmentation. The exclusions are analytical scope decisions, not findings that the records are errors.

Purchase value includes qualifying merchandise purchases before cancellations. Cancellation measures describe recorded activity and have not been verified as matched refunds. These measures do not establish net revenue or profit.

## Methodology

### SQL Preparation

The SQL workflow organizes source records into staging, customer, invoice, product, and invoice-line tables.

Investigations examine missing identifiers, product descriptions, prices, special stock codes, repeated records, and cancellation activity. Separate analytical views define qualifying merchandise purchases and cancellations.

Purchases and cancellations are aggregated independently before being joined at customer level. This avoids multiplying transaction rows when combining the two types of activity.

The resulting table contains 12 behavioral features:

| Purchasing Features | Cancellation Features |
|---|---|
| Recency days | Cancellation frequency |
| Purchase frequency | Cancellation line count |
| Purchase line count | Distinct cancelled products |
| Distinct products | Cancelled quantity |
| Purchase quantity | Cancellation value |
| Purchase value | |
| Average order value | |

The analysis includes recency, frequency, and monetary value, but the additional features make it a broader behavioral segmentation rather than an RFM-only model.

### Python Analysis

The notebook follows a documented exploratory workflow:

1. Standardize the initial features and examine PCA and KMeans results.
2. Review exceptional customer profiles and exclude two customers.
3. Refit preprocessing and clustering on the retained customers.
4. Compare remaining small groups using KMeans and hierarchical clustering.
5. Retain all remaining customers and apply `log1p` to eleven features, leaving recency unlogged.
6. Standardize all twelve features and refit PCA.
7. Compare candidate cluster counts using silhouette scores, sizes, and profiles in original units.
8. Evaluate the selected model and validate its exports.

The final model uses **three principal components**, retaining approximately **87.16% of standardized feature variance**, and **four KMeans clusters**.

### Power BI Reporting

Power BI presents the finalized customer assignments and summaries. It communicates segment profiles, proposed business actions, methodological decisions, and validation results.

Clustering and model comparisons are performed in Python.

## Model Selection and Validation

| Assessment | Result | Interpretation |
|---|---|---|
| Number of clusters | Two clusters achieved the highest tested silhouette score at 0.469. Four clusters scored 0.358. | Four clusters were selected for additional purchasing and cancellation detail, accepting lower statistical separation |
| Random initialization | Customer groupings matched across six tested random seeds | The selected solution was consistent across the tested starting points |
| Repeated-record sensitivity | 4,322 of 4,332 customers, or 99.77%, remained in corresponding segments. Adjusted Rand index was 0.992806. | Main findings changed very little under the tested alternative treatment of repeated records |

The primary analysis retains all recorded occurrences because repeated source rows were not established to be errors.

The sensitivity alternative keeps one occurrence per exact group across the eight loaded source fields. Standardization, PCA, and KMeans are refitted separately for this alternative.

## Tools and Libraries

| Tool | Purpose |
|---|---|
| MySQL / MySQL Workbench | Relational data preparation, transaction investigation, feature engineering, and validation |
| Python / Jupyter Notebook | Exploratory analysis, preprocessing, segmentation, and export validation |
| pandas and NumPy | Data manipulation and numerical calculations |
| scikit-learn | Standardization, PCA, KMeans, silhouette scores, and adjusted Rand index |
| SciPy | Hierarchical clustering |
| Matplotlib and seaborn | Analytical charts and feature-profile visualizations |
| Power BI Desktop | Report development, measures, and visual presentation |

## Reproducing the Analysis

### Run the Notebook from Prepared Inputs

The notebook requires these two CSV files in the same folder:

- `customer_features.csv`
- `customer_features_one_per_group.csv`

Each input should contain **4,334 data rows and 18 columns, plus one header row**. Keep customers `12346` and `16446` in these inputs. The notebook applies the exclusions.

Install the required libraries:

```bash
pip install pandas numpy matplotlib seaborn scikit-learn scipy jupyter
```

Start Jupyter from the project folder, open `retail_pca.ipynb`, and run all cells in order.

Check that the primary CSV's date formats match the explicit parsing formats in the notebook's final export cell. Preserve missing cancellation dates as missing values.

The notebook validates the inputs, selected customer table, cluster assignments, and summary totals. It writes these files to `Exports/`:

- `log_segment_profiles_heatmap_values.csv`
- `retail_customer_segments.csv`
- `retail_segment_profiles.csv`
- `retail_segment_summary.csv`
- `retail_segment_cancellations.csv`

The four final customer and segment tables are read back and compared with the in-memory results after export.

### Rebuild the Inputs from Source Data

Use MySQL 8.0 or a compatible version. Follow the source download and CSV preparation instructions in `SQL/staging.sql`.

Adjust the server import path and verify the CSV encoding, line endings, and date format before loading.

Run the scripts in this order, reviewing validation results at each checkpoint:

1. `staging.sql`
2. `invoice.sql`
3. `customer.sql`
4. `product.sql`
5. `invoice_line.sql`
6. `transaction_cleaning.sql`
7. `analytical_views.sql`
8. `customer_features.sql`
9. `duplicate_sensitivity.sql`
10. `final_validation.sql`

The build scripts are intended for a fresh database. Rerunning the staging load or invoice-line insert can append duplicate records. Run the temporary-table workflow in `product.sql` in one connection.

Export the primary feature result from `customer_features.sql` as `customer_features.csv`. Export the alternative feature result from `duplicate_sensitivity.sql` as `customer_features_one_per_group.csv`.

The SQL queries display results. They do not write these CSV files automatically. Disable or increase the Workbench result-row limit so the exports include all customers.

`final_validation.sql` checks summary totals in the primary feature table. It does not validate the alternative CSV or the notebook's cluster assignments.

## Limitations

- The analysis is retrospective and covers approximately one year of transactions. Older purchases alone do not establish churn or seasonal purchasing.
- Segment names describe group tendencies. Purchasing distributions overlap, and the selected cluster count reflects interpretability as well as statistical evaluation.
- Cancellation activity is recorded separately from purchases. No transaction-level refund matching is established.
- Initialization consistency and repeated-record sensitivity do not demonstrate stability over time or robustness to every modeling choice.
- Proposed business actions require additional data and evaluation before their effectiveness can be established.

## Data Source Citation

Chen, D. (2015). *Online Retail* [Dataset]. UCI Machine Learning Repository. https://doi.org/10.24432/C5BW33

## Licensing

The original project code is licensed under the [MIT License](LICENSE).

The Online Retail dataset by Daqing Chen is provided through the UCI Machine Learning Repository under [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/).

The included CSV files are derived from that dataset through the filtering, aggregation, feature engineering, and segmentation steps documented in this repository. The MIT license does not replace the source dataset's license.

## Author

[Jason Staats](https://github.com/Jason-Staats)
