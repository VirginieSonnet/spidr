---
title: "Subsampling of Plankton Imagery Datasets and Reprojection in a reduced space"
author: "Virginie Sonnet \nvirginie_sonnet@my.uri.edu \nhttps://github.com/VirginieSonnet"
date: "May 4th, 2020"
output:
  rmdformats::readthedown:
    lightbox: TRUE
    highlight: pygments
    # use_bookdown: TRUE # section numbering 
    # toc: TRUE
    toc_depth: 5 # types of headers to include 
    # toc_float: TRUE
    # number_sections: FALSE
    # code_folding: "hide"
---

<style>
body {
font-family: "LM Roman";
text-align: justify}
</style>


```{r setup, include=FALSE}
knitr::opts_chunk$set(eval=FALSE,
                      results = "hide",
                      error=FALSE,
                      message=F,
                      warning=F,
                      cache=FALSE)
```

# Introduction

### *Large morphological datasets*

Plantkon imagers can image planktonic organisms from 300nm (FlowCam nano) up to 10cm (ISIIS) (Lombard et al, 2019). Some run in a lab but more and more are automated and can be deployed on cruises or on fixed platforms, generating **millions and millions of images**. Those datasets are mostly used for taxonomic purposes. However, a number of morphological characteristics associated to each individual are often generated to be used within machine learning algorithms. If those features form the basis of the plankton image recognition, they are also interesting measures of variability within the community that do not depend on the species level.

Such morphological datasets that combine numerous columns of morphological features and millions of observations, can't easily be opened in any of the widely used programming softwares (Python, R, MATLAB) for further exploration with multivariate data analysis. Even if it was possible, running a Principal Component Analysis or a t-SNE on millions of lines takes time and computer power. Knowledge of methods and resources specific to big data analysis such as MapReduce with Hadoop or High Performance Computing could be an answer but these resources are not available to everyone and these tools have a quite steep learning curve.

<br> 

### *A methodology based on subsampling, dimension reduction and clustering*

**Here, we detail a workflow to explore morphological variation and diversity of planktonic organisms based on subsampling, Principal Component Analysis, K-means clustering and reprojection** (Figure 1). The goal is to explore the main morphological variations within the dataset with a dimension reduction technique, the PCA, and to cluster the images projected in this morphological space into morpho groups that can be used similarly as species with the diversity indices developed by Villeger et al. (2008). We use subsampling to run these analysis and the single value decomposition (SVD) matrix from the PCA with the k nearest neighbour method to reproject the totality of the dataset into the morphological space and assign them a morpho group. The methodology comports 3 steps: 

<b>
1. How many images have to be subsampled to capture the morphological variation? <br>
2. How many clusters are needed to capture the morphological diversity? <br> 
3. Analysis and reprojection 
</b>

![](figures/workflow.png)

<font size="2"> **Figure 1.** *Workflow of the methodology based on subsampling and a combination of dimension reduction, clustering and diversity indices* </font>

<br> 

### *Applications and example* 

The full methodology was applied to a 2-years dataset of phytoplankton imagery from an Imaging FlowCytobot (Sonnet et al., in preparation) while the morphological approach combining PCA, k-means and diversity and designed by Jean-Olivier Irisson and Sakina-Dorothée Ayata was used on Mediterannean zooplankton (Irisson et al., pre-print) Arctic zooplankton (Vilgrain et al., 2020, in press) and marine detritus (Trudnowska et al., 2020, in review). 

Below, you can find an example with a morphological dataset from an Imaging FlowCytobot. The graphs come from the analysis of the 2-years dataset but if you want to try running the analysis, in the github folder you will find a 2-days extract of the dataset and the files that stem from this analysis applied on it.  

<br> 

### *Storage* 

I assume the morphological features are stored for each image within a **database**. All the queries within this document are only examples and will need to be adapted to the structure of your database. The same applies for the database information and password. For reference, Figure 2 shows the structure of the database I used (designed by *Audrey Ciochetto*). 

*If you only have csv files, you can combine them within the shell and work from there and the principles of the analysis are the same. I also have some codes that I previously used when I was in this situation and I would be happy to share them if they could be useful.* 

