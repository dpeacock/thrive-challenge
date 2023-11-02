# frozen_string_literal: true

# Usage: ruby challenge.rb [options]
#         --users_file USERSFILE
#         --companies_file COMPANIESFILE
#
# Ensure you have the required gems (i.e. bundle install or gem install json-schema)
#
# The program processes a json file of users, and a json file of companies.
# The files must match the schemas provided below (USERS_SCHEMA & COMPANIES_SCHEMA) to be processed.
# It creates an output file (output.txt) in the directory it's run from.
# The output file outputs a list of companies (id & name) and the total amount of tokens topped up
# It includes a list of whether the users should be e-mailed or not
# The lists include the user name, e-mail and their balance pre and post top-up
#
# Recommendations & assumptions
# - Challenge doesn't mention the "Total amount of top ups", but it's in the output so I included it
# - The total amount of top ups line was indented to line up with "Users Not Emailed:" rather than under the company
#   itself.
#   I've lined it up with the company itself as the total is for all users, not just those emailed.
# - The output format in the sample output for "Previous token balance" has a comma after it,
#   whereas "New Token Balance" does not, I've made these consistent in my output
# - The sample output has the header for "Users Emailed:" output even when there are no users, so I included it too.
#   It might be worth hiding this or changing it to something different if the list is empty (same applies for no users
#   e-mailed being empty)

# Future thoughts
# - Implement tests
# - Allow output file as a param
# - Pull users/companies to their own classes instead of working with hashes
# - Implement e-mailing

require 'json'
require 'json-schema'
require 'optparse'

USERS_SCHEMA = {
  "type": 'array',
  "items": {
    "type": 'object',
    "required": ['id', 'first_name', 'last_name', 'email', 'company_id', 'email_status', 'active_status', 'tokens'],
    "properties": {
      "id": {
        "type": 'integer'
      },
      "first_name": {
        "type": 'string'
      },
      "last_name": {
        "type": 'string'
      },
      "email": {
        "type": 'string',
        "format": 'email',
        "pattern": '^\\S+@\\S+\\.\\S+$',
        "minLength": 6,
        "maxLength": 127
      },
      "company_id": {
        "type": 'integer'
      },
      "email_status": {
        "type": 'boolean'
      },
      "active_status": {
        "type": 'boolean'
      },
      "tokens": {
        "type": 'integer'
      }
    }
  }
}.freeze

COMPANIES_SCHEMA = {
  "type": 'array',
  "items": {
    "type": 'object',
    "required": ['id', 'name', 'top_up', 'email_status'],
    "properties": {
      "id": {
        "type": 'integer'
      },
      "name": {
        "type": 'string'
      },
      "top_up": {
        "type": 'integer'
      },
      "email_status": {
        "type": 'boolean'
      }
    }
  }
}.freeze

# Read a json file and validate it against a schema
class JSONFileReader
  def initialize(file_path, schema)
    @file_path = file_path
    @schema = schema
  end

  def file_hash
    @file_hash ||= begin
      validate_schema
      JSON.parse(file_content)
    rescue StandardError => e
      puts "Error - #{@file_path} is not valid JSON."
      puts e.message
      exit
    end
  end

  private

  def validate_schema
    JSON::Validator.validate!(@schema, file_content)
  rescue JSON::Schema::ValidationError => e
    puts "Error - #{@file_path} is in an invalid format: #{e.message}"
    exit
  end

  def file_content
    @file_content ||= begin
      unless File.exist?(@file_path)
        puts "Error - #{file_path} does not exist"
        exit
      end

      File.read(@file_path)
    rescue StandardError
      puts "Error reading file #{@file_path}"
      exit
    end
  end
end

# A logger service for our email program
class EmailLogger
  def initialize(output_file_path)
    @output_file_path = output_file_path
  end

  def log_company_results(company, users_emailed, users_not_emailed, total_top_ups)
    output_company_header(company)
    output_user_list('Users Emailed:', users_emailed)
    output_user_list('Users Not Emailed:', users_not_emailed)
    output_top_ups(company['name'], total_top_ups)
  end

  def close
    file.close
  end

  private

  def file
    @file ||= File.open(@output_file_path, 'w')
  end

  def log_line(line)
    file.puts(line)
  end

  def output_company_header(company)
    log_line('')
    log_line("  Company Id: #{company['id']}")
    log_line("  Company Name: #{company['name']}")
  end

  def output_user_list(header, user_list)
    log_line("  #{header}")
    user_list.each { |user| user_output(user) }
  end

  def output_top_ups(company_name, total_top_ups)
    log_line("  Total amount of top ups for #{company_name}: #{total_top_ups}")
  end

  def user_output(user)
    log_line("    #{user['last_name']}, #{user['first_name']}, #{user['email']}")
    log_line("      Previous Token Balance #{user['tokens']}")
    log_line("      New Token Balance #{user['new_balance']}")
  end
end

# Main emailer class used for the challenge, accepts a user and company file
# processes them and provides it's output to the output_file_path
class Emailer
  def initialize(users_file_path, companies_file_path, output_file_path)
    @users_file_path = users_file_path
    @companies_file_path = companies_file_path
    @output_file_path = output_file_path
  end

  def send_mail
    companies_hash.each do |company|
      users_emailed = []
      users_not_emailed = []
      total_top_ups = 0

      # Get users for company
      users_by_company_hash[company['id']]&.each do |user|
        # Skip processing inactive users
        next if user['active_status'] == false

        # top up the users tokens based on company top ups
        user['new_balance'] = user['tokens'] + company['top_up']
        total_top_ups += company['top_up']

        # Determine whether an e-mail should be sent or not and add to list
        if company['email_status'] && user['email_status']
          users_emailed.push(user)
        else
          users_not_emailed.push(user)
        end
      end

      # Skip output if there's no active users for the company
      next if users_emailed.empty? && users_not_emailed.empty?

      # Log this companies results
      email_logger.log_company_results(company, users_emailed, users_not_emailed, total_top_ups)
    end
  ensure
    email_logger.close
  end

  private

  def email_logger
    @email_logger ||= EmailLogger.new(@output_file_path)
  end

  def companies_hash
    @companies_hash ||= begin
      companies_hash = JSONFileReader.new(@companies_file_path, COMPANIES_SCHEMA).file_hash

      # Companies should be ordered by company id.
      companies_hash.sort { |a, b| a['id'] <=> b['id'] }
    end
  end

  def users_by_company_hash
    @users_by_company_hash ||= begin
      users_hash = JSONFileReader.new(@users_file_path, USERS_SCHEMA).file_hash

      # Users should be ordered alphabetically by last name.
      sorted_users_hash = users_hash.sort { |a, b| a['last_name'] <=> b['last_name'] }

      # Map users to company
      sorted_users_hash.each_with_object({}) do |user_info, hash|
        if hash[user_info['company_id']]
          hash[user_info['company_id']].push(user_info)
        else
          hash[user_info['company_id']] = [user_info]
        end
      end
    end
  end
end

OUTPUT_FILE = './output.txt'.freeze
options = {}
OptionParser.new do |opt|
  opt.on('--users_file USERSFILE') { |o| options[:users_file] = o }
  opt.on('--companies_file COMPANIESFILE') { |o| options[:companies_file] = o }
end.parse!

if !options[:users_file] || !options[:companies_file]
  puts 'Invalid format, run with --help for usage details'
  exit
end

puts "Processing e-mails for companies: #{options[:companies_file]} and users: #{options[:users_file]}"
Emailer.new(options[:users_file], options[:companies_file], OUTPUT_FILE).send_mail
puts "Processing complete, see #{OUTPUT_FILE} for more details"
