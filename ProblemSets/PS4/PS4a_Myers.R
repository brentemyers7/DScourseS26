# PS4a - Question 5: JSON Exercise
# Load libraries
library(jsonlite)
library(tidyverse)

# (a) Download the JSON file using wget
system('wget -O dates.json "https://www.vizgr.org/historical-events/search.php?format=json&begin_date=00000101&end_date=20240209&lang=en"')

# (b) Print the file to the console
system('cat dates.json')

# (c) Convert JSON to data frame
mylist <- fromJSON('dates.json')
mydf <- bind_rows(mylist$result[-1])

# (d) Check object types
print(class(mydf))
print(class(mydf$date))

# (e) List the first 6 rows
print(head(mydf))

