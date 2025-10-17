/*
============================================================
DATA CLEANING PROJECT - NYC Restaurant Menus (1840-Present)
By Kevin Kovács
============================================================

TRANSFORMATIONS PERFORMED:
----------------------------
1. DROPPED COLUMNS:
    - language (100% NULL)
    - keywords (empty)
    - location_type (empty)

2. STANDARDIZED FORMATS:
    - date: Unified to YYYY-MM-DD format, removed invalid dates
    - currency_symbol: Converted all to ISO codes (USD, GBP, EUR, etc.)
    - event: Uppercase, removed special characters
    - venue: Mapped abbreviations to full names (COM->COMMERCIAL, etc.)

3. DATA CLEANING:
   - name: Removed placeholder values, stripped quotes
   - occasion: Fixed OCR errors, standardized anniversaries, corrected possessives
   - place: Standardized abbreviations
   - location: Moved "The" to beginning of names
   - call_number: Split into normalized version + is_wotm flag
   - sponsor: Removed brackets and special characters

4. MISSING DATA HANDLING:
   - currency: Replaced NULLs with 'Unknown'
   - Various columns: Converted empty strings and placeholders to NULL

5. DATA QUALITY IMPROVEMENTS:
   - Fixed future dates (2928->NULL)
   - Removed invalid menu entries
   - Standardized capitalization across columns

============================================================
 */

ALTER TABLE IF EXISTS lovedata2024_openrefine_menudataset
    RENAME TO restaurants;

SELECT *
FROM restaurants
LIMIT 100;

-- Find Missing Values
SELECT COUNT(*) FILTER ( WHERE name IS NULL or name = '')         AS missing_name,
       COUNT(*) FILTER ( WHERE date IS NULL)                      AS missing_date,
       COUNT(*) FILTER ( WHERE currency IS NULL or currency = '') AS missing_currency
FROM restaurants;

-- In the following segment, I will check distinct or duplicate values (to see if there are different formats, null values, placeholders, etc.)
-- In this order:
-- language, currency, status, name, date, event, venue, id, sponsor, place, physical_description
-- occasion, notes, call_number, keywords, location, location_type, currency_symbol, page_count, dish_count

---------------- LANGUAGE -----------
-- SELECT DISTINCT language
-- FROM restaurants
-- ORDER BY language;
-- Languages column is always NULL. In a real scenario this might be enriched with
-- external sources (for example: language detection). For this project, I dropped it

ALTER TABLE restaurants
    DROP COLUMN IF EXISTS language;

---------------- CURRENCY -----------
SELECT DISTINCT currency
FROM restaurants
ORDER BY currency;
-- Currency column has ~63% missing values
SELECT COUNT(*) FILTER (WHERE currency IS NULL) AS missing_currency,
       COUNT(*)                                 AS total_rows
FROM restaurants;

-- I explored multiple approaches:
-- 1. Keep NULLs for unknown values
-- 2. Fill using location or context (if available)
-- For this project I chose to replace missing currencies with Unknown to maintain completeness without introducing bias

UPDATE restaurants
SET currency = 'Unknown'
WHERE currency IS NULL;

---------------- STATUS -----------
SELECT DISTINCT status
FROM restaurants
ORDER BY status;
-- Status only has two values, no need to clean here

---------------- NAME -----------
SELECT DISTINCT name
FROM restaurants
ORDER BY name;
-- Name column has placeholder values: [Not given] and [Restaurant name and/or location not given]
-- I will standardize these values by converting to NULL for consistency

UPDATE restaurants
SET name = NULL
WHERE name ILIKE '%Not given%'
   or name ILIKE '%Restaurant name and/or location not given%';

-- Name column has values where the name is between quotes. I removed these quotes
UPDATE restaurants
SET name = TRIM(BOTH '"' FROM name)
WHERE name LIKE '"%"';

---------------- DATE -----------
SELECT DISTINCT date
FROM restaurants
ORDER BY date;
-- Date column has different formats and invalid values. I added a new column for safety/backup

ALTER TABLE restaurants
    ADD COLUMN date_clean DATE;

-- Update the table to the same format and
-- remove invalid dates (using the fact that we know the dates go from 1840 to now)

UPDATE restaurants
SET date_clean = TO_DATE(date, 'YYYY-MM-DD')
WHERE date ~ '^\d{4}-\d{2}-\d{2}$'
  AND TO_DATE(date, 'YYYY-MM-DD') >= '1840-01-01';

UPDATE restaurants
SET date_clean = TO_DATE(date, 'MM/DD/YYYY')
WHERE date ~ '^\d{1,2}/\d{1,2}/\d{4}$'
  AND TO_DATE(date, 'MM/DD/YYYY') >= '1840-01-01';

