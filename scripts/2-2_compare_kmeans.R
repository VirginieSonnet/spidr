#!usr/bin/env R

# %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# % Compare kmeans with different numbers of clusters % 
# %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

# 1. Make graphs based on the centers of the morpho groups: position of the centers 
#    for the different subsampling in the 1st and 2nd dimension and in the 3rd and 
#    4th dimension 
# 2. Make graphs based on the number of morphs per days: correlation plot between 
#    the total clusters and time series
# 3. Time series of diversity indices based on the total number of clusters 
# 4. Correlation plots of the time series of indices based on the total number of clusters 


# Set-up  -----------------------------------------------------------------

rm(list = ls())
gc()

library(tidyverse)
library(corrplot)
library(castr)
library(data.table)
library(facetscales)

# Color palette for the correlation plots: you might want to change based on your correlations 
# ansd preferences
col1 <- viridis_pal(direction = -1, option="A")(20) # 20 colors from viridis magma from dart to light 
col1 <- c(col1[11:20],col1[1:10]) # take the 10 dark ones and replace by the 10 clear ones because the 
# 10 dark ones will correspond to (-1,0) and will be removed 


# 1. Graphs centers -------------------------------------------------------

kmeans_centers<- read_csv("data/subsp_kmeans_centers.csv") 

# Graph 1: position centers of the morpho groups in the in the 1st and 2nd dimensions 
# of the pca depending on the number of groups
kmeans_centers %>% 
  ggplot(aes(Dim.1, Dim.2, color=as.factor(sp))) +
  facet_wrap(tot_k~., nrow=2, labeller = labeller(tot_k = c("10" = "10 clusters",
                                                            "25" = "25 clusters",
                                                            "50" = "50 clusters",
                                                            "100" = "100 clusters",
                                                            "150" = "150 clusters",
                                                            "250" = "250 clusters",
                                                            "500" = "500 clusters",
                                                            "1000" = "1000 clusters"))) + 
  geom_point(alpha=0.5) +
  theme_light() + theme(text = element_text(size=20, family = "LM Roman 10 Bold")) +
  labs(color="Replicate", x = "PC1", y = "PC2")

# Graph 2: position centers of the morpho groups in the in the 3rd and 4th dimensions 
# of the pca depending on the number of groups
kmeans_centers %>% 
  ggplot(aes(Dim.3, Dim.4, color=as.factor(sp))) +
  facet_wrap(tot_k~., nrow=2, labeller = labeller(tot_k = c("10" = "10 clusters",
                                                            "25" = "25 clusters",
                                                            "50" = "50 clusters",
                                                            "100" = "100 clusters",
                                                            "150" = "150 clusters",
                                                            "250" = "250 clusters",
                                                            "500" = "500 clusters",
                                                            "1000" = "1000 clusters"))) +
  geom_point(alpha=0.5) +
  theme_light() + theme(text = element_text(size=15)) +
  labs(color="Sample", x = "PC3", y = "PC4")

rm(kmeans_centers)



# 2. Number of morphs per day ------------------------------------------------------

diversity <- read_csv("data/subsp_diversity_explo.csv") 

# Number of morph per day for each total cluster number scenario
morph_evol <- diversity %>% 
  group_by(tot_k, date) %>% # group by total cluster number and date 
  summarize(mean_nbsp = mean(Nb_sp, na.rm=TRUE), std_nbsp = sd(Nb_sp, na.rm=TRUE)) %>% 
  mutate(smooth_nbsp = slide(mean_nbsp, k=10, mean, n=1, na.rm=T)) # add a smoothed mean 


# Correlation between the time series for each cluster number scenario 
corr <- morph_evol %>% 
  select(date,tot_k,mean_nbsp) %>% 
  pivot_wider(values_from="mean_nbsp",names_from="tot_k") %>%
  select(-date) %>%
  cor()

# Correlation plot 
# par(family="LM Roman 10 Bold")
corrplot(corr,method="color", type="upper", is.cor=TRUE, 
         # colorbar
         cl.lim=c(0,1), cl.cex=1.5, col=col1,
         # labels
         tl.cex=2, tl.srt=360, tl.col="black", tl.offset=0.5)
# png(file="figures/corr_morphs.png")
  

# Time series plot 

# Add rows of NA values for more than 5 days gaps to make smoothed curve clearer 
idx_gaps <- which(diff(morph_evol$date) > 60*24*5) # gaps of 60minutes*24hours*5days = 5 days

# Tibble with the previous date + 25 minutes
gaps <- tibble(mean_nbsp=NA,std_nbsp=NA,smooth_nbsp=NA,date=morph_evol$date[idx_gaps] + 25*60,
               tot_k=morph_evol$tot_k[idx_gaps])
morph_evol <- rbindlist(l=list(morph_evol, gaps), use.names=TRUE) # add the new rows with NA 
morph_evol <- arrange(morph_evol, date) # reorder per date 

# Plot 
morph_evol %>% 
  ggplot() + 
  facet_grid(tot_k~., scales="free_y") + 
  geom_errorbar(aes(x=date, ymin=mean_nbsp-std_nbsp, ymax=mean_nbsp+std_nbsp), color="grey70") + # errorbar due to samples 
  geom_point(aes(x=date, y = mean_nbsp),size=0.1) + # mean
  geom_line(aes(x=date, y = mean_nbsp),size=0.15) + # mean
  geom_path(aes(x=date, y=smooth_nbsp), colour="red", size=0.75) + # moving mean 
  labs(y = "Mean number of morpo groups", x = "Date") +
  # theme_light() + theme(text = element_text(size=15, family="LM Roman 10 Bold)) +
  theme_light() + theme(text = element_text(size=15)) +
  theme(
    strip.background = element_rect(
      color="black", fill="firebrick", size=1.5, linetype="solid"
    )) + 
  scale_x_datetime(date_breaks = "4 months", date_labels = "%m-%Y")
  

