FROM ruby:3.3-slim

WORKDIR /app

# Install required dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Copy Gemfile and install dependencies
COPY Gemfile ./
RUN bundle install --without development test

# Copy application code
COPY . .

# Expose port
EXPOSE 4567

# Run the application
CMD ["bundle", "exec", "rackup", "--host", "0.0.0.0", "-p", "4567"]
