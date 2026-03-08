# Use the official Haskell image
FROM haskell:latest

# Set the working directory
WORKDIR /app

# Copy all your project files into the container
COPY . /app

# Setup the exact compiler version required by your project
RUN stack setup

# Build using only 1 core and no optimizations to save memory
RUN stack build --fast --jobs=1

# Expose the port
EXPOSE 3000

# Run the server
CMD ["stack", "run"]