require 'aws-sdk-ec2'
require 'faraday'
require 'dotenv/load'

def instance_stopped?(ec2_client, instance_id)
  response = ec2_client.describe_instance_status(instance_ids: [instance_id])

  if response.instance_statuses.count.positive?
    state = response.instance_statuses[0].instance_state.name
    case state
    when 'stopping'
      puts 'The instance is already stopping.'
      return true
    when 'stopped'
      puts 'The instance is already stopped.'
      return true
    when 'terminated'
      puts 'Error stopping instance: ' \
        'the instance is terminated, so you cannot stop it.'
      return false
    end
  end

  ec2_client.stop_instances(instance_ids: [instance_id])
  ec2_client.wait_until(:instance_stopped, instance_ids: [instance_id])
  puts "Instance stopped."
  return true
rescue StandardError => e
  puts "Error stopping instance: #{e.message}"
  return false
end

def notify_line(text)
  puts text
  connection = Faraday.new(
    url: 'https://api.line.me',
    headers: {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{ENV['LINE_CHANNEL_ACCESS_TOKEN']}",
    }
  )

  params = {
    "to": ENV['LINE_GROUP_ID'],
    "messages":[
      {
        :type => "text",
        :text => text,
      },
    ]
  }
  response = connection.post '/v2/bot/message/push', params.to_json
  puts response.body
end

def stop_instance()
  region = ENV["AWS_REGION"]
  instance_id = ENV["TARGET_INSTANCE"]

  notify_line("停止するよ")
  
  ec2_client = Aws::EC2::Client.new(region: region)
  if instance_stopped?(ec2_client, instance_id)
    notify_line("停止したよ")
    true
  else
    notify_line("Could not stop instance.")
    false
  end
end

def lambda_handler(event:, context:)
  result = stop_instance
  {
    statusCode: 200,
    body: JSON.generate("#{result ? '停止しました' : '停止に失敗しました'}")
  }
end

stop_instance if $PROGRAM_NAME == __FILE__

