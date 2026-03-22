import subprocess

def run_prometheus():
    # Define the path to your configuration file
    config_path = '/Users/m1air/Downloads/prometheus.yml'
    
    # Define the Docker run command
    command = [
        'docker', 'run', '-d',
        '-p', '9090:9090',
        '-v', f'{config_path}:/etc/prometheus/prometheus.yml',
        '--name', 'prometheus',
        'prom/prometheus'
    ]

    try:
        # Run the command
        subprocess.run(command, check=True)
        print("Prometheus container started successfully!")
    except subprocess.CalledProcessError as e:
        print(f"An error occurred: {e}")

# Call the function
run_prometheus()
