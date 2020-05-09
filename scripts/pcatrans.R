#!usr/bin/env R 

# @title Compute a weighted-PCA with transformation 

# @description
# This function computes a transformation ot not of the variables for better normality. 


# @param file <tibble, df> : the dataset on which to run the pca (need to have a column "date" for the weights)
# @param rm_cols <vector> : columns of no interest for the PCA (but necessary for joining the concentration vector)
# @param trans <string> : type of transformation, one of
# \itemize{
#   \item{\code{"log10"} transforms all variables except \code{no_trans} with \code{log10}}
#   \item{\code{"boxcox"} switch columns with minimum values inferior to 1 (from min_cols) to above 1, compute the 
#    boxcox coefficients and apply boxcox transformation
# } 
# @param min_cols <matrix> : minimum for each numeric column 
# @param no_trans <vector> : names of the variables you don't want to transform
# @param coeffs <logical>: TRUE records boxcox coefficients used for the transformation (default: FALSE) 
# @param lambda <named numeric vector>: coefficients for the BoxCox transformation 
# @param coeffs_file <string> : path and filename for the file containing the boxcox coefficients 

# @return A tibble with transformed values 

# @examples 
## Required libraries
# library(tidyverse)

# Data 
# file <- read_csv("data/combined_cleaned.csv")
# mincols <- as.matrix(read_csv("data/mincols.csv",col_names=TRUE)
# no_trans <- c("texture", "nb.blobs")
# rm_cols <- c("id","filename","date","class_id")

# Transformation 
# file <- pcatrans(file = file, rm_cols = rm_cols, trans = "boxcox", min_cols = mincols, 
#                  coeffs=FALSE, no_trans = no_trans)


pcatrans <- function(file, rm_cols = NULL,trans = NULL, min_cols = NULL,
                   no_trans = NULL, lambda = NULL, coeffs = FALSE, coeffs_file){
  
  # Libraries
  require(car)
  
  # Remove the non-numeric columns if rm_cols is not empty
  if (!(is_empty(rm_cols))){
    file <- file %>% select(-rm_cols)
    }
  
  ### Transformation 
  
  if (trans %in% c("boxcox","log10")){
    
    # Switch all values by the minimum of the database column and add 1 to be sure the minimum is 1
    idx <- which(min_cols < 1)
    for (ii in idx) {
      file[[ii]] <- file[[ii]] - mincols[ii] + 1
      }
    
    # No boxcox coefficients provided (no lambda) 
    if (is_empty(lambda)){
      for (ii in colnames(file)){
        if (!(ii %in% no_trans)){
          
          # Box-Cox transformation for the skewed variables 
          if (trans == "boxcox"){
            x <- powerTransform(file[[ii]]) # boxcox coefficient
            lambda[ii] <- x$lambda
            file[[ii]] <- bcPower(file[[ii]], x$lambda) # boxcox transformation 
            cat("Column",ii,"done, lambda is:",x$lambda,". ")
          }
          # Logarithmic transformation for the skewed variables 
          else if (trans == "log10"){file[[ii]] <- log10(file[[ii]])} # log10 transformation 
        }
      }
      if (coeffs == TRUE){
        write_csv(enframe(lambda),coeffs_file)
      }
    }
    # BoxCox coefficients provided (lambda)
    else {
      for (ii in colnames(file)){
        if (!(ii %in% no_trans)){
            file[[ii]] <- bcPower(file[[ii]], lambda[[ii]]) # boxcox transformation 
        }
      }
    }
  }
  return(file)
}
