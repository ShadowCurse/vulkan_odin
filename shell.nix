{ pkgs ? import <nixpkgs> { } }:
pkgs.mkShell {
  LD_LIBRARY_PATH="${pkgs.glfw}/lib:${pkgs.vulkan-loader}/lib:${pkgs.vulkan-validation-layers}/lib";
  VULKAN_SDK = "${pkgs.vulkan-headers}";
  VK_LAYER_PATH = "${pkgs.vulkan-validation-layers}/share/vulkan/explicit_layer.d";

  buildInputs = with pkgs; [
    odin
    ols
    glfw
    vulkan-tools
    vulkan-loader
    vulkan-headers
    vulkan-validation-layers
    pkg-config
    shaderc
  ];
}
