#!usr/bin/env R

#########################
# Compute concentration #
#########################

# This code is used to compute  the concentration for each of the samples. 
# Output: concentration.csv 


# 1. Connect to the database and query the counts, runTime, inhibitTime and mL_counted
#     --> you might want to change the conditions of the query 
# 2. Compute the concentration
# 3. Export to csv


# Set-up ------------------------------------------------------------------

require(tidyverse) # data manipulation
require(RMySQL) # if it doesn't install: brew install mariadb-connector-c 
require(dbplyr) # database
require(tictoc) # timer


rm(list=ls()) # clear workspace
gc() # garbage collection

# Set up password
Sys.setenv(MYSQL_PWD_STUDENT = "Restmonami")



# 1. Get the data ---------------------------------------------------------

# Connect to the database
db <- dbConnect(MySQL(),dbname="plankton_images", host="images.gso.uri.edu", port=3306, user="student", 
                password=Sys.getenv("MYSQL_PWD_STUDENT"))

# Query the counts 
tic()
concentration <- dbGetQuery(conn = db, 
                     statement = "SELECT filename,date,runTime, inhibitTime,mL_counted, COUNT(*) AS counts 
                                  FROM roi JOIN raw_files ON roi.raw_file_id=raw_files.id 
                                  WHERE runTime != 0 AND deployment_id = 2 AND qc_file != 2
                                  GROUP BY filename,date,runTime, inhibitTime,mL_counted;")
toc()


# 2. Compute the concentration --------------------------------------------

# If you don't have the mL counted you can retrieve them with the flushed volume (0.25 ml/min)
# concentration$mL_counted <- 0.25*(conc$runTime - conc$inhibitTime)/60
concentration <- concentration %>% 
  mutate(conc = counts/mL_counted) %>% 
  select(filename, date, counts, conc)



# 3. Export to csv  -------------------------------------------------------

write_csv(concentration, "data/concentration.csv")


