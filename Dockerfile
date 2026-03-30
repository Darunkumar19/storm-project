# Pull the exact Haskell 9.10 image to skip the heavy compiler download
FROM haskell:9.10

# Set the working directory
WORKDIR /app

# Copy all your project files
COPY . /app

# Build the project safely using the pre-installed system compiler
RUN stack build --system-ghc --fast --jobs=1

# Expose the port
EXPOSE 3000

# Run the server
CMD ["stack", "run", "--system-ghc"]