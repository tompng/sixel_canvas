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
      @color = 1.0
    else
      @color = 0xffffff
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

  def _stroke(points, radius)
    y_by_x = {}
    x_bounds = []
    radius_i = radius.ceil
    points.each do |x, y|
      (y_by_x[x] ||= {})[y] = true
      x_bounds << x - radius_i
      x_bounds << x + radius_i + 0.5
    end
    pixel_x_set = {}
    each_merged_range_value x_bounds do |target_x|
      x = target_x / @antialias
      pixel_x_set[x] = true if 0 <= x && x < @width
    end
    pixel_x_set.each_key do |pixel_x|
      antialias_y_bounds = @antialias.times.map do |i|
        target_x = pixel_x * @antialias + i
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
        compact_y_bounds = []
        each_overlapped_range y_bounds do
          compact_y_bounds << _1
          compact_y_bounds << _2 + 0.5
        end
        compact_y_bounds
      end
      subtract_bounds = []
      updates = Hash.new 0
      each_overlapped_range antialias_y_bounds.flatten, @antialias do |y_from_a, y_to_a|
        y_from = (y_from_a + @antialias - 1) / @antialias
        y_to = (y_to_a - @antialias) / @antialias
        subtract_bounds << y_from * @antialias
        subtract_bounds << (y_to + 1) * @antialias + 0.5
        next if y_to < 0 || y_from >= @height
        ([y_from, 0].max..[y_to, @height - 1].min).each do |y|
          updates[y] = @antialias_area if y >= 0 && y < @height
        end
      end
      antialias_y_bounds.each do |y_bounds|
        each_subtract_range y_bounds, subtract_bounds do |y_from_a, y_to_a|
          y_from_a = y_from_a.clamp 0, @height * @antialias
          y_to_a = y_to_a.clamp 0, @height * @antialias
          y_from = y_from_a / @antialias
          y_to = (y_to_a - 1) / @antialias
          next if y_to < 0 || y_from >= @height

          (y_from + 1..y_to - 1).each do |y|
            updates[y] += @antialias
          end
          if y_from == y_to
            updates[y_from] += y_to_a - y_from_a
          else
            updates[y_from] += @antialias - y_from_a % @antialias
            updates[y_to] += (y_to_a - 1) % @antialias + 1
          end
        end
      end
      if @colors
        updates.each do |y, count|
          alpha = @alpha * count / @antialias_area
          @pixels[y][pixel_x] = @pixels[y][pixel_x] * (1 - alpha) + @color * alpha
        end
      else
        updates.each do |y, count|
          alpha = @alpha * count / @antialias_area
          col = @pixels[y][pixel_x]
          r = (col >> 16) & 0xff
          g = (col >> 8) & 0xff
          b = col & 0xff
          r = r * (1 - alpha) + @r * alpha
          g = g * (1 - alpha) + @g * alpha
          b = b * (1 - alpha) + @b * alpha
          @pixels[y][pixel_x] = (r.round << 16) | (g.round << 8) | b.round
        end
      end
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
