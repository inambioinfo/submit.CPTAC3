# stage data by copying source data to target.  Staging directories created
# Usage: 
#  stage_data.sh [options] analysis datadir input.suffix output.suffix source-es
#
# analysis: canonical analysis name, e.g., WGS-Germline
# datadir: root directory of data 
# input.suffix: suffix of input filename.  Added to CASE to construct input data filename, like "C3L-00004.SVsomatic.vcf"
# output.suffix: suffix of output filename.  Added to CASE to construct output filename.  Need not be the same as input.suffix
# source-es: experimental strategy of input data: WGS, WXS, or RNA-Seq 
#   this is used only to get the path to the appropriate BamMap file, which is parsed to get all cases
#
# There are assumptions about the filename of the source data, which is determined by -T flag.
# If -T not set, assumed that one data file per case, with the data filename format CASE.suffix 
# If -T is set, assumed data filename format is CASE.X.suffix, with X either T (tumor) or N (normal)
# Other options will be added as necessary.
#
# Options:
# -z: compress the file while staging
# -f: force overwrite of target even if it exists
# -d: dry run.  Only pretend to copy
# -1: Stop after one case
# -T: Data as tumor/normal pair
# -D: Append cancer type to datadir, e.g., /data/UCEC/CASE.fn for UCEC
# -Q: Append cancer type to filename, e.g., /data/UCEC__CASE.fn for UCEC.  This is ad hoc and can be removed after file naming standardized

# Note that CNV analysis differs significantly from germline/somatic wrapper results in that it has more than one result
# per case; specifically, tumor and normal results exist for each case.
# For now, "process_case" is tweaked so that the passed argument (CASE) is a string corresponding to the case ID for the
# wrapper results (e.g., C3L-00003), whereas for CNV analyses (-T set), CASE takes values like C3L-00003.T and C3L-00003.N (from the sample name)
# Such renaming is confusing and fragile, and in future revisions the flow should be reworked to incorporate these two cases more gracefully

source batch_config.sh
#source submit.CPTAC3/get_SN.sh  # this is no longer needed?

# Make destination directory
function make_staging_dir {
    CANCER=$1
    mkdir -p $(getd $CANCER $ANALYSIS)
}

# for CNV, each case has two results, one for tumor and one for normal
# for germline and somatic, each case has only one result file 
function process_case {
    # copy data generated by somatic or germline wrappers into staging directory, 
    # It is assumed input data files are named CASE.xxx, where xxx is given by input.suffix argument
    # Add analysis name to front of filename, and add output.suffix after CASE
    # If compressing, filename has .gz appended
    CASE=$1
    CANCER=$2

    # We may make this an assumption about the filename naming convention, with the understanding
    # that "CASE" here may be "CASE.T" or "CASE.N", if workflow spits these out individually
    # FN is the input filename
    if [ -z $APPEND_DIS ]; then
        FN="$DATD/${CASE}.${INPUT_SUFFIX}"
    elif [ -z $QS_MODE ]; then
        FN="$DATD/${CANCER}__${CASE}.${INPUT_SUFFIX}"
    else
        FN="$DATD/$CANCER/${CASE}.${INPUT_SUFFIX}"
    fi

    if [ ! -e $FN ]; then  # Might be good to have option here to either warn or quit 
        >&2 echo $FN does not exist.  Quitting
        exit 1
    fi

    # Staging directory
    DESTD=$(getd $CANCER $ANALYSIS)

    if [ $COMPRESS ]; then
        DESTFN="$DESTD/${ANALYSIS}.${CASE}.${OUTPUT_SUFFIX}.gz"
    else
        DESTFN="$DESTD/${ANALYSIS}.${CASE}.${OUTPUT_SUFFIX}"
    fi

    if [ -e $DESTFN ] && [ -s $DESTFN ];  then  # file exists and is not zero size
        if [  $FORCE_OVERWRITE ]; then
            >&2 echo Destination file $DESTFN exists.  Overwriting
        else
            >&2 echo Destination file $DESTFN exists.  Skipping
            return
        fi
    fi

    if [ $COMPRESS ]; then
        >&2 echo Compressing $FN to $DESTFN
        if [ $DRYRUN ]; then
            echo gzip -v - \<$FN \> $DESTFN
        else 
            gzip -v - <$FN > $DESTFN
        fi
    else
        >&2 echo Copying $FN to $DESTFN
        if [ $DRYRUN ]; then
            echo cp $FN $DESTFN
        else
            cp $FN $DESTFN
        fi
    fi
}

# http://wiki.bash-hackers.org/howto/getopts_tutorial
while getopts ":dzf1TDQ" opt; do
  case $opt in
    d) # Dry run 
      >&2 echo "Dry run" >&2
      DRYRUN=1
      ;;
    z) # compress while copying 
      >&2 echo "Compressing" >&2
      COMPRESS=1
      ;;
    f)  
      >&2 echo "Force Overwrite" >&2
      FORCE_OVERWRITE=1
      ;;
    1)  
      STOPATONE=1
      ;;
    T)  
      IS_TUMOR_NORMAL=1
      ;;
    D)  
      APPEND_DIS=1
      ;;
    Q) # Ad hoc naming mode where filename is e.g., /data/UCEC__C3N-00734.suffix
      QG_MODE=1
      ;;
#    x) # example of value argument
#      FILTER=$OPTARG
#      >&2 echo "Setting memory $MEMGB Gb" 
#      ;;
    \?)
      >&2 echo "Invalid option: -$OPTARG" 
      exit 1
      ;;
    :)
      >&2 echo "Option -$OPTARG requires an argument." 
      exit 1
      ;;
  esac
done
shift $((OPTIND-1))

if [ "$#" -ne 5 ]; then
    >&2 echo Error: Require 5 arguments: analysis, datadir, input.suffix, output.suffix, source_es
    exit 1  # exit code 1 indicates error
fi

ANALYSIS=$1  # e.g. WGS-Somatic
DATD=$2
#DATFT=$3
INPUT_SUFFIX=$3
OUTPUT_SUFFIX=$4
SOURCE_ES=$5

mkdir -p $STAGE_ROOT
echo Writing data to $STAGE_ROOT

# Make staging directories
for D in $DISEASES; do
    make_staging_dir $D
done

# get the BamMap path for this particular experimental strategy 
BM=$(getBM $SOURCE_ES)


while read C; do

    [[ $C = \#* ]] && continue  # Skip commented out entries
    >&2 echo Processing $C

    CANCER=$(cut -f 1,2 $SR | grep $C | cut -f 2 | sort -u)

    if [ $IS_TUMOR_NORMAL ]; then
    # this mimicks naming convention in BamMap
        process_case ${C}.T $CANCER
        process_case ${C}.N $CANCER
    else
        process_case ${C} $CANCER
    fi

    if [ $STOPATONE ]; then
        >&2 echo Stopping after one
        exit 0  # 0 indicates no error 
    fi

done < <(grep -v "^#" $BM | cut -f 2 | sort -u)  # pull out all case IDs out of BamMap and loop through them
