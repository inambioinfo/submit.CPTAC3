# Set system-specific paths here

# SR and BAM MAP are used to get all cases and the associated disease

# Starting with Batch 2 have single unified BamMap file
#BAMMAP="/diskmnt/Projects/cptac/GDC_import/import.config/CPTAC3.b2/CPTAC3.b2.BamMap.dat"
BAMMAP="/gscuser/mwyczalk/projects/CPTAC3/data/GDC_import/import.config/CPTAC3.b2/CPTAC3.b2.BamMap.dat"

# SR file (from "Submitted Reads") is created by case discovery, and provides information necessary
# for download of BAM and FASTQ files from GDC
SR="/gscmnt/gc2521/dinglab/mwyczalk/somatic-wrapper-data/GDC_import/import.config/CPTAC3.b2/CPTAC3.b2.SR.dat"

# where verbatim copy of uploaded data is stored
#STAGE_ROOT="/diskmnt/Projects/cptac/CPTAC3-DCC-Staging/staged_data.${PROJECT}.${SUBMIT}"
STAGE_ROOT="/gscmnt/gc2521/dinglab/mwyczalk/CPTAC3-submit/staged_data.${PROJECT}.${SUBMIT}"

#ASCP_CONNECT="/home/mwyczalk_test/.aspera/connect"
ASCP_CONNECT="/gscuser/mwyczalk/.aspera/connect"
