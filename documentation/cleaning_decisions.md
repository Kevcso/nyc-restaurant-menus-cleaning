# Data Cleaning Decisions & Rationale

## Philosophy

This project prioritizes **data integrity** and **analytical clarity** over completeness. When faced with ambiguous or missing data, decisions were made to preserve accuracy rather than introduce bias through assumptions.

---

## Column-by-Column Decisions

### DROPPED COLUMNS

#### Language
**Decision**: DROP (100% NULL)  
**Rationale**: 
- Every single record had NULL values
- No value for analysis

#### Keywords
**Decision**: DROP (empty)  
**Rationale**:
- Column provided no data
- Information redundant with other fields
- Takes up unnecessary storage

#### Location Type
**Decision**: DROP (empty)  
**Rationale**:
- Empty column
- Venue type captured in `venue` column already
- Would be redundant data

#### Call Number (original)
**Decision**: SPLIT into `call_number_normalized` + `is_wotm` boolean  
**Rationale**:
- Original column mixed catalog numbers with metadata flag (`_wotm`)
- Separating into two columns improves queryability
- Boolean flag enables filtering by collection source
- Cleaner data model for analysis

---

### DATE

**Original Issues**: Multiple formats (YYYY-MM-DD, MM/DD/YYYY), invalid dates (future dates like 2928)

**Decision**: Unified to PostgreSQL DATE type with range validation

**Approach**:
```
1. Parse YYYY-MM-DD format
2. Parse MM/DD/YYYY format
3. Validate range: 1840-01-01 to CURRENT_DATE
4. Set invalid dates to NULL
```

**Rationale**:
- DATE type enables proper sorting and arithmetic
- Invalid dates removed rather than guessed
- Historical context (1840-present) used as validation boundary
- NULL is semantically correct for truly unknown dates

**Trade-off**: 589 records lost date information but quality improved

---

### CURRENCY

**Original Issue**: 63% NULL values; inconsistent format

**Decision**: Replace NULL with "Unknown" instead of deleting records

**Rationale**:
- Maintains record count (important for analysis)
- "Unknown" is explicit and queryable (unlike NULL)
- Better for business reporting/dashboards
- Doesn't introduce bias by guessing currency
- Alternative: Could have inferred from location but risky for historical data

**Trade-off**: Less pure from analytical perspective but more practical

---

### CURRENCY SYMBOL

**Original Issue**: 30+ inconsistent formats ($, £, c, Fr, Drs., etc.)

**Decision**: Standardize to ISO 4217 three-letter codes

**Rationale**:
- International standard enables currency conversion
- Unambiguous (no ambiguity like "$" could mean USD, CAD, AUD, etc.)
- Machine-readable
- Facilitates future currency analysis or exchange rate calculations

**Mapping Examples**:
- `$`, `c` → `USD` (context: historical NYC restaurant data)
- `£`, `p` → `GBP` (British pound and pence)
- `Fr`, `FF` → `FRF` (French Franc variants)

**Validation**: All 23 codes cross-referenced with ISO 4217 standard

---

### NAME

**Original Issues**: 
- Placeholder values: "[Not given]", "[Restaurant name and/or location not given]"
- Values in quotes: `"Hotel Dakota"`
- Duplicated across 3 columns (name, sponsor, location)

**Decision**: 
1. Remove placeholders → NULL
2. Strip quotes
3. Consolidate from 3 columns into 1

**Rationale**:
- "[Not given]" is metadata, not data
- Quotes are formatting artifacts
- Three identical columns = redundant storage
- Consolidation improves data model clarity


---

### OCCASION

**Original Issues**: 15,000+ OCR errors from historical document scanning

**Examples of Corrections**:
| Before | After | Fix |
|--------|-------|-----|
| `?Anniv?` | `Anniversary` | Removed question marks |
| `0ther` | `Other` | OCR: zero → letter 'o' |
| `c0mpl` | `Compl` | OCR: zero → letter 'o' |
| `Lincoln'S` | `Lincoln's` | INITCAP capitalized after apostrophe |
| `aniv`, `anniv`, `anivv` | `Anniv` | Normalized variations |
| `Amnnual`, `Annu al` | `Annual` | Fixed typos/spacing |

**Decision**: Pattern-based regex corrections + INITCAP + manual standardization

**Rationale**:
- OCR artifacts common in historical documents
- Regular expressions handle bulk corrections efficiently
- INITCAP provides consistent Title Case
- Manual standardization (anniversary → Anniversary) improves clarity

**Quality Check**: Sample 50 records manually verified

---

### EVENT

**Original Issues**: Mixed case, special characters, varying conventions

