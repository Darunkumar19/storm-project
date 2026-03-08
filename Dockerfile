FROM haskell:latest
WORKDIR /app
COPY . /app
RUN stack build
EXPOSE 3000
CMD ["stack", "run"]