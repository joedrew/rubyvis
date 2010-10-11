module Rubyvis
  module SvgScene
    def self.line(scenes)
      e=scenes._g.elements[1]
      return e if (scenes.size < 2)
      s = scenes[0]
      # segmented */
      return self.line_segment(scenes) if (s.segmented)

      #/* visible */
      return e if (!s.visible)
      fill = s.fill_style
      stroke = s.stroke_style

      return e if (fill.opacity==0.0 and  stroke.opacity==0.0)
      #/* points */

      d = "M" + s.left.to_s + "," + s.top.to_s

      if (scenes.size > 2 and (s.interpolate == "basis" or s.interpolate == "cardinal" or s.interpolate == "monotone"))
        case (s.interpolate)
        when "basis"
          d = d+ curve_basis(scenes)
        when "cardinal"
          d = d+curve_cardinal(scenes, s.tension)
        when "monotone"
          d = d+curve_monotone(scenes)
        end

      else
        (1...scenes.size).each {|i|
          d+= path_segment(scenes[i-1],scenes[i])
        }
      end

      e = SvgScene.expect(e, "path", {
        "shape-rendering"=> s.antialias ? nil : "crispEdges",
        "pointer-events"=> s.events,
        "cursor"=> s.cursor,
        "d"=> d,
        "fill"=> fill.color,
        "fill-opacity"=> (fill.opacity==0.0) ? nil : fill.opacity,
        "stroke"=> stroke.color,
        "stroke-opacity"=> (stroke.opacity==0.0) ? nil : stroke.opacity,
        "stroke-width"=> (stroke.opacity>0) ? s.line_width / self.scale : nil,
        "stroke-linejoin"=> s.line_join
      });
      return SvgScene.append(e, scenes, 0);
    end

    def self.line_segment(scenes)

      e=scenes._g.elements[1]

      s = scenes[0];
      paths=nil
      case s.interpolate
      when "basis"
        paths = curve_basis_segments(scenes)
      when "cardinal"
        paths=curve_cardinal_segments(scenes, s.tension)
      when "monotone"
        paths = curve_monotone_segments(scenes)
      end

      (scenes.length-1).times {|i|

        s1 = scenes[i]
        s2 = scenes[i + 1];

        #/* visible */
        next if (!s1.visible and !s2.visible)

        stroke = s1.stroke_style
        fill = pv.Color.transparent

        next if stroke.opacity==0.0

        #/* interpolate */
        d=nil
        if ((s1.interpolate == "linear") and (s1.lineJoin == "miter"))
          fill = stroke;
          stroke = pv.Color.transparent;
          d = path_join(scenes[i - 1], s1, s2, scenes[i + 2]);
        elsif(paths)
          d = paths[i];
        else
          d = "M" + s1.left + "," + s1.top + path_segment(s1, s2);
        end

        e = SvgScene.expect(e, "path", {
          "shape-rendering"=> s1.antialias ? nil : "crispEdges",
          "pointer-events"=> s1.events,
          "cursor"=> s1.cursor,
          "d"=> d,
          "fill"=> fill.color,
          "fill-opacity"=> (fill.opacity==0.0) ? nil : fill.opacity,
          "stroke"=> stroke.color,
          "stroke-opacity"=> (stroke.opacity==0.0) ? nil : stroke.opacity,
          "stroke-width"=> stroke.opacity>0 ? s1.line_width / self.scale : nil,
          "stroke-linejoin"=> s1.line_join
        });
        e = SvgScene.append(e, scenes, i);
      }
      return e
    end

    #/** @private Returns the path segment for the specified points. */

    def self.path_segment(s1, s2)
      l = 1; # sweep-flag
      case (s1.interpolate)
      when "polar-reverse"
        l = 0;
      when "polar"
        dx = s2.left - s1.left,
        dy = s2.top - s1.top
        e = 1 - s1.eccentricity
        r = Math.sqrt(dx * dx + dy * dy) / (2 * e)
        if !((e<=0) and (e>1))
          return "A#{r},#{r} 0 0,#{l} #{s2.left},#{s2.top}"
        end
      when "step-before"
        return "V#{s2.top}H#{s2.left}"
      when "step-after"
        return "H#{s2.left}V#{s2.top}"
      end
      return "L#{s2.left},#{s2.top}"
    end

    #/** @private Line-line intersection, per Akenine-Moller 16.16.1. */
    def self.line_intersect(o1, d1, o2, d2)
      return o1.plus(d1.times(o2.minus(o1).dot(d2.perp()) / d1.dot(d2.perp())));
    end

    #/** @private Returns the miter join path for the specified points. */
    def self.path_join(s0, s1, s2, s3)
      #
      # P1-P2 is the current line segment. V is a vector that is perpendicular to
      # the line segment, and has length lineWidth / 2. ABCD forms the initial
      # bounding box of the line segment (i.e., the line segment if we were to do
      # no joins).
      #

      p1 = pv.vector(s1.left, s1.top)

      p2 = pv.vector(s2.left, s2.top)

      p = p2.minus(p1)

      v = p.perp().norm()

      w = v.times(s1.lineWidth / (2 * this.scale))

      a = p1.plus(w)
      b = p2.plus(w)
      c = p2.minus(w)
      d = p1.minus(w)

      #/*
      # * Start join. P0 is the previous line segment's start point. We define the
      # * cutting plane as the average of the vector perpendicular to P0-P1, and
      # * the vector perpendicular to P1-P2. This insures that the cross-section of
      # * the line on the cutting plane is equal if the line-width is unchanged.
      # * Note that we don't implement miter limits, so these can get wild.
      # */
      if (s0 and s0.visible)
        v1 = p1.minus(s0.left, s0.top).perp().norm().plus(v);
        d = line_intersect(p1, v1, d, p);
        a = line_intersect(p1, v1, a, p);
      end

      #/* Similarly, for end join. */
      if (s3 && s3.visible)
        v2 = pv.vector(s3.left, s3.top).minus(p2).perp().norm().plus(v);
        c = line_intersect(p2, v2, c, p);
        b = line_intersect(p2, v2, b, p);
      end

      return "M" + a.x + "," + a.y+ "L" + b.x + "," + b.y+ " " + c.x + "," + c.y+ " " + d.x + "," + d.y
    end
  end
end
