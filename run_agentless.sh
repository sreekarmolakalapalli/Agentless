#!/bin/bash

result_folder="results/dj11099demo"
instance="django__django-11099"
# instance="astropy__astropy-14182"
# instance="astropy__astropy-12907"
# Previously ran: django__django-10914

start=$SECONDS
# ---- LOCALIZE ----

# 1: Have LLM find files
printf "\nxxxxx\n[LOCALIZE:LLM finding files.]\n"
python3 agentless/fl/localize.py --file_level \
                                --output_folder $result_folder/file_level \
                                --num_threads 10 \
                                --skip_existing \
                                --target_id=${instance}
# 
# 2: Have LLM determine irrelevant folders (for retrieval)
printf "\nxxxxx\n[LOCALIZE:LLM retrieving irrelevant folders.]\n"
python agentless/fl/localize.py --file_level \
                                --irrelevant \
                                --output_folder $result_folder/file_level_irrelevant \
                                --num_threads 10 \
                                --skip_existing \
                                --target_id=${instance}
# 
# 3: Use embedding retrieval
printf "\nxxxxx\n[LOCALIZE:Use embedding-based retrieval.]\n"
python agentless/fl/retrieve.py --index_type simple \
                                --filter_type given_files \
                                --filter_file $result_folder/file_level_irrelevant/loc_outputs.jsonl \
                                --output_folder $result_folder/retrievel_embedding \
                                --persist_dir embedding/swe-bench_simple \
                                --num_threads 10 \
                                --target_id=${instance}
# 
# 4: Combine LLM and embedding retrieved files
printf "\nxxxxx\n[LOCALIZE:Combine LLM and embedding retrieved files.]\n"
python agentless/fl/combine.py  --retrieval_loc_file $result_folder/retrievel_embedding/retrieve_locs.jsonl \
                                --model_loc_file $result_folder/file_level/loc_outputs.jsonl \
                                --top_n 3 \
                                --output_folder $result_folder/file_level_combined
# 
# 5: Use LLM to find suspicious locations in file (related elements)
printf "\nxxxxx\n[LOCALIZE:Use LLM to find suspicious locations in file (related elements).]\n"
python agentless/fl/localize.py --related_level \
                                --output_folder $result_folder/related_elements \
                                --top_n 3 \
                                --compress_assign \
                                --compress \
                                --start_file $result_folder/file_level_combined/combined_locs.jsonl \
                                --num_threads 10 \
                                --skip_existing \
                                --target_id=${instance}
# 
# 6: Use LLM to get edit locations from related elements
printf "\nxxxxx\n[LOCALIZE:Use LLM to get edit locations from related elements.]\n"
python agentless/fl/localize.py --fine_grain_line_level \
                                --output_folder $result_folder/edit_location_samples \
                                --top_n 3 \
                                --compress \
                                --temperature 0.8 \
                                --num_samples 4 \
                                --start_file $result_folder/related_elements/loc_outputs.jsonl \
                                --num_threads 10 \
                                --skip_existing \
                                --target_id=${instance}
# 
# 7: Generate sets of edit locations from the individual ones
printf "\nxxxxx\n[LOCALIZE:Generate sets of edit locations from the individual ones.]\n"
python agentless/fl/localize.py --merge \
                                --output_folder $result_folder/edit_location_individual \
                                --top_n 3 \
                                --num_samples 4 \
                                --start_file $result_folder/edit_location_samples/loc_outputs.jsonl \
                                --target_id=${instance}

# ---- REPAIR ----
# Generate patches
printf "\nxxxxx\n[REPAIR:Generate patches.]\n"
# TODO: currently only using loc_merged_0_0 in validation (I think)
for i in {0..3}; do
    python agentless/repair/repair.py --loc_file $result_folder/edit_location_individual/loc_merged_${i}-${i}_outputs.jsonl \
                                    --output_folder $result_folder/repair_sample_$((i)) \
                                    --loc_interval \
                                    --top_n=3 \
                                    --context_window=10 \
                                    --max_samples 10  \
                                    --cot \
                                    --diff_format \
                                    --gen_and_process \
                                    --num_threads 2 
done

# ---- Patch Validation and Selection ----

printf "\nxxxxx\n[VALIDATION: Getting list of passing regresstion tests.]\n"
# 1. Get list of passing regression tests
python agentless/test/run_regression_tests.py --run_id generate_regression_tests \
                                              --output_file $result_folder/passing_tests.jsonl \
                                              --instance_id=${instance}

