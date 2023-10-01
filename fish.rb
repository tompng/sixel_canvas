require_relative 'sixel'
include Math
def fish(x,y,t)
  [
    y*y-((1.5+x)/16*((1-x)**3+1/16.0+(2+cos(t)**2)/(1+exp(-32*y*cos(t)))/(1+exp(6-8*x))))**2*(1-x*x),h(x,y,t)
  ].min
end
$a = 0
$wtime = 0
def update(d)
  amax = 64*PI
  wmax = 16
  $a = ($a + amax * d / 3) % amax
  $wtime = ($wtime + wmax * d) % wmax
end

def wfin(x,t) = (1.5+x)*sin(4*x-4+(x-1)**2/2-t)/16
def wgrad(x,t) = (wfin(x+0.001,t)-wfin(x-0.001,t))/0.002
def h(x,y,t) = [g(x,y,0.5+(sin(t)+cos(t))/8,-1.0),g(x,y,-0.5-(sin(t)+cos(t))/8,+1.0)].min
def g(x,y,b,c) = (6*((x+0.5)*cos(b)+(y+c/8)*sin(b))-1)**2+(32*((y+c/8)*cos(b)-(x+0.5)*sin(b)))**2-1

def fish_swimming(x,y,t) = fish(x+y*wgrad(x,t),y-wfin(x,t),t)
def fish_left(x,y,d,s) = fish_swimming_rot(
  (x-d)%PI-PI/2+1.5**2*sin(2*(d+I(x,d)+s))/8,
  y-1.5*sin(d+I(x,d)+s)+3*sin((3+s)*I(x,d)),
  $a-I(x,d),
  atan2(1.5*cos(d+I(x,d)+s),1-1.5**2*cos(2*(d+I(x,d)+s))/8)
)
def fish_swimming_rot(x,y,ts,tr) = fish_swimming(x*cos(tr)+y*sin(tr),y*cos(tr)-x*sin(tr),ts)
def fishes(x,y) = fish_left(x,y,-$a/16,5.0)
def I(x,d) = ((x-d)/PI).floor%4

def wave1d(x,t) = (sin(4*x-2*t)/(1+(x-t-1)**2)-sin(4*x+2*t)/(1+(x+t+1)**2))/sqrt(1+x*x)*($wtime%8)*(1-t/8)**2*4
def wave(x,y,t) = wave1d(hypot(x,y),t)+sin(5*y-2*PI*t)/16
def wavex(x,y,t) = (wave(x+0.001,y,t) - wave(x-0.001,y,t)) / 0.002
def wavey(x,y,t) = (wave(x,y+0.001,t) - wave(x,y-0.001,t)) / 0.002
def poi_outer_base(x,y) = [
  (x*x+y*y-1.6)*(x*x+y*y-2),
  y*y+[2**0.5-x,0,x-3].max**2-0.01,
  ((x-3.2)**2+y*y-0.04)*((x-3.2)**2+y*y-0.01)
].min
def poi_inner(x,y) = x*x+y*y-1.6

def theta_poi = sin($a/16.0)/8
def poi_outer(x,y)
  c = cos(theta_poi)
  s = sin(theta_poi)
  poi_outer_base(x*c+y*s,y*c-x*s)
end
def x_poi = 2**0.5-2*sin(2*PI*$wtime/16)
def y_poi = sin(4*PI*$wtime/16)/4

def fill_fish(x,y) = fishes(x+wavex(x,y,$wtime%8)/8,y+wavey(x,y,$wtime%8)/8)<0
def fill_wave(x,y) = wavex(x,y,$wtime%8)+wavey(x,y,$wtime%8)/2>2
def poi_z(x,y) = x+y/8-wave(x,y,$wtime%8)/4
def fill_poi_inner(x,y) = poi_inner(x-x_poi,y-y_poi)<0
def fill_poi_outer(x,y) = poi_outer(x-x_poi,y-y_poi)<0
def poi_under_dx(x,y) = -wavex(x,y,$wtime%8)*poi_z(x,y)/12
def poi_under_dy(x,y) = -wavey(x,y,$wtime%8)*poi_z(x,y)/12

colors = [
  [255,0,0,1],
  [50,50,50,0.4],
  [50,50,50,1],
  [100,100,100,0.25],
  [100,100,100,0.4],
  [100,100,100,1],
]
color_table = 64.times.map do |i|
  c = colors.size.times.select { (i >> _1) & 1 == 1}.map { colors[_1] }
  r,g,b=c.reduce([0,0,0]){|rgb,(*rgb2,a)|
    rgb.zip(rgb2).map{_1*(1-a)+_2*a}
  }
  (r.to_i << 16 | g.to_i << 8 | b.to_i)
end
size = 128
$><< "\e[H\e[2J"
loop do
  image = size.times.map do |iy|
    row = size.times.map do |ix|
      x = 8.0*ix/size-4
      y = 4-8.0*iy/size
      color = 0
      color |= 1 if fill_fish(x,y)
      color |= 8 if fill_wave(x,y)
      if poi_z(x,y)>0
        if fill_poi_inner(x,y)
          color |= 16
        elsif fill_poi_outer(x,y)
          color = 32
        end
      else
        dx = poi_under_dx(x,y)
        dy = poi_under_dy(x,y)
        if fill_poi_inner(x+dx,y+dy)
          color |= 2
        elsif fill_poi_outer(x+dx,y+dy)
          color |= 4
        end
      end
      color
    end
  end
  update(0.01)
  puts "\e[H" + Sixel.build(image, color_table)
end
