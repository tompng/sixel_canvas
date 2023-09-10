=begin
<ESC>Pq
#0;2;0;0;0#1;2;100;100;0#2;2;0;100;0
#1~@v@#2~@~$
#2?}G}#1?}?-
#0;2;0;0;0#1;2;50;60;40#2;2;80;30;70
#1!7@
<ESC>\
=end

def sixel
  header = "\ePq"
  footer = "\e\\"
  color_table = 101.times.map{"##{[_1,2,_1,_1,_1]*';'}"}.join
  w = 60
  h = 60
  image = h.times.map{|i|
    w.times.map{|j|
      (Math.sqrt(i**2+j**2)).round % 101
    }
  }
  sixel_lines = (h.fdiv(6).ceil).times.map { {} }
  h.times do |y|
    w.times do |x|
      color = image[y][x]
      (sixel_lines[y / 6][color] ||= Hash.new(0))[x] |= 1 << (y % 6)
    end
  end
  output = [header, color_table]
  sixel_lines.each do |line|
    (0..100).each do |color|
      bitslist = line[color]
      next unless bitslist
      output << "###{color}"
      w.times do |x|
        output << (63+bitslist[x]).chr
      end
      output << '$'
    end
    output << '-'
  end
  puts [output, footer].join
  data = 10.times.map{
    "###{rand 101}#{60.times.map{(63+rand(64)).chr}}-"
  }
  puts [header,color_table,data, footer].join
end

sixel