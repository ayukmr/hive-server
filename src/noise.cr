module Hive
  class Noise
    def initialize
      perm = (0..255).to_a.shuffle
      @p = Array(Int32).new(512) { |i| perm[i % 256] }
    end

    def fade(t : Float64) : Float64
      t * t * t * (t * (t * 6 - 15) + 10)
    end

    def lerp(t : Float64, a : Float64, b : Float64) : Float64
      a + t * (b - a)
    end

    GRADIENTS = [
      {1.0, 0.0}, {-1.0, 0.0}, {0.0, 1.0}, {0.0, -1.0},
      {1.0, 1.0}, {-1.0, 1.0}, {1.0, -1.0}, {-1.0, -1.0}
    ]

    def grad(hash : Int32, x : Float64, y : Float64) : Float64
      g = GRADIENTS[hash & 7]
      g[0] * x + g[1] * y
    end

    def sample(x : Float64, y : Float64) : Float64
      xi = x.floor.to_i & 255
      yi = y.floor.to_i & 255
      xf = x - x.floor
      yf = y - y.floor

      u = fade(xf)
      v = fade(yf)

      aa = @p[@p[xi] + yi]
      ab = @p[@p[xi] + yi + 1]
      ba = @p[@p[xi + 1] + yi]
      bb = @p[@p[xi + 1] + yi + 1]

      x1 = lerp(u, grad(aa, xf, yf), grad(ba, xf - 1, yf))
      x2 = lerp(u, grad(ab, xf, yf - 1), grad(bb, xf - 1, yf - 1))

      lerp(v, x1, x2) / 2 + 0.5
    end
  end
end
