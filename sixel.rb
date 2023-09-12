module Sixel
  N = 4
  SENSIVITY = (N * N).times.map { _1 * 51 / (N * N) }.shuffle
  def self.build(image, palette = nil)
    header = "\ePq"
    footer = "\e\\"
    if palette
      color_table = palette.map.with_index do |color, idx|
        r, g, b = 3.times.map { ((color >> (16 - 8 * _1) & 0xff) * 100 / 255.0).round }
        "##{idx};2;#{r};#{g};#{b}"
      end
    else
      color_table = (6**3).times.map { "##{[_1, 2, _1/6/6*20, _1/6%6*20, _1%6*20] * ';'}" }.join
    end
    h = image.size
    w = image.first.size
    sixel_lines = (h.fdiv(6).ceil).times.map { {} }
    h.times do |y|
      w.times do |x|
        color = image[y][x]
        unless palette
          sensivity = SENSIVITY[x % N * N + y % N]
          r, g, b = 3.times.map do |k|
            v = color >> (16 - 8 * k) & 0xff
            (v + sensivity) / 51
          end
          color = r * 36 + g * 6 + b
        end
        (sixel_lines[y / 6][color] ||= Hash.new(0))[x] |= 1 << (y % 6)
      end
    end
    output = [header, color_table]
    sixel_lines.each do |line|
      linedata = []
      line.each do |color, bitmasks|
        linedata << '$' unless linedata.empty?
        linedata << "##{color}"
        prev_x = -1
        bitmasks.sort_by{_1}.each do |x, bitmask|
          linedata << (prev_x + 2 == x ? '?' : "!#{x - prev_x - 1}?") if prev_x + 1 < x
          linedata << (63 + bitmask).chr
          prev_x = x
        end
      end
      output << linedata << '-'
    end
    [output, footer].join
  end
end