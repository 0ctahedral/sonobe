#define pi 3.14159265359
#define tau 6.28318530718

/// produce a random vec2 using fract magic
vec2 random2(vec2 p) {
    return fract(sin(vec2(dot(p,vec2(127.1,311.7)),dot(p,vec2(269.5,183.3))))*43758.5453);
}

/// produces the nearest point and distance to it using the voronoi algorithm
void voronoi(vec2 uv, float density, out float m_dist, out vec2 m_point) {
  // set a max distance first
  m_dist = 10;
  // scale the uv by density for tiling
  vec2 i_st = floor(uv * density);
  vec2 f_st = fract(uv * density);

  // loop over adjacent tiles
  for (int y= -1; y <= 1; y++) {
    for (int x= -1; x <= 1; x++) {
      // Neighbor place in the grid
      vec2 neighbor = vec2(float(x),float(y));
      // Random position from current + neighbor place in the grid
      vec2 point = random2(i_st + neighbor);
      // Vector between the pixel and the point
      vec2 diff = neighbor + point - f_st;
      // Distance to the point
      float dist = length(diff);
      if (dist < m_dist) {
        m_dist = dist;
        m_point = point;
      }
    }
  }
}

/// draws lines based on uv
/// useful for debugging grids and stuff
void draw_uv(vec2 uv, vec3 line_color, inout vec3 color) {
  vec2 i_st = floor(uv);
  vec2 f_st = fract(uv);
  color += line_color * (step(.98, f_st.x) + step(.98, f_st.y));
}

/// maps a value from range one to range 2
#define map(value, low1, high1, low2, high2) \
  low2 + (value - low1) * (high2 - low2) / (high1 - low1)
