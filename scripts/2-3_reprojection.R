#!usr/bin/env R 

#  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
#  % Reproject images in the PCA space and assign cluster number %
#  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

# This code reads the whole csv files chunks by chunks and reprojects each image. 
# It uses the SVD matrix from the projection of the subsampled images to reproject 
# all of the images in the morphological space. 

# 1. Load the data 
# 2. Define the function to apply on each chunk of the csv file (transformation+reprojection)
# 3. Run the reprojection on each chunk 

# Set-up ------------------------------------------------------------------

# General libraries
library(tidyverse) # data manipulation
library(tictoc) # timer
library(matrixStats) # conditional sums

# PCA
source("scripts/pcatrans.R") # pca with transformation and weights

# Clustering
# devtools::install_github("jiho/wkmeans")
library(wkmeans) # weighted k-means
library(FNN)

# Diversity 
source("scripts/lib_functional_diversity.R") # multidimFD4: functional diversity
source("scripts/morphological_diversity.R") # wrap-up around multidimFD4


# 1. Load the data --------------------------------------------------------

# Column names 
names <- as.matrix(read_csv("data/colnames.csv",col_names=FALSE))

# Concentration 
concentration <- read_csv("data/concentration.csv") %>% 
  select(date,conc) %>% # select only the sample date and the concentration 
  mutate(date = as.POSIXct(date)) # make sure the date is in POSIXct format 

# Minimum values per column of interest
mincols <- as.matrix(read_tsv("data/mincols.csv",col_names=TRUE))

# Variables you don't wish to transform 
no_trans <- c("ecc", "extent", "tx.contrast", "tx.gray", "tx.entropy", "tx.smooth", "tx.3rd.mom", "mode.dist","kurt.dist","skew.dist","area.perim2","circ", "nb.blobs")

# BoxCox coefficients 
coeffs <- read_csv("data/lambda.csv")
lambda <- as_vector(coeffs$value)
names(lambda) <- coeffs$name

# PCA results 
res.pca <- readRDS("data/res_pca.rds")
centre <- res.pca$call$centre
ecart.type <- res.pca$call$ecart.type
loadings <- res.pca$svd$V[,1:4]

# Kmeans 
kmeans_centers <- read_csv("data/kmeans_centers.csv") %>%
  select(Dim.1:Dim.4)


rm(coeffs, res.pca)



# 2. Function ------------------------------------------------------------------

pca_morphs <- function(morpho.bcx,pos){
  
  print(pos)
  
  # Weights: create a weight for each image based on concentration
  poids <- morpho.bcx %>%
    select(date) %>%
    left_join(concentration,by="date")
  row.w = poids$conc/sum(poids$conc)
  cat("Weights done.")
  
  # Keep important information 
  imp <- select(morpho.bcx, id, roi_number, class_id)
  
  # make sure lambda has no values for the not transformed columns
  lambda = lambda[!(names(lambda) %in% no_trans)]  
  
  # Transformation (BoxCox)
  morpho.bcx <- pcatrans(morpho.bcx, rm_cols = c("id","roi_number", "filename","date","class_id"), 
                   trans="boxcox",min_cols=mincols, no_trans = no_trans, lambda=lambda,
                   coeffs = FALSE)
  cat("Transformation done.")
  

  # PCA: Use the svd matrix to project the data onto the PCA space
  pca_coord <- scale(morpho.bcx,centre,ecart.type) %*% loadings
  cat("Reprojection done")
  
  pca_coord <- cbind(imp, poids, pca_coord)
}


# 3. Run reprojection ----------------------------------------------------------

tic()
full_data <- read_tsv_chunked("data/combined_cleaned.csv", DataFrameCallback$new(pca_morphs), chunk_size = 100000, col_names=names)
toc()

write_csv(full_data,"data/full_data_pca.csv")
