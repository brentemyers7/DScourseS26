# =============================================================
# visualizations.R
# Econ 5253 Final Project — Income Shifting Visualizations
# Author: Brent Myers
# =============================================================
# This script reads the cleaned regression dataset exported
# from SAS and generates two figures for the final paper:
#   1. Mean income shifting by fiscal year (line chart)
#   2. Tax differential vs. income shifting (scatter plot)
# =============================================================

# ---- Load packages ----
library(tidyverse)

# ---- Read data ----
df <- read_csv("is_reg.csv")

# ---- Figure 1: Mean Income Shifting Over Time ----
# Compute mean income_shift by fiscal year
yearly_means <- df %>%
  group_by(fyear) %>%
  summarise(
    mean_shift = mean(income_shift, na.rm = TRUE),
    n = n(),
    .groups = "drop"
  )

fig1 <- ggplot(yearly_means, aes(x = fyear, y = mean_shift)) +
  geom_line(color = "#2C7BB6", linewidth = 1) +
  geom_point(color = "#2C7BB6", size = 2.5) +
  geom_hline(yintercept = 0, linetype = "dotted", color = "gray50") +
  geom_vline(xintercept = 2017, linetype = "dashed", color = "#D7191C", linewidth = 0.8) +
  annotate("text", x = 2017, y = max(yearly_means$mean_shift) * 0.95,
           label = "TCJA\n(2017)", color = "#D7191C", hjust = 1.1, size = 3.5) +
  scale_x_continuous(breaks = seq(2010, 2024, by = 2)) +
  labs(
    title = "Mean Income Shifting by Fiscal Year",
    subtitle = "Foreign minus domestic profit margin differential (2017 excluded — TCJA transition year)",
    x = "Fiscal Year",
    y = "Mean Income Shifting"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold"),
    panel.grid.minor = element_blank()
  )

ggsave("fig1_income_shift_over_time.png", fig1, width = 8, height = 5, dpi = 300)

# ---- Figure 2: Tax Differential vs. Income Shifting ----
# Color-code by pre- vs. post-TCJA; add fitted regression lines
fig2_data <- df %>%
  filter(!is.na(tax_diff)) %>%
  mutate(period = ifelse(post_tcja == 1, "Post-TCJA (2018–2024)", "Pre-TCJA (2010–2016)"))

fig2 <- ggplot(fig2_data, aes(x = tax_diff, y = income_shift, color = period)) +
  geom_point(alpha = 0.3, size = 1.2) +
  geom_smooth(method = "lm", se = FALSE, linewidth = 1) +
  scale_color_manual(
    values = c("Pre-TCJA (2010–2016)" = "#2C7BB6", "Post-TCJA (2018–2024)" = "#D7191C"),
    name = ""
  ) +
  geom_hline(yintercept = 0, linetype = "dotted", color = "gray50") +
  geom_vline(xintercept = 0, linetype = "dotted", color = "gray50") +
  labs(
    title = "Tax Differential and Income Shifting",
    subtitle = "Each point is a firm-year; lines are OLS fits by period",
    x = "Tax Differential (Foreign ETR − U.S. Statutory Rate)",
    y = "Income Shifting (Foreign − Domestic Profit Margin)"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold"),
    panel.grid.minor = element_blank(),
    legend.position = "bottom"
  )

ggsave("fig2_tax_diff_vs_shift.png", fig2, width = 8, height = 5, dpi = 300)

# ---- Confirmation ----
cat("\nFigures saved:\n")
cat("  fig1_income_shift_over_time.png\n")
cat("  fig2_tax_diff_vs_shift.png\n")