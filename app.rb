# app.rb
require 'sinatra'
require 'json'
require 'date'
require 'aws-sdk-dynamodb'
require 'sqlite3'

# Environment detection
ENVIRONMENT = ENV['ENVIRONMENT'] || 'development'

# Configuration
configure do
  set :host_authorization, { permitted_hosts: [] }
  
  # Setup database connection
  if ENVIRONMENT == 'development'
    # Local SQLite database
    DB = SQLite3::Database.new('users.db')
    DB.execute <<-SQL
      CREATE TABLE IF NOT EXISTS users (
        username TEXT PRIMARY KEY,
        date_of_birth TEXT NOT NULL
      );
    SQL
  else
    # AWS DynamoDB
    DYNAMODB = Aws::DynamoDB::Client.new(
      region: ENV['AWS_REGION'] || 'eu-west-1',
      access_key_id: ENV['AWS_ACCESS_KEY_ID'],
      secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
    )
    
    # Create table if it doesn't exist
    begin
      DYNAMODB.describe_table(table_name: 'Users')
    rescue Aws::DynamoDB::Errors::ResourceNotFoundException
      DYNAMODB.create_table({
        table_name: 'Users',
        key_schema: [
          { attribute_name: 'username', key_type: 'HASH' }
        ],
        attribute_definitions: [
          { attribute_name: 'username', attribute_type: 'S' }
        ],
        provisioned_throughput: {
          read_capacity_units: 5,
          write_capacity_units: 5
        }
      })
      
      # Wait for table to be created
      DYNAMODB.wait_until(:table_exists, table_name: 'Users')
    end
  end
end

# Health check endpoint
get '/health' do
  status 200
  content_type :json
  { status: 'UP', environment: ENVIRONMENT }.to_json
end

# Save/update user data
put '/hello/:username' do |username|
  # Validate username (letters only)
  if username !~ /^[A-Za-z]+$/
    status 400
    return { error: "Username must contain only letters" }.to_json
  end
  
  # Parse request body
  begin
    request_payload = JSON.parse(request.body.read)
  rescue JSON::ParserError
    status 400
    return { error: "Invalid JSON in request body" }.to_json
  end
  
  # Extract and validate date of birth
  date_of_birth = request_payload['dateOfBirth']
  if date_of_birth.nil?
    status 400
    return { error: "Missing dateOfBirth field" }.to_json
  end
  
  # Validate date format and value
  begin
    dob = Date.parse(date_of_birth)
    if dob >= Date.today
      status 400
      return { error: "Date of birth must be before today" }.to_json
    end
  rescue ArgumentError
    status 400
    return { error: "Invalid date format. Use YYYY-MM-DD" }.to_json
  end
  
  # Save to database
  if ENVIRONMENT == 'development'
    # Save to SQLite
    DB.execute(
      "INSERT OR REPLACE INTO users (username, date_of_birth) VALUES (?, ?)",
      [username, date_of_birth]
    )
  else
    # Save to DynamoDB
    DYNAMODB.put_item({
      table_name: 'Users',
      item: {
        'username' => username,
        'dateOfBirth' => date_of_birth
      }
    })
  end
  
  status 204
end

# Get birthday message
get '/hello/:username' do |username|
  # Validate username (letters only)
  if username !~ /^[A-Za-z]+$/
    status 400
    return { error: "Username must contain only letters" }.to_json
  end
  
  # Retrieve from database
  date_of_birth = nil
  
  if ENVIRONMENT == 'development'
    # Retrieve from SQLite
    result = DB.get_first_row(
      "SELECT date_of_birth FROM users WHERE username = ?",
      [username]
    )
    date_of_birth = result[0] if result
  else
    # Retrieve from DynamoDB
    response = DYNAMODB.get_item({
      table_name: 'Users',
      key: { 'username' => username }
    })
    date_of_birth = response.item['dateOfBirth'] if response.item
  end
  
  # Return 404 if user not found
  if date_of_birth.nil?
    status 404
    return { error: "User not found" }.to_json
  end
  
  # Calculate days until next birthday
  dob = Date.parse(date_of_birth)
  today = Date.today
  next_birthday = Date.new(today.year, dob.month, dob.day)
  
  # If the birthday has already occurred this year, calculate for next year
  next_birthday = Date.new(today.year + 1, dob.month, dob.day) if next_birthday < today
  
  # Calculate days until birthday
  days_until_birthday = (next_birthday - today).to_i
  
  # Prepare response
  status 200
  content_type :json
  
  if days_until_birthday == 0
    { message: "Hello, #{username}! Happy birthday!" }.to_json
  else
    { message: "Hello, #{username}! Your birthday is in #{days_until_birthday} day(s)" }.to_json
  end
end

# Error handling
not_found do
  status 404
  content_type :json
  { error: "Resource not found" }.to_json
end

error do
  status 500
  content_type :json
  { error: "Internal server error" }.to_json
end
