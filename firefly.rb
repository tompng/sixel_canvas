require_relative 'canvas'
size = 256
canvas = Canvas.new(size, size, colors: Canvas.colors(:green))

puts Canvas::TERMINAL_CLEAR_SCREEN
params = 8.times.map { 100.times.map { 2 * Math::PI * rand } }
loop do
  t = Time.now.to_f / 2.0
  canvas.clear 0, alpha: 0.2

  srand 2
  10.times do
    x = rand * size
    y = size - rand ** 2 * size / 3
    canvas.new_path do |path|
      path.curve(12.times.map { [x + rand * 64 - 32, y + rand * 64 - 32] })
      path.fill(color: 1, alpha: 0.05 + rand * 0.05)
    end
  end

  params.each do |p|
    point = -> u {
      v = t*0.4 - u
      i=-1
      x, y, z = 3.times.map do |axis|
        20.times.sum do |j|
          a = axis == 1 ? 0.5 : 1
          k = 1 + j * 0.5
          Math.sin(k * v * a + p[i += 1]) / k / 4
        end
      end
      w = 4 + z
      [
        size / 2 + 3 * size * x / w,
        size / 2 + 3 * size * y / w,
        w
      ]
    }
    th = t * 2 + p[0] * 0.4
    col = (Math.sin(th) - Math.sin(2 * th) / 4 + 1.3) / 1.3
    points = (0..10).map do |i|
      u = i / 10.0
      x, y, w = point.call u / 2.0
      [x, y, 16 * (1 - u) / w]
    end
    canvas.new_path do |path|
      path.curve points
      path.stroke(alpha: 0.1 + 0.1 * col, color: 1)
    end
    canvas.new_path do |path|
      x, y, w = point.call 0
      path.dot(x, y, col * 16 / w)
      path.stroke(color: 1, alpha: col)
    end
  end
  puts Canvas::TERMINAL_CURSOR_RESET + canvas.to_sixel
end
