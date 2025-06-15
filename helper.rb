module Helper
  def get_current_time
    time_str = DateTime.now.to_s

    time = Time.iso8601(time_str)

    moscow_time = time.localtime("+03:00")

    formatted = moscow_time.strftime("%Y-%m-%d %H:%M:%S")

    formatted
  end
end