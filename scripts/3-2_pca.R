#!usr/bin/env R 

# %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# % Run weighted-PCA and weighted Kmeans on the subsample %
# %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

# This code with compute a weighted-PCA and weighted-kmeans using concentration
# as weights on the morphological characteristics of a dataset. 

# 1. Load the data 
# 2. weighted-PCA
# 3. Export


# Set-up ------------------------------------------------------------------

library(tidyverse) # data manipulation
library(tictoc) # timer
source("scripts/pcatrans.R") # pca with transformation and weights
library(FactoMineR)
library(data.table)

# datasets
# full dataset 
colnames <- "data/colnames.csv"
filename <- "data/combined_sampled_250im.csv"
conc <- "data/concentration.csv"
min <- "data/mincols.csv"
lambda_file <- "data/lambda.csv"
pca_file <- "data/res_pca.rds"
pca_coord_file <- "data/pca_coord.csv"


# 1. Load the data --------------------------------------------------------

# OPTION 1: file without column names 
names <- as.matrix(read_tsv(colnames,col_names=FALSE))
file <- read_tsv(filename, col_names = names)

# OPTION 2: file with column names 
file <- read_tsv(filename)

# 2. PCA ------------------------------------------------------------------

# Concentration 
concentration <- read_csv(conc) %>% 
  select(date,conc) %>% # select only the sample date and the concentration 
  mutate(date = as.POSIXct(date)) # make sure the date is in POSIXct format 

# Minimum values per column of interest
mincols <- as.matrix(read_tsv(min,col_names=TRUE))

# Variables you don't wish to transform 
no_trans <- c("ecc", "extent", "tx.avg.contrast", "tx.avg.gray", "tx.entropy", "tx.smooth", "tx.3rd.mom", "mode.dist","kurt.dist","skew.dist","area.perim2","circ", "nb.blobs")


###### PCA

# Weights: create a weight for each image based on concentration
poids <- file %>%
  select(date) %>%
  left_join(concentration,by="date")
row.w = poids$conc/sum(poids$conc)


# Transformation (BoxCox)
lambda <- fread(lambda_file) 
names <- lambda$name
lambda <- lambda %>% 
  select(-name) %>% 
  transpose()
colnames(lambda) <- names


tic()
# if you didn't calculate or kept lambda coefficients before 
#trans_file <- pcatrans(file, rm_cols = c("id", "roi_number", "filename","date","class_id"), 
#                 trans="boxcox",min_cols=mincols, no_trans = no_trans, 
#                 coeffs = FALSE, coeffs_file = "data/lambda.csv")
# if you have lambda coefficients 
trans_file <- pcatrans(file, rm_cols = c("id", "roi_number", "filename","date","class_id"), 
trans="boxcox",min_cols=mincols, no_trans = no_trans, 
coeffs = FALSE, lambda=lambda)
toc()

# PCA with 6 components, weight based on concentration
res.pca <- PCA(trans_file,row.w=row.w, graph=FALSE, scale=TRUE, ncp=6)

morpho <- file %>% select(id, roi_number, filename) %>% cbind(poids, res.pca$ind$coord[,1:6])



# 3. Export ---------------------------------------------------------------

saveRDS(res.pca, pca_file)
write_csv(morpho, pca_coord_file)
rm(mincols,trans_file, file,names,no_trans)

