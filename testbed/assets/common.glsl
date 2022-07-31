#define pi 3.14159265359
#define tau 6.28318530718

vec2 random2( vec2 p ) {
    return fract(sin(vec2(dot(p,vec2(127.1,311.7)),dot(p,vec2(269.5,183.3))))*43758.5453);
}

vec2 unity_voronoi_noise_randomVector (vec2 UV, float off)
{
    mat2 m = mat2(15.27, 47.63, 99.41, 89.98);
    UV = fract(sin(UV* m) * 46839.32);
    return vec2(sin(UV.y*+off)*0.5+0.5, cos(UV.x*off)*0.5+0.5);
}

void Unity_Voronoi_float(vec2 UV, float AngleOffset, float CellDensity, out float Out, out float Cells)
{
    vec2 g = floor(UV * CellDensity);
    vec2 f = fract(UV * CellDensity);
    float t = 8.0;
    vec3 res = vec3(8.0, 0.0, 0.0);

    for(int y=-1; y<=1; y++)
    {
        for(int x=-1; x<=1; x++)
        {
            vec2 lattice = vec2(x,y);
            vec2 off = unity_voronoi_noise_randomVector(lattice + g, AngleOffset);
            float d = distance(lattice + off, f);
            if(d < res.x)
            {
                res = vec3(d, off.x, off.y);
                Out = res.x;
                Cells = res.y;
            }
        }
    }
}

void voronoi(vec2 uv, float density, out float m_dist, out vec2 m_point) {
  m_dist = 10;
  vec2 i_st = floor(uv * density);
  vec2 f_st = fract(uv * density);
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

void draw_uv(vec2 uv, vec3 line_color, inout vec3 color) {
  vec2 i_st = floor(uv);
  vec2 f_st = fract(uv);
  color += line_color * (step(.98, f_st.x) + step(.98, f_st.y));
}

// #define saturate()
