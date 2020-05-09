#!usr/bin/env R 

# @title Functional diversity indices developed by Villeger et al (2008) on the results of a kmeans

# @description
# This function computes functional diversity indices developed by Villeger et al (2008) (richness,
# evenness, divergence) on from the cluster numbers and the centers coordinates of a kmeans. 


# @param morpho_div <tibble, df> : dataset with the morph number for each image, need at least a column
# \itemize{
#   \item{\code{"date"} date of the sample
#   \item{\code{"morph_nb"} morph number for each image
#   \item{\code{"conc"}} concentration/weight associated with each image 
# }     
# @param centers_div <tibble, df> : dataset with the coordinates of the morphs centers, need columns 
# \itemize{
#   \item{\code{"morph_nb"} morph number
#   \item{\code{"Dim.1"} coordinate on the first principal component axis
#   \item{\code{"Dim.2"}} coordinate on the second principal component axis
#   \item{\code{"Dim.3"} coordinate on the third principal component axis
#   \item{\code{"Dim.4"}} coordinate on the fourth principal component axis
# } 
# @param verb <logical> : TRUE prints processing of samples in multidimFD4 (default: TRUE)

# @return A tibble with the divergence, evenness and richness for each date 

# @examples 
## Required libraries
# require(matrixStats)
# source("scripts/lib_functional_diversity.R") # functional diversity

# Data 
# kmeans_res <- read_csv("data/subsp_pca+conc+cluster.csv") %>% filter(tot_k==10 & sp==1)
# kmeans_centers <- read_csv("data/subsp_kmeans_centers.csv") %>% filter(tot_k==10 & sp==1)

# Diversity 
# fd <- morphological_diversity(morpho_div, centers_div) 


morphological_diversity <- function(morpho_div, centers_div, verb=TRUE){
    
    # Weights matrix: date x morph_nb 
    weights <- morpho_div %>% 
      group_by(date, morph_nb) %>% 
      summarize(conc = sum(conc)) %>% # concentration per date per morph
      arrange(morph_nb) %>% 
      # wide format: morph_nb (column), date (row) and concentration or 0 (fill) 
      pivot_wider(names_from = morph_nb, values_from = conc, values_fill = list(conc = 0)) %>% 
      column_to_rownames(var = "date") %>% 
      as.matrix()
    
    
    # ATTENTION: you need at least 5 morphs for each date 
    zero <- rowSums2(weights != 0) # number of columns for each row that are != 0
    if (sum(zero < 5) != 0){
      stop("No need to continue, you won't be able to compute the diversity indices for ", sum(zero < 5), " dates because you don't have at least 5 morphs with a concentration above 0.")
    }
    rm(zero)
    
    
    # Morphological space matrix: morphs x axes
    space <- centers_div %>% select(morph_nb,Dim.1:Dim.4) %>% 
      column_to_rownames(var = "morph_nb") %>% as.matrix()
    
    
    # Diversity index
    fd <- multidimFD4(space, weights, verb=verb)
}

