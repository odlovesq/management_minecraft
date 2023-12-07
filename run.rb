require 'aws-sdk-ec2'
require 'faraday'
require 'dotenv/load'
require './notify'

def instance_started?(ec2_client, instance_id)
  response = ec2_client.describe_instance_status(instance_ids: [instance_id])

  if response.instance_statuses.count.positive?
    state = response.instance_statuses[0].instance_state.name
    case state
    when "pending"
      puts "Error starting instance: the instance is pending. Try again later."
      return false
    when "running"
      puts "The instance is already running."
      return true
    when "terminated"
      puts "Error starting instance: " \
        "the instance is terminated, so you cannot start it."
      return false
    end
  end

  ec2_client.start_instances(instance_ids: [instance_id])
  ec2_client.wait_until(:instance_running, instance_ids: [instance_id])
  puts "Instance started."
  puts ec2_client.describe_instance_status(instance_ids: [instance_id])
  return true
rescue StandardError => e
  puts "Error starting instance: #{e.message}"
  return false
end

def get_instance_public_ip(ec2_client, instance_id)
  response = ec2_client.describe_instances(
    instance_ids: [instance_id]
  )

  if response.count.zero?
    puts 'No matching instance found.'
  else
    instance = response.reservations[0].instances[0]
    puts "The instance with ID '#{instance_id}' is '#{instance.state.name}'."
  end

  instance.public_ip_address
rescue StandardError => e
  puts "Error getting information about instance: #{e.message}"
end

def run_instance()
  region = ENV["AWS_REGION"]
  instance_id = ENV["TARGET_INSTANCE"]

  notify_line("起動するよ")

  ec2_client = Aws::EC2::Client.new(region: region)
  if instance_started?(ec2_client, instance_id)
    public_ip = get_instance_public_ip(ec2_client, instance_id)
    notify_line(public_ip)
    public_ip
  else
    notify_line("Could not start instance.")
    "-"
  end
end

def lambda_handler(event:, context:)
  ip= run_instance
  {
    statusCode: 200,
    body: JSON.generate("IP: #{ip}")
  }
end

run_instance if $PROGRAM_NAME == __FILE__

