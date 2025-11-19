import os
import json
import tempfile
import subprocess
import sys
from flask import Flask, request, jsonify
import ast

app = Flask(__name__)

def validate_script(script):
    """
    Validate that the script contains a main() function.
    Returns (is_valid, error_message)
    """
    try:
        tree = ast.parse(script)
    except SyntaxError as e:
        return False, f"Syntax error in script: {str(e)}"
    
    # Check if main() function exists
    has_main = False
    for node in ast.walk(tree):
        if isinstance(node, ast.FunctionDef) and node.name == 'main':
            has_main = True
            break
    
    if not has_main:
        return False, "Script must contain a main() function"
    
    return True, None

def execute_script_safely(script):
    """
    Execute the script safely using nsjail and return the result.
    Returns (success, result, stdout, error_message)
    """
    # Create a temporary file for the script
    with tempfile.NamedTemporaryFile(mode='w', suffix='.py', delete=False) as f:
        script_path = f.name
        # Wrap the script to capture return value
        wrapped_script = script + """

if __name__ == '__main__':
    import json
    import sys
    result = main()
    # Write result to a special marker so we can parse it
    print("__RESULT_START__")
    print(json.dumps(result))
    print("__RESULT_END__")
"""
        f.write(wrapped_script)
    
    try:
        # nsjail command for safe execution
        nsjail_cmd = [
            'nsjail',
            '-Mo',  # Mode: execute once and exit
            '--quiet',  # Suppress nsjail info messages
            '--chroot', '/',
            '--user', '99999',
            '--group', '99999',
            '--time_limit', '30',  # 30 seconds timeout
            '--max_cpus', '1',
            '--rlimit_as', '512',  # Memory limit: 512 MB
            '--rlimit_cpu', '10',  # CPU time limit: 10 seconds
            '--rlimit_nofile', '64',  # Max open files
            '--rlimit_nproc', '0',  # No new processes
            '--disable_proc',  # Disable /proc
            '-R', '/usr/lib',
            '-R', '/usr/local/lib',
            '-R', '/lib',
            '-R', '/lib64',
            '-R', '/bin',
            '-R', '/usr/bin',
            '-R', '/usr/local/bin',
            '-R', f'{script_path}:{script_path}',
            '--',
            '/usr/local/bin/python3',
            script_path
        ]
        
        # Execute with nsjail
        process = subprocess.Popen(
            nsjail_cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        
        stdout, stderr = process.communicate(timeout=35)
        
        # Parse the output to separate stdout from result
        if "__RESULT_START__" in stdout and "__RESULT_END__" in stdout:
            parts = stdout.split("__RESULT_START__")
            regular_stdout = parts[0].strip()
            
            result_part = parts[1].split("__RESULT_END__")[0].strip()
            
            try:
                result = json.loads(result_part)
            except json.JSONDecodeError as e:
                return False, None, regular_stdout, f"main() must return a JSON-serializable object. Error: {str(e)}"
            
            return True, result, regular_stdout, None
        else:
            # Execution failed or didn't return properly
            # Try to extract just the Python error from stderr
            if stderr:
                # Look for common Python error patterns
                lines = stderr.strip().split('\n')
                # Get the last line which usually contains the actual error
                error_msg = lines[-1] if lines else stderr
                # If it's a traceback, include the exception type and message
                if 'Traceback' in stderr:
                    # Find the actual error line (last non-empty line)
                    for line in reversed(lines):
                        if line.strip() and not line.startswith(' '):
                            error_msg = line.strip()
                            break
            else:
                error_msg = "Script execution failed or main() did not return a value"
            
            # Clean stdout - remove our internal markers if present
            clean_stdout = stdout.split("__RESULT_START__")[0].strip() if "__RESULT_START__" in stdout else stdout.strip()
            
            return False, None, clean_stdout, error_msg
    
    except subprocess.TimeoutExpired:
        return False, None, "", "Script execution timeout"
    except Exception as e:
        return False, None, "", f"Execution error: {str(e)}"
    finally:
        # Clean up temporary file
        try:
            os.unlink(script_path)
        except:
            pass

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({"status": "healthy"}), 200

@app.route('/execute', methods=['POST'])
def execute():
    """
    Execute a Python script and return the result.
    Expected JSON body: {"script": "def main(): ..."}
    """
    # Validate request
    if not request.is_json:
        return jsonify({"error": "Content-Type must be application/json"}), 400
    
    data = request.get_json()
    
    if 'script' not in data:
        return jsonify({"error": "Missing 'script' field in request body"}), 400
    
    script = data['script']
    
    if not isinstance(script, str):
        return jsonify({"error": "'script' must be a string"}), 400
    
    if not script.strip():
        return jsonify({"error": "'script' cannot be empty"}), 400
    
    # Validate script
    is_valid, error_msg = validate_script(script)
    if not is_valid:
        return jsonify({"error": error_msg}), 400
    
    # Execute script safely
    success, result, stdout, error_msg = execute_script_safely(script)
    
    if not success:
        return jsonify({"error": error_msg, "stdout": stdout}), 400
    
    return jsonify({
        "result": result,
        "stdout": stdout
    }), 200

if __name__ == '__main__':
    # Run on port 8080
    app.run(host='0.0.0.0', port=8080)

