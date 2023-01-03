{
  customer = (import ../customers.example.nix).mustermann;
  project = "Allerlei";
  statements = [
    { rate = 19.99; units = 2; name = "Lektorat (Stunde)"; }
    { rate = 45; units = 5; name = "Scheibenwischen (Scheibe)"; }
    { rate = 3.95; units = 12; name = "Tasse Kaffee"; }
  ];
}
