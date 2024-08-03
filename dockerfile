# Base image
FROM archlinux:latest

# Install necessary packages
RUN pacman -Syu --noconfirm \
    && pacman -S --noconfirm sudo git base-devel

# Create a non-root user for security purposes
RUN useradd -m -s /bin/bash builder \
    && echo "builder ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Set the user to builder
USER builder

# Define /workspace as a volume
VOLUME /home/runner/work/StratOS-repo

# Change the working directory to /workspace
WORKDIR /home/runner/work/StratOS-repo

# Copy the build.sh script to the container
COPY --chown=builder:builder build.sh /home/runner/work/StratOS-repo/build.sh

# Give execute permission to build.sh
RUN chmod +x /home/runner/work/StratOS-repo/build.sh

# Default command to execute when the container starts
CMD ["/home/runner/work/StratOS-repo/build.sh"]
