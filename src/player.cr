module Hive
  class Player < Socket
    getter id : String
    @game : Game?

    def initialize(ws : HTTP::WebSocket, @id, g_id : Int32)
      super(ws)

      if Hive.has_id?(@id)
        error "error: socket for '#{@id}' already connected"
        ws.close
      end

      Hive.players.push(self)

      check_game
      join(g_id)

      ws.on_message do |data|
        msg  = JSON.parse(data)
        type = msg["type"]

        if type == "move"
          dir = msg["dir"].as_s
          move(dir)
        else
          error "error: invalid message type '#{type}'"
        end
      end

      ws.on_close do
        Hive.players.delete(self)

        next unless game = @game

        if game.has_moved?(@id).nil?
          game.remove_player(@id)
          game.watchers_send
        end
      end
    end

    def in_game?(game)
      @game && @game.not_nil!.id == game
    end

    def check_game
      g_id = Hive.db.query_one? "
        SELECT game FROM players WHERE id = ?
      ", @id, as: Int32

      return unless g_id

      game  = Game.new(g_id)
      @game = game

      if game.has_moved?(@id) == false
        msg = {
          type: "next",
          data: game.data(before_move: true)
        }.to_json

        send msg
      end
    end

    def join(g_id : Int32)
      return if @game

      game = Game.new(g_id)
      num = game.find_open

      if num
        @game = game

        game.add_player(@id, num)

        game.watchers_send
        game.try_start
      else
        error "error: game '#{g_id}' is full"
      end
    end

    def move(dir : String)
      return unless game = @game

      dirs = {
        "stay":  [ 0,  0],
        "left":  [-1,  0],
        "right": [ 1,  0],
        "up":    [ 0, -1],
        "down":  [ 0,  1]
      }

      delta = dirs[dir]?

      if delta
        dx, dy = delta

        game.move_player(@id, dx, dy)
        game.try_finish
      else
        error "error: invalid direction '#{dir}'"
      end
    end
  end
end