-- Remove invalid future dates
UPDATE restaurants
SET date = NULL
WHERE date > CURRENT_DATE;

-- Drop the date column and replace it with the updated column
ALTER TABLE restaurants
    DROP COLUMN date;
ALTER TABLE restaurants
    RENAME COLUMN date_clean TO date;

---------------- EVENT -----------
SELECT DISTINCT event
FROM restaurants
ORDER BY event;
-- Event column has a lot of incorrect names. The goal is to clean it consistently so analysis is possible.

-- Add a new event column for safety/backup
ALTER TABLE restaurants
    ADD COLUMN event_clean TEXT;

-- Remove brackets, quotes, question marks, etc. if they don't fit
UPDATE restaurants
SET event_clean =
        TRIM(
                REGEXP_REPLACE(
                        REGEXP_REPLACE(
                                REGEXP_REPLACE(event, '[\[\]()"?]+', '', 'g'),
                                '^''+', '', 'g'), '\s+', ' ', 'g')
        )
WHERE event IS NOT NULL;

-- Missing values -> NULL
UPDATE restaurants
SET event_clean = NULL
WHERE event_clean = ''
   OR event_clean ~ '^\s*$';

-- Uppercase
UPDATE restaurants
SET event_clean = UPPER(event_clean);

-- Drop the event column and replace it with the updated column
ALTER TABLE restaurants
    DROP COLUMN event;
ALTER TABLE restaurants
    RENAME COLUMN event_clean TO event;

---------------- VENUE -----------
SELECT DISTINCT venue
FROM restaurants
ORDER BY venue;
-- Venue column needs standardizing
-- Same method: add new column for safety/backup

ALTER TABLE restaurants
    ADD COLUMN venue_clean TEXT;

UPDATE restaurants
SET venue_clean = TRIM(
        UPPER(
                REGEXP_REPLACE(
                        REGEXP_REPLACE(venue, '[\[\]()"?.,]+', '', 'g'),
                        '\s*;\s*', ';', 'g'
                )
        )
                  )
WHERE venue IS NOT NULL;

-- My approach using mapping
-- Create new table -> insert values -> update the table using the mapped values
CREATE TABLE venue_mapping
(
    raw_value      TEXT PRIMARY KEY,
    standard_value TEXT
);

-- Pro: good for scalability because I can just add new values in the future
INSERT INTO venue_mapping (raw_value, standard_value)
VALUES ('COM', 'COMMERCIAL'),
       ('COMM', 'COMMERCIAL'),
       ('COMMERCIAL', 'COMMERCIAL'),
       ('CMMERCIAL', 'COMMERCIAL'),
       ('COMMERCOA', 'COMMERCIAL'),

       ('EDUC', 'EDUCATIONAL'),
       ('EDUCATIONAL', 'EDUCATIONAL'),
       ('EDUS', 'EDUCATIONAL'),

       ('GOV', 'GOVERNMENT'),
       ('GOVT', 'GOVERNMENT'),
       ('GOV''T', 'GOVERNMENT'),
       ('GOVERNMENT', 'GOVERNMENT'),

       ('SOC', 'SOCIAL'),
       ('SOCIAL', 'SOCIAL'),

       ('PROF', 'PROFESSIONAL'),
       ('PROFESSIONAL', 'PROFESSIONAL'),

       ('MIL', 'MILITARY'),
       ('MILITARY', 'MILITARY'),
       ('NAVAL', 'MILITARY'),

       ('FOREIGN', 'FOREIGN'),
       ('FOREIGN HOTEL', 'FOREIGN'),
       ('FOREIGN RESTAURANT', 'FOREIGN'),
       ('NULL', NULL);


UPDATE restaurants r
SET venue_clean = m.standard_value
FROM venue_mapping m
WHERE r.venue_clean = m.raw_value;

-- For business reports or dashboards I would use "Unknown" strings instead of NULL values
-- but in this project I change the strings to NULL values for better and easier analysis

UPDATE restaurants
SET venue_clean = NULL
WHERE venue_clean ILIKE 'NULL';

ALTER TABLE restaurants
    DROP COLUMN venue;
ALTER TABLE restaurants
    RENAME COLUMN venue_clean TO venue;

---------------- ID -----------
-- ID column -> checking for duplicates (result: there is none)
SELECT id, COUNT(*) AS occurrences
FROM restaurants
GROUP BY id
HAVING COUNT(*) > 1;

---------------- SPONSOR -----------
SELECT DISTINCT sponsor
FROM restaurants
ORDER BY sponsor;