![](figures/IFCB-database.png) 
<font size="2"> **Figure 2.** *Diagram of the database structure in the Mouw lab. Main boxes are tables and each table has a first column called id. Smaller boxes on arrows are the column name that relates the right table with the id column of the left table.* </font>

<br>

###  *Codes* 

Most of the codes have not been turned into functions because there are many possibilities in your column names, morphological characteristics, conditions specific to the deployment of any plankton imager and the parameters you will want to test. However, both within this document and at the beginning of each code, there is an indication of which sections of the code you might be willing to adapt. 

Throughout the document and the codes associated, I assume you are in an R project and directory that have 4 folders: *data*, *figures*, *documents* and *scripts*. 

******

# **1. Number of images**  

The number of images to subsample will probably never be completely objective. Any criteria or threshold will be based on your computer power, your time, your dataset, the analysis you are planning, even on you... 

<span style="color:green"> **Method**</span>: I chose to take **5% of my total number of samples** and then to try with **3, 10, 100, 250, 500 and 1000 images per sample** and look at the changes in variance explained and variables contributing the most to the principal components. I repeat the subsampling **10 times for each case** to estimate the standard deviation and the mean. 

<br>

### 1.1. Random files 

I have inherent criteria based on my instrument when I select my **samples**, your criteria will depend on your instrument and the way your database is organized. In my case: 

* a deployment id (*deployment_id = 1*)
* we have had a few files where the timing is not recorded so I can't use them quantitatively and I exclude them from the analysis (*runTime != 0*) = remove 23 samples 
* the quality control code is good (*qc = 1*)
* the minimum number of images in the sample: (*n_roi > 250*)
* dates between 2017-11-01 and 2019-11-01 (*date > '2017-11-01' & date < '2019-11-01'*)

For the **roi** or **images**, I have more criteria: 

* the name of my columns: *metadata columns* (id, roi_number, filename, date, taxonomic id), *columns chosen* (area, perim...) and an associated *shorter name* 
* add 3 columns to the columns originally in the database: major axis/minor axis, perimeter/major axis and circularity
* the *class_id* is not one of the ciliates, zooplankton, detritus, mix 
* if the class_id is *unclassified*, then the *area has to be under 90 000 pixel squared* to avoid images of algae or nematodes 

<br>

I use these criteria within the **R script** `1-1_sample_files.R` to select a percentage of random samples from your dataset. 

1. Get the number of files present in the database and meeting your criteria *(you might want to change these criteria in the query)*
2. Calculate the number of files to sample based on a percentage *(the percentage is 5 in the code)* 
3. Query the files id and take randomly the number determined in 2. *(you might want to change these criteria in the query)*
4. Query the images that meet your criteria from the files id *(you might want to change the criteria of the images in the query)*
5. Extract counts per sample 
6. Export to csv

<u> *Outputs*</u>: combined images file ($\small{\textit{subsp_combined.csv}}$) and counts per file ($\small{\textit{subsp_counts_cleaned.csv}}$)

Extract column names in **bash**: 
```{bash, eval = FALSE}
head -1 data/subsp_combined.csv > data/colnames.csv
```


<br>

### 1.2. Subsampling 

Subsample 3, 10, 100, 250, 500 and 1000 images per sample and repeat 10 times (total: 60 files): **bash script** `1-2_subsampling.sh`

<span style="color:red"> This code calls 2 other codes, **extract.awk** and **indices.R**.</span> 

<u> **Arguments**</u>: 

* -d: path where to get and write the data 
* -p: path where to get the scripts (no slash at the end)
* -f: filename of the combined images (default: *combined.csv*)
* -c: filename with the counts per sample after query/cleaning (default: *counts_cleaned.csv*)
* -s: type of sampling, proportion of the file (*proportion*) VS number of images per sample (*date*) (default)
* -i: replicate number
* -n: number of images to sample per file or proportion of the file to sample 

<u> **Output**</u>: $\small{\textit{combined_sampled{i}_{n}im.csv}}$

```{bash, eval = FALSE}
# bash code
for i in 3 10 50 100 250 500 1000 # images subsampled by sample (you might want to try other ones)
do
    for j in {1..10} # replicates  
    do
      bash scripts/1-2_subsampling.sh -d data/ -p scripts -f subsp_combined.csv \
      -c subsp_counts_cleaned.csv -s date -i $j -n $i
    done
done
rm data/idxToSample.csv # remove the csv file with the random indices generated at each iteration  
```


