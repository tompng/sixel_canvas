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
    (0..step).each do |i|
      t = i.fdiv step
      x = (x1 + (x2 - x1) * t).round
      y = (y1 + (y2 - y1) * t).round
      @pixels[y][x] = @color if (0...width).cover?(x) && (0...height).cover?(y)
    end
  end

  def to_int_pixel(max)
    @pixels.map do |row|
      row.map { (_1 * max).round }
    end
  end
end
