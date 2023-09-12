class Canvas
  attr_reader :width, :height, :pixels, :color, :line_width
  def initialize(width, height)
    @width = width
    @height = height
    @color = 1.0
    @alpha = 1.0
    @antialias = 2
    @bitcounts = (1 << @antialias**2).times.map { _1.to_s(2).count '1' }
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

  def alpha=(alpha)
    @alpha = alpha.clamp(0, 1).to_f
  end

  def line_width=(line_width)
    @line_width = [1, line_width].max
  end

  def bezier(a, b, c, d)
    points = []
    _bezier_path a, b, c, d, points
    _stroke points, @line_width * @antialias / 2
  end

  def _bezier_path(pa, pb, pc, pd, points)
    ax, ay = pa.map { _1 * @antialias }
    bx, by = pb.map { _1 * @antialias }
    cx, cy = pc.map { _1 * @antialias }
    dx, dy = pd.map { _1 * @antialias }
    dab = Math.hypot (bx - ax).abs, (by - ay).abs
    dcd = Math.hypot (dx - cx).abs, (dy - cy).abs
    step = ([dab, dcd].max * 3).ceil
    x0 = ax
    x1 = 3 * (bx - ax)
    x2 = 3 * (ax - 2 * bx + cx)
    x3 = -ax + 3 * bx - 3 * cx + dx
    y0 = ay
    y1 = 3 * (by - ay)
    y2 = 3 * (ay - 2 * by + cy)
    y3 = -ay + 3 * by - 3 * cy + dy

    (0..step).each do |i|
      t = i.fdiv step
      x = x0 + x1 * t + x2 * t**2 + x3 * t**3
      y = y0 + y1 * t + y2 * t**2 + y3 * t**3
      points << [x.round, y.round]
    end
  end

  def line(p1, p2)
    points = []
    _line_path p1, p2, points
    _stroke points, @line_width * @antialias / 2
  end

  def _line_path(p1, p2, points)
    x1, y1 = p1.map { _1 * @antialias }
    x2, y2 = p2.map { _1 * @antialias }
    step = [(x2 - x1).abs, (y2 - y1).abs].max
    (0..step).each do |i|
      t = i.fdiv step
      x = (x1 + (x2 - x1) * t).round
      y = (y1 + (y2 - y1) * t).round
      points << [x, y]
    end
  end

  def bounds_each(bounds)
    return if bounds.empty?

    bounds = bounds.sort
    prev_x = bounds.first.first - 1
    level = 0
    bounds.each do |x, delta|
      level += delta
      if delta > 0 && level == 0
        (prev_x..x).each do
          yield _1
        end
      elsif delta < 0 && level == -1
        prev_x = x
      end
    end
  end
  
  def _stroke(points, radius)
    radius *= @antialias
    y_by_x = {}
    x_bounds = []
    radius_i = radius.ceil
    points.each do |x, y|
      (y_by_x[x] ||= {})[y] = true
      x_bounds << [x - radius_i, -1]
      x_bounds << [x + radius_i, +1]
    end
    updates = Hash.new 0
    bounds_each x_bounds do |target_x|
      next if target_x < 0 || target_x >= @width * @antialias
      y_bounds = []
      (-radius_i..radius_i).each do |dx|
        ys = y_by_x[target_x + dx]
        next unless ys

        dy2 = (radius + 0.5)**2 - dx**2
        next unless dy2 > 0

        dy = Math.sqrt(dy2).floor
        ys.each_key do |y|
          y_bounds << [y - dy, -1]
          y_bounds << [y + dy, +1]
        end
      end
      bounds_each y_bounds do |target_y|
        next if target_y < 0 || target_y >= @height * @antialias
        updates[[target_x / @antialias, target_y / @antialias]] += 1
      end
    end
    updates.each do |(x, y), count|
      alpha = @alpha * count / @antialias**2
      @pixels[y][x] = @pixels[y][x] * (1 - alpha) + @color * alpha
    end
  end

  def to_int_pixel(max)
    @pixels.map do |row|
      row.map { (_1 * max).round }
    end
  end
end
