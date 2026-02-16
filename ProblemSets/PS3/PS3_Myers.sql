-- (a) Read in the Florida insurance CSV into a table called fl_ins
DROP TABLE IF EXISTS fl_ins;
.mode csv
.import FL_insurance_sample.csv fl_ins

-- (b) Print first 10 rows
SELECT * FROM fl_ins
LIMIT 10;

-- (c) List unique counties and provide total number of distinct counties
SELECT DISTINCT county
FROM fl_ins
ORDER BY county;

SELECT COUNT(DISTINCT county) AS n_counties
FROM fl_ins;

-- (d) Average property appreciation (2011 to 2012)
SELECT AVG(tiv_2012 - tiv_2011) AS avg_appreciation
FROM fl_ins;

-- (e) Construction frequency table with fractions
SELECT construction,
       COUNT(*) AS n,
       1.0 * COUNT(*) / (SELECT COUNT(*) FROM fl_ins) AS fraction
FROM fl_ins
GROUP BY construction
ORDER BY n DESC;

