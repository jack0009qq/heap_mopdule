import os
import subprocess
import time
import signal
import pandas as pd

def execute_command(command, cwd=None):
    result = subprocess.run(command, cwd=cwd, capture_output=True, text=True, shell=True)
    return result

def run_task_py():
    print("Running task.py...")    
    result = execute_command('python3 ../create_task_py/task.py')
    if result.returncode != 0:
        print(f"Error running task.py: {result.stderr}")
        return False
    print("task.py completed successfully.")
    return True

def move_user_c():
    print("Moving user.c to app folder...")
    try:
        #os.rename('user.c', '../001_heap_table/app/user.c')
        #os.rename('user.c', '../002_noheap_table/app/user.c')
        os.rename('user.c', '../003_noheap_for/app/user.c')
        print("user.c moved successfully.")
    except Exception as e:
        print(f"Error moving user.c: {e}")
        return False
    return True

def run_os_makefile():
    #result = execute_command('make', cwd='../001_heap_table')
    #result = execute_command('make', cwd='../002_noheap_table')
    result = execute_command('make', cwd='../003_noheap_for')
    if result.returncode != 0:
        print("Error running makefile in")
        return False
    print("sussses running makefile in")
    return True

def run_testbemch_makefile():
    #command ="obj_dir/Vsoc_top 001_heap_table/os.bin"
    #command ="obj_dir/Vsoc_top 002_noheap_table/os.bin"
    command ="obj_dir/Vsoc_top 003_noheap_for/os.bin"
    cwd = "../"
    
    process = subprocess.Popen(command,cwd=cwd ,stdout=subprocess.PIPE, shell=True)   
    time.sleep(80)
    process.terminate()
    
    
    stdout, stderr = process.communicate()

    

    #print stdout
    stdout_lines = stdout.decode().splitlines()
    print("STDOUT:")
    for line in stdout_lines:
        print(line)

    

    return {
        "STDOUT": stdout.decode().splitlines(),
    }
    
    
    
    # output = {
    #     "STDOUT": stdout.decode() if isinstance(stdout, bytes) else stdout,
    #     "STDERR": stderr.decode() if isinstance(stderr, bytes) else stderr
    # }
    
    
    #return output

    # with open("command_output.txt", "w") as file:
    #     file.write("STDOUT:\n")
    #     file.write(stdout.decode() if isinstance(stdout, bytes) else stdout)
    #     file.write("\n\nSTDERR:\n")
    #     file.write(stderr.decode() if isinstance(stderr, bytes) else stderr)

def save_to_excel(results, filename):
    df = pd.DataFrame()
    
    # Iterate through each result and add it to the DataFrame
    for i, result in enumerate(results):
        # Convert STDOUT lines to a DataFrame
        stdout_df = pd.DataFrame({
            f'STDOUT_{i+1}': result['STDOUT']           
        })

        
        # Concatenate with the existing DataFrame
        df = pd.concat([df, stdout_df], axis=1)
    
    # Remove duplicate Iteration column
    df = df.loc[:, ~df.columns.duplicated()]
    
    # Save DataFrame to Excel
    df.to_excel(filename, index=False)

def save_output_to_file(filename, output):
    with open(filename, "w") as file:
        for line in output:
            file.write(line + "\n")






def main():
    all_results = []
    
    for i in range(1):
        print(f"Running iteration {i+1}...")
        run_task_py()
        move_user_c()
        run_os_makefile()
        
    #     result = run_testbemch_makefile()

    #     all_results.append(result)
        
    
    # save_to_excel(all_results, "example_2.xlsx")
    
    

main()