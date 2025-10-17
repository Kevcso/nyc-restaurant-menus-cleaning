# NYC Restaurant Menus Data Cleaning Project

## Overview

Comprehensive data cleaning project on 17,544 historical restaurant menu records from the New York Public Library's "What's On The Menu" collection, spanning from 1840 to 2025.

## Dataset Information

- **Source**: New York Public Library - What's On The Menu
- **Records**: 17,544 menu entries
- **Time Period**: 1840 - 2025
- **Original Issues**: OCR errors, inconsistent formatting, missing values, duplicate columns

## Cleaning Summary

### Columns Dropped
- `language` - 100% NULL values
- `keywords` - Empty column
- `location_type` - Empty column
- `call_number` - Replaced with normalized version + boolean flag

### Key Transformations

| Column | Issues | Solution |
|--------|--------|----------|
| `date` | Multiple formats, invalid dates | Unified to DATE type, removed dates > 2025 |
| `currency_code` | 30+ inconsistent symbols | Standardized to 23 ISO codes (USD, GBP, EUR, etc.) |
| `event` | Mixed case, special characters | UPPERCASE, removed brackets/quotes |
| `venue` | Abbreviations (COM, GOV, PROF) | Mapped to full names using lookup table |
| `occasion` | OCR errors, typos | Fixed: `0ther`→`other`, `'S`→`'s`, `aniv`→`anniv` |
| `name` | Duplicated across 3 columns | Consolidated from name/sponsor/location |

### Data Quality Results

**Before:**
- 14,485 missing names (82.6%)
- 589 missing dates (3.4%)
- 30+ currency formats
- 15,000+ OCR errors in occasion field

**After:**
- Standardized to 23 ISO currency codes
- All OCR errors fixed
- Consistent formatting across columns
- 17,544 records with proper data types

## Technologies Used

- **Database**: PostgreSQL
- **IDE**: DataGrip
- **Techniques**: 
  - Regular expressions (REGEXP_REPLACE)
  - Common Table Expressions (CTEs)
  - Mapping tables for standardization
  - Window functions
  - Date parsing and validation

## Project Structure

```
nyc-restaurant-menus-cleaning/
├── README.md                          # This file
├── data/
│   ├── raw/
│   │   └── restaurants_raw_sample.xlsx        # Original messy data (100 rows)
│   └── cleaned/
│       └── restaurants_cleaned_sample.xlsx    # Cleaned data (100 rows)
├── sql/
│   └── data_cleaning.sql              # Complete cleaning script
├── documentation/
│   ├── data_dictionary.md             # Column descriptions
│   └── cleaning_decisions.md          # Rationale for cleaning choices
└── images/
    └── screenshots/                   # Before/after comparisons
```


## Key Features

✅ Scalable venue mapping using lookup table  
✅ Comprehensive OCR error correction  
✅ Handles multiple date formats  
✅ Standardized currency codes for international data  
✅ Safe approach with temporary backup columns  
✅ Well-documented decision rationale  

## Data Dictionary

| Column | Type | Description |
|--------|------|-------------|
| `id` | INTEGER | Unique menu identifier |
| `name` | TEXT | Restaurant/venue name |
| `date` | DATE | Menu service date (1851-2025) |
| `place` | TEXT | Geographic location (city, state) |
| `event` | TEXT | Event type (DINNER, BREAKFAST, etc.) |
| `venue` | TEXT | Venue category (COMMERCIAL, SOCIAL, etc.) |
| `occasion` | TEXT | Special occasion (Anniversary, Birthday, etc.) |
| `call_number_normalized` | TEXT | Archive reference number |
| `is_wotm` | BOOLEAN | Part of NYPL WOTM collection |
| `currency_code` | TEXT | ISO 4217 currency code |
| `page_count` | INTEGER | Number of menu pages |
| `dish_count` | INTEGER | Number of dishes listed |

## Next Steps

This cleaned dataset could be used for:
- Power BI dashboard analyzing restaurant trends over 180 years
- Customer segmentation analysis by venue type and era
- Historical dining pattern exploration

## Author

**Kevin Kovács**  
Portfolio Project
