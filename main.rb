require_relative 'canvas'

use_rgb = rand < 0.5
# use_rgb: color = 0xRRGGBB
# indexed: color = 0.0..1.0 with color table

canvas = Canvas.new(256, 256, colors: use_rgb ? nil : Canvas.colors(:blue))

puts Canvas::TERMINAL_CLEAR_SCREEN
loop do
  canvas.clear 0, alpha: 0.2
  color1 = use_rgb ? rand(0xffffff) : 1.0
  color2 = use_rgb ? rand(0xffffff) : 0.8

  canvas.stroke_line [rand(256), rand(256)], [rand(256), rand(256)], line_width: 16, color: color1, alpha: 0.1
  canvas.new_path line_width: 4 do |path|
    path.move_to rand(256), rand(256), 10
    path.bezier_curve_to [rand(256), rand(256), 7], [rand(256), rand(256), 4], [rand(256), rand(256), 1]
    path.stroke(alpha: 1, color: color2)
  end

  path = canvas.new_path
  path.move_to rand(256), rand(256)
  4.times do
    path.bezier_curve_to(*3.times.map { [rand(256), rand(256)] })
  end
  canvas.fill(path, alpha: 0.1, color: color2)
  puts Canvas::TERMINAL_CURSOR_RESET + canvas.to_sixel
end