Sometimes, a couple of the subsamples have a header. To make sure none of them have one, remove lines that contain the header pattern (make sure this pattern does not appear in your filename!). 


```{bash, eval = FALSE}
grep "id" data/combined_sampled* | cut -d: -f1 | xargs -n1 sed -i .bak '1d' # select the files with a header and remove this header
rm data/*.bak # remove the temporary .bak files
grep "id" data/combined_sampled* # verify there are none left 
```

<br>

### 1.3. Subsample Analysis

I chose to perform a **weighted-PCA with Box-Cox transformation** for the non-normal variables. If that's also your case, you'll need: 

* the **minimum value** that each column can take in the database to switch the columns to have a minimum higher than 1
* the **concentration** of organisms per sample
* run the **weighted-PCA with Box-Cox transformation** 

#### *Minimum per column*

Let's first get the minimum: use this **bash** command replacing the arguments with your database information: 

```{bash, eval = FALSE}
mysql -h images.gso.uri.edu -D plankton_images -u student -pRestmonami -e "query;" > data/mincols.csv
```

Note that I add 3 columns to the columns originally in the database: major axis/minor axis, perimeter/major axis and circularity. 

```{sql, eval = FALSE}
SELECT MIN(Area) AS area, MIN(Biovolume) AS vol, MIN(ConvexArea) AS 'c.area', 
MIN(ConvexPerimeter) AS 'c.perim', MIN(Eccentricity) AS ecc, 
MIN(EquivDiameter) AS 'eq.diam', MIN(Extent) AS extent, MIN(H180) AS h180, MIN(H90) AS h90, 
MIN(Hflip) AS hflip, MIN(MajorAxisLength) AS 'maj.ax', 
MIN(MinorAxisLength) AS 'min.ax', MIN(Perimeter) AS perim, MIN(Solidity) AS solid, 
MIN(numBlobs) AS 'nb.blobs', MIN(shapehist_kurtosis_normEqD) AS 'kurt.dist', 
MIN(shapehist_mean_normEqD) AS 'mean.dist', MIN(shapehist_median_normEqD) AS 'med.dist', 
MIN(shapehist_mode_normEqD) AS 'mode.dist', MIN(shapehist_skewness_normEqD) AS 'skew.dist', 
MIN(summedArea) AS 's.area', MIN(summedBiovolume) AS 's.vol', MIN(summedConvexArea) AS 's.c.area', 
MIN(summedConvexPerimeter) AS 's.c.perim', MIN(summedMajorAxisLength) AS 's.maj.ax', 
MIN(summedMinorAxisLength) AS 's.min.ax', MIN(summedPerimeter) AS 's.perim', 
MIN(texture_average_contrast) AS 'tx.contrast', MIN(texture_average_gray_level) AS 'tx.gray', 
MIN(texture_entropy) AS 'tx.entropy', MIN(texture_smoothness) AS 'tx.smooth', 
MIN(texture_third_moment) AS 'tx.3rd.mom', MIN(texture_uniformity) AS 'tx.unif', 
MIN(RotatedBoundingBox_xwidth) AS 'r.bbox.x', MIN(RotatedBoundingBox_ywidth) AS 'r.bbox.y',
MIN(Area_over_PerimeterSquared) AS 'area.perim2', MIN(Area_over_Perimeter) AS 'area.perim', 
MIN(H90_over_Hflip) AS 'h90.hflip', MIN(H90_over_H180) AS 'h90.h180', 
MIN(summedConvexPerimeter_over_Perimeter) AS 's.c.perim.perim', 
MIN(MajorAxisLength/MinorAxisLength) AS 'maj.min', 
MIN(Perimeter/MajorAxisLength) AS 'perim.maj', 
MIN(4*3.14159265359*Area_over_PerimeterSquared) AS 'circ' 
FROM roi JOIN raw_files ON roi.raw_file_id = raw_files.id 
         JOIN auto_class ON roi.id = auto_class.roi_id 
WHERE runTime != 0 AND 
      deployment_id = 1 AND 
      qc_file = 1 AND 
      n_roi > 250 AND
      date > '2017-11-01' AND date < '2019-11-01' AND
      class_id NOT IN (58,85,88,90,91,94,106,109,110,111,119,121,122,124,127,128,129) AND
      !(class_id = 96 AND Area > 90000)
```

