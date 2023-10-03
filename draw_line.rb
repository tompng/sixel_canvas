require_relative './sixel'
image = [
  [0, 0, 0, 0, 0, 0, 0, 0],
  [0, 0, 0, 0, 0, 0, 0, 0],
  [0, 0, 0, 0, 0, 0, 0, 0],
  [0, 0, 0, 0, 0, 0, 0, 0],
  [0, 0, 0, 0, 0, 0, 0, 0],
  [0, 0, 0, 0, 0, 0, 0, 0],
  [0, 0, 0, 0, 0, 0, 0, 0],
  [0, 0, 0, 0, 0, 0, 0, 0]
]
# draw_line([2, 1], [4, 6])
image = [
  [0, 0, 0, 0, 0, 0, 0, 0],
  [0, 0, 0, 0, 0, 0, 0, 0],
  [0, 1, 1, 0, 0, 0, 0, 0],
  [0, 0, 0, 1, 1, 0, 0, 0],
  [0, 0, 0, 0, 0, 1, 1, 0],
  [0, 0, 0, 0, 0, 0, 0, 0],
  [0, 0, 0, 0, 0, 0, 0, 0],
  [0, 0, 0, 0, 0, 0, 0, 0]
]
color_table = [0x0000ff, 0xffff00]
puts Sixel.build(image, color_table)




require_relative 'canvas'
canvas = Canvas.new(256, 256, colors: Canvas.colors(:grayscale))

points = (1..7).map { [_1 * 256 / 8, rand(64)] }
canvas.new_path do |path|
  path.curve(points.map{[_1, _2]})
  path.stroke(color: 1, line_width: 1)
end

canvas.new_path do |path|
  path.curve(points.map{[_1, _2 + 64]})
  path.stroke(color: 1, line_width: 16)
end

canvas.new_path do |path|
  path.curve(points.map{[_1, _2 + 128, 8 + 6 * Math.cos(_1)]})
  path.stroke(color: 1)
end

puts canvas.to_sixel
