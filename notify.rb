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
