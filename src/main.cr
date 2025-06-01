require "./lib"

Hive.init_tables

before_all do |env|
  env.response.headers["Access-Control-Allow-Origin"] = "*"

  auth = env.params.query["auth"]?
  raise "client unauthorized" if auth != ENV["AUTH"]
end

ws "/play" do |ws, env|
  p_id = env.params.query["id"]?
  g_id = env.params.query["game"]?

  raise "player id or game not given" unless p_id && g_id

  g_id = g_id.to_i

  raise "invalid game number" if g_id < 0 || g_id > 4

  Hive::Player.new(ws, p_id, g_id)
end

ws "/watch" do |ws|
  Hive::Watcher.new(ws)
end

Kemal.config.env = "production"
Kemal.run
