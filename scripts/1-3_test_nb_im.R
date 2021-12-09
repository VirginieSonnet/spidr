#!usr/bin/env R 

# %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# % Explore the different subsamplings %
# %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

# Input: 
# - combined results for each subsampling: subsp_results.csv

# 1. Import the necessary files 
# 2. Run and extract information from the PCA on each file 
# 3. Export to csv
# 4. Graphs 


# Set-up ------------------------------------------------------------------

rm(list = ls())
gc()


# Libraries 
library(tidyverse) # data manipulation 
library(tictoc) # timing 
library(car) # Box-Cox 
library(FactoMineR) # pca 
library(factoextra) # visualization
source("scripts/pcatrans.R")



# 1. Import files ---------------------------------------------------------

# Concentration 
concentration <- read_csv("data/concentration.csv") %>%
  select(date,conc) %>% # select only the sample date and the concentration
  mutate(date = as.POSIXct(date)) # make sure the date is in POSIXct format 


# Paths of subsampled files 
files <- sort(list.files(path="data",pattern="combined_sampled",full.names=TRUE))

# Column names  
names <- as.matrix(read_csv("data/colnames.csv",col_names=FALSE))

# Load the minimum values per column and get the ones below 1
mincols <- as.matrix(read_tsv("data/mincols.csv",col_names=TRUE))

# Define the variables you don't wish to transform 
no_trans <- c("ecc", "extent", "tx.avg.contrast", "tx.avg.gray", "tx.entropy", "tx.smooth", "tx.3rd.mom", "mode.dist","kurt.dist","skew.dist","area.perim2","circ", "nb.blobs")


# Empty tibble for the PCA results 
pc_res <- tibble(nb_im = numeric(),sp = numeric(),pc = numeric(),eig = numeric(),
                 var = numeric(),first = character(),second = character(),third = character(),
                 last = character())



# 2. Loop over the files for the PCA  -------------------------------------

for (ii in 1:length(files)) {
  
  ##### File 
  filename <- files[ii]
  print(paste("Processing file",basename(filename),sep=" "))
  tic()
  file <- read_csv(filename, col_names=names) %>%
    drop_na() # remove the lines with null values 
  
  ###### Weights: create a weight for each image based on concentration
  poids <- file %>%
    select(date) %>%
    left_join(concentration,by="date")
  row.w = poids$conc/sum(poids$conc)
  
  ###### Transformation (BoxCox) with the function pcatrans
  # pcatrans 
  # Def: This function computes a transformation ot not of the variables for better normality.
  # Args: 
  #      file <tibble, df>         the dataset on which to run the pca (need to have a column "date" for the weights)
  #      rm_cols <vect of str>     columns of no interest for the PCA (but necessary for joining the concentration vector)
  #      trans <str>               type of transformation, one of "log10" (logarithmic), "boxcox" (switch columns with minimum value and Box-Cox)
  #      min_cols <matrix>         minimum for each numeric column 
  #      no_trans <vect of str>    names of the variables you don't want to transform
  #      coeffs <logical>          TRUE records boxcox coefficients used for the transformation (default: FALSE) 
  #      lambda <named num vect>   coefficients for the BoxCox transformation 
  #      coeffs_file <str>         path and filename for the file containing the boxcox coefficients 
  # Output: <tibble> transformed variables 
  file <- pcatrans(file, rm_cols = c("id","filename","date","class_id"), 
                   trans="boxcox",min_cols=mincols, no_trans = no_trans, 
                   coeffs = FALSE)
  
  ##### PCA with 6 components, weight based on concentration
  res.pca <- PCA(file,row.w=row.w, graph=FALSE, scale=TRUE, ncp=6)
  


  
  ###### Extract information 
  for (jj in 1:6) {
    variables <- res.pca$var$contrib[order(res.pca$var$contrib[,jj], decreasing=TRUE),]
    pc_res <- add_row(pc_res, nb_im = gsub(".*_\\s*|im.*", "", filename), 
                            sp = gsub(".*sampled\\s*|_.*", "", filename), 
                            pc = jj, 
                            eig = res.pca$eig[jj,1],
                            var = res.pca$eig[jj,2], 
                            first = row.names(variables)[1],
                            second = row.names(variables)[2],
                            third = row.names(variables)[3],
                            last = tail(row.names(variables),1))
  }
  toc()
}



# 3. Export to csv --------------------------------------------------------

pc_res <- pc_res %>% arrange(nb_im) %>%
  mutate(nb_im = as.numeric(nb_im))

write_csv(pc_res,"data/subsp_results.csv")

rm(res.pca,variables, names, files, mincols)



# 4. Graphs ---------------------------------------------------------------

# Import the results 
pc_res <- read_csv("data/subsp_results.csv") %>%
  pivot_longer(cols = first:last,names_to="place",values_to="variable") %>%
  mutate(place = factor(place, levels = c("first","second","third","last")))


# Percentage of variance explained for each PC depending on the number of images sampled 
var_evol <- pc_res %>% 
  group_by(nb_im,pc) %>%
  summarize(mean_var = mean(var), std_var=sd(var)) # mean and standard deviation per pc for each number of images sampled 

ggplot(var_evol, aes(x=nb_im,y=mean_var)) + 
  facet_wrap(.~pc, scales = "free", # one plot for each pc 
             labeller = labeller(pc=c("1"="PC1","2"="PC2","3"="PC3","4"="PC4","5"="PC5","6"="PC6"))) + # change titles of the plots 
  geom_ribbon(aes(ymin=mean_var-std_var, ymax=mean_var+std_var), fill = "grey70") +
  geom_errorbar(aes(ymin=mean_var-std_var, ymax=mean_var+std_var), width=.2,
                position=position_dodge(0.05)) + 
  geom_point() +
  geom_line() + 
  labs(y = "Mean variance explained", x = "Number of images subsampled per file") +
  # theme_light() + theme(text = element_text(size=20), family = "LM Roman 10 Bold") +
  theme_light() + theme(text = element_text(size=20)) +
  theme(
    strip.background = element_rect(
      color="black", fill="firebrick", size=1.5, linetype="solid"
    )) + 
  theme(panel.grid.major = element_line(colour="grey66"),
        panel.grid.minor = element_line(colour="grey94"))
# ggsave("figures/var_eval.png")


# Occurences of variables as first, second and third contributor for each of the 4 first PCs 
counts <- pc_res %>%
  group_by(nb_im,pc,place,variable) %>%
  summarize(n = n()) %>% #  
  arrange(pc) %>%
  filter(place != "last") %>%
  filter(pc %in% c(1:4))

counts %>%
  mutate(variable = factor(variable, levels=unique(counts$variable))) %>%
  ggplot(aes(fill=variable, x=as.factor(nb_im), y = n)) + 
  facet_grid(pc~place, 
             labeller = labeller(pc=c("1"="PC1","2"="PC2","3"="PC3","4"="PC4","5"="PC5","6"="PC6"), 
                                 place = c("first" = "1st contributor","second" = "2nd contributor", "third" = "3rd contributor"))) + 
  geom_bar(position="dodge", stat="identity") + 
  theme_light() + theme(text = element_text(size=20),
                        axis.text.x = element_text(angle = 45, hjust=1)) +
  # theme(text = element_text(size=20), family = "LM Roman 10 Bold", axis.text.x = element_text(angle = 45, hjust=1)) +
  scale_y_continuous(breaks = c(0,5,10),minor_breaks = NULL) + 
  #theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank()) + 
  labs(x = "Number of images sampled per sample", 
       y = "Counts the variable appears in this position",
       color = "Variables")
# ggsave("figures/counts_var.png")


