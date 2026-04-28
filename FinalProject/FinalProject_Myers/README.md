# What Drives Income Shifting by Multinational Enterprises?

**Author:** Brent Myers  
**Course:** Econ 5253 — Data Science for Economists, Spring 2026  
**University of Oklahoma**

## Overview

This project examines income shifting behavior among U.S. multinational enterprises (MNEs) from 2010–2024 (excluding 2017, the TCJA transition year). It investigates how tax rate differentials, firm-specific characteristics, and the Tax Cuts and Jobs Act of 2017 influence cross-jurisdictional income shifting. The analysis uses OLS regression with robust standard errors on Compustat data accessed via WRDS.

## Repository Structure

All files are located in `/DScourseS26/FinalProject/FinalProject_Myers/`.

| File | Description |
|------|-------------|
| `is_analysis.sas` | SAS script — data extraction, cleaning, variable construction, and regression |
| `tables.R` | R script — generates LaTeX regression and summary tables from cleaned data |
| `visualizations.R` | R script — generates figures from cleaned data |
| `is_reg.csv` | Main regression dataset (1,553 obs, exported from SAS) |
| `sens_reg.csv` | Sensitivity regression dataset excluding ambiguous segments (995 obs) |
| `paper.tex` | LaTeX source for the paper |
| `references.bib` | BibTeX bibliography |
| `paper.pdf` | Compiled paper |
| `tab_summary.tex` | Auto-generated Table 1: Summary statistics |
| `tab_regression.tex` | Auto-generated Table 2: Models 1–3 |
| `tab_industry_fe.tex` | Auto-generated Table 3: Model 4 (industry FE) |
| `tab_sensitivity.tex` | Auto-generated Table 4: Sensitivity analysis |
| `fig1_income_shift_over_time.png` | Figure 1: Mean income shifting by fiscal year |
| `fig2_tax_diff_vs_shift.png` | Figure 2: Tax differential vs. income shifting scatter |
| `slides.tex` | Beamer presentation source |
| `slides.pdf` | Compiled presentation |
| `README.md` | This file |

**Note:** All output files (tables, figures, paper PDF, and slides PDF) are already included in the repository. The replication steps below describe how to reproduce them from scratch.

## Data

The raw data come from two Compustat datasets accessed via WRDS SAS Studio:

- **Compustat Fundamentals Annual** (`comp.funda`) — firm-level financial data
- **Compustat Segment Merged** (`compseg.wrds_segmerged`) — geographic segment data

**These data cannot be redistributed.** To replicate, you must have a valid WRDS account with access to Compustat North America.

The SAS script pulls directly from the WRDS cloud libraries and produces cleaned, regression-ready datasets (`is_reg.csv` and `sens_reg.csv`).

## Replication Instructions

### Step 1: Run the SAS analysis

1. Log in to WRDS SAS Studio (https://wrds-cloud.wharton.upenn.edu/SASStudio/)
2. Upload `is_analysis.sas` to your WRDS home directory
3. Create a directory `~/inc_shift` for permanent datasets: `libname isdata "~/inc_shift";`
4. Run `is_analysis.sas` — this will:
   - Extract and merge Compustat Fundamentals and Segment data
   - Classify geographic segments as domestic vs. foreign
   - Construct regression variables (income shifting measure, tax differential, firm controls)
   - Estimate OLS models with robust standard errors
   - Export `is_reg.csv` and `sens_reg.csv` for use in R

### Step 2: Generate tables in R

1. Open `tables.R` in RStudio
2. Ensure required packages are installed: `tidyverse`, `modelsummary`, `lmtest`, `sandwich`
3. Place `is_reg.csv` and `sens_reg.csv` in the working directory
4. Run the script — four `.tex` table files will be saved to the working directory

### Step 3: Generate visualizations in R

1. Open `visualizations.R` in RStudio
2. Ensure required packages are installed: `tidyverse`, `ggplot2`
3. Place `is_reg.csv` in the working directory
4. Run the script — figures will be saved as `.png` files

### Step 4: Compile the paper and slides

1. Upload `paper.tex`, `references.bib`, all `tab_*.tex` files, and all `.png` figure files to Overleaf
2. Compile `paper.tex` to produce `paper.pdf`
3. Upload `slides.tex` and figure files, then compile to produce `slides.pdf`

## Software

- **SAS 9.4** (via WRDS SAS Studio)
- **R 4.x** with packages: `tidyverse`, `ggplot2`, `modelsummary`, `lmtest`, `sandwich`
- **LaTeX** (compiled via Overleaf; requires `tabularray` and `siunitx` packages)
