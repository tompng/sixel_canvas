require_relative 'sixel'

class Path
  attr_reader :dot_points, :paths
  def initialize(canvas, line_width)
    @current_path = []
    @dot_points = []
    @paths = [@current_path]
    @canvas = canvas
    @x = @y = nil
    @line_width = line_width.to_i
    yield self if block_given?
  end

  def dot(x, y, radius = @line_width / 2.0)
    @dot_points << [x, y, 2.0 * radius]
    self
  end

  def dots(points, radius = @line_width / 2.0)
    @dot_points.concat points.map { |x, y, r| [x, y, (r || radius) * 2.0] }
    self
  end

  def polygon(points, line_width = @line_width)
    return self if points.empty?

    x0, y0, w0 = points.first
    prev = [x0, y0, w0 || line_width]
    move_to(*prev)
    (1...points.size).each do |i|
      x, y, w = points[i]
      p = [x, y, w || line_width]
      @canvas._line_path prev, p, @current_path
      prev = p
    end
    @x, @y, @line_width = prev
    self
  end

  def line_to(x, y, line_width = @line_width)
    return self unless @x && @y

    @canvas._line_path [@x, @y, @line_width], [x, y, line_width], @current_path
    @x = x
    @y = y
    @line_width = line_width
    self
  end

  def bezier_curve_to((x1, y1, w1), (x2, y2, w2), (x3, y3, w3), line_width = @line_width)
    return self unless @x && @y

    @canvas._bezier_path [@x, @y, @line_width], [x1, y1, w1 || line_width], [x2, y2, w2 || line_width], [x3, y3, w3 || line_width], @current_path
    @x = x3
    @y = y3
    @line_width = w3 || line_width
    self
  end

  def stroke(line_width: nil, alpha: nil, color: nil)
    @canvas.stroke(self, **{ line_width:, alpha:, color: }.compact)
  end

  def fill(alpha: nil, color: nil)
    @canvas.fill(self, **{ alpha:, color: }.compact)
  end

  def move_to(x, y, line_width = @line_width)
    @line_width = line_width
    return self if @x == x && @y == y

    @x = x
    @y = y
    return self if @current_path.empty?

    @paths << @current_path = []
    self
  end

  def close
    return self if @current_path.empty?

    @paths << @current_path = []
    self
  end
end

