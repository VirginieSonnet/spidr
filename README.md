# Subsampling of Plankton Imagery Datasets and Reprojection in a reduced space

**** 

This folder contains a worflow to process morphological features of plankton imagery in order to extract the main **morphological variations and diversity**. It includes a subsampling step that allows to deal with datasets too big to be opened in a programming software without (hopefully) losing too much resolution in the variations and diversity. 

<br>

### Analysis 

The morphological analysis is based on **dimension reduction** (weighted-Principal Component Analysis), **clustering** (weighted K-means) and **functional diversity indices** as defined by Villéger et al. (2008). 

The subsampling determines a number of images to subsample per sample date and a number of clusters, and perform the morphological analysis on the subsampled data. The full dataset is then **reprojected** into the PCA space using the SVD matrix and a cluster number is associated based on the **k-nearest neighbours** method. 

<br>

### Material 

**All the details and an example on an ImagingFlowCytobot dataset can be found in the HTML file `spidr.html`.** 

The scripts assume access to a database and the queries will have to be modified following the database structure. All the scripts and functions are in the `scripts/` folder except the file `lib_functional_diversity.R` that contains the function `multidimFD4` written by Sébastien Villéger and available at http://villeger.sebastien.free.fr/Rscripts.html.  

A very short subset of the dataset we used as an example is provided in the `data/` folder, along with the CSV files that come from the database if you wish to try running the scripts. 

<br>

*Villéger, S., Mason, N. W. H., & Mouillot, D. (2008). New multidimensional diversity indices for a multifaceted framework in functional ecology. Ecology, 89(8), 2290–2301. https://doi.org/10.1890/07-1206.1*



