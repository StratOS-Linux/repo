# Base image
FROM ghcr.io/stratos-linux/stratos-base:latest

# Define /workspace as a volume
VOLUME /workspace

# Change the working directory to /workspace
WORKDIR /workspace

COPY build.py /workspace/build.py

RUN chmod +x /workspace/build.py

# CMD ["python3", "/workspace/build.py"]