class Canvas
  TERMINAL_CLEAR_SCREEN = "\e[H\e[2J"
  TERMINAL_CURSOR_RESET = "\e[H"

  attr_reader :width, :height, :pixels, :color
  def initialize(width, height, colors: nil, antialias: 3)
    @width = width
    @height = height
    @colors = colors
    @antialias = antialias.to_i.clamp 1, 8
    @antialias_area = @antialias**2
    @pixels = @height.times.map do
      [@colors ? 0.0 : 0] * @width
    end
  end

  def new_path(line_width: 1, &block)
    Path.new self, line_width, &block
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

  def default_color
    @colors ? 1 : 0xffffff
  end

  def deconstruct_color(color)
    if @colors
      [0, 0, 0, color.clamp(0, 1).to_f]
    else
      c = color.to_i
      r = (c >> 16) & 0xff
      g = (c >> 8) & 0xff
      b = c & 0xff
      [r, g, b, 0]
    end
  end

  def _bezier_path(pa, pb, pc, pd, points)
    ax, ay, aw = pa.map { _1 * @antialias }
    bx, by, bw = pb.map { _1 * @antialias }
    cx, cy, cw = pc.map { _1 * @antialias }
    dx, dy, dw = pd.map { _1 * @antialias }
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
    w0 = aw
    w1 = 3 * (bw - aw)
    w2 = 3 * (aw - 2 * bw + cw)
    w3 = -aw + 3 * bw - 3 * cw + dw
    (0..step).each do |i|
      t = i.fdiv step
      x = x0 + x1 * t + x2 * t**2 + x3 * t**3
      y = y0 + y1 * t + y2 * t**2 + y3 * t**3
      w = [w0 + w1 * t + w2 * t**2 + w3 * t**3, 1].max
      points << [x.round, y.round, w]
    end
  end

  def stroke_line(p1, p2, line_width: 1, alpha: 1, color: default_color)
    stroke(new_path(line_width:).move_to(*p1).line_to(*p2), alpha:, color:)
  end

  def stroke_bezier(a, b, c, d, line_width: 1, alpha: 1, color: default_color)
    stroke(new_path(line_width:).move_to(*a).bezier_curve_to(b, c, d), alpha:, color:)
  end


  def _line_path(p1, p2, points)
    x1, y1, w1 = p1.map { _1 * @antialias }
    x2, y2, w2 = p2.map { _1 * @antialias }
    step = [(x2 - x1).abs, (y2 - y1).abs, 1].max
    (0..step).each do |i|
      t = i.fdiv step
      x = (x1 + (x2 - x1) * t).round
      y = (y1 + (y2 - y1) * t).round
      w = [w1 + (w2 - w1) * t, 1].max
      points << [x, y, w]
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

  def fill(path, alpha: 1, color: default_color)
    alpha = alpha.clamp(0, 1).to_f
    color = deconstruct_color color
    row_xor_bounds_a = {}
    path.paths.each do |points|
      dedup_points = []
      points.each do |p|
        dedup_points << p if dedup_points.last != p
      end
      dedup_points.pop while !dedup_points.empty? && dedup_points.first == dedup_points.last
      next if dedup_points.empty?

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
      next if pixel_y < 0 || pixel_y >= @height
      _fill_antialias_bounds(pixel_y, antialias_x_bounds, color, alpha)
    end
  end

  def _fill_antialias_bounds(pixel_y, antialias_x_bounds, color, alpha)
    cr, cg, cb, cvalue = color
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
        a = alpha * count / @antialias_area
        pixels_row[x] = pixels_row[x] * (1 - a) + cvalue * a
      end
    else
      updates.each do |x, count|
        a = alpha * count / @antialias_area
        col = pixels_row[x]
        r = (col >> 16) & 0xff
        g = (col >> 8) & 0xff
        b = col & 0xff
        r = r * (1 - a) + cr * a
        g = g * (1 - a) + cg * a
        b = b * (1 - a) + cb * a
        pixels_row[x] = (r.round << 16) | (g.round << 8) | b.round
      end
    end
  end

  def stroke(path, line_width: nil, alpha: 1, color: default_color)
    alpha = alpha.clamp(0, 1).to_f
    color = deconstruct_color color
    row_bounds_a = {}

    add_bounds = -> points do
      points.each do |x, y, w|
        radius = (line_width || w) / 2.0
        ((y - radius).ceil..(y + radius)).each do |target_y|
          pixel_y = target_y / @antialias
          next if pixel_y < 0 || pixel_y >= @height
          x_bounds = (row_bounds_a[pixel_y] ||= [])[target_y % @antialias] ||= []
          dx2 = radius**2 - (target_y - y)**2
          next unless dx2 > 0
          dx = Math.sqrt(dx2).floor
          x_bounds << x - dx << x + dx + 0.5
        end
      end
    end
    add_bounds.call path.dot_points
    path.paths.each(&add_bounds)

    row_bounds_a.each do |pixel_y, antialias_x_bounds|
      compact_antialias_x_bounds = antialias_x_bounds.compact.map do |x_bounds|
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
      _fill_antialias_bounds(pixel_y, compact_antialias_x_bounds, color, alpha)
    end
  end

  def self.colors(type)
    themes = {
      grayscale: -> { (0..100).map { (_1 * 255 / 100) * 0x10101 } },
      red: [1, 2, 2],
      green: [2, 1, 2],
      blue: [2, 2, 1],
      cyan: [2, 1, 1],
      magenta: [1, 2, 1],
      yellow: [1, 1, 2]
    }
    theme = themes[type]
    raise ArgumentError, "Unknown theme #{type}. Should be one of #{themes.keys}" unless theme
    return theme.call if theme.is_a? Proc
    r_ex, g_ex, b_ex = theme
    colors = 256.times.map do
      t = _1.fdiv 255
      r = ((t ** r_ex) * 255).round
      g = ((t ** g_ex) * 255).round
      b = ((t ** b_ex) * 255).round
      (r << 16) | (g << 8) | b
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