-- Preview to see changes
SELECT sponsor,
       NULLIF(TRIM(REGEXP_REPLACE(sponsor, '[\[\]()"?]+', '', 'g')), '') AS sponsor_clean_preview
FROM restaurants
WHERE sponsor IS NOT NULL
LIMIT 100;

-- Remove brackets, quotes, etc. and convert empty strings to NULL
UPDATE restaurants
SET sponsor = NULLIF(
        TRIM(
                REGEXP_REPLACE(
                        REGEXP_REPLACE(sponsor, '[\[\]()"?\\]+', '', 'g'), '\s+', ' ', 'g')), '')
WHERE sponsor IS NOT NULL;

---------------- PLACE -----------
SELECT DISTINCT place
FROM restaurants
ORDER BY place;
-- Standardize, handle ? marks, fix abbreviations, correct typos
-- Preview
WITH step1 AS (SELECT NULLIF(
                              TRIM(
                                      REGEXP_REPLACE(
                                              REGEXP_REPLACE(
                                                      REGEXP_REPLACE(
                                                              REGEXP_REPLACE(
                                                                      place,
                                                                      '[\[\]()"“”]+', '', 'g'), '\?', '', 'g'),
                                                      '\s{2,}', ' ', 'g'), '[;.,]+$', '', 'g')), ''
                      ) AS place_clean
               FROM restaurants
               WHERE place IS NOT NULL),
     step2 AS (SELECT CASE
                          -- fix state/city abbreviations
                          WHEN place_clean ILIKE '%, ny' THEN REGEXP_REPLACE(place_clean, ', ny$', ', NY')
                          WHEN place_clean ILIKE '%, fla' THEN REGEXP_REPLACE(place_clean, ', fla$', ', FL')
                          WHEN place_clean ILIKE '%, cal' OR place_clean ILIKE '%, ca'
                              THEN REGEXP_REPLACE(place_clean, ', cal?', ', CA')
                          WHEN place_clean ILIKE '%, pa' THEN REGEXP_REPLACE(place_clean, ', pa$', ', PA')
                          WHEN place_clean ILIKE '%, il' THEN REGEXP_REPLACE(place_clean, ', il$', ', IL')
                          ELSE place_clean
                          END AS place_final
               FROM step1)
SELECT place_final
FROM step2
LIMIT 200;


-- update
UPDATE restaurants
SET place = (SELECT CASE
                        -- fix state/city abbreviations
                        WHEN place_clean ILIKE '%, ny' THEN REGEXP_REPLACE(place_clean, ', ny$', ', NY')
                        WHEN place_clean ILIKE '%, fla' THEN REGEXP_REPLACE(place_clean, ', fla$', ', FL')
                        WHEN place_clean ILIKE '%, cal' OR place_clean ILIKE '%, ca'
                            THEN REGEXP_REPLACE(place_clean, ', cal?', ', CA')
                        WHEN place_clean ILIKE '%, pa' THEN REGEXP_REPLACE(place_clean, ', pa$', ', PA')
                        WHEN place_clean ILIKE '%, il' THEN REGEXP_REPLACE(place_clean, ', il$', ', IL')
                        ELSE place_clean
                        END
             FROM (SELECT id,
                          CASE
                              WHEN LOWER(TRIM(
                                      REGEXP_REPLACE(
                                              REGEXP_REPLACE(
                                                      REGEXP_REPLACE(
                                                              REGEXP_REPLACE(
                                                                      restaurants.place,
                                                                      '[\[\]()"“”]+', '', 'g'),
                                                              '\?', '', 'g'), '\s{2,}', ' ', 'g'), '[;.,]+$', '', 'g')
                                         )) = 'unknown' THEN NULL
                              ELSE NULLIF(
                                      TRIM(
                                              REGEXP_REPLACE(
                                                      REGEXP_REPLACE(
                                                              REGEXP_REPLACE(
                                                                      REGEXP_REPLACE(
                                                                              restaurants.place,
                                                                              '[\[\]()"“”]+', '', 'g'
                                                                      ), '\?', '', 'g'), '\s{2,}', ' ', 'g'), '[;.,]+$',
                                                      '', 'g')), '')
                              END AS place_clean
                   FROM restaurants) sub
             WHERE sub.id = restaurants.id);

---------------- PHYSICAL DESCRIPTION -----------
SELECT physical_description
FROM restaurants
GROUP BY physical_description;
-- I don't think this column provide anything to the topic/analysis,
-- so I could drop it but I'm going to keep it in case it's needed for some reason in the future

---------------- OCCASION -----------
SELECT occasion
FROM restaurants
GROUP BY occasion;

