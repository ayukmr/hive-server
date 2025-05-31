module Hive
  module GameDB
    def data(before_move : Bool = false)
      game = Hive.db.query_one "
        SELECT id, turn FROM games WHERE id = ?
      ", @id, as: Data::Game

      players = Hive.db.query_all "
        SELECT id, num, #{before_move ? "last_x AS x, last_y AS y" : "x, y"}, pollen
        FROM players WHERE game = ?
      ", @id, as: Data::Player

      walls = Hive.db.query_all "
        SELECT x, y FROM walls WHERE game = ?
      ", @id, as: Data::Wall

      flowers = Hive.db.query_all "
        SELECT x, y, pollen FROM flowers WHERE game = ?
      ", @id, as: Data::Flower

      hives = Hive.db.query_all "
        SELECT player, x, y, pollen FROM hives WHERE game = ?
      ", @id, as: Data::Hive

      {
        game:    game,
        players: players,
        walls:   walls,
        flowers: flowers,
        hives:   hives
      }
    end

    def reset
      Hive.db.exec "UPDATE games SET turn = 0 WHERE id = ?", @id

      Hive.db.exec "DELETE FROM players WHERE game = ?", @id
      Hive.db.exec "DELETE FROM walls   WHERE game = ?", @id
      Hive.db.exec "DELETE FROM flowers WHERE game = ?", @id
      Hive.db.exec "DELETE FROM hives   WHERE game = ?", @id
    end

    def move_player(p_id : String, dx : Int32, dy : Int32)
      cur_x, cur_y = Hive.db.query_one "
        SELECT x, y FROM players WHERE id = ?
      ", p_id, as: {Int32, Int32}

      x, y = cur_x + dx, cur_y + dy

      if (0...Hive::SIZE).includes?(x) && (0..Hive::SIZE).includes?(y)
        Hive.db.exec "
          UPDATE players
          SET x = ?, y = ?
          WHERE id = ? AND moved = FALSE
          AND NOT EXISTS (
            SELECT 1 FROM walls WHERE game = ? AND x = ? AND y = ?
          )
        ", x, y, p_id, @id, x, y
      end

      Hive.db.exec "UPDATE players SET moved = TRUE WHERE id = ?", p_id

      watchers_send
    end

    def init_players
      players = Hive.db.query_all "
        SELECT id, num FROM players WHERE game = ?
      ", @id, as: {String, Int32}

      locs = [
        {3, 3}, {Hive::SIZE - 1 - 3, 3},
        {3, Hive::SIZE - 1 - 3}, {Hive::SIZE - 1 - 3, Hive::SIZE - 1 - 3}
      ]

      players.each do |(p_id, num)|
        x, y = locs[num]

        Hive.db.exec "
          INSERT INTO hives (game, player, x, y) VALUES (?, ?, ?, ?)
        ", @id, p_id, x, y

        Hive.db.exec "
          UPDATE players
          SET x = ?, y = ?, last_x = ?, last_y = ?
          WHERE id = ?
        ", x, y, x, y, p_id
      end
    end

    def create_walls
      noise = Noise.new
      scale = 1.0 / Hive::SIZE.to_f

      (2...(Hive::SIZE - 2)).each do |y|
        (2...(Hive::SIZE - 2)).each do |x|
          sample = noise.sample(x * 4 * scale, y * 4 * scale)

          next unless sample > 0.7 && !taken?(x, y)

          Hive.db.exec "INSERT INTO walls VALUES (?, ?, ?)", @id, x, y
        end
      end
    end

    def create_flowers
      rand(10...15).times do
        x, y = rand(0...Hive::SIZE), rand(0...Hive::SIZE)

        while taken?(x, y)
          x, y = rand(0...Hive::SIZE), rand(0...Hive::SIZE)
        end

        Hive.db.exec "INSERT INTO flowers (game, x, y) VALUES (?, ?, ?)", @id, x, y
      end
    end

    def handle_collisions
      hive_resets
      average_pollen
    end

    def hive_resets
      cols = Hive.db.query_all "
        SELECT p.id, o.id, p.pollen, o.pollen, p.x, p.y
        FROM players p JOIN players o
        ON p.id < o.id AND p.x = o.x AND p.y = o.y
        WHERE p.game = ? AND o.game = ?
      ", @id, @id, as: {String, String, Int32, Int32, Int32, Int32}

      cols.each do |p_id, o_id, p_pollen, o_pollen, x, y|
        hive = Hive.db.query_one? "
          SELECT player FROM hives WHERE game = ? AND x = ? AND y = ?
        ", @id, x, y, as: String

        case hive
        when p_id
          give_reset(o_id, p_id, o_pollen)

        when o_id
          give_reset(p_id, o_id, p_pollen)
        end
      end
    end

    def average_pollen
      Hive.db.exec "
        WITH avgs AS (
          SELECT x, y, ROUND(AVG(pollen)) AS pollen
          FROM players
          WHERE game = ?
          GROUP BY x, y
        )
        UPDATE players
        SET pollen = avgs.pollen FROM avgs
        WHERE players.game = ? AND players.x = avgs.x AND players.y = avgs.y
      ", @id, @id
    end

    def give_reset(from : String, to : String, pollen : Int32)
      x, y = Hive.db.query_one "
        SELECT x, y FROM hives WHERE player = ?
      ", from, as: {Int32, Int32}

      Hive.db.exec "
        UPDATE players SET x = ?, y = ?, pollen = 0 WHERE id = ?
      ", x, y, from

      Hive.db.exec "
        UPDATE players SET pollen = pollen + ? WHERE id = ?
      ", pollen, to
    end

    def tick_flowers
      Hive.db.exec "UPDATE flowers SET pollen = pollen + 1 WHERE game = ?", @id
    end

    def collect_pollen
      players = Hive.db.query_all "
        SELECT id, x, y FROM players WHERE game = ?
      ", @id, as: {String, Int32, Int32}

      players.each do |(p_id, x, y)|
        pollen = Hive.db.query_one? "
          SELECT pollen FROM flowers WHERE game = ? AND x = ? AND y = ?
        ", @id, x, y, as: Int32

        next unless pollen

        Hive.db.exec "UPDATE players SET pollen = pollen + ? WHERE id = ?", pollen, p_id

        Hive.db.exec "
          UPDATE flowers SET pollen = 0 WHERE game = ? AND x = ? AND y = ?
        ", @id, x, y
      end
    end

    def handle_hives
      players = Hive.db.query_all "
        SELECT id, x, y, pollen FROM players WHERE game = ?
      ", @id, as: {String, Int32, Int32, Int32}

      players.each do |(p_id, x, y, p_pollen)|
        hive = Hive.db.query_one? "
          SELECT player, pollen FROM hives WHERE game = ? AND x = ? AND y = ?
        ", @id, x, y, as: {String, Int32}

        next unless hive

        h_player, h_pollen = hive
        h_delta = p_id == h_player ? 1 : -1

        next if (h_delta == 1 && p_pollen == 0) || (h_delta == -1 && h_pollen == 0)

        Hive.db.exec "UPDATE players SET pollen = pollen + ? WHERE id = ?", -h_delta, p_id

        Hive.db.exec "
          UPDATE hives SET pollen = pollen + ? WHERE game = ? AND x = ? AND y = ?
        ", h_delta, @id, x, y
      end
    end

    def taken?(x : Int32, y : Int32) : Bool
      query = "SELECT 1 FROM %s WHERE game = ? AND x = ? AND y = ?"

      hive   = Hive.db.query_one? (query % "hives"),   @id, x, y, as: Int32
      flower = Hive.db.query_one? (query % "flowers"), @id, x, y, as: Int32
      wall   = Hive.db.query_one? (query % "walls"),   @id, x, y, as: Int32

      !!(hive || flower || wall)
    end

    def players_joined? : Bool
      players = Hive.db.query_all "SELECT 1 FROM players WHERE game = ?", @id, as: Int32
      players.size == Hive::PLAYERS
    end

    def moves_done? : Bool
      !Hive.db.query_one? "
        SELECT 1 FROM players WHERE game = ? AND moved = FALSE LIMIT 1
      ", @id, as: Int32
    end

    def has_moved?(p_id : String) : Bool?
      Hive.db.query_one "SELECT moved FROM players WHERE id = ?", p_id, as: Bool?
    end

    def add_player(p_id : String, num : Int32)
      Hive.db.exec "
        INSERT INTO players (id, game, num) VALUES (?, ?, ?)
      ", p_id, @id, num
    end

    def remove_player(p_id : String)
      Hive.db.exec "DELETE FROM players WHERE id = ?", p_id
    end

    def cur_turn : Int32
      Hive.db.query_one "SELECT turn FROM games WHERE id = ?", @id, as: Int32
    end

    def set_last_pos
      Hive.db.exec "UPDATE players SET last_x = x, last_y = y WHERE game = ?", @id
    end

    def set_moved
      Hive.db.exec "UPDATE players SET moved = TRUE WHERE id = ?", @id
    end

    def reset_moved
      Hive.db.exec "UPDATE players SET moved = FALSE WHERE game = ?", @id
    end

    def player_nums
      Hive.db.query_all "SELECT num FROM players WHERE game = ?", @id, as: Int32
    end

    def inc_turn
      Hive.db.exec "UPDATE games SET turn = turn + 1 WHERE id = ?", @id
    end
  end
end
