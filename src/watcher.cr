module Hive
  class Watcher < Socket
    def initialize(ws)
      super(ws)
      Hive.watchers.push(self)

      ws.on_message do |data|
        msg  = JSON.parse(data)
        type = msg["type"]

        if type == "reset"
          g_id = msg["game"].as_i
          game = Game.new(g_id)

          game.reset
          game.watchers_send
        else
          error "error: invalid message type '#{type}'"
        end
      end

      ws.on_close do
        Hive.watchers.delete(self)
      end

      5.times do |g_id|
        send Game.new(g_id).data.to_json
      end
    end
  end
end
