def sixel(image)
  header = "\ePq"
  footer = "\e\\"
  color_table = 101.times.map { "##{[_1, 2, _1, _1, _1] * ';'}" }.join
  h = image.size
  w = image.first.size
  sixel_lines = (h.fdiv(6).ceil).times.map { {} }
  h.times do |y|
    w.times do |x|
      color = image[y][x]
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

$> << "\e[H\e[2J"
(0..).each do |t|
  w = h = 240
  image = h.times.map{|i|
    w.times.map{|j|
      # Calculate color(grayscale, 0..100) for each pixel
      (Math.sqrt(i**2+j**2)-t+Math.sin(0.1*(i-4*t))+Math.sin(0.1*(j-4*t))).round % 101
    }
  }

  sixel_data = sixel(image)
  $> << "\e[H"+sixel_data+"\r\n\e[Ksixel_bytes = #{sixel_data.size}\n\e[K"
  sleep 0.01
end
