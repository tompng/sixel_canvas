class Canvas
  attr_reader :width, :height, :pixels, :color, :line_width
  def initialize(width, height)
    @width = width
    @height = height
    @color = 1.0
    @alpha = 1.0
    @antialias = 2
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

  def polygon(points)
    render_points = []
    points.each_cons(2) do |p1, p2|
      _line_path p1, p2, render_points
    end
    _stroke render_points, @line_width * @antialias / 2
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

  def each_merged_range(bounds)
    return if bounds.empty?
    level = 0
    prev = 0
    bounds.sort.each do |v|
      if v % 1 == 0 # range begin
        prev = v if level == 0
        level += 1
      else # range end
        level -= 1
        if level == 0
          yield prev, v.ceil
        end
      end
    end
  end

  def each_merged_range_value(bounds)
    each_merged_range bounds do |from, to|
      (from...to).each { yield _1}
    end
  end

  def _stroke(points, radius)
    y_by_x = {}
    x_bounds = []
    radius_i = radius.ceil
    points.each do |x, y|
      (y_by_x[x] ||= {})[y] = true
      x_bounds << x - radius_i
      x_bounds << x + radius_i + 0.5
    end
    updates = Hash.new 0
    each_merged_range_value x_bounds do |target_x|
      next if target_x < 0 || target_x >= @width * @antialias
      y_bounds = []
      (-radius_i..radius_i).each do |dx|
        ys = y_by_x[target_x + dx]
        next unless ys

        dy2 = (radius + 0.5)**2 - dx**2
        next unless dy2 > 0

        dy = Math.sqrt(dy2).floor
        ys.each_key do |y|
          y_bounds << y - dy
          y_bounds << y + dy + 0.5
        end
      end
      each_merged_range y_bounds do |y_from_a, y_to_a|
        y_from_a = y_from_a.clamp 0, @height * @antialias
        y_to_a = y_to_a.clamp 0, @height * @antialias
        y_from = y_from_a / @antialias
        y_to = (y_to_a - 1) / @antialias
        next if y_from >= @height

        (y_from + 1..y_to - 1).each do |y|
          updates[[target_x / @antialias, y]] += @antialias
        end
        if y_from == y_to
          updates[[target_x / @antialias, y_from]] += y_to_a - y_from_a
        else
          updates[[target_x / @antialias, y_from]] += @antialias - y_from_a % @antialias
          updates[[target_x / @antialias, y_to]] += (y_to_a - 1) % @antialias + 1
        end
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
