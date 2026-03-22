import subprocess


def container_exists(name):
    # Java is not needed because jenkins in docker image already has it, so we just check if the container exists
    result = subprocess.run(
        ["docker", "ps", "-a", "--format", "{{.Names}}"],
        capture_output=True, text=True
    )
    return name in result.stdout


def run_jenkins():
    container_name = "jenkins"
    jenkins_home = "/Users/m1air/jenkins_home"

    if container_exists(container_name):
        print("⚠ Jenkins container already exists. Starting it...")
        subprocess.run(["docker", "start", container_name], check=True)
    else:
        print("Creating and starting Jenkins container...")
        subprocess.run([
            "docker", "run", "-d",
            "-p", "8082:8082",
            "-p", "50000:50000",
            "-v", f"{jenkins_home}:/var/jenkins_home",
            "--name", container_name,
            "jenkins/jenkins:lts"
        ], check=True)

    print("🌐 Jenkins URL: http://localhost:8082")


run_jenkins()
