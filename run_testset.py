import argparse
import os
import subprocess


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
    Process each instance ID by creating a corresponding result folder.

    Args:
    instance_ids (list): List of instance IDs to process.
    output_folder (str): Path to the main output folder.
    """
    for instance_id in instance_ids:
        result_folder = os.path.join(output_folder, f"result_{instance_id}")
        os.makedirs(result_folder, exist_ok=True)
        print(f"Created folder: {result_folder}")

        localize_files_command = f"""python agentless/fl/localize.py --file_level --related_level --fine_grain_line_level \
                                --output_folder {result_folder} --top_n 3 \
                                --compress \
                                --context_window=10 \
                                --temperature 0.8 \
                                --num_samples 4"""

        run_command(localize_files_command) # runs the localize files command

        #This will save all the localized locations in results/location/loc_outputs.jsonl with 
        # the logs saved in results/location/localize.log

        # then we need to perform merging to form a bigger list of edit locations

    

        merge_localize_command = f"""python agentless/fl/localize.py --merge \
                                --output_folder results/location_merged \
                                --start_file results/location/loc_outputs.jsonl \
                                --num_samples 4"""



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