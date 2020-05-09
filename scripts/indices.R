#!usr/bin/env R

######################################
# Select randomly n indices per date #
######################################

# ATTENTION: To be used within the bash subsampling file. 

# This code generates a file with a list of random row indices (idxToSample.csv).

# 1. Create start and end indices for each date based on the counts per sample 
# 2. Get the chosen number of images per day 
# 3. Export to CSV



# Arguments: 
# -path for the data files (ex: project/data) = args[1]
# -name of the counts file = args[2]
# -number of images per date to sample (n in 3.8) = args[3]

# Usage: Rscript scripts/indices.R data subsp_counts_cleaned.csv 100 



# Settings --------------------------------------------------------------------

# Libraries 
require(readr)

# Read arguments 
args <- commandArgs(trailingOnly = TRUE) # only print the arguments 
print(args)

counts <- read_csv(paste(args[1],"/",args[2],sep="")) # counts per date 
nb <- as.numeric(args[3]) # number of images to sample per date 




# 1. Create start and end indices for each date -------------------------------

counts$end <- cumsum(counts$count) # store the last image index of the date (based on the number of images during the date) 
counts$start <- c(1, counts$end[-nrow(counts)] + 1) # store the first image index of the date 




# 2. Get n indices per day --------------------------------------------------


# Function get_indices: sample 100 or the max number of images for a specific date 
# based on start and end indexes 

# - filename <numeric,char>: identifier of the date (filename or date itself)
# - nb <double>: number of images to sample 


get_indices = function(filename, nb) {
	idx <- which(counts$filename==filename)

	# If more than 100 images, sample 100, if less, sample all 
	if (counts$count[idx] > nb) {
   	 	sample(c(counts$start[idx]:counts$end[idx]), nb)
  	}
  	else {
    	c(counts$start[idx]:counts$end[idx])
	}
}

# Apply the function on each line of the tibble (faster than for loop)
sampling <- lapply(counts$filename, FUN=get_indices, nb=nb) 
idxToSample <- sort(unlist(sampling)) # transform into a vector 



# 3. Export to CSV --------------------------------------------------------

write_csv(as.data.frame(idxToSample), paste(args[1],"/idxToSample.csv",sep=""), col_names=FALSE)



