N = 5
SENSIVITY = (N * N).times.map { _1 * 51 / (N * N) }.shuffle
def sixel(image, palette = nil)
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

def create_rgb_image(w, h, t)
  h.times.map do |i|
    w.times.map do |j|
      r = (Math.sqrt(i**2+j**2)*3-t).round%256
      g = (128+127*Math.sin(0.07*(Math.sqrt((i-w)**2+j**2)-t))).round
      b = (128+127*Math.sin(0.03*(Math.sqrt(i**2+(j-h)**2)-t))).round
      (r << 16) | (g << 8) | b
    end
  end
end

def create_grayscale_image(w, h, t)
  h.times.map do |i|
    w.times.map do |j|
      ((Math.sqrt(i**2+j**2)-t+Math.sin(0.1*(i-4*t))+Math.sin(0.1*(j-4*t)))).round % 100
    end
  end
end

$> << "\e[H\e[2J"
grayscale = [true, false].sample
(0..).each do |t|
  w = h = 180
  if grayscale
    color_palette = 100.times.map { (_1 * 255 / 100) * 0x010101 }
    image = create_grayscale_image(w, h, t)
    sixel_data = sixel(image, color_palette)
  else
    image = create_rgb_image(w, h, t)
    sixel_data = sixel(image)
  end
  $> << "\e[H#{sixel_data}\r\n\e[Ksixel_bytes = #{sixel_data.size}\n\e[K"
  sleep 0.01
end
