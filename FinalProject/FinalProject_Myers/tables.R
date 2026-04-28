# =============================================================
# tables.R
# Econ 5253 Final Project — Auto-generated LaTeX Tables
# Author: Brent Myers
# =============================================================
# This script reads the cleaned regression datasets exported
# from SAS and generates four LaTeX table files:
#   1. tab_summary.tex     — Summary statistics (Table 1)
#   2. tab_regression.tex  — Models 1-3 side by side (Table 2)
#   3. tab_industry_fe.tex — Model 4 Industry FE (Table 3)
#   4. tab_sensitivity.tex — Sensitivity analysis (Table 4)
# These files are included in main.tex via \input{} commands.
#
# Required packages: tidyverse, modelsummary, lmtest, sandwich
# Required data files: is_reg.csv, sens_reg.csv
# =============================================================

# ---- Load packages ----
library(tidyverse)
library(modelsummary)
library(lmtest)
library(sandwich)

# ---- Read data ----
df <- read_csv("is_reg.csv", show_col_types = FALSE)
sens <- read_csv("sens_reg.csv", show_col_types = FALSE)

# ---- Prepare regression data ----
reg_df <- df %>% filter(!is.na(tax_diff))
sens_reg <- sens %>% filter(!is.na(tax_diff))



# ---- Helper: add [H], extract caption, add \caption + \label ----
add_label <- function(filepath, label) {
  lines <- readLines(filepath)
  
  # 1. Add [H] placement to \begin{table}
  lines <- sub("^\\s*\\\\begin\\{table\\}\\s*$", "\\\\begin{table}[H]", lines)
  
  # 2. Switch talltblr -> tblr (talltblr auto-generates a duplicate caption)
  lines <- gsub("talltblr", "tblr", lines)
  
  # 3. Find the caption= line in tabularray outer spec and extract it
  cap_idx <- grep("caption=\\{", lines)
  if (length(cap_idx) > 0) {
    cap_line <- trimws(lines[cap_idx[1]])
    cap_text <- sub("^caption=\\{(.*)\\},?$", "\\1", cap_line)
    lines <- lines[-cap_idx[1]]
    # Insert \caption and \label after \centering
    cen_idx <- grep("\\\\centering", lines)
    if (length(cen_idx) > 0) {
      lines <- append(lines, c(
        paste0("\\caption{", cap_text, "}"),
        paste0("\\label{", label, "}")
      ), after = cen_idx[1])
    }
  }
  
  writeLines(lines, filepath)
}

# =============================================================
# Table 1: Summary Statistics
# =============================================================

# Use plain names (no LaTeX escaping — tabularray handles underscores)
summ_df <- df %>%
  select(
    income_shift  = income_shift,
    tax_diff      = tax_diff,
    ww_profit     = ww_profit,
    size          = size,
    leverage      = leverage,
    rnd_intensity = rnd_intensity,
    ad_intensity  = ad_intensity,
    ppe_intensity = ppe_intensity,
    year_trend    = year_trend,
    post_tcja     = post_tcja
  )

datasummary(
  All(summ_df) ~ N + Mean + Median + SD + Min + Max,
  data = summ_df,
  fmt = 4,
  title = "Summary Statistics for All Regression Variables",
  notes = "Source: Compustat via WRDS. Sample period: 2010--2024, excluding 2017.",
  output = "tab_summary.tex"
)

add_label("tab_summary.tex", "tab:summary")


# =============================================================
# Table 2: Models 1-3 Side by Side
# =============================================================

# Model 1: Baseline OLS
model1 <- lm(income_shift ~ tax_diff + ww_profit + size + leverage +
               rnd_intensity + ad_intensity + ppe_intensity +
               year_trend + post_tcja,
             data = reg_df)

# Model 2: Year Fixed Effects
reg_df <- reg_df %>%
  mutate(fyear_factor = factor(fyear, levels = c(2010:2016, 2018:2024)))

model2 <- lm(income_shift ~ tax_diff + ww_profit + size + leverage +
               rnd_intensity + ad_intensity + ppe_intensity +
               fyear_factor,
             data = reg_df)

# Model 3: Interaction Terms
reg_df <- reg_df %>%
  mutate(
    tax_diff_x_post      = tax_diff * post_tcja,
    rnd_intensity_x_post = rnd_intensity * post_tcja,
    ww_profit_x_post     = ww_profit * post_tcja
  )

model3 <- lm(income_shift ~ tax_diff + ww_profit + size + leverage +
               rnd_intensity + ad_intensity + ppe_intensity +
               year_trend + post_tcja +
               tax_diff_x_post + rnd_intensity_x_post + ww_profit_x_post,
             data = reg_df)

# Coefficient mapping — use plain names for tabularray
coef_map_123 <- c(
  "(Intercept)"          = "Intercept",
  "tax_diff"             = "tax_diff",
  "ww_profit"            = "ww_profit",
  "size"                 = "size",
  "leverage"             = "leverage",
  "rnd_intensity"        = "rnd_intensity",
  "ad_intensity"         = "ad_intensity",
  "ppe_intensity"        = "ppe_intensity",
  "year_trend"           = "year_trend",
  "post_tcja"            = "post_tcja",
  "tax_diff_x_post"      = "tax_diff x post_tcja",
  "rnd_intensity_x_post" = "rnd_intensity x post_tcja",
  "ww_profit_x_post"     = "ww_profit x post_tcja"
)

