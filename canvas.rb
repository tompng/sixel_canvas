require_relative 'sixel'

class Canvas
  TERMINAL_CLEAR_SCREEN = "\e[H\e[2J"
  TERMINAL_CURSOR_RESET = "\e[H"

  attr_reader :width, :height, :pixels, :color, :line_width
  def initialize(width, height, colors: nil, antialias: 3)
    @width = width
    @height = height
    @colors = colors
    if @colors
      self.color = 1.0
    else
      self.color = 0xffffff
    end
    @alpha = 1.0
    @line_width = 1.0
    @antialias = antialias.to_i.clamp 1, 8
    @antialias_area = @antialias**2
    @pixels = @height.times.map do
      [@colors ? 0.0 : 0] * @width
    end
  end

  def clear(color = 0, alpha: 1)
    alpha = alpha.clamp(0, 1).to_f
    if @colors
      color = color.clamp(0, 1).to_f
      @pixels.each do |row|
        row.map! do |c|
          c * (1 - alpha) + color * alpha
        end
      end
    else
      color = color.to_i
      cr = (color >> 16) & 0xff
      cg = (color >> 8) & 0xff
      cb = color & 0xff
      @pixels.each do |row|
        row.map! do |c|
          r = (c >> 16) & 0xff
          g = (c >> 8) & 0xff
          b = c & 0xff
          r = r * (1 - alpha) + cr * alpha
          g = g * (1 - alpha) + cg * alpha
          b = b * (1 - alpha) + cb * alpha
          (r.round << 16) | (g.round << 8) | b.round
        end
      end
    end
  end

  def color=(color)
    if @colors
      @color = color.clamp(0, 1).to_f
    else
      @color = color.to_i
      @r = (@color >> 16) & 0xff
      @g = (@color >> 8) & 0xff
      @b = @color & 0xff
    end
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
    dab = [(bx - ax).abs, (by - ay).abs].max
    dcd = [(dx - cx).abs, (dy - cy).abs].max
    dad = [(dx - ax).abs, (dy - ay).abs].max
    step = [3 * dab, 3 * dcd, 1.5 * dad, 1].max.ceil
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
    step = [(x2 - x1).abs, (y2 - y1).abs, 1].max
    (0..step).each do |i|
      t = i.fdiv step
      x = (x1 + (x2 - x1) * t).round
      y = (y1 + (y2 - y1) * t).round
      points << [x, y]
    end
  end

  def each_overlapped_range(bounds, overlaps = 1)
    return if bounds.empty?
    level = 0
    prev = 0
    bounds.sort.each do |v|
      if v % 1 == 0 # v % 1 == 0 is range begin
        level += 1
        prev = v if level == overlaps
      else # v % 1 == 0.5 is range end
        if level == overlaps
          yield prev, v.ceil
        end
        level -= 1
      end
    end
  end

  def each_subtract_range(target_bounds, sub_bounds)
    bounds = target_bounds + sub_bounds.map { _1 + (_1 % 1) * 0.5 - 0.125 }
    level = 0
    sub_level = 0
    prev = 0
    bounds.sort.each do |v|
      case v % 1
      when 0
        prev = v if level == 0 && sub_level == 0
        level += 1
      when 0.5
        level -= 1
        yield prev.ceil, v.ceil if level == 0 && sub_level == 0
      when 0.625
        sub_level -= 1
        prev = v if level > 0 && sub_level == 0
      when 0.875
        yield prev.ceil, v.ceil if level > 0 && sub_level == 0
        sub_level += 1
      end
    end
  end

  def each_merged_range_value(bounds)
    each_overlapped_range bounds do |from, to|
      (from...to).each { yield _1 }
    end
  end

  def compact_xor_range(xor_bounds)
    ranges = []
    prev = -1
    fill = false
    xor_bounds.sort.each do |v|
      if fill
        if ranges.last&.last == prev
          ranges.last[1] = v
        else
          ranges << [prev, v]
        end
        prev = v
        fill = false
      else
        prev = v
        fill = true
      end
    end
    ranges
  end

  def _fill(points)
    row_xor_bounds_a = {}
    dedup_points = []
    points.each do |p|
      dedup_points << p if dedup_points.last != p
    end
    dedup_points.pop while dedup_points.first == dedup_points.last
    return if dedup_points.empty?

    dedup_points.size.times do |i|
      x1, y1 = dedup_points[i - 1]
      x2, y2 = dedup_points[i]
      step = (y2 - y1).abs
      (1...step).each do |j|
        c1 = 2 * (step - j)
        c2 = 2 * j
        x = (c1 * x1 + c2 * x2 + step) / step / 2
        y = (c1 * y1 + c2 * y2 + step) / step / 2
        (row_xor_bounds_a[y] ||= []) << x
      end
      x0, y0 = dedup_points[i - 2]
      if (y0 != y1 || y1 != y2) && ((y1 - y0) * (y2 - y1) > 0 || (y0 == y1 && ((x0 < x1) ^ (y1 < y2))) || (y1 == y2 && ((x1 > x2) ^ (y0 < y1))))
        (row_xor_bounds_a[y1] ||= []) << x1
      end
    end
    row_bounds = {}
    row_xor_bounds_a.each do |y_a, xor_bounds|
      x_bounds = []
      compact_xor_range(xor_bounds).each do |from, to|
        x_bounds << from
        x_bounds << to + 0.5
      end
      (row_bounds[y_a / @antialias] ||= []) << x_bounds
    end
    row_bounds.each do |pixel_y, antialias_x_bounds|
      _fill_antialias_bounds(pixel_y, antialias_x_bounds)
    end
  end

  def _fill_antialias_bounds(pixel_y, antialias_x_bounds)
    pixels_row = @pixels[pixel_y]
    subtract_bounds = []
    updates = Hash.new 0
    each_overlapped_range antialias_x_bounds.flatten, @antialias do |x_from_a, x_to_a|
      x_from = (x_from_a + @antialias - 1) / @antialias
      x_to = (x_to_a - @antialias) / @antialias
      next if x_to < 0 || x_from >= @width || x_from >= x_to

      subtract_bounds << x_from * @antialias
      subtract_bounds << (x_to + 1) * @antialias + 0.5
      ([x_from, 0].max..[x_to, @width - 1].min).each do |x|
        updates[x] = @antialias_area if x >= 0 && x < @width
      end
    end
    antialias_x_bounds.each do |x_bounds|
      each_subtract_range x_bounds, subtract_bounds do |x_from_a, x_to_a|
        x_from_a = x_from_a.clamp 0, @height * @antialias
        x_to_a = x_to_a.clamp 0, @height * @antialias
        x_from = x_from_a / @antialias
        x_to = (x_to_a - 1) / @antialias
        next if x_to < 0 || x_from >= @height

        (x_from + 1..x_to - 1).each do |x|
          updates[x] += @antialias
        end
        if x_from == x_to
          updates[x_from] += x_to_a - x_from_a
        else
          updates[x_from] += @antialias - x_from_a % @antialias
          updates[x_to] += (x_to_a - 1) % @antialias + 1
        end
      end
    end
    if @colors
      updates.each do |x, count|
        alpha = @alpha * count / @antialias_area
        pixels_row[x] = pixels_row[x] * (1 - alpha) + @color * alpha
      end
    else
      updates.each do |x, count|
        alpha = @alpha * count / @antialias_area
        col = pixels_row[x]
        r = (col >> 16) & 0xff
        g = (col >> 8) & 0xff
        b = col & 0xff
        r = r * (1 - alpha) + @r * alpha
        g = g * (1 - alpha) + @g * alpha
        b = b * (1 - alpha) + @b * alpha
        pixels_row[x] = (r.round << 16) | (g.round << 8) | b.round
      end
    end
  end

  def _stroke(points, radius)
    x_by_y = {}
    y_bounds = []
    radius_i = radius.ceil
    points.each do |x, y|
      (x_by_y[y] ||= {})[x] = true
      y_bounds << y - radius_i
      y_bounds << y + radius_i + 0.5
    end
    pixel_y_set = {}
    each_merged_range_value y_bounds do |target_y|
      y = target_y / @antialias
      pixel_y_set[y] = true if 0 <= y && y < @height
    end
    pixel_y_set.each_key do |pixel_y|
      antialias_x_bounds = @antialias.times.map do |i|
        target_y = pixel_y * @antialias + i
        x_bounds = []
        (-radius_i..radius_i).each do |dy|
          xs = x_by_y[target_y + dy]
          next unless xs

          dx2 = (radius + 0.5)**2 - dy**2
          next unless dx2 > 0

          dx = Math.sqrt(dx2).floor
          xs.each_key do |x|
            x_bounds << x - dx
            x_bounds << x + dx + 0.5
          end
        end
        compact_x_bounds = []
        each_overlapped_range x_bounds do |from, to|
          if compact_x_bounds.last&.> from
            compact_x_bounds.pop
          else
            compact_x_bounds << from
          end
          compact_x_bounds << to + 0.5
        end
        compact_x_bounds
      end
      _fill_antialias_bounds(pixel_y, antialias_x_bounds)
    end
  end

  def to_sixel
    if @colors
      max_color_index = @colors.size - 1
      image = @pixels.map do |row|
        row.map { (_1 * max_color_index).round }
      end
      Sixel.build image, @colors
    else
      Sixel.build @pixels
    end
  end
end
