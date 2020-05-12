#!usr/bin/env R 

# %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# % Run weighted-PCA and weighted Kmeans on the subsample %
# %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

# This code with compute a weighted-PCA and weighted-kmeans using concentration
# as weights on the morphological characteristics of a dataset. 

# 1. Load the data 
# 2. weighted-PCA
# 3. weighted-Kmeans clustering


# Set-up ------------------------------------------------------------------

library(tidyverse) # data manipulation
library(tictoc) # timer
source("scripts/pcatrans.R") # pca with transformation and weights
library(wkmeans) # weighted k-means
library(FactoMineR)




# 1. Load the data --------------------------------------------------------

names <- as.matrix(read_csv("data/colnames.csv",col_names=FALSE))
file <- read_tsv("data/combined_sampled_250im.csv", col_names = names)

# 2. PCA ------------------------------------------------------------------

# Concentration 
concentration <- read_csv("data/concentration.csv") %>% 
  select(date,conc) %>% # select only the sample date and the concentration 
  mutate(date = as.POSIXct(date)) # make sure the date is in POSIXct format 

# Minimum values per column of interest
mincols <- as.matrix(read_tsv("data/mincols.csv",col_names=TRUE))

# Variables you don't wish to transform 
no_trans <- c("ecc", "extent", "tx.avg.contrast", "tx.avg.gray", "tx.entropy", "tx.smooth", "tx.3rd.mom", "mode.dist","kurt.dist","skew.dist","area.perim2","circ", "nb.blobs")


###### PCA

# Weights: create a weight for each image based on concentration
poids <- file %>%
  select(date) %>%
  left_join(concentration,by="date")
row.w = poids$conc/sum(poids$conc)


# Transformation (BoxCox)
tic()
trans_file <- pcatrans(file, rm_cols = c("id","filename","date","class_id"), 
                 trans="boxcox",min_cols=mincols, no_trans = no_trans, 
                 coeffs = TRUE, coeffs_file = "data/lambda.csv")
toc()

# PCA with 6 components, weight based on concentration
res.pca <- PCA(trans_file,row.w=row.w, graph=FALSE, scale=TRUE, ncp=6)

morpho <- file %>% select(id) %>% cbind(poids, res.pca$ind$coord[,1:6])

saveRDS(res.pca, "data/res_pca.rds")
write_csv(morpho, "data/pca_coord.csv")
rm(mincols,trans_file, file,names,no_trans)


# 3. Clustering -----------------------------------------------------------

# Clustering with 150 clusters 
tic()
morphs <- wkmeans(select(morpho, Dim.1:Dim.4), k=150, w=row.w, iter_max=100, nstart=50, cores=12)
toc()

kmeans_centers <- as_tibble(morphs$centers) %>% 
  rownames_to_column(var="morph_nb") %>%
  mutate(morph_nb = as.numeric(morph_nb)) 

write_csv(kmeans_centers,"data/kmeans_centers.csv")


