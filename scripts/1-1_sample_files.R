#!usr/bin/env R

# %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# % Vector of indices for sampled files % 
# %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

# This code creates a vector of random indices of the samples. You will need to change the information 
# related to your database in the set-up. 

# 1. Get the number of files present in the database and meeting your criteria 
#      --> you might want to change these criteria in the query 
# 2. Calculate the number of files to sample based on a percentage 
#      --> the percentage is 5 in the code 
# 3. Query the files ids and take them randomly for the number determined in 2.
#      --> you might want to change these criteria in the query 
# 4. Query the rois from the files ids that meet your criteria 
#      --> you might want to change these criteria
# 5. Extract counts per sample 
# 6. Export to csv


# Set-up  -----------------------------------------------------------------

require(tidyverse) # data manipulation
require(RMySQL) # if it doesn't install: brew install mariadb-connector-c 
require(dbplyr) # database
require(tictoc) # timer

rm(list=ls()) # clear workspace
gc() # garbage collection

# Set up password: CHANGE FOR YOURS 
Sys.setenv(MYSQL_PWD_STUDENT = "Restmonami")

# Connect to the database
db <- dbConnect(MySQL(),dbname="plankton_images", host="images.gso.uri.edu", port=3306, user="student", 
                password=Sys.getenv("MYSQL_PWD_STUDENT"))



# 1. Get the number of files ---------------------------------------------

# Criteria: 
# - no runTime null (can't calculate the concentration)
# - deployment_id = 2 (GSO dock)
# - qc_file = 1 (the file has no problems)

nb_raw <- dbGetQuery(conn = db, 
                     statement = "SELECT COUNT(*) AS count FROM raw_files 
                                  WHERE runTime != 0 AND deployment_id = 2 AND qc_file = 1;")



# 2. Percentage of files to sample  ---------------------------------------

sp <- as.numeric(round(5*nb_raw/100))
rm(nb_raw)



# 3. Query the random file ids --------------------------------------------

rd_id <- dbGetQuery(conn = db, 
                     statement = paste("SELECT id FROM raw_files 
                                  WHERE runTime != 0 AND deployment_id = 2 AND qc_file = 1
                                  ORDER BY RAND()
                                  LIMIT ",sp,";",sep=""))



# 4. Query them ------------------------------------------------------------

# Criteria: 
# - specific columns I have chosen for my analysis with an associated shorter column name and 
#   some metadata columns (roi id, filename, date, taxonomic classification)
# - raw_file_id are the ones of the randomly queried ones 
# - the class_id is not one of the ciliates, zooplanktom, detritus, mix 
# - if the class_id is unclassified, then the area has to be under 90 000 pixel squared

# Timer: 15 minutes for 1417 files 
# It takes as much time from the command line (16 min)

# The function argument collapse in the paste function allow you to transform a numeric vector
# into a character separated by a specific separator. 
tic()
rd_sp <- dbGetQuery(conn = db, 
               statement = paste("SELECT roi.id, filename, date, Area AS area, Biovolume AS vol, ConvexArea AS 'c.area', ConvexPerimeter AS 'c.perim', Eccentricity AS ecc, EquivDiameter AS 'eq.diam', Extent AS extent, H180 AS h180, H90 AS h90, Hflip AS hflip, MajorAxisLength AS 'maj.ax', MinorAxisLength AS 'min.ax', Perimeter AS perim, Solidity AS solid, numBlobs AS 'nb.blobs', shapehist_kurtosis_normEqD AS 'kurt.dist', shapehist_mean_normEqD AS 'mean.dist', shapehist_median_normEqD AS 'med.dist', shapehist_mode_normEqD AS 'mode.dist', shapehist_skewness_normEqD AS 'skew.dist', summedArea AS 's.area', summedBiovolume AS 's.vol', summedConvexArea AS 's.c.area', summedConvexPerimeter AS 's.c.perim', summedMajorAxisLength AS 's.maj.ax', summedMinorAxisLength AS 's.min.ax', summedPerimeter AS 's.perim', texture_average_contrast AS 'tx.contrast', texture_average_gray_level AS 'tx.gray', texture_entropy AS 'tx.entropy', texture_smoothness AS 'tx.smooth', texture_third_moment AS 'tx.3rd.mom', texture_uniformity AS 'tx.unif', RotatedBoundingBox_xwidth AS 'r.bbox.x', RotatedBoundingBox_ywidth AS 'r.bbox.y', Area_over_PerimeterSquared AS 'area.perim2', Area_over_Perimeter AS 'area.perim', H90_over_Hflip AS 'h90.hflip', H90_over_H180 AS 'h90.h180', summedConvexPerimeter_over_Perimeter AS 's.c.perim.perim', MajorAxisLength/MinorAxisLength AS 'maj.min', Perimeter/MajorAxisLength AS 'perim.maj', 4*3.14159265359*Area_over_PerimeterSquared AS 'circ', class_id  
                                  FROM roi JOIN raw_files ON roi.raw_file_id = raw_files.id 
                                           JOIN auto_class ON roi.id = auto_class.roi_id 
                                  WHERE raw_file_id IN (",paste(rd_id$id,collapse=', '),") AND
                                        class_id NOT IN (58,85,88,90,91,94,106,109,110,111,119,121,122,124,127,128,129) AND
                                        !(class_id = 96 AND Area > 90000)
                                  ORDER BY roi_id;",
                                  sep=""))
toc()



# 5. Extract counts per sample  -------------------------------------------

counts <- rd_sp %>%
  select(filename) %>% 
  group_by(filename) %>% 
  summarize(count = n())


# 6. Export to csv --------------------------------------------------------

write_csv(rd_sp,"data/subsp_combined.csv")
write_csv(counts,"data/subsp_counts_cleaned.csv")
