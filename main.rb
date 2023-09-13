require_relative 'canvas'

use_rgb = rand < 0.5
# use_rgb: color = 0xRRGGBB
# indexed: color = 0.0..1.0 with color table
unless use_rgb
  colors = 256.times.map do |i|
    t = i.fdiv 255
    r, g, b = [t**3, t**2, t].map { (_1 * 255).round }
    (r << 16) | (g << 8) | b
  end
end
canvas = Canvas.new(240, 240, colors:)

puts Canvas::TERMINAL_CLEAR_SCREEN
loop do
  canvas.clear 0, alpha: 0.1
  canvas.alpha = 1
  canvas.color = use_rgb ? rand(0xffffff) : 1.0
  canvas.line_width = 4
  canvas.line [rand(200), rand(200)], [rand(200), rand(200)]
  canvas.line_width = 16
  canvas.color = canvas.color = use_rgb ? rand(0xffffff) : 0.8
  canvas.line [rand(200), rand(200)], [rand(200), rand(200)]
  canvas.alpha = 0.8
  canvas.line [rand(200), rand(200)], [rand(200), rand(200)]
  canvas.bezier [rand(180), rand(180)], [100, rand(180)], [rand(180), 40], [160 + rand(200), 160 + rand(200)]
  path = []
  canvas._bezier_path([30, 30], [100, 280], [120, -40], [60, 220], path)
  canvas._fill(path)
  puts Canvas::TERMINAL_CURSOR_RESET + canvas.to_sixel
end
