class VitClient
  require 'yaml'
  APP_CONFIG = YAML.load_file(File.join(__dir__, 'config.yml'))&.transform_keys(&:to_sym)

  extend Helper

  VIT_HOST = APP_CONFIG[:vit_host]
  VIT_MENU_URL = APP_CONFIG[:vit_menu_url]
  VIT_REGION_URL = APP_CONFIG[:vit_region_url]
  TGBOTAPI = APP_CONFIG[:tg_bot_api]
  MY_CHAT_ID = APP_CONFIG[:my_chat_id]

  PRODUCT_NAME = 'Игрушка'
  DSCRIPTION_FLAG = 'Смешарик'

  REQ_RETRY = 2

  VRN_L1 = '39.206208'
  VRN_L2 = '51.669302'
  MSK_L1 = '37.570247'
  MSK_L2 = '51.669302'

  @@cached = {}

  def self.ping(force = false, respond_to_id = MY_CHAT_ID)
    process_locations(
      locations: fetch_regions(VRN_L1, VRN_L2).take(14),
      delay: force ? 1 : 10,
      force: force,
      respond_to_id: respond_to_id
    )
  end

  def self.msk(respond_to_id = MY_CHAT_ID)
    process_locations(
      locations: fetch_regions(MSK_L1, MSK_L2).select { |r| r['region'] == 'Москва' },
      respond_to_id: respond_to_id,
      filter_available: true
    )
  end

  def self.vrn(respond_to_id = MY_CHAT_ID)
    process_locations(
      locations: fetch_regions(VRN_L1, VRN_L2).take(30),
      respond_to_id: respond_to_id,
      filter_available: true
    )
  end

  private

  def self.fetch_regions(long, lat)
    retry_count = 0
    region_url = VIT_HOST + VIT_REGION_URL.gsub(':long', long).gsub(':lat', lat)
    
    begin
      response = HTTParty.get(region_url, {
        headers: {
          'User-Agent' => 'Ruby Restaurant Menu Client',
          'Accept' => 'application/json'
        }
      })

      response.success? ? JSON.parse(response.body) : (puts response.body)
    rescue StandardError => e
      puts "An error occurred: #{e.message}"
      retry_count += 1
      retry if retry_count <= REQ_RETRY
    end
  end

  def self.fetch_menu(city_object_id)
    retry_count = 0
    menu_url = VIT_HOST + VIT_MENU_URL.gsub(':city_object_id', city_object_id)
    
    begin
      response = HTTParty.get(menu_url, {
        headers: {
          'User-Agent' => 'Ruby Restaurant Menu Client',
          'Accept' => 'application/json'
        }
      })

      response.success? ? JSON.parse(response.body) : (puts response.body)
    rescue StandardError => e
      puts "An error occurred: #{e.message}"
      retry_count += 1
      retry if retry_count <= REQ_RETRY
    end
  end

  def self.process_locations(locations:, delay: 0, force: false, respond_to_id: MY_CHAT_ID, filter_available: false)
    hash = {}
    
    locations.each do |co|
      sleep delay if delay > 0
      co = co.transform_keys(&:to_sym)
      mac_response = fetch_menu(co[:xmlId])
      next if mac_response.nil?

      address = format_address(co)
      puts "Забираем из #{address}"
      
      available = product_available?(mac_response)
      hash[address] = available
      puts "В #{address} - #{available ? 'Есть' : 'Нет'}"
    end

    send_notification(hash, force, respond_to_id, filter_available)
  rescue => e
    handle_error(e, force, respond_to_id)
  end

  def self.format_address(co)
    "#{co[:region]}, #{co[:city]}, #{co[:street]}, #{co[:house]} (#{co[:name].split[2]})"
  end

  def self.product_available?(menu_response)
    menu_response['products'].detect do |_, v| 
      v['name'] == PRODUCT_NAME && v['detailText'].include?(DSCRIPTION_FLAG)
    end
  end

  def self.send_notification(hash, force, respond_to_id, filter_available)
    changed = @@cached != hash
    return unless force || changed

    @@cached = hash if changed

    message = build_message(hash, force, filter_available)
    puts message
    
    send_telegram_message(respond_to_id, message)
  end

  def self.build_message(hash, force, filter_available)
    base_message = force ? 
      ["Состояние по запросу на #{get_current_time}\n"] : 
      ["🚨 ЧТО-ТО Поменялось! 🚨 \n\n Состояние на #{get_current_time}\n"]
    
    locations_list = filter_available ? 
      hash.select { |_, v| v } : 
      hash
    
    res = (base_message + locations_list.map do |k, v| 
      "#{v ? "✅" : "❌"} #{k} - #{v ? 'Есть' : 'Нет'}"
    end).join("\n")

    locations_list.empty? ? base_message.join("\n") + "\n Смешариков нет :(" : res
  end

  def self.send_telegram_message(chat_id, text)
    Telegram::Bot::Client.run(TGBOTAPI) do |bot|
      bot.api.send_message(chat_id: chat_id, text: text)
    end
  end

  def self.handle_error(e, force, respond_to_id)
    send_telegram_message(
      MY_CHAT_ID, 
      "Не удалось запросить данные на момент #{get_current_time}"
    )
    
    pp e
    force ? exit(1) : raise(e)
  rescue => e
    pp e
  end
end