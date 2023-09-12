require_relative 'sixel'
require_relative 'canvas'

canvas = Canvas.new 400, 400
color_palette = 100.times.map do |i|
  t = i.fdiv 100 - 1
  r, g, b = [t**3, t**2, t].map { (_1 * 255).round }
  (r << 16) | (g << 8) | b
end
puts "\e[H\e[2J"
loop do
  canvas.clear 0
  canvas.alpha = 0.5
  canvas.color = 1
  canvas.line_width = 4
  canvas.line [rand(100), 100], [30, 130]
  canvas.line_width = 8
  canvas.line [110, 160], [150, 40]
  canvas.line [30, 20], [130, 120]
  canvas.bezier [30, rand(180)], [100, rand(180)], [rand(180), 40], [160, 160]
  puts "\e[H" + Sixel.build(canvas.to_int_pixel(color_palette.size - 1), color_palette)
end
