#!/bin/bash
{
# $1: should be a file with a list of instance ids
echo "Subset file: $1"
subset_name=$1
subset_filename="rq1_verified_subsets/${1}.txt"
log_file="./results/${subset_name}_log.txt"
touch $log_file

while IFS= read -r line; do
    ./run_agentless_instance_control.sh $line 2>&1 | tee -a $log_file
done < $subset_filename

# TODO: write python that does this, bash can't work with json files
# Combine the all_preds for each instance into one.
# all_preds_subset_file="all_preds_${instances_filename}.json"
# touch $all_preds_subset_file
# while IFS= read -r line; do
#     read -r preds<./results/${line}/all_preds.json
#     echo -e "${preds}\n" >> all_preds_subset_file
# done < $instances_filename

exit
}