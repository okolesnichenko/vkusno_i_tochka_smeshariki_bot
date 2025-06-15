require 'httparty'
require 'json'
require 'byebug'
require 'telegram/bot'
require 'time'
require 'yaml'
require_relative 'helper'
require_relative 'vit_client'

class Pinger

  require 'yaml'
  APP_CONFIG = YAML.load_file(File.join(__dir__, 'config.yml'))&.transform_keys(&:to_sym)

  TGBOTAPI = APP_CONFIG[:tg_bot_api]
  MY_CHAT_ID = APP_CONFIG[:my_chat_id]

  PING_SLEEP = 1200
  
  extend Helper

  def self.run_loop
    index = 0
    loop do
      index += 1
      puts "Пинг № #{index} - Начало пинга #{get_current_time}"
      VitClient.ping
      puts "Пинг № #{index} - Начало отдыха #{get_current_time} следущий пинг через #{PING_SLEEP} секунд"
      sleep PING_SLEEP
    end
  end

  def self.listen
    Telegram::Bot::Client.run(TGBOTAPI) do |bot|
      bot.listen do |message|
        case message.text
        when '/ping'
          VitClient.ping(true, message.chat.id)
        when '/msk'
          VitClient.msk(message.chat.id)
        when '/vrn'
          VitClient.vrn(message.chat.id)
        end
      end
    end
  rescue => e
    pp e
    exit 1
  end

end


$stdout.sync = true

puts "This will appear immediately in Docker logs"
STDOUT.flush

case ENV['MODE'].to_sym
  
when :listener
  Pinger.listen
when :loop
  Pinger.run_loop
when :msk
  Pinger.msk
when :vrn
  Pinger.vrn
end


