# Base image
FROM archlinux:latest

# Install necessary packages
RUN pacman -Syu --noconfirm \
    && pacman -S --noconfirm sudo git base-devel

# Define /workspace as a volume
VOLUME /workspace

# Change the working directory to /workspace
WORKDIR /workspace

# Copy the build.sh script to the container
COPY build.sh /workspace/build.sh

# Give execute permission to build.sh
RUN chmod +x /workspace/build.sh