-- Add a new column
ALTER TABLE restaurants
    ADD COLUMN occasion_clean TEXT;


UPDATE restaurants
SET occasion_clean = NULLIF(
        TRIM(
                REGEXP_REPLACE(
                        REGEXP_REPLACE(
                                REGEXP_REPLACE(
                                        REGEXP_REPLACE(
                                                REGEXP_REPLACE(
                                                        REGEXP_REPLACE(
                                                                REGEXP_REPLACE(
                                                                        REGEXP_REPLACE(
                                                                                REGEXP_REPLACE(
                                                                                        REGEXP_REPLACE(
                                                                                                INITCAP(
                                                                                                        REGEXP_REPLACE(
                                                                                                                REGEXP_REPLACE(
                                                                                                                        LOWER(occasion),
                                                                                                                        '0ther',
                                                                                                                        'other',
                                                                                                                        'g'
                                                                                                                ),
                                                                                                                'c0mpl',
                                                                                                                'compl',
                                                                                                                'g'
                                                                                                        )
                                                                                                ),
                                                                                                '([' || chr(39) ||
                                                                                                chr(8217) || '])S\b',
                                                                                                '\1s', 'g'
                                                                                        ),
                                                                                        'Amnnual|Annu Al',
                                                                                        'Annual', 'g'
                                                                                ),
                                                                                'Anniversary(esary|ersary)?',
                                                                                'Anniversary', 'gi'
                                                                        ),
                                                                        'Aniv\w*', 'Anniv', 'gi'
                                                                ), '\s{2,}', ' ', 'g'
                                                        ), '[,;]+$', '', 'g'
                                                ), '[\[\]"()]+', '', 'g'
                                        ), '\s+,', ',', 'g'
                                ), ',\s*', ', ', 'g'
                        ), '[?]+', '', 'g'
                )), ''
                     );

ALTER TABLE restaurants
    DROP COLUMN occasion;

ALTER TABLE restaurants
    RENAME COLUMN occasion_clean TO occasion;


---------------- NOTES -----------
-- Nothing to clean
SELECT notes
FROM restaurants
GROUP BY notes;


---------------- CALL NUMBER -----------
-- I deleted call numbers that include wotm, instead I made multiple columns to better showcase the important information
SELECT call_number
FROM restaurants
GROUP BY call_number;

ALTER TABLE restaurants
    ADD COLUMN call_number_normalized TEXT,
    ADD COLUMN is_wotm                BOOLEAN;

UPDATE restaurants
SET call_number_normalized = CASE
                                 WHEN call_number ~ '^[*\s]*wotm$' THEN NULL
                                 ELSE REGEXP_REPLACE(call_number, '_wotm$', '', 'i')
    END,
    is_wotm                = CASE
                                 WHEN call_number LIKE '%wotm%' THEN TRUE
                                 ELSE FALSE
        END;

ALTER TABLE restaurants
    DROP COLUMN IF EXISTS call_number;

-- Verify the results
SELECT call_number_normalized, is_wotm
FROM restaurants
LIMIT 100;


---------------- KEYWORDS -----------
-- SELECT keywords
-- FROM restaurants
--GROUP BY keywords;
-- Empty column, so I dropped it
ALTER TABLE restaurants
    DROP COLUMN IF EXISTS keywords;


---------------- LOCATION TYPE -----------
-- SELECT location_type
-- FROM restaurants
-- GROUP BY location_type;
-- Empty column, so I dropped it. If it wasn't empty then it can also be included in the "location" column if needed
ALTER TABLE restaurants
    DROP COLUMN IF EXISTS location_type;


---------------- LOCATION -----------
SELECT distinct location
FROM restaurants
GROUP BY location;
-- Fix "The" at the end of the location (supposed to be at the beginning)
UPDATE restaurants
SET location = REGEXP_REPLACE(location, '^(.+);\s*The$', 'The \1', 'i')
WHERE location ~ ';\s*The$';


---------------- CURRENCY SYMBOL -----------
SELECT distinct currency_symbol
FROM restaurants
GROUP BY currency_symbol;
-- This column needs to be standardized

