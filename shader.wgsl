var<private> positions: array<vec2<f32>, 3> = array<vec2<f32>, 3>(
    vec2<f32>(0.0, -0.5), 
    vec2<f32>(0.5, 0.5), 
    vec2<f32>(-0.5, 0.5)
);

var<private> colors: array<vec3<f32>, 3> = array<vec3<f32>, 3>(
    vec3<f32>(1.0, 0.0, 0.0), 
    vec3<f32>(0.0, 1.0, 0.0), 
    vec3<f32>(0.0, 0.0, 1.0), 
);

struct VertexOutput {
  @builtin(position) clip_position: vec4<f32>,
  @location(0) color: vec3<f32>,
}

@vertex 
fn vs_main(@builtin(vertex_index) index: u32) -> VertexOutput {
  var out: VertexOutput;
  out.clip_position = vec4(positions[index], 0.0, 1.0);
  out.color = colors[index];
  return out;
}

@fragment 
fn fs_main(vertex: VertexOutput) -> @location(0) vec4<f32> {
  return vec4(vertex.color, 1.0);
}
