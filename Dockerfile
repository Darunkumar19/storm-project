# Use the official Haskell image
FROM haskell:latest

# Set the working directory
WORKDIR /app

# Copy all your project files into the container
COPY . /app

# Build with 1 core, and FORCE it to install the exact compiler version needed
RUN stack build --install-ghc --fast --jobs=1

# Expose the port
EXPOSE 3000

# Run the server
CMD ["stack", "run"]