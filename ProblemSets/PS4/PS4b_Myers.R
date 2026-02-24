# PS4b_Myers.R

# (1) load packages
library(sparklyr)
library(dplyr)   # or library(tidyverse)

# (2) connect
sc <- spark_connect(master = "local")

# (3) create a tibble with iris
df1 <- tibble::as_tibble(iris)

# (4) copy to Spark
df <- copy_to(sc, df1, name = "df", overwrite = TRUE)

# (5) class checks
class(df1)
class(df)

# (6) column names
names(df1)
names(df)

# (7) select
df %>% select(Sepal_Length, Species) %>% head(6) %>% print()

# (8) filter
df %>% filter(Sepal_Length > 5.5) %>% head(6) %>% print()

# (9) pipeline: filter + select
df %>% filter(Sepal_Length > 5.5) %>% select(Sepal_Length, Species) %>% head(6) %>% print()

# (10) group_by + summarize
df2 <- df %>%
  group_by(Species) %>%
  summarize(meanSepalLength = mean(Sepal_Length), count = n())

df2 %>% head() %>% print()

# (11) arrange (may error per instructions)
df2 %>% arrange(Species) %>% head() %>% print()

spark_disconnect(sc)