<br>

#### *Concentration per sample* 

**Second**, for the weighted-PCA you will need the **concentration** of organisms per sample to use as weight: **R script** `concentration.R`. 

1. Connect to the database and query the counts, runTime, inhibitTime and mL_counted *(you might want to change the criteria of the query)*
2. Compute the concentration: $mL\_counted = 0.25 \times \frac{(runTime-inhibitTime)}{60}$ and $concentration = \frac{counts}{mL\_counted}$
3. Export to csv

<span style="color:red">  **ATTENTION**: This code is specifically designed for data from the Imaging FlowCytobot, you will need to estimate the concentration differently for other instruments. </span>

<br>

#### *Principal Component Analysis*

**Third**, you can run the **PCA** on each sample and look at how well it performs: **R script** `1-3_test_nb_im.R`. 

<span style="color:red"> This code uses the function **pcatrans.R**. </span> This function is also in the github repository and allows you to transform certain variables of a dataset with a logarithmic or Box-Cox transformation. 


1. Import files (this will need to be modified based on your instrument and database): 
    * concentration per sample ($\small{\textit{concentration.csv}}$)
    * name of subsampled files ($\small{\textit{combined_sampled{i}_{n}im.csv}}$)
    * column names ($\small{\textit{colnames.csv}}$) 
    * minimum value in the database per column ($\small{\textit{mincols.csv}}$) and index of the ones below 0
    * define the columns you don't want to Box-Cox transform 
2. Run the transformation and the PCA 
    * swith columns by their minimum 
    * Box-Cox transformation 
    * weighted-PCA keeping the 6 first components (the weight is the concentration of the sample)
    * store information on the variance explained by the PCs and the main contributors in a tibble 
3. Export to csv
4. Graphs 
    * percentage of variance explained for each of the 6 first PC depending on the number of images sampled (Figure 3)
    * occurences of variables as 1st, 2nd and 3rg contributor for each of the 4 first PCs (Figure 4)
5. Statistiques: linear regressions 

<u> **Output** </u>: results of the comparison between the pca ($\small{\textit{subsp_results.csv}}$) and graphs 

![](figures/pc_var.png) 
<font size="2">  **Figure 3.** *Variance explained by each axis depending on the number of images subsampled, the black bars are the standard deviations, also materialized by the grey ribbon and the green arrows indicate the values for 250 images* </font>

![](figures/counts_var.png) 
<font size="2"> **Figure 4.** *Number of replicates for which a morphological feature is first, second or third contributor for each of the principal components 1 to 4 depending on the number of images subsampled. The morphological variables are coloured and for each number of images subsampled we count how many times they appear as first, second or thirdcontributor on the 4 axes in the 10 replicates. For example, the convex perimeter is the first contributor for the principal component 1 for all 10 replicates whatever the number of images we subsample. However, when we take 3 images per sample, the second contributor of the first principal component is the major axis in 3 replicates and the perimeter in 7 replicates.* </font>

For my analysis, I have decided for **250 images** per sample because the variance  is small between replicates and the main contributors are similar. You need to take into account further analysis down the road. In my case, I want to look at the evolution hour by hour so I want to keep a maximum of details. 

**You will only need one of the subsamples (with the number of images you have chosen!) for the step 2 so you can delete the others in bash.** 

```{bash, eval=FALSE}
find data/combined_sampled* ! -name combined_sampled1_250im.csv | xargs -n1 rm # change your sample name 
```

******

# **2. Number of clusters** 

<span style="color:green"> **Method**</span>: I will cluster the data with 10, 25, 100, 250, 500 and 1000 clusters 10 times on the pca coordinates and compute the diversity indices from Villéger et al (2008) - Richness, Eveness and Divergence - on the outputs to compare them. 

<br>

### 2.1. Compute clustering with different number of groups

On one of the samples for the number of images determined in 1, run: **R script** `2-1_explo_kmeans.R`. 

