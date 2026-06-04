.pragma library

var fontFamily = "GohuFont 11 Nerd Font";
var bg = "#1a1110";
var fg = "#f1dfdb";
var surface = "#271d1c";
var primary = "#ffb4a7";
var muted = "#66f1dfdb";
var error = "#f38ba8";
var warning = "#f9e2af";

var home = "";
var helperDir = "";

function bin(name) {
  if (helperDir === "")
    helperDir = "/home/jllyn/.config/quickshell/helpers";
  return helperDir + "/" + name;
}

function config(path) {
  if (home === "")
    home = "/home/jllyn";
  return home + "/.config/" + path;
}
