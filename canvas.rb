class Canvas
  attr_reader :width, :height, :pixels, :color, :line_width
  def initialize(width, height)
    @width = width
    @height = height
    @color = 1.0
    @pixels = @height.times.map do
      [0.0] * @width
    end
  end

  def clear(color = 0)
    color = color.clamp(0, 1).to_f
    @pixels.each do |row|
      row.fill color
    end
  end

  def color=(color)
    @color = color.clamp(0, 1).to_f
  end

  def line_width=(line_width)
    @line_width = [0, line_width].max
  end

  def draw_line((x1, y1), (x2, y2))
    step = [(x2 - x1).abs, (y2 - y1).abs].max
    points = []
    (0..step).each do |i|
      t = i.fdiv step
      x = (x1 + (x2 - x1) * t).round
      y = (y1 + (y2 - y1) * t).round
      @pixels[y][x] = @color if (0...width).cover?(x) && (0...height).cover?(y)
      points << [x, y]
    end
    stroke points, @line_width / 2
  end



  def bounds_each(bounds)
    return if bounds.empty?

    bounds = bounds.sort_by(&:first)
    prev_x = bounds.first.first - 1
    level = 0
    bounds.each do |x, delta|
      level += delta
      if delta < 0 || level > 1
        (prev_x + 1 .. x).each do
          yield _1
        end
      end
      prev_x = x
    end
  end

  def stroke(points, radius)
    y_by_x = {}
    x_bounds = []
    points.each do |x, y|
      (y_by_x[x] ||= {})[y] = true
      x_bounds << [x - radius, 1]
      x_bounds << [x + radius, -1]
    end

    bounds_each x_bounds do |target_x|
      y_bounds = []
      (-radius .. radius).each do |dx|
        ys = y_by_x[target_x + dx]
        next unless ys
        dy = Math.sqrt((radius + 0.5) ** 2 - dx ** 2).floor
        ys.each_key do |y|
          y_bounds << [y - dy, 1]
          y_bounds << [y + dy, -1]
        end
      end
      bounds_each y_bounds do |target_y|
        @pixels[target_y][target_x] = @color if (0...width).cover?(target_x) && (0...height).cover?(target_y)
      end
    end
  end

  def to_int_pixel(max)
    @pixels.map do |row|
      row.map { (_1 * max).round }
    end
  end
end