rm(morph_evol, idx_gaps, gaps, corr)



# 3. Diversity  -----------------------------------------------------------

diversity <- read_csv("data/subsp_diversity_explo.csv") 

# Mean diversity per date and scenario of number of clusters for each diversity index
diversity_evol <- diversity %>% 
    rename(Richness=FRic, Divergence=FDiv, Evenness=FEve) %>%
    pivot_longer(cols = Richness:Evenness, names_to="index",values_to = "div") %>%
    group_by(index, tot_k, date) %>% # group by diversity index, total number of cluster and date
    summarize(mean_div = mean(div, na.rm=TRUE), std_div = sd(div, na.rm=TRUE)) %>% 
    arrange(index,tot_k,date) %>% # order by diversity index, number of clusters and date
    mutate(smooth_div = slide(mean_div, k=10, mean, n=3, na.rm=T)) # moving mean 


# Time series 

# Add rows of NA values for more than 5 days gaps to make smoothed curve clearer 
idx_gaps <- which(diff(diversity_evol$date) > 60*24*5) # gaps of 60minutes*24hours*5days = 5 days

# Tibble with the previous date + 25 minutes
gaps <- tibble(mean_div=NA,std_div=NA,smooth_div=NA,date=diversity_evol$date[idx_gaps] + 25*60,
               tot_k=diversity_evol$tot_k[idx_gaps],index=diversity_evol$index[idx_gaps])
diversity_evol <- rbindlist(l=list(diversity_evol, gaps), use.names=TRUE)
diversity_evol <- arrange(diversity_evol, date)

diversity_evol %>% 
  filter(tot_k %in% c(10, 25, 50, 100, 1000)) %>% # only plot some of the clusters to not overvrowd the graph 
  ggplot(aes(x=date, y = mean_div)) + 
  facet_grid(index~tot_k, scale="free_y", labeller = labeller(tot_k = c("10" = "10 clusters",
                                                                        "25" = "25 clusters",
                                                                        "50" = "50 clusters",
                                                                        "150" = "150 clusters",
                                                                        "1000" = "1000 clusters"))) + 
  #geom_errorbar(aes(x=date, ymin=mean_div-std_div, ymax=mean_div+std_div), color="grey70") + 
  geom_point(aes(x=date, y = mean_div),size=0.1) + 
  geom_line(aes(x=date, y = mean_div),size=0.15) + 
  geom_path(aes(x=date, y=smooth_div), colour="red", size=0.5) +
  labs(y = "Diversity indices", x = "Date") +
  # theme_light() + theme(text = element_text(size=20, family="LM roman 10 Bold)) +
  theme_light() + theme(text = element_text(size=20)) +
  theme(
    strip.background = element_rect(
      color="black", fill="firebrick", size=1.5, linetype="solid"
    )) +
  theme(axis.text.x = element_text(size=11), axis.text.y=element_text(size=14)) + 
  scale_x_datetime(date_breaks = "year", date_labels = "%Y")





# 4. Correlation analysis -------------------------------------------------

# Create a tibble to store the correlation between adjacent time series of diversity indices, 
# filling the first column of the tibble with the number of clusters (there is not 10 because 
# it's the correlation between 2 clusters numbers)
tbl_cor <- tibble(nb_clusters = c(25, 50, 100, 150, 250, 500, 1000))

# Column names of the tibble 
names <- c("nb_clusters", "Divergence", "Evenness","Richness")


for (ii in 2:4){ 
  # Calculate the correlation between the clusters number for each diversity indice 
  correlation <- diversity_evol %>% 
            ungroup() %>%
            drop_na() %>% 
            filter(index==names[ii]) %>% 
            select(tot_k,date,mean_div) %>% 
            pivot_wider(names_from="tot_k", values_from="mean_div") %>% 
            select(-date) %>% 
            cor()
  # Correlation plot 
  par(family="LM Roman 10 Bold")
  corrplot(correlation,method="color", type="upper", is.cor=TRUE, 
           # colorbar
           cl.lim=c(0,1), cl.cex=1.5, col=col1,
           # labels
           tl.cex=2, tl.srt=360, tl.col="black", tl.offset=0.5)
  png(file=paste("figures/corr_",names[ii],".png",sep=""))
  
  # Extract the correlation between adjacent numbers (10-25, 25-50, 50-100,etc)
  nb_cd <- row(correlation) - col(correlation)
  tbl_cor[,ii] <- unlist(split(correlation,nb_cd)[nrow(tbl_cor)])
}
colnames(tbl_cor) <- names


# Correlation between adjacent time series 
tbl_cor %>% 
  pivot_longer(2:4, names_to = "index", values_to="div") %>%
  ggplot(aes(x=nb_clusters, y=div)) + geom_line() + geom_point() + 
  facet_wrap(.~index) +
  labs(y = "Correlation", x = "Number of clusters") +
  theme_light() + scale_y_continuous(limits = c(0,1), expand=c(0,0)) +
  theme(
    strip.background = element_rect(
      color="black", fill="firebrick", size=1.5, linetype="solid"
    )) + 
  theme(text = element_text(size=15)) 
# theme(text = element_text(size=15, family="LM Roman 10 Bold")) 
