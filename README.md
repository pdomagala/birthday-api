# Birthday API

A simple Sinatra application that provides birthday greeting functionality with both SQLite (for development) and DynamoDB (for production) backends.

## Features

- Save/update user's name and date of birth
- Get personalized birthday messages
- SQLite for local development
- DynamoDB for production
- AWS ECS Fargate deployment with zero-downtime updates
- Terraform for infrastructure as code

## API Endpoints

### Save/Update User

```
PUT /hello/<username>
Content-Type: application/json
Request Body: { "dateOfBirth": "YYYY-MM-DD" }
Response: 204 No Content
```

#### Validation Rules:
- `username` must contain only letters
- `dateOfBirth` must be a date before today

### Get Birthday Message

```
GET /hello/<username>
Response: 200 OK
Response Body (birthday in N days): { "message": "Hello, <username>! Your birthday is in N day(s)" }
Response Body (birthday today): { "message": "Hello, <username>! Happy birthday!" }
```

### Health Check

```
GET /health
Response: 200 OK
Response Body: {"status":"UP","environment":"production"}
```

## Development Environment

### Prerequisites

- Ruby 3.3 or higher
- Bundler
- Git

### Local Setup

1. Clone the repository:
   ```
   git clone <repo-url>
   cd birthday-app
   ```

2. Install dependencies:
   ```
   bundle install
   ```

3. Run the application in development mode:
   ```
   bundle exec rackup
   ```
   This will start the application with SQLite as the database.

4. The API is accessible at http://localhost:9292

### Testing

Run the test suite:
```
bundle exec rspec
```

## Production Environment

### AWS Infrastructure

This application is designed to run on AWS ECS Fargate with DynamoDB as the database backend. Infrastructure is defined using Terraform.

### Deployment

1. Set up AWS credentials:
   ```
   export AWS_ACCESS_KEY_ID=your_access_key
   export AWS_SECRET_ACCESS_KEY=your_secret_key
   export AWS_REGION=your_preferred_region
   ```

2. Change directory to `terraform`:
   ```
   cd terraform
   ```

3. Initialize Terraform:
   ```
   terraform init
   ```

4. Apply Terraform configuration:
   ```
   terraform apply
   ```

5. Deploy application:
   ```
   scripts/deployment.sh
   ```

## Zero-Downtime Deployment

The deployment script implements a zero-downtime deployment strategy using ECS's rolling updates:

1. Build and push a new Docker image
2. Register a new task definition with the updated image
3. Update the ECS service to use the new task definition
4. ECS performs rolling deployment (starts new tasks before stopping old ones)
5. Health checks ensure the new version is operating correctly
6. Automatic rollback if deployment fails

## Architecture

- **Web Application**: Ruby with Sinatra framework
- **Local Database**: SQLite
- **Production Database**: AWS DynamoDB
- **Container**: Docker
- **Orchestration**: AWS ECS Fargate
- **Load Balancing**: AWS Application Load Balancer
- **Infrastructure as Code**: Terraform/Opentofu

## File Structure

```
.
├── app.rb                   # Main application code
├── Gemfile                  # Ruby dependencies
├── config.ru                # Rack configuration
├── Dockerfile               # Docker configuration
├── scripts/                 # Scripts
│   └── deployment.sh
├── spec/                    # Test files
│   └── app_spec.rb
├── terraform/               # Infrastructure as code
│   ├── ecs.tf
│   ├── [...]
└── README.md
```
