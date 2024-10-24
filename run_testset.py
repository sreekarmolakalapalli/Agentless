import argparse
import os
import subprocess
import sys


def read_problems(input_file):
    """
    Read problem instances from the input file.

    Args:
    input_file (str): Path to the input file containing instance IDs.

    Returns:
    list: A list of non-empty, stripped lines from the input file.
    """
    with open(input_file, 'r') as file:
        return [line.strip() for line in file if line.strip()]


def run_command(command):
    """
    Execute a shell command and return its output.

    Args:
    command (str): The shell command to execute.

    Returns:
    str: The command's stdout if successful, or an error message if failed.
    """
    try:
        result = subprocess.run(command, shell=True, check=True, text=True, capture_output=True)
        return result.stdout
    except subprocess.CalledProcessError as e:
        return f"Error: {e.stderr}"
    

def process_instances(instance_ids, output_folder):
    """
    Process each instance ID by creating a corresponding result folder and running various commands.

    Args:
    instance_ids (list): List of instance IDs to process.
    output_folder (str): Path to the main output folder.
    """
    # Add the parent directory of 'agentless' to the Python path
    agentless_parent_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
    sys.path.insert(0, agentless_parent_dir)
    
    for instance_id in instance_ids:
        result_folder = os.path.join(output_folder, f"result_{instance_id}")
        os.makedirs(result_folder, exist_ok=True)
        print(f"Created folder: {result_folder}")

        commands = [
            ("Localize Files", f"""python -m agentless.fl.localize --file_level --related_level --fine_grain_line_level \
                                --output_folder {result_folder} --top_n 3 \
                                --compress \
                                --target_id={instance_id} \
                                --context_window=10 \
                                --temperature 0.8 \
                                --num_samples 4"""),
            
            ("Merge Localize", f"""python -m agentless.fl.localize --merge \
                                --output_folder {os.path.join(result_folder, "location_merged")} \
                                --start_file {os.path.join(result_folder, "loc_outputs.jsonl")} \
                                --num_samples 4"""),
            
            ("Repair 0-1", f"""python -m agentless.repair.repair --loc_file {os.path.join(result_folder, "location_merged", "loc_merged_0-1_outputs.jsonl")} \
                                  --output_folder {os.path.join(result_folder, "repair_run_1")} \
                                  --loc_interval --top_n=3 --context_window=10 \
                                  --max_samples 21  --cot --diff_format \
                                  --gen_and_process """),
            
            ("Repair 2-3", f"""python -m agentless.repair.repair --loc_file {os.path.join(result_folder, "location_merged", "loc_merged_2-3_outputs.jsonl")} \
                                  --output_folder {os.path.join(result_folder, "repair_run_2")} \
                                  --loc_interval --top_n=3 --context_window=10 \
                                  --max_samples 21  --cot --diff_format \
                                  --gen_and_process """),
            
            ("Rerank", f"""python -m agentless.repair.rerank --patch_folder {os.path.join(result_folder, "repair_run_1")},{os.path.join(result_folder, "repair_run_2")} --num_samples 42 --deduplicate --plausible""")
        ]

        for command_name, command in commands:
            print(f"\nExecuting {command_name} command:")
            print(f"Command: {command}")
            output = run_command(command)
            print(f"Output:\n{output}")

        print(f"Successfully completed {instance_id}!")
        break

    print(f"Processed all {len(instance_ids)} instance IDs.")

def main():
    """
    Main function to handle command-line arguments and orchestrate the script's execution.
    """
    parser = argparse.ArgumentParser(description="Process instance IDs from an input file and create result folders.")
    parser.add_argument("--input_file", required=True, help="Path to the input file containing instance IDs")
    parser.add_argument("--output_folder", required=True, help="Path to the output folder for results")
    
    args = parser.parse_args()

    # Ensure the output folder exists
    os.makedirs(args.output_folder, exist_ok=True)

    instance_ids = read_problems(args.input_file)

    process_instances(instance_ids, args.output_folder)

    print(f"Processed {len(instance_ids)} instance IDs. Result folders created in {args.output_folder}")


if __name__ == "__main__":
    main()