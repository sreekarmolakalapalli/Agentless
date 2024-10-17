#!/bin/sh

# Read in test instance ids into an array
mapfile -t instance_ids < test_instance_ids.txt
# printf '%s\n' "${instance_ids[@]}"

result_folder="results"

# TODO: skip instance id folders that already exist
for instance_id in "${instance_ids[@]}"
do
    echo ----------- RUNNING "$instance_id" -------------
    # Localize files
    python -m agentless.fl.localize --file_level --related_level --fine_grain_line_level \
                                    --output_folder $result_folder/$instance_id/localization --top_n 3 \
                                    --compress \
                                    --target_id=$instance_id \
                                    --context_window=10 \
                                    --temperature 0.8 \
                                    --num_samples 4
    
    # Merge Localize
    python -m agentless.fl.localize --merge \
                                    --output_folder $result_folder/$instance_id/edit_loc_samples_merged \
                                    --start_file $result_folder/$instance_id/localization/loc_outputs.jsonl \
                                    --num_samples 4

    # Repair (Just using all_merged for now)
    python -m agentless.repair.repair --loc_file $result_folder/$instance_id/edit_loc_samples_merged/loc_all_merged_outputs.jsonl \
                                    --output_folder $result_folder/$instance_id/repair_no_test_patch \
                                    --loc_interval --top_n=3 --context_window=10 \
                                    --max_samples 10  --cot --diff_format \
                                    --gen_and_process

    # Rerank
    python -m agentless.repair.rerank --patch_folder $result_folder/$instance_id/repair_no_test_patch \
                                    --output_file $result_folder/$instance_id/all_preds_no_test_patch.json
                                    --deduplicate
    
    # Repair with test patch
    python -m agentless.repair.repair --loc_file $result_folder/$instance_id/edit_loc_samples_merged/loc_all_merged_outputs.jsonl \
                                    --output_folder $result_folder/$instance_id/repair_with_test_patch \
                                    --loc_interval --top_n=3 --context_window=10 \
                                    --max_samples 10  --cot --diff_format \
                                    --gen_and_process
                                    --use_test_patch

    # Rerank with test patch
    python -m agentless.repair.rerank --patch_folder $result_folder/$instance_id/repair_with_test_patch \
                                    --output_file $result_folder/$instance_id/all_preds_with_test_patch.json
    
    printf "\n"
exit 0
done

            