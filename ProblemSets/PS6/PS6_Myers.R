# Problem Set 6 - Data Cleaning and Visualization

# Load necessary libraries
library(tidyverse)
library(tidyquant)
library(zoo)


# Pull 10 years of daily stock prices for Big Tech
tickers <- c("AAPL", "MSFT", "GOOGL", "AMZN", "META")
stock_data <- tq_get(tickers,
                     get  = "stock.prices",
                     from = "2016-03-23",
                     to   = "2026-03-23")

# Confirm the data pull worked
glimpse(stock_data)

# Check for missing values
summary(stock_data)
sum(is.na(stock_data))


# Data Cleaning & Transformation
stock_data <- stock_data %>%
  group_by(symbol) %>%
  arrange(date) %>%
  mutate(
    daily_return  = (close - lag(close)) / lag(close) * 100,
    moving_avg_50 = zoo::rollmean(close, k = 50, fill = NA, align = "right"),
    year          = year(date)
  ) %>%
  ungroup()

# Check the transformed data
glimpse(stock_data)
head(stock_data)


# Visualizations (all plots use colorblind-friendly viridis palette)


# Plot A: Closing prices over time
plot_a <- ggplot(stock_data, aes(x = date, y = close, color = symbol)) +
  geom_line(linewidth = 0.5) +
  scale_color_viridis_d() +
  labs(title = "Big Tech Stock Prices (2016-2026)",
       x = "Date", y = "Closing Price ($)", color = "Ticker") +
  theme_minimal()
ggsave("PS6a_Myers.png", plot_a, width = 10, height = 6, dpi = 300)

# Check if the file was saved successfully
# file.exists("PS6a_Myers.png")

# View Plot A in RStudio
# plot_a


# Plot B: AAPL Close vs 50-Day Moving Average
plot_b <- stock_data %>%
  filter(symbol == "AAPL") %>%
  ggplot(aes(x = date)) +
  geom_line(aes(y = close, color = "Close Price"), linewidth = 0.5) +
  geom_line(aes(y = moving_avg_50, color = "50-Day MA"), linewidth = 0.7) +
  scale_color_viridis_d() +
  labs(title = "AAPL: Close Price vs. 50-Day Moving Average",
       x = "Date", y = "Price ($)", color = "") +
  theme_minimal()
ggsave("PS6b_Myers.png", plot_b, width = 10, height = 6, dpi = 300)

# View Plot B in RStudio
# plot_b


# Plot C: Average Annual Return by Stock
annual_returns <- stock_data %>%
  filter(!is.na(daily_return)) %>%
  group_by(symbol, year) %>%
  summarize(avg_daily_return = mean(daily_return), .groups = "drop")

plot_c <- ggplot(annual_returns, aes(x = factor(year), y = avg_daily_return, fill = symbol)) +
  geom_bar(stat = "identity", position = "dodge") +
  scale_fill_viridis_d() +
  labs(title = "Average Daily Return by Year and Stock",
       x = "Year", y = "Average Daily Return (%)", fill = "Ticker") +
  theme_minimal()
ggsave("PS6c_Myers.png", plot_c, width = 10, height = 6, dpi = 300)

# View Plot C in RStudio
# plot_c

