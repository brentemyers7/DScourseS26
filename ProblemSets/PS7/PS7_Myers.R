# ============================================================================
# Problem Set 7 — Imputing Missing Data & Automated Reporting
# Econ 5253: Data Science for Economists
# ============================================================================


# Load required libraries
library(tidyverse)    # data wrangling and visualization
library(mice)         # multiple imputation for missing data
library(modelsummary) # automated summary stats and regression tables in LaTeX
library(naniar)       # MCAR testing


# --- Step 1: Load and prepare data -------------------------------------------

# Load the wages dataset (approx. 2,250 women working in US in 1988)
df <- read_csv("wages.csv")

# Preview the structure of the data
glimpse(df)

# Drop rows where hgc or tenure are missing (per PS7 instructions)
df <- df %>% filter(!is.na(hgc) & !is.na(tenure))

# Confirm new number of observations (should be 2,229)
nrow(df)


# --- Step 2: Summary statistics ----------------------------------------------

# View summary stats in RStudio Viewer pane
datasummary_skim(df)

# Generate LaTeX table without histograms (cleaner for Overleaf)
datasummary_skim(df, output = "latex", histogram = FALSE)

# Calculate the fraction of logwage observations that are missing (~25.1%)
sum(is.na(df$logwage)) / nrow(df)


# --- Step 3: Test missingness mechanism --------------------------------------

# Test for MCAR — p-value near 0 means we reject MCAR
mcar_test(df)

# Test for MAR — logistic regression of missingness on observed variables
# Significant coefficients (p < 0.05) indicate MAR
df$logwage_miss <- is.na(df$logwage)
summary(glm(logwage_miss ~ hgc + college + tenure + age + married,
            family = binomial, data = df))
# Result: hgc and tenure are highly significant (p < 2e-16) → supports MAR

# Remove the temporary missingness indicator before modeling
df <- df %>% select(-logwage_miss)


# --- Step 4: Regression models with different imputation methods -------------

# Model 1: Complete cases (listwise deletion — assumes MCAR)
# lm() automatically drops rows where logwage is NA
est_listwise <- lm(logwage ~ hgc + college + tenure + I(tenure^2) + age + married,
                   data = df)
summary(est_listwise)

# Model 2: Mean imputation — replace missing logwage with the mean of observed logwage
df_mean_imp <- df %>%
  mutate(logwage = ifelse(is.na(logwage), mean(logwage, na.rm = TRUE), logwage))

est_mean_imp <- lm(logwage ~ hgc + college + tenure + I(tenure^2) + age + married,
                   data = df_mean_imp)
summary(est_mean_imp)

# Model 3: Predicted value imputation — assumes MAR
# Use the complete cases model to predict logwage for observations where it's missing
df_pred_imp <- df %>%
  mutate(logwage = ifelse(is.na(logwage), predict(est_listwise, newdata = .), logwage))

est_pred_imp <- lm(logwage ~ hgc + college + tenure + I(tenure^2) + age + married,
                   data = df_pred_imp)
summary(est_pred_imp)

# Model 4: Multiple imputation via mice — accounts for uncertainty in imputed values
# Run mice to create multiple imputed datasets (default is 5 imputations)
imp <- mice(df, m = 5, method = "pmm", seed = 12345, printFlag = FALSE)

# Estimate the regression on each imputed dataset and pool the results
est_mice <- with(imp, lm(logwage ~ hgc + college + tenure + I(tenure^2) + age + married))
est_mice_pooled <- pool(est_mice)
summary(est_mice_pooled)


# --- Step 5: Combined regression table ---------------------------------------

# Combine all four models into one LaTeX regression table using modelsummary
# Note: mice pooled results need to be wrapped in a list for modelsummary
models <- list(
  "Listwise"   = est_listwise,
  "Mean Imp."  = est_mean_imp,
  "Pred. Imp." = est_pred_imp,
  "MICE"       = est_mice_pooled
)

# View in RStudio
modelsummary(models)

# Output as LaTeX for your .tex writeup
modelsummary(models, output = "latex")

# --- Step 6: Save Tables  ---------------------------------------------------

# Save summary stats table to a .tex file
datasummary_skim(df, output = "summary_table.tex", histogram = FALSE)

# Save regression table to a .tex file
modelsummary(models, output = "regression_table.tex")