printf "\nxxxxx\n[VALIDATION: LLM removes tests which aren't useful.]\n"
# 2. Have LLM remove tests which aren't useful
python agentless/test/select_regression_tests.py --passing_tests $result_folder/passing_tests.jsonl \
                                                 --output_folder $result_folder/select_regression \
                                                 --instance_id=${instance}

printf "\nxxxxx\n[VALIDATION: Run all regression tests which were identified as useful.]\n"
# 3. Run all "generated" regression tests on all the patches.
#    Creates select_regression/output.jsonl and repair_sample_{i}/output_{n}_regression_test_results.jsonl (and _processed.jsonl?)
for i in {0..3}; do
    folder=${result_folder}/repair_sample_${i}
    for num in {0..9..1}; do
        run_id_prefix=$(basename $folder); 
        python agentless/test/run_regression_tests.py --regression_tests $result_folder/select_regression/output.jsonl \
                                                    --predictions_path="${folder}/output_${num}_processed.jsonl" \
                                                    --run_id="${run_id_prefix}_regression_${num}" \
                                                    --num_workers 10
    done
done


printf "\nxxxxx\n[VALIDATION: Generating reproduction tests.]\n"
# 4. Generate reproduction tests
python agentless/test/generate_reproduction_tests.py --max_samples 40 \
                                                     --output_folder $result_folder/reproduction_test_samples \
                                                     --num_threads 10 \
                                                     --target_id=${instance}

# 5. Run reproduction tests to see if they can reproduce issue
# Do one not in parallel so it sets up the docker containers first
# TODO: not working for astropy__astropy-12907 right now, though django__django-10914 worked before. It's failing to run containers. idk, in process of figuring it out.
printf "\nxxxxx\n[VALIDATION: Run reproduction test to see if they can reproduce issue.]\n"
python agentless/test/run_reproduction_tests.py --run_id="reproduction_test_generation_filter_sample_1" \
                                                --test_jsonl="${result_folder}/reproduction_test_samples/output_1_processed_reproduction_test.jsonl" \
                                                --num_workers 1 \
                                                --testing \
                                                --instance_ids=${instance}
for st in {0..36..4}; do   en=$((st + 3));   
        echo "Processing ${st} to ${en}";   
        for num in $(seq $st $en); do
            echo "Processing ${num}";     
            python agentless/test/run_reproduction_tests.py --run_id="reproduction_test_generation_filter_sample_${num}" \
                                                            --test_jsonl="${result_folder}/reproduction_test_samples/output_${num}_processed_reproduction_test.jsonl" \
                                                            --num_workers 1 \
                                                            --testing \
                                                            --instance_ids=${instance}
done & done

# 6. Pick best reproduction test
# TODO: previous stepping not generating reproduction_test_samples/output_0_processed_reproduction_test_verified.jsonl (missing a few _verified.jsonl's)
printf "\nxxxxx\n[VALIDATION: Picking best reproduction test.]\n"
python agentless/test/generate_reproduction_tests.py --max_samples 40 \
                                                     --output_folder $result_folder/reproduction_test_samples \
                                                     --output_file reproduction_tests.jsonl \
                                                     --select

# 7. Evaluate patches on chosen generated unit test
printf "\nxxxxx\n[VALIDATION: Evaluating patches on chosen generated unit test.]\n"
folder=$result_folder/repair_sample_1
for num in {0..9..1}; do
    run_id_prefix=$(basename $folder); 
    python agentless/test/run_reproduction_tests.py --test_jsonl $result_folder/reproduction_test_samples/reproduction_tests.jsonl \
                                                    --predictions_path="${folder}/output_${num}_processed.jsonl" \
                                                    --run_id="${run_id_prefix}_reproduction_${num}" --num_workers 10;
done

# 8. select best patch with regression and reproduction tests
printf "\nxxxxx\n[VALIDATION: Select best patch with regression and reproduction tests.]\n"
python agentless/repair/rerank.py --patch_folder $result_folder/repair_sample_1/ \
                                  --num_samples 10 \
                                  --deduplicate \
                                  --regression \
                                  --reproduction \
                                  --output_file ${result_folder}/all_preds.jsonl

duration=$((SECONDS - start))
printf "\n"
printf "Script duration: $duration seconds\n"
