module Hive
  class Game
    include GameDB

    getter id : Int32

    def initialize(@id)
    end

    def start
      init_players
      create_walls
      create_flowers

      inc_turn
      watchers_send

      spawn do
        sleep Time::Span.new(seconds: 1)

        reset_moved
        players_send
      end
    end

    def try_start
      start if players_joined?
    end

    def finish_turn
      handle_flowers
      handle_collisions
      handle_hives

      set_last_pos

      watchers_send

      if cur_turn < 20
        inc_turn

        spawn do
          sleep Time::Span.new(seconds: 1)

          reset_moved
          players_send
        end
      end
    end

    def handle_flowers
      tick_flowers
      collect_pollen
    end

    def try_finish
      finish_turn if moves_done?
    end

    def find_open : Int32?
      nums = player_nums

      all = Set.new(0..3)
      free = all - nums.to_set

      free.first if !free.empty?
    end

    def exec_move(p_id : String, dx : Int32, dy : Int32)
      move_player(p_id, dx, dy)
      set_moved(p_id)
      watchers_send
    end

    def players_send
      msg = {
        type: "next",
        data: data(before_move: true)
      }.to_json

      Hive.players
        .select { |socket| socket.in_game?(@id) }
        .each   { |socket| socket.send msg }
    end

    def watchers_send
      msg = data.to_json

      Hive.watchers.each { |socket| socket.send msg }
    end
  end
end
