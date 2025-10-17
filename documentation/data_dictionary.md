# Data Dictionary

## Final Table: `restaurants`

### Core Information

| Column | Data Type | Description | Example | Notes |
|--------|-----------|-------------|---------|-------|
| `id` | INTEGER | Unique menu identifier | 13355 | Primary key, auto-generated |
| `name` | TEXT | Restaurant/venue/organization name | "The Dakota" | Consolidated from 3 original columns; NULL if not provided |
| `date` | DATE | Menu service date | 1900-12-25 | Range: 1851-01-01 to 2025-10-14; NULL for invalid dates |
| `place` | TEXT | Geographic location | "NEW YORK, NY" | State abbreviations standardized (NY, PA, FL, etc.) |

### Menu Details

| Column | Data Type | Description | Example | Notes |
|--------|-----------|-------------|---------|-------|
| `event` | TEXT | Type of event | "CHRISTMAS DINNER" | All uppercase; special characters removed |
| `venue` | TEXT | Venue category | "COMMERCIAL" | Standardized values only (see Venue Categories) |
| `occasion` | TEXT | Special occasion | "Anniversary" | Title case; OCR errors corrected |
| `physical_description` | TEXT | Physical characteristics | "CARD; ILLUS; 5X8" | Format and dimensions of menu |
| `page_count` | INTEGER | Number of pages | 4 | No cleaning applied |
| `dish_count` | INTEGER | Number of dishes listed | 127 | No cleaning applied |
| `status` | TEXT | Completeness status | "complete" | Values: "complete", "under review" |

### Financial Information

| Column | Data Type | Description | Example | Notes |
|--------|-----------|-------------|---------|-------|
| `currency` | TEXT | Currency name | "Dollars" | "Unknown" replaces NULL values (63% were missing) |
| `currency_code` | TEXT | ISO 4217 currency code | "USD" | Standardized to 23 ISO codes; originally 30+ formats |

### Archive Information

| Column | Data Type | Description | Example | Notes |
|--------|-----------|-------------|---------|-------|
| `call_number_normalized` | TEXT | Archive catalog number | "1901-2313" | Original suffix `_wotm` removed for clarity |
| `is_wotm` | BOOLEAN | NYPL WOTM collection flag | TRUE | TRUE = part of "What's On The Menu" collection |

### Additional Fields

| Column | Data Type | Description | Example | Notes |
|--------|-----------|-------------|---------|-------|
| `notes` | TEXT | Additional context | Free text | No standardization applied |

---

## Venue Categories

Standard values in `venue` column:

| Category | Description |
|----------|-------------|
| COMMERCIAL | Restaurants, hotels, dining establishments |
| SOCIAL | Social clubs, societies, associations |
| GOVERNMENT | Government institutions, official events |
| MILITARY | Military vessels, bases, events |
| EDUCATIONAL | Schools, universities, educational institutions |
| PROFESSIONAL | Professional organizations, conferences |
| FOREIGN | Foreign steamships, embassies |

---

## Event Types

Common values in `event` column (examples):

- BREAKFAST
- LUNCH
- DINNER
- SUPPER
- ANNUAL BANQUET
- GALA
- CONFERENCE
- CHRISTIMAS DINNER
- TABLE D'HOTE

---

## Occasion Types

Common values in `occasion` column (examples):

- Anniversary
- Birthday
- Religious Holiday
- Patriotic Holiday
- Wedding
- Corporate Event
- Complimentary/Testimonial
- Daily Menu
- Other

---

## Currency Codes

All 23 standardized ISO 4217 codes in dataset:

| Code | Currency | Example Original Format |
|------|----------|------------------------|
| USD | US Dollar | $, c |
| GBP | British Pound | £, p |
| EUR | Euro | € |
| JPY | Japanese Yen | ¥ |
| CAD | Canadian Dollar | C$ |
| AED | UAE Dirham | Dh |
| CZK | Czech Koruna | Cr. |
| DEM | Deutsche Mark | DM |
| GRD | Greek Drachma | Drs. |
| NLG | Dutch Guilder | f, F |
| FRF | French Franc | FF, Fr |
| HUF | Hungarian Forint | Ft |
| IEP | Irish Pound | I£ |
| ITL | Italian Lira | L, Ls |
| SEK | Swedish Krona | K, kr., Kr. |
| FIM | Finnish Markka | mk |
| TWD | Taiwan Dollar | NT$ |
| ESP | Spanish Peseta | Pt |
| GTQ | Guatemalan Quetzal | Q |
| SAR | Saudi Riyal | QR |
| PEN | Peruvian Sol | s, S, S/. |
| BEF | Belgian Franc | BEF |
| PLN | Polish Zloty | zł. |

---

## Data Quality Flags

### NULL Handling

- `name` = NULL: Restaurant/venue name not provided in original data
- `currency` = "Unknown": Original value was NULL (63% of records)
- `occasion` = NULL: No specific occasion recorded
- `date` = NULL: Date format invalid or outside 1840-2025 range

### Missing Data Summary

| Column | Missing Count | Missing % |
|--------|---------------|-----------|
| name | ~2,000 | ~11% |
| date | 589 | 3.4% |
| occasion | ~8,000 | ~45% |
| currency | 0 | 0% (replaced with "Unknown") |

---

## Data Type Notes

- **DATE**: PostgreSQL DATE type enables date arithmetic and sorting
- **BOOLEAN**: TRUE/FALSE values
- **TEXT**: Variable length, no character limit enforced
- **INTEGER**: Whole numbers only, no decimal values