<span style="color:red"> **ATTENTION**: this code calls the functions **pcatrans.R**, **lib_functional_diversity.R** and **morphological_diversity.R**. </span> The function morphological_diversity is a wrap-up around the function lib_functional_diversity.R from Villéger that reearranges the dataset into weights per date per morph and centers coordinates necessary for the diversity indices. 

1. Run the pca (with 4 components) on the subsample you have kept and store the coordinates for each image *(you might want to change the number of components)*
2. Perform the kmeans 10 times for 10, 25, 50, 100, 250, 500 and 1000 clusters *=> long step and you might want to change the numbers of clusters* 
3. Export the tibble with pca coordinates and cluster number, and the one with the kmeans centers 
4. Compute the diversity for each of the output *=> longest step* 
5. Export the diversity per date

<u> **Outputs**</u>: the pca coordinates and cluster number for each image with different clusterings ($\small{\textit{subsp_pca+conc+cluster.csv}}$), the kmeans centers ($\small{\textit{subsp_kmeans_centers.csv}}$) and the diversity per date ($\small{\textit{subsp_diversity_explo.csv}}$). 

<br> 

### 2.2. Determine the number of groups to use 

Use the csv files generated before in the **R script** `2-2_compare_kmeans.R`. All parts are independant, if you only want to compute some of the graphs. 

1. Make graphs based on the **centers of the morpho groups**: position of the centers for the different subsampling in the 1st and 2nd dimension (Figure 5) and in the 3rd and 4th dimension (Figure 6)

![](figures/subsp_centers_pc1-2.png)
<font size="2"> **Figure 5.** *Position of the morpho groups' centers in the first 2 axis of the morphological space created by the PCA, depending on the number of clusters chosen.* </font>


![](figures/subsp_centers_pc3-4.png)
<font size="2"> **Figure 6.** *Position of the morpho groups' centers in the third and fourth axis of the morphological space created by the PCA, depending on the number of clusters chosen.* </font>

2. Make graphs based on the **number of morphs per days**: correlation plot between the scenario of total clusters and time series (Figure 7) 

![](figures/morpho_groups.png)
<font size="2"> **Figure 7.** *(left) Correlation between the time series of morphological groups and (right) mean number of morphological groups per sample date for each number of clusters. The red curve is the smoothed mean number of morphological groups with a window of 10 values before and after and the error bars are in grey. See Appendix for all clusters.* </font>

3. **Time series of diversity indices** based on the total number of clusters (Figure 8)

![](figures/subsp_ts_diversity.png)
 <font size="2"> **Figure 8.** *Time series of diversity indices for 10, 25, 50, 150 and 1000 clusters.* </font>
 
4. **Correlation plots of the time series of indices** based on the total number of clusters (Figure 9)

![](figures/corr_div.png)
<font size="2"> **Figure 9.** *(top) Correlation between diversity time series depending on the number of clusters and (bottom) Correlation between adjacent numbers of clusters: the rst dot is the correlation between the curves of 10 and 25 clusters, the second between 25 and 50 clusters, etc.* </font>

In my case, I have decided to settle for 150 clusters but as often in clustering, there is a piece of subjectivity involved. 

You can delete the subsampled file. 

```{bash}
# bash 
rm data/combined_sampled* 
```


******

# **3. Analysis and reprojection ** 

### 3.1. Data

Same as for the subsampling, query the data through bash but this time query your **whole** dataset. 

```{bash, eval = FALSE}
mysql -h images.gso.uri.edu -D plankton_images -u student -pRestmonami -e  "query;" > data/combined.csv
```

For reference, here is the query I used and it took 411 minutes (7h) to pull 110 741 191 rows from the database (but I have very specific conditions in my query that make it much slower): 

