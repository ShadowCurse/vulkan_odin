{ pkgs ? import <nixpkgs> { } }:
pkgs.mkShell {
  buildInputs = with pkgs; [
    odin
    ols
    glfw
    pkg-config
  ];
}
