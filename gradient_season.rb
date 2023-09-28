require_relative 'sixel'

clear_screen = "\e[H\e[2J"
reset_cursor = "\e[H"

$stdout.write clear_screen
width = 160
height = 120
image = height.times.map do |y|
  width.times.map do |x|
    ((x.fdiv(width) + y.fdiv(height) * 0.5) / 1.5 * 255).round
  end
end

colors = [
  [[0.8, 0.8, 1], [1, 1, 1]],
  [[0.7, 0.7, 1], [1, 0.5, 0.5]],
  [[0.6, 0.6, 1], [0.5, 1, 0.5]],
  [[0.5, 0.5, 1], [0, 1, 0]],
  [[0.8, 0.8, 1], [1, 1, 0]],
  [[1, 0, 0], [1, 1, 0]],
  [[1, 0.8, 0.8], [1, 1, 1]]
]

def mix(rgb1, rgb2, t)
  rgb1.zip(rgb2).map { |c1, c2| c1 * (1 - t) + c2 * t }
end

(0..).each do |i|
  phase = (i / 20.0) % colors.size
  (a1, a2), (b1, b2) = colors[phase.floor], colors[phase.ceil % colors.size]
  t = phase % 1
  t = t * t * (3 - 2 * t)
  c1 = mix(a1, b1, t)
  c2 = mix(a2, b2, t)
  palette = 255.times.map do |j|
    r, g, b = mix(c1, c2, j / 255.0).map { (_1 * 255).round }
    (r << 16) | (g << 8) | b
  end
  puts reset_cursor + Sixel.build(image, palette)
  sleep 0.1
end
