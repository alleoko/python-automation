import subprocess

def run_grafana():
    # Define the Docker run command for Grafana
    command = [
        'docker', 'run', '-d',
        '-p', '3000:3000',
        '--name', 'grafana',
        'grafana/grafana'
    ]

    try:
        # Run the command
        subprocess.run(command, check=True)
        print("Grafana container started successfully!")
    except subprocess.CalledProcessError as e:
        print(f"An error occurred: {e}")

# Call the function
run_grafana()
