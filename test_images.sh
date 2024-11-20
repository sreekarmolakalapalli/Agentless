

export PYTHONPATH="${PWD}:$PYTHONPATH"

result_folder="/home/sujit/Desktop/capstone/agentless_mod/Agentless/nov7demo"
instance="django__django-10914"

python agentless/test/run_reproduction_tests.py --run_id="sample_run_for_test_script_testing4" \
                                                --test_jsonl="${result_folder}/reproduction_test_samples/reproduction_tests.jsonl" \
                                                --predictions_path "${result_folder}/repair_sample_1/output_8_processed.jsonl" \
                                                --num_workers 1



