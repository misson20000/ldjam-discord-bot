require "discordrb"

bot = Discordrb::Commands::CommandBot.new token: "<insert token here>", client_id: <insert client id here>, prefix: "!"

puts "Invite URL is #{bot.invite_url}"

class JamEvent
  def initialize(channels, json)
    @@named_events||= {}
    
    @channels = channels
    @title = json["title"]
    @time = Time.utc(json["year"], json["month"], json["day"], json["hour"], json["minute"])
    @afterward_msg = json["afterward"]
    
    if json["id"] then
      @@named_events[json["id"]] = self
    end

    @blocked = (json["blocked"] || []).map do |id|
      @@named_events[id]
    end
  end

  def show?
    return @blocked.all? do |e|
      e.passed?
    end
  end
  
  def passed?
    return Time.now > @time
  end
  
  attr_reader :channels
  attr_reader :title
  attr_reader :time
  attr_reader :afterward_msg
end

events = []

Dir.foreach("./jamevents") do |item|
  if item.end_with? ".json" then
    json = JSON.parse(File.read(File.join("jamevents/", item)))
    channels = json["channels"]
    json["times"].each do |t|
      event = JamEvent.new(channels, t)
      events.push event
    end
  end
end

GAMEJAM_SERVER_ID = "218883154155536384"
#GAMEJAM_SERVER_ID = "218891291340046336" # bot test playground

puts events
events.sort_by do |a|
  a.time
end

bot.command :timeleft do |cmd|
  server_id = cmd.message.channel.server.id
  channel_name = "#" + cmd.message.channel.name
  
  evts = events.select do |evt|
    !evt.passed? && evt.show?
  end

  if evts.length == 0 then
    i = events.rindex do |evt|
      true
    end
    evt = i && events[i]
    next (evt && (Time.now - evt.time) < (60*60*24) && evt.afterward_msg) || ("There is no game jam coming up that I know about yet.")
  end
  
  next evts.map do |evt|
    seconds = evt.time - Time.now
    increments = [
      {:plural => "weeks", :singular => "week", :length => 7 * 24 * 60 * 60},
      {:plural => "days", :singular => "day", :length => 24 * 60 * 60},
      {:plural => "hours", :singular => "hour", :length => 60 * 60},
      {:plural => "minutes", :singular => "minute", :length => 60},
      {:plural => "seconds", :singular => "second", :length => 1}
    ]
    str = ""
    increments.each do |unit|
      number = (seconds/unit[:length]).floor
      if number > 0 then
        if str != "" then
          str+= ", "
        end
        str+= number.to_s + " " + (number == 1 ? unit[:singular] : unit[:plural])
        seconds-= number * unit[:length]
      end
    end
    next str + " left until " + evt.title
  end.join("\n")
end

bot.run