```{sql, eval = FALSE}
SELECT roi.id, roi_number, filename, date, Area AS area, Biovolume AS vol, ConvexArea AS 'c.area', ConvexPerimeter AS 'c.perim', Eccentricity AS ecc, EquivDiameter AS 'eq.diam', Extent AS extent, H180 AS h180, H90 AS h90, Hflip AS hflip, MajorAxisLength AS 'maj.ax', MinorAxisLength AS 'min.ax', Perimeter AS perim, Solidity AS solid, numBlobs AS 'nb.blobs', shapehist_kurtosis_normEqD AS 'kurt.dist', shapehist_mean_normEqD AS 'mean.dist', shapehist_median_normEqD AS 'med.dist', shapehist_mode_normEqD AS 'mode.dist', shapehist_skewness_normEqD AS 'skew.dist', summedArea AS 's.area', summedBiovolume AS 's.vol', summedConvexArea AS 's.c.area', summedConvexPerimeter AS 's.c.perim', summedMajorAxisLength AS 's.maj.ax', summedMinorAxisLength AS 's.min.ax', summedPerimeter AS 's.perim', texture_average_contrast AS 'tx.contrast', texture_average_gray_level AS 'tx.gray', texture_entropy AS 'tx.entropy', texture_smoothness AS 'tx.smooth', texture_third_moment AS 'tx.3rd.mom', texture_uniformity AS 'tx.unif', RotatedBoundingBox_xwidth AS 'r.bbox.x', RotatedBoundingBox_ywidth AS 'r.bbox.y', Area_over_PerimeterSquared AS 'area.perim2', Area_over_Perimeter AS 'area.perim', H90_over_Hflip AS 'h90.hflip', H90_over_H180 AS 'h90.h180', summedConvexPerimeter_over_Perimeter AS 's.c.perim.perim', MajorAxisLength/MinorAxisLength AS 'maj.min', Perimeter/MajorAxisLength AS 'perim.maj', 4*3.14159265359*Area_over_PerimeterSquared AS 'circ', class_id 
FROM roi JOIN raw_files ON roi.raw_file_id = raw_files.id 
         JOIN auto_class ON roi.id = auto_class.roi_id 
WHERE runTime != 0 AND 
      deployment_id = 1 AND 
      qc_file = 1 AND 
      n_roi > 250 AND
      date > '2017-11-01' AND date < '2019-11-01' AND
      class_id NOT IN (58,85,88,90,91,94,106,109,110,111,119,121,122,124,127,128,129) AND
      !(class_id = 96 AND Area > 90000)
ORDER BY date, roi_number
```

<span style="color:red"> **ATTENTION**: The subsample file in step 1 was exported from R to csv, as such, it was comma delimited while the combined file we just queried from bash is **tab delimited**. </span>

The cleaning left consist in removing lines with **NULL** (or NA depending on your database) values because they correspond to very small cells for which the morphology could not be computed in our case (left: 110 741 171) and removing the header line. In bash, run: 

```{bash, eval = F}
grep -v "NULL" data/combined.csv > data/combined_cleaned.csv # remove lines with NULL values 
head -1 data/combined_cleaned.csv > data/colnames.csv # keep the header in case 
sed -i .bak '1d' data/combined_cleaned.csv # remove the header 
rm data/combined.csv */*.bak
```

As an example, here is how the first columns and lines of my dataset look like. As I mentioned, it has 110 741 171 images (rows) and 47 variables (columns). 

![](figures/combined_cleaned.png)

To subsample, you will need the number of images per sample. The following bash code will look at the third column (filename) and count the occurence of each one of them, the second awk will just reorganize to file to have "filename,counts". For my file the code took 45min.   

```{bash, eval = F}
time awk '{print $3}' data/combined_cleaned.csv | uniq -c | awk 'NR==1; NR > 1 {print $2","$1 | "sort"}' > data/counts.csv # the 2nd awk reorganize
sed -i .bak '1d' data/counts.csv # remove first line with the count for "filename"
head -1 data/subsp_counts_cleaned.csv | cat - data/counts.csv > data/counts_cleaned.csv # add a header based on the header of the subsampled counts (filename, count)
rm */*.bak data/counts.csv

# if I have removed the header  
echo "filename, counts" > counts_cleaned.csv 
awk 'NR==1; {print $2","$1}' counts.csv | sed -n 2p >> counts_cleaned.csv
tail -n+2 counts.csv >> counts_cleaned.csv
```

<br>

### 3.2. PCA and clustering on subsampling  

**Subsample** with the number of images you determined in **1**, in my case 250. 

```{bash, eval = FALSE}
time bash scripts/1-2_subsampling.sh -d data -p scripts -f combined_cleaned.csv \
-c counts_cleaned.csv -s date -n 250
```

Run the PCA and clustering on the subsampled file. Use the **Rscript** `3-2_pca+clustering.R`. 

1. Load the data *(you might need to change the name of the file based on the number of images you subsampled)*
2. weighted-PCA with Box-Cox transformation
3. weighted-Kmeans clustering *(you might want to change the number of clusters based on what you decided)*

<u> **Outputs**</u>: a csv file with the Box-Cox coefficients used for the transformation ($\small{lambda.csv}$), a R file with the result object of the PCA ($\small{\textit{res_pca.rds}}$) and a csv file with the coordinates of the centers of the morphological groups from the kmeans ($\small{\textit{kmeans_centers.csv}}$)

<br>

### 3.3. Reprojection and cluster assignment 

Reproject all images in the PCA space, assign a cluster number and compute the diversity indices. Use the **Rscript** `3-3_reprojection.R`. 

1. Load the data 
2. Define the function to apply on each chunk of the csv file (reprojection+knn)
    * use the boxcox coefficients from the boxcox transformation of the subsample and apply them on each chunk of data
    * use the SVD matrix from the weighted-PCA run on the subsample to reproject all images in the morphological space
    * use the k-nearest-neighbour approach with the centers coordinates from the weighted-kmeans run on the subsample (k=10 neighbours) to assign a morpho group to all images 
3. Run the reprojection and knn on each chunk 
4. Compute the diversity indices 

<u> **Outputs**</u>: a file with the coordinates in the morphological space and the cluster number for each image ($\small{\textit{full_data_pca+kmeans.csv}}$) and a file with the morphological diversity indices for each sample ($\small{\textit{full_data_diversity.csv}}$)


**You have your data ready for analysis!!**

******

# Credits 

The subsampling methodology to deal with large datasets and the comparison for the number of images and the number of clusters were designed by **Virginie Sonnet** (Graduate School of Oceanography, University of Rhode Island). 

The morphological analysis workflow was developed by **Jean-Olivier Irisson** and **Sakina-Dorothée Ayata** (Laboratoire d'Océanographie de Villefranche-sur-Mer, Sorbonne Université). 

******

# Sources 

Irisson, J.-O., Cailleton, M., Desnos, C., Jalabert, L., Elineau, A., Stemmann, L., & Ayata, S.-D. (2020). Morphological diversity increases with oligotrophy along a zooplankton time series. Ocean Sciences Meeting 2020.

Lombard, F., Boss, E., Waite, A. M., Vogt, M., Uitz, J., Stemmann, L., Sosik, H. M., Schulz, J., Romagnan, J.-B., Picheral, M., Pearlman, J., Ohman, M. D., Niehoff, B., Möller, K. O., Miloslavich, P., Lara-Lpez, A., Kudela, R., Lopes, R. M., Kiko, R., … Appeltans, W. (2019). Globally Consistent Quantitative Observations of Planktonic Ecosystems. Frontiers in Marine Science, 6, 196. https://doi.org/10.3389/fmars.2019.00196

Sonnet, V., Guidi, L., Mouw, C. B., & Ayata, S.-D. (2020). Morphological Diversity of Phytoplankton: Identification of Traits, Morphological Succession and Periodicities from Imagery in Narragansett Bay, US. Ocean Sciences Meeting 2020.

Trudnowska, E., Lacour, L., Rogge, A., Irisson, J. O., Waite, A. M., Babin, M., & Stemmann, L. (2020). Unravelling the dynamics of pelagic ecosystems by quantitative observation of morphological attributes of marine snow: A case study in the Arctic. Ocean Sciences Meeting 2020.

Vilgrain, L., Irisson, J.-O., Ayata, S.-D., Picheral, M., Babin, M., & Maps, F. (2020). Morphological traits of zooplankton reveal ecological patterns along ice melt dynamics in the Arctic. Ocean Sciences Meeting 2020.
Villéger, S., Mason, N. W. H., & Mouillot, D. (2008). New multidimensional diversity indices for a multifaceted framework in functional ecology. Ecology, 89(8), 2290–2301. https://doi.org/10.1890/07-1206.1