**Decision**: UPPERCASE + remove brackets/quotes + collapse spaces

**Rationale**:
- UPPERCASE standardizes all event names
- Special characters removed (database artifacts)
- Consistent format enables grouping and analysis

**Example**:
```
"[CHRISTMAS DINNER]" → CHRISTMAS DINNER
```

---

### VENUE

**Original Issues**: Abbreviations (COM, GOV, PROF, SOCIAL, etc.) and typos

**Decision**: Create mapping table for scalable standardization

**Rationale**:
- **Scalability**: Easy to add new mappings in future
- **Auditability**: Mapping table serves as documentation
- **Reusability**: Can be used across multiple tables/projects

**Mapping Approach**:
```sql
CREATE TABLE venue_mapping (
    raw_value      TEXT PRIMARY KEY,
    standard_value TEXT
);
```

**Standards Applied**:
- COM, COMM → COMMERCIAL
- GOV, GOVT → GOVERNMENT
- SOCIAL, SOC → SOCIAL
- MILITARY, MIL, NAVAL → MILITARY
- PROFESSIONAL, PROF → PROFESSIONAL
- EDUCATIONAL, EDUC → EDUCATIONAL

---

### PLACE (Geographic Location)

**Original Issues**: 
- Mixed case
- Trailing punctuation
- Abbreviations (ny, fla, pa, il, cal)
- Special characters, question marks

**Decision**: Standardize abbreviations to uppercase state codes

**Rationale**:
- Consistent state abbreviations enable geographic grouping
- NY vs ny vs N.Y. would otherwise create duplicates
- Question marks removed (scanning artifacts)

**Standardizations**:
- `ny` → `NY`
- `fla` → `FL`
- `cal` or `ca` → `CA`
- `pa` → `PA`
- `il` → `IL`

---

### SPONSOR & LOCATION (Consolidation)

**Original Issue**: Three columns (name, sponsor, location) contained identical/redundant data

**Decision**: Consolidate into single `name` column; drop `sponsor` and `location`

**Rationale**:
- Redundant storage wastes space
- Three columns doing same job = poor data modeling
- Consolidation using COALESCE picks best available value
- Improves clarity (one name field instead of three)

**Order of Priority**:
1. location (cleanest, Title Case)
2. name (original)
3. sponsor (original)

---

### IS_WOTM (Boolean Flag)

**Original Issue**: Metadata (WOTM collection indicator) mixed into call_number as suffix

**Decision**: Extract into separate BOOLEAN column

**Rationale**:
- Separates concerns (catalog number vs collection source)
- BOOLEAN type semantically correct for yes/no flags
- Enables efficient filtering/aggregation
- Improves query clarity

**Population Logic**:
```sql
is_wotm = CASE
    WHEN call_number LIKE '%_wotm' THEN TRUE
    ELSE FALSE
END
```

---

## Overall Philosophy Decisions

### NULL vs "Unknown"

**Decision**: Mixed approach based on context

**For `currency`**: NULL → "Unknown"  
- Rationale: Missing currency shouldn't delete record; "Unknown" is explicit

**For other columns**: NULL = NULL  
- Rationale: Better for analysis, can filter/aggregate more easily

### Data Loss vs Data Quality

**Example**: 589 invalid dates removed

**Trade-off Analysis**:
- **Cost**: Lost date information for 3.4% of records
- **Benefit**: Remaining 96.6% have validated, usable dates
- **Decision**: Accept loss for quality

### Safe Approach

**Method**: Created backup columns before transformations

**Example**:
```sql
ALTER TABLE restaurants ADD COLUMN date_clean DATE;
-- Populate date_clean
ALTER TABLE restaurants DROP COLUMN date;
ALTER TABLE restaurants RENAME COLUMN date_clean TO date;
```

**Rationale**: Safety net if transformation logic had errors

---

## Future Improvements

1. **Language Detection**: Use NLP to auto-populate language field
2. **Price Standardization**: Parse prices from descriptions, standardize to USD

---

## Validation & Quality Assurance

### Checks Performed

1. **Duplicate ID check**: Confirmed 17,544 unique IDs
2. **Date range validation**: Confirmed 1851-2025 range
3. **Data type validation**: All columns proper types
4. **Categorical values**: All venue/event values in approved lists
5. **Mapping completeness**: All original values covered in venue_mapping

### Known Limitations

- Historical OCR data will have uncorrected errors despite best efforts
- Some records have minimal information (minimal context for cleaning decisions)
- Currency inferences made conservatively (63% "Unknown" rather than guessed)
- Date range chosen as 1840-present (may exclude some valid edge cases)