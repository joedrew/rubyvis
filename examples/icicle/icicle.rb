# = Icicle
# An icicle is simply a sunburst transformed from polar to cartesian coordinates. Here we show the various files on Rubyvis package; the color of each cell corresponds to the package, while the area encodes the size of the source code in bytes 

$:.unshift(File.dirname(__FILE__)+"/../../lib")
require 'rubyvis'

def get_files(path)
  h={}
  Dir.glob("#{path}/*").each {|e|
    next if File.expand_path(e)=~/pkg|web|vendor|~/
    pa=File.expand_path(e) 
    if File.stat(pa).directory?
      h[File.basename(pa)]=get_files(pa)
    else
      h[File.basename(pa)]=File.stat(pa).size
    end
  }
  h
end

$flare=get_files(File.dirname(__FILE__)+"/../../")



#load(File.dirname(__FILE__)+"/icicle_data.rb")

colors=Rubyvis::Colors.category19
vis = Rubyvis::Panel.new.
  width(600).
  height(500).
  bottom(30)
#$flare={:a=>{:b=>1,:c=>2}}

layout = vis.add(Rubyvis::Layout::Partition::Fill).
  nodes(Rubyvis.dom($flare).root("rubyvis").nodes)
layout.order("descending")
layout.orient("top")
layout.size(lambda {|d| d.node_value})

layout.node.add(pv.Bar).
  fill_style(lambda {|d| colors.scale(d.parent_node)}).
  stroke_style("rgba(255,255,255,.5)").
  line_width(1).
  antialias(false)

layout.node_label.add(pv.Label)
    .text_angle(-Math::PI / 2.0)
    .visible(lambda {|d| d.dx >6 })
vis.render()

puts vis.to_svg
