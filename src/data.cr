module Hive
  module Data
    class Game
      include DB::Serializable
      include JSON::Serializable

      @id : Int32
      @turn : Int32
    end

    class Player
      include DB::Serializable
      include JSON::Serializable

      @id : String
      @num : Int32

      @x : Int32?
      @y : Int32?

      @pollen : Int32
    end

    class Wall
      include DB::Serializable
      include JSON::Serializable

      @x : Int32
      @y : Int32
    end

    class Flower
      include DB::Serializable
      include JSON::Serializable

      @x : Int32
      @y : Int32

      @pollen : Int32
    end

    class Hive
      include DB::Serializable
      include JSON::Serializable

      @player : String

      @x : Int32
      @y : Int32

      @pollen : Int32
    end
  end
end
