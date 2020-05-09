#!usr/bin/env R 

# %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# % Compare kmeans with different number of groups %
# %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

# This code compares the output of a wighted-kmeans clustering with different clusters number. 
# The weighted-kmeans is based on an implementation developed by Dr. Jean-Olivier 
# Irisson. 

# 1. Run the pca on the subsample you have kept and store the coordinates for each image
#     --> you might want to change the number of components (4 in the code)
# 2. Perform the kmeans 10 times for 10, 25, 50, 100, 250, 500 and 1000 clusters 
#     --> you might want to test other numbers of clusters
# 3. Export the tibble with pca coordinates and cluster number and the kmeans centers 
# 4. Compute the diversity for each of the output 
# 5. Export the diversity per date


# Set-up ------------------------------------------------------------------

# General libraries
library(tidyverse) # data manipulation
# devtools::install_github("jiho/castr")
library(castr) # smoothing
library(tictoc) # timer
library(data.table) # binding tables
library(matrixStats) # conditional sums

# PCA
source("scripts/pcatrans.R") # pca with transformation and weights

# Clustering
# devtools::install_github("jiho/wkmeans")
library(wkmeans) # weighted k-means

# Diversity 
# install.packages("geometry")
# install.packages("ape")
source("scripts/lib_functional_diversity.R") # multidimFD4: functional diversity
source("scripts/morphological_diversity.R") # wrap-up around multidimFD4


# Column names 
names <- as.matrix(read_csv("data/colnames.csv",col_names=FALSE))

# Get the  subsample that you have kept 
filename <- list.files(path="data",pattern="combined_sampled",full.names=TRUE)
full_file <- read_csv(filename, col_names = names)


# 1. Run the pca ----------------------------------------------------------

###### Data 

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
poids <- full_file %>%
  select(date) %>%
  left_join(concentration,by="date")
row.w = poids$conc/sum(poids$conc)


# Transformation (BoxCox)
file <- pcatrans(full_file, rm_cols = c("id","filename","date","class_id"), 
                 trans="boxcox",min_cols=mincols, no_trans = no_trans, 
                 coeffs = FALSE)

# PCA with 4 components, weight based on concentration
res.pca <- PCA(file,row.w=row.w, graph=FALSE, scale=TRUE, ncp=4)


###### Tibble with id, date, concentration and the PC coordinates  
morpho <- full_file %>%
  left_join(concentration, by="date") %>% 
  select(id, date, conc) %>% 
  bind_cols(as_tibble(res.pca$ind$coord))

# Remove non-useful variables  
rm(mincols,full_file, file,filename,names,no_trans)



# 2. K-means ------------------------------------------------------------

# tot_k is the total number of clusters for the run, sp, the sample number and
# k the cluster for this image 
kmeans_res <- tibble(id = numeric(), date = as.POSIXct(NA), conc=numeric(), Dim.1 = numeric(), Dim.2 = numeric(),
                     Dim.3 = numeric(), Dim.4 = numeric(), tot_k = numeric(),sp = numeric(), morph_nb = numeric())
kmeans_centers <- tibble(morph_nb = numeric(), tot_k = numeric(), sp = numeric(), Dim.1 = numeric(),
                         Dim.2 = numeric(), Dim.3 = numeric(), Dim.4 = numeric())

# Run 10 times the kmeans for 10 (1min), 25 (2min), 50 (3min), 100 (5min), 
# 150 (8min), 250 (13min), 500 (23min) and 1000 (46min) clusters (approximate
# time for 315 250) images  
for (ii in c(10, 25, 50, 100, 150, 250, 500, 1000)){
  for (jj in 1:10){
    tic()
    message("Processing clustering for ", ii, " clusters, sample number ", jj)
    morphs <- wkmeans(select(morpho, Dim.1:Dim.4), k=ii, w=morpho$conc, iter_max=100, nstart=50, cores=12)
    
    res <- morpho %>% 
      select(id:Dim.4) %>% 
      add_column(tot_k = ii, sp = jj, morph_nb = morphs$cluster)
    kmeans_res <- rbindlist(l= list(kmeans_res,res), use.names=TRUE) 
    
    centers <- as_tibble(morphs$centers) %>% 
      rownames_to_column(var="morph_nb") %>%
      mutate(morph_nb = as.numeric(morph_nb)) %>% 
      add_column(tot_k = ii, sp = jj)
    kmeans_centers <- rbindlist(l=list(kmeans_centers, centers), use.names=TRUE)
    toc()
  }
}



# 3. Export to csv --------------------------------------------------------

write_csv(kmeans_res, "data/subsp_pca+conc+cluster.csv")
write_csv(kmeans_centers, "data/subsp_kmeans_centers.csv")


# 4. Diversity analysis ----------------------------------------------------

# kmeans_res <- read_csv("data/subsp_pca+conc+cluster.csv")
# kmeans_centers <- read_csv("data/subsp_kmeans_centers.csv")


div <- tibble(Nb_sp=numeric(), Tot_weight=numeric(), FRic=numeric(), FDiv=numeric(), 
              FEve=numeric(), date = as.POSIXct(NA), tot_k=numeric(), sp=numeric())

for (ii in c(10, 25, 50, 100, 150, 250, 500, 1000)){
  for (jj in 1:10){
    tic()
    message("Processing diversity for ", ii, " clusters, sample number ", jj)

    morpho_div <- kmeans_res %>% filter(tot_k==ii & sp==jj)
    centers_div <- kmeans_centers %>% filter(tot_k==ii & sp==jj)

    # Compute diversity indices for each date 
    fd <- morphological_diversity(morpho_div,centers_div,verb=FALSE) # verb=TRUE print each sample when done 

    diversity <- as_tibble(fd) %>%
      mutate(date = as.POSIXct(rownames(fd))) %>%
      add_column(tot_k = ii, sp = jj)
    div <- rbindlist(l = list(div,diversity), use.names=TRUE)
    toc()
  }
}


# 5. Export to csv --------------------------------------------------------

write_csv(div, "data/subsp_diversity_explo.R")