UPDATE restaurants
SET currency_symbol = CASE
    -- Major currency symbols to ISO codes
                          WHEN currency_symbol = '$' THEN 'USD'
                          WHEN currency_symbol = '$U' THEN 'USD'
                          WHEN currency_symbol = '£' THEN 'GBP'
                          WHEN currency_symbol = '€' THEN 'EUR'
                          WHEN currency_symbol = '¥' THEN 'JPY'

    -- Already ISO or convert to ISO
                          WHEN currency_symbol = 'BEF' THEN 'BEF' -- Belgian Franc
                          WHEN currency_symbol = 'c' THEN 'USD' -- American Dollar
                          WHEN currency_symbol = 'C$' THEN 'CAD' -- Canadian Dollar
                          WHEN currency_symbol = 'Cr.' THEN 'CZK' -- Czech Koruna
                          WHEN currency_symbol = 'Dh' THEN 'AED' -- Dirham
                          WHEN currency_symbol = 'DM' THEN 'DEM' -- Deutsche Mark
                          WHEN currency_symbol = 'Drs.' THEN 'GRD' -- Greek Drachma
                          WHEN currency_symbol IN ('f', 'F') THEN 'NLG' -- Dutch Guilder
                          WHEN currency_symbol IN ('FF', 'Fr') THEN 'FRF' -- French Franc
                          WHEN currency_symbol = 'Ft' THEN 'HUF' -- Hungarian Forint
                          WHEN currency_symbol = 'I£' THEN 'IEP' -- Irish Pound
                          WHEN currency_symbol IN ('K', 'kr.', 'Kr.') THEN 'SEK' -- Swedish Krona
                          WHEN currency_symbol IN ('L', 'Ls') THEN 'ITL' -- Italian Lira
                          WHEN currency_symbol = 'mk' THEN 'FIM' -- Finnish Markka
                          WHEN currency_symbol = 'NT$' THEN 'TWD' -- Taiwan Dollar
                          WHEN currency_symbol = 'p' THEN 'GBP' -- British pence
                          WHEN currency_symbol = 'Pt' THEN 'ESP' -- Spanish Peseta
                          WHEN currency_symbol = 'Q' THEN 'GTQ' -- Guatemalan Quetzal
                          WHEN currency_symbol = 'QR' THEN 'SAR' -- Saudi Riyal
                          WHEN currency_symbol IN ('s', 'S', 'S/.') THEN 'PEN' -- Peruvian Sol
                          WHEN currency_symbol = 'SEK' THEN 'SEK' -- Swedish Krona
                          WHEN currency_symbol = 'zł.' THEN 'PLN' -- Polish Zloty

                          ELSE currency_symbol
    END;

-- Checking how many times each currency occurred
SELECT currency_symbol, COUNT(*)
FROM restaurants
GROUP BY currency_symbol
ORDER BY currency_symbol;


---------------- PAGE COUNT -----------
SELECT distinct page_count
FROM restaurants
GROUP BY page_count;
-- There is nothing to fix


---------------- DISH COUNT -----------
SELECT distinct dish_count
FROM restaurants
GROUP BY dish_count;
-- There is nothing to fix


-- Final data quality check
SELECT COUNT(*)                             as total_rows,
       COUNT(DISTINCT id)                   as unique_ids,
       COUNT(*) FILTER (WHERE name IS NULL) as missing_names,
       COUNT(*) FILTER (WHERE date IS NULL) as missing_dates,
       MIN(date)                            as earliest_date,
       MAX(date)                            as latest_date
FROM restaurants;


---------------- POST CLEANING FIXES -----------

-- Fix typo CHRISTMAN -> CHRISTMAS
UPDATE restaurants
SET event = REGEXP_REPLACE(event, 'CHRISTMAN', 'CHRISTMAS', 'gi')
WHERE event ILIKE '%CHRISTMAN%';

-- Fix NTH ordinal errors
UPDATE restaurants
SET occasion = REGEXP_REPLACE(occasion, '(\d+)NTH\b', '\1th', 'gi')
WHERE occasion ~ '\d+NTH\b';

-- Ensure all sponsor names are uppercase
UPDATE restaurants
SET sponsor = UPPER(sponsor)
WHERE sponsor IS NOT NULL
  AND sponsor != UPPER(sponsor);

-- Fix "The" word at the end of the sponsor names
UPDATE restaurants
SET sponsor = REGEXP_REPLACE(sponsor, '^(.+);\s*THE$', 'THE \1', 'i')
WHERE sponsor ~ ';\s*THE$';

-- Upon further review, I realized that the name, location and sponsor columns are all the same (or empty) so I merged these into the name column.
UPDATE restaurants
SET name = COALESCE(location, name, sponsor);

ALTER TABLE restaurants
    DROP COLUMN IF EXISTS sponsor,
    DROP COLUMN IF EXISTS location;

-- Export Raw Data (100 samples)
SELECT *
FROM lovedata2024_openrefine_menudataset
LIMIT 100;

-- Export Cleaned Data (100 samples)
SELECT *
FROM restaurants
LIMIT 100;