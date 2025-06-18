
-- 🧼 Data Cleaning - SQL Portfolio Project

-- Dataset Source: https://www.kaggle.com/datasets/swaptr/layoffs-2022





-- STEP 1: Exploring the data
-- Starting with a simple SELECT to understand the structure and content of the dataset

SELECT * FROM layoffs;


-- STEP 2: Creating a staging table to work on
-- It's a best practice to avoid making changes directly to the original dataset
-- This way, we can safely clean and experiment without risking the source data

CREATE TABLE layoffs_staging 
LIKE layoffs;

INSERT layoffs_staging 
SELECT * 
FROM layoffs;



-- 🔧 Cleaning Plan:
-- 1. Remove duplicates
-- 2. Standardize formatting and fix inconsistencies
-- 3. Handle NULLs and empty values
-- 4. Drop unnecessary rows/columns (if any)




-- 🔍 Step 1: Removing duplicates


-- We'll use the ROW_NUMBER() function inside a CTE to detect duplicates
-- It's more reliable than COUNT(), especially with more complex datasets
SELECT *,
  ROW_NUMBER() OVER(
      PARTITION BY company, location, industry, total_laid_off
  ) AS row_num  
FROM layoffs_staging1;


-- Wrapping it in a CTE to filter out duplicate rows (where row_num > 1)
WITH duplicates AS (
  SELECT *,
    ROW_NUMBER() OVER(
        PARTITION BY company, location, industry, total_laid_off
    ) AS row_num  
  FROM layoffs_staging1
)
SELECT *
FROM duplicates
WHERE row_num > 1;


-- We'll remove those duplicate entries by filtering out rows where row_num > 1
-- Creating a new staging table with the row_num column added
CREATE TABLE layoffs_staging1 (
  company TEXT,
  location TEXT,
  industry TEXT,
  total_laid_off INT DEFAULT NULL,
  percentage_laid_off TEXT,
  date TEXT,
  stage TEXT,
  country TEXT,
  funds_raised_millions INT DEFAULT NULL,
  row_num INT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


INSERT layoffs_staging1
SELECT *,
  ROW_NUMBER() OVER(
    PARTITION BY company, location, industry, total_laid_off,
                 percentage_laid_off, date, stage,
                 country, funds_raised_millions
  ) AS row_num  
FROM layoffs_staging;


-- Removing duplicate rows based on row_num
DELETE FROM layoffs_staging1
WHERE row_num > 1;




-- 🧽 Step 2: Standardizing the data


-- Trimming leading/trailing spaces from company names
SELECT TRIM(company)
FROM layoffs_staging1;
UPDATE layoffs_staging1
SET company = TRIM(company);

-- Same for locations: check before and after
SELECT TRIM(location), location
FROM layoffs_staging1 ORDER BY 1;
UPDATE layoffs_staging1
SET location = TRIM(location);

-- Checking for inconsistencies in industry names
SELECT DISTINCT industry 
FROM layoffs_staging1 
ORDER BY 1;

-- Found that "Crypto" appears in inconsistent formats, so I'm standardizing them
SELECT * 
FROM layoffs_staging1 
WHERE industry LIKE 'crypto%';
UPDATE layoffs_staging1
SET industry = 'crypto'
WHERE industry LIKE 'crypto%';

-- Fixing country names with trailing dots
SELECT TRIM(TRAILING '.' FROM country) 
FROM layoffs_staging1 
WHERE country LIKE 'United States%';

UPDATE layoffs_staging1
SET country = TRIM(TRAILING '.' FROM country)
WHERE country LIKE 'United States%';

-- Converting the date column from text to a standard DATE format
SELECT DISTINCT date,
 STR_TO_DATE(date, '%m/%d/%Y') 
FROM layoffs_staging1;

UPDATE layoffs_staging1
SET date = STR_TO_DATE(date, '%m/%d/%Y');

-- Updating the column type from TEXT to DATE for proper handling
ALTER TABLE layoffs_staging1
MODIFY COLUMN date DATE;



-- ⚠️ Step 3: Handling NULLs and blank fields


-- Checking for missing or empty values in the industry column
SELECT * 
FROM layoffs_staging1
WHERE industry IS NULL OR industry = '';

-- Before running any EDA, I'm checking if these missing values can be filled
-- by matching other rows from the same company
SELECT * 
FROM layoffs_staging1
WHERE company LIKE 'Carvana%';

-- Preparing to fill missing industries by using a self-join strategy
-- First, converting empty strings to NULLs for easier handling
UPDATE layoffs_staging1
SET industry = NULL
WHERE industry = '';

SELECT *
FROM layoffs_staging1 t1
JOIN layoffs_staging1 t2
ON t1.company = t2.company
WHERE t1.industry IS NULL;

UPDATE layoffs_staging1 t1
JOIN layoffs_staging1 t2
ON t1.company = t2.company
SET t1.industry = t2.industry
WHERE t1.industry IS NULL 
AND t2.industry IS NOT NULL;


-- 4. Removing unreliable data  


-- Rows missing both 'total_laid_off' and 'percentage_laid_off' lack essential information  
-- Since we can't trust these incomplete records, we will remove them 
DELETE 
FROM layoffs_staging1
WHERE total_laid_off IS NULL 
  AND percentage_laid_off IS NULL;
  
-- dropping 'row_num' column now
ALTER TABLE layoffs_staging1
DROP COLUMN row_num;

-- now we see the final result :)
SELECT*
FROM layoffs_staging1