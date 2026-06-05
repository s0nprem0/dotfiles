.pragma library

var fontFamily = "GohuFont 11 Nerd Font";
var bg = "#1a1110";
var fg = "#f1dfdb";
var surface = "#271d1c";
var surfaceLighter = "#3D2826";
var primary = "#ffb4a7";
var muted = "#66f1dfdb";
var error = "#f38ba8";
var warning = "#f9e2af";
var green = "#A6DA95";
var blue = "#8AADF4";

var home = "";
var helperDir = "";

function bin(name) {
  return helperDir + "/" + name;
}

function config(path) {
  return home + "/.config/" + path;
}
