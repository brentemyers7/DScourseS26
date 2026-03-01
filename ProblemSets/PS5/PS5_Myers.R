# Problem Set 5 - Webscraping Practice


## Without API 
library(rvest)
library(tidyverse)

# Scrape the data from the website
url <- "https://en.wikipedia.org/wiki/List_of_S%26P_500_companies"
page <- read_html(url)
sp500_table <- page %>% html_element("table.wikitable") %>% html_table()
head(sp500_table)
glimpse(sp500_table)

# Write the data to a CSV file
write_csv(sp500_table, "ProblemSets/PS5/sp500_companies.csv")



## With API - no key
library(tidyquant)

#Stock data for Apple (AAPL) from 2020-01-01 to 2025-01-01
stock_data <- tq_get("AAPL", get = "stock.prices", from = "2020-01-01", to = "2025-01-01")
head(stock_data)
glimpse(stock_data)

# Write the data to a CSV file
write_csv(stock_data, "ProblemSets/PS5/aapl_stock_data.csv")



## With API - Key
library(fredr)

# Set your FRED API key
fredr_set_key(Sys.getenv("FRED_API_KEY"))

# Pull CPI data from FRED
cpi_data <- fredr(series_id = "CPIAUCSL", observation_start = as.Date("2000-01-01"))
head(cpi_data)
glimpse(cpi_data)

# Write the data to a CSV file
write_csv(cpi_data, "ProblemSets/PS5/cpi_data.csv")



#### Visualizations (not part of the problem set, but just for fun) ####
library(ggplot2)

# Plot the stock price of Apple over time
ggplot(stock_data, aes(x = date, y = close)) +
  geom_line(color = "blue") +
  labs(title = "Apple Stock Price Over Time", x = "Date", y = "Closing Price") +
  theme_minimal()

# Plot the CPI data over time
ggplot(cpi_data, aes(x = date, y = value)) +
  geom_line(color = "red") +
  labs(title = "Consumer Price Index (CPI) Over Time", x = "Date", y = "CPI") +
  theme_minimal()
