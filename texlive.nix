# Generated with texnix 1.0.0
{ texlive, extraTexPackages ? {} }:
texlive.combine ({
  inherit (texlive) scheme-small;
  "amsmath" = texlive."amsmath";
  "babel" = texlive."babel";
  "bitset" = texlive."bitset";
  "booktabs" = texlive."booktabs";
  "ctablestack" = texlive."ctablestack";
  "etoolbox" = texlive."etoolbox";
  "fontaxes" = texlive."fontaxes";
  "fontspec" = texlive."fontspec";
  "geometry" = texlive."geometry";
  "graphics" = texlive."graphics";
  "hopatch" = texlive."hopatch";
  "hycolor" = texlive."hycolor";
  "hypdoc" = texlive."hypdoc";
  "hyperref" = texlive."hyperref";
  "iftex" = texlive."iftex";
  "libertine" = texlive."libertine";
  "libertinust1math" = texlive."libertinust1math";
  "luaotfload" = texlive."luaotfload";
  "luatexbase" = texlive."luatexbase";
  "minitoc" = texlive."minitoc";
  "mweights" = texlive."mweights";
  "ntheorem" = texlive."ntheorem";
  "tipa" = texlive."tipa";
  "url" = texlive."url";
  "xkeyval" = texlive."xkeyval";
  "xunicode" = texlive."xunicode";
  latexmk = texlive.latexmk;
} // extraTexPackages)
