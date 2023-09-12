require_relative 'sixel'
require_relative 'canvas'

canvas = Canvas.new 400, 400
canvas.line_width = 10
canvas.draw_line [140, 100], [310, 130]
canvas.draw_line [210, 360], [150, 240]
canvas.draw_line [300, 200], [130, 320]
color_palette = 100.times.map { (_1 * 255 / 100) * 0x010101 }
puts Sixel.build canvas.to_int_pixel(100 - 1), color_palette
exit

if ARGV[0]
  require 'chunky_png'
  image = ChunkyPNG::Image.from_file(ARGV[0])
  sixel_data = Sixel.build(image.pixels.map{_1>>8}.each_slice(image.width).to_a)
  puts sixel_data
  exit
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
    sixel_data = Sixel.build(image, color_palette)
  else
    image = create_rgb_image(w, h, t)
    sixel_data = Sixel.build(image)
  end
  $> << "\e[H#{sixel_data}\r\n\e[Ksixel_bytes = #{sixel_data.size}\n\e[K"
  sleep 0.01
end