gof_map_123 <- tribble(
  ~raw,             ~clean,              ~fmt,
  "nobs",           "N",                 0,
  "r.squared",      "R-squared",         4,
  "adj.r.squared",  "Adj. R-squared",    4
)

modelsummary(
  list("Model 1" = model1, "Model 2" = model2, "Model 3" = model3),
  vcov = "HC0",
  coef_map = coef_map_123,
  gof_map = gof_map_123,
  stars = c("*" = 0.10, "**" = 0.05, "***" = 0.01),
  title = "OLS Regression Results --- Income Shifting Models (Robust Standard Errors)",
  notes = c(
    "Heteroskedasticity-consistent (HC0) standard errors in parentheses.",
    "Model 2 includes year fixed effects (2010 omitted); year_trend and post_tcja dropped due to collinearity."
  ),
  output = "tab_regression.tex"
)

add_label("tab_regression.tex", "tab:regression")


# =============================================================
# Table 3: Model 4 — Industry Fixed Effects
# =============================================================

reg_df <- reg_df %>%
  mutate(sic2 = sich %/% 100)

sic2_counts <- reg_df %>%
  filter(!is.na(sic2)) %>%
  count(sic2, name = "n_sic")

reg_df <- reg_df %>%
  left_join(sic2_counts, by = "sic2") %>%
  mutate(sic2_grp = factor(if_else(is.na(sic2) | n_sic < 10, 99L, as.integer(sic2))))

model4 <- lm(income_shift ~ tax_diff + ww_profit + size + leverage +
               rnd_intensity + ad_intensity + ppe_intensity +
               year_trend + post_tcja + sic2_grp,
             data = reg_df)

coef_map_4 <- c(
  "(Intercept)"   = "Intercept",
  "tax_diff"      = "tax_diff",
  "ww_profit"     = "ww_profit",
  "size"          = "size",
  "leverage"      = "leverage",
  "rnd_intensity" = "rnd_intensity",
  "ad_intensity"  = "ad_intensity",
  "ppe_intensity" = "ppe_intensity",
  "year_trend"    = "year_trend",
  "post_tcja"     = "post_tcja"
)

gof_map_4 <- tribble(
  ~raw,             ~clean,              ~fmt,
  "nobs",           "N",                 0,
  "r.squared",      "R-squared",         4,
  "adj.r.squared",  "Adj. R-squared",    4
)

modelsummary(
  list("Model 4" = model4),
  vcov = "HC0",
  coef_map = coef_map_4,
  gof_map = gof_map_4,
  stars = c("*" = 0.10, "**" = 0.05, "***" = 0.01),
  title = "OLS Regression with Industry Fixed Effects (Robust Standard Errors)",
  notes = c(
    "Heteroskedasticity-consistent (HC0) standard errors in parentheses.",
    "Industry dummies based on 2-digit SIC codes (industries with <10 obs collapsed into Other).",
    "Industry coefficients suppressed for brevity; jointly significant (p < 0.001)."
  ),
  output = "tab_industry_fe.tex"
)

add_label("tab_industry_fe.tex", "tab:industry_fe")


# =============================================================
# Table 4: Sensitivity Analysis
# =============================================================

model_sens <- lm(income_shift ~ tax_diff + ww_profit + size + leverage +
                   rnd_intensity + ad_intensity + ppe_intensity +
                   year_trend + post_tcja,
                 data = sens_reg)

coef_map_sens <- c(
  "(Intercept)"   = "Intercept",
  "tax_diff"      = "tax_diff",
  "ww_profit"     = "ww_profit",
  "size"          = "size",
  "leverage"      = "leverage",
  "rnd_intensity" = "rnd_intensity",
  "ad_intensity"  = "ad_intensity",
  "ppe_intensity" = "ppe_intensity",
  "year_trend"    = "year_trend",
  "post_tcja"     = "post_tcja"
)

gof_map_sens <- tribble(
  ~raw,             ~clean,              ~fmt,
  "nobs",           "N",                 0,
  "r.squared",      "R-squared",         4,
  "adj.r.squared",  "Adj. R-squared",    4
)

modelsummary(
  list("Main Sample" = model1, "Excl. Ambiguous" = model_sens),
  vcov = "HC0",
  coef_map = coef_map_sens,
  gof_map = gof_map_sens,
  stars = c("*" = 0.10, "**" = 0.05, "***" = 0.01),
  title = "Sensitivity Analysis --- Excluding Ambiguous Domestic Segments",
  notes = c(
    "Heteroskedasticity-consistent (HC0) standard errors in parentheses.",
    "Excl. Ambiguous drops segments labeled North America, Americas, The Americas, and Corporate before classifying."
  ),
  output = "tab_sensitivity.tex"
)

add_label("tab_sensitivity.tex", "tab:sensitivity")


# ---- Confirmation ----
cat("\nTables saved:\n")
cat("  tab_summary.tex\n")
cat("  tab_regression.tex\n")
cat("  tab_industry_fe.tex\n")
cat("  tab_sensitivity.tex\n")
