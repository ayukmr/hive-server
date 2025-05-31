module Hive
  class Socket
    @ws : HTTP::WebSocket

    def initialize(@ws)
    end

    def send(data : String)
      @ws.send data
    end

    def error(msg : String)
      send ({ type: "error", message: msg }).to_json
    end
  end
end
