#!usr/bin/env bash

########################################
# Subsampling within the cleaned file  #
########################################

# Arguments:
 								
# -d path for data (+ storage)						
# -p path for script (default:$DATA)
# -c filename for the file with counts (default: counts_cleaned.csv)
# -f filename for the file with combined cleaned data (default: combined_cleaned.csv) 
# -s sampling type (proportion of the file or fixed number of images per sample) (default:date)
# -i sample id in case you want to generate a batch of subsampled file	
# -n proportion of the file to subsample or number of images to sample for each sample (default: 100)

# Inputs: 
# - file with counts after cleaning
# - file with combined images 
# - Rscript to compute the randome indices 
# - Awk script to extract the rows 

# Outputs: 
# - combined_sampled{i}_{n}im.csv

while getopts d:p:c:f:o:s:i:n: option
do
        case "${option}"
                in
                d) DATA=${OPTARG};;     # <path> Location of the data

                p) SCRIPTS=${OPTARG};;  # <path> Location of the scripts
                                                # default = $DATA

                c) FILECOUNT=${OPTARG};;    # <string> Filename for the counts
                                                # default = counts_cleaned.csv

                f) FILE=${OPTARG};;    # <string> Filename for the combined cleaned file
                                                # default = combined_cleaned.csv

                s) SAMPLING=${OPTARG};; # <proportion, date> Type of sampling
                                                # default = date

                i) SAMPLE_ID=${OPTARG};; # <integer> Sample number

                n) NR=${OPTARG};;       # <integer> Number of images to sample per sample or proportion of the dataset
                                                # default = 100
        esac
done

# Set default values if variables left empty

if [ -z "$FILE" ]
then FILE="combined_cleaned.csv"
fi

if [ -z "$FILECOUNT" ]
then FILECOUNT="counts_cleaned.csv"
fi

if [ -z "$SAMPLING" ]
then SAMPLING=date
fi

if [ -z "$NR" ]
then NR=100
fi

echo "Combined file is $FILE -f"
echo "Counts file is $FILECOUNT -c"
echo "Data are in $DATA -d"
echo "Scripts are in $SCRIPTS -p"
echo "Type of sampling: $SAMPLING -s"
echo "Sample number: $SAMPLE_ID -i"
echo "Number of images to sample per sample: $NR -n"

export  FILE FILECOUNT DATA SCRIPTS SAMPLING SAMPLE_ID NR


case "$SAMPLING"
     in
     # use directly the combined file and take a proportion of each date 
     proportion) perl -ne "print if (rand() < ${NR})" $DATA/$FILE > $DATA/combined_sampled${SAMPLE_ID}.csv;;
     # use the Rscript to generate a file of random indices (idxToSample.csv) and extract the corresponding lines in combined_cleaned.csv
     date)       Rscript $SCRIPTS/indices.R $DATA $FILECOUNT $NR;
      		 awk -v linesfile=$DATA/idxToSample.csv -f $SCRIPTS/extract.awk $DATA/$FILE \
						> $DATA/combined_sampled${SAMPLE_ID}_${NR}im.csv;;
esac
