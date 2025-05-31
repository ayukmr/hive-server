module Hive
  GAMES = 5
  PLAYERS = 4
  SIZE = 15

  @@players  = [] of Player
  @@watchers = [] of Watcher

  @@db : DB::Database = DB.open("sqlite3://./data.db")

  def self.db : DB::Database
    @@db
  end

  def self.players : Array(Player)
    @@players
  end

  def self.watchers : Array(Watcher)
    @@watchers
  end

  def self.has_id?(p_id : String)
    @@players.any? { |socket| socket.id == p_id }
  end

  def self.init_tables
    if !table_exists?("players")
      Hive.db.exec "CREATE TABLE players (
        id TEXT PRIMARY KEY,
        game INTEGER NOT NULL,
        num INTEGER NOT NULL,

        x INTEGER,
        y INTEGER,

        last_x INTEGER,
        last_y INTEGER,

        moved BOOLEAN,

        pollen INTEGER DEFAULT 0,

        UNIQUE (game, num)
      )"
    end

    if !table_exists?("walls")
      Hive.db.exec "CREATE TABLE walls (
        game INTEGER NOT NULL,

        x INTEGER NOT NULL,
        y INTEGER NOT NULL,

        PRIMARY KEY (game, x, y)
      )"
    end

    if !table_exists?("flowers")
      Hive.db.exec "CREATE TABLE flowers (
        game INTEGER NOT NULL,

        x INTEGER NOT NULL,
        y INTEGER NOT NULL,

        pollen INTEGER DEFAULT 0,

        PRIMARY KEY (game, x, y)
      )"
    end

    if !table_exists?("hives")
      Hive.db.exec "CREATE TABLE hives (
        game INTEGER NOT NULL,
        player TEXT NOT NULL,

        x INTEGER NOT NULL,
        y INTEGER NOT NULL,

        pollen INTEGER DEFAULT 0,

        PRIMARY KEY (game, x, y)
      )"
    end

    if !table_exists?("games")
      Hive.db.exec "CREATE TABLE games (
        id INTEGER PRIMARY KEY,
        turn INTEGER DEFAULT 0
      )"

      GAMES.times do |g_id|
        Hive.db.exec "INSERT INTO games VALUES (?, 0)", g_id
      end
    end
  end

  def self.table_exists?(table : String) : Bool
    res = Hive.db.query_one? "
      SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?
    ", table, as: Int32

    !!res
  end
end
