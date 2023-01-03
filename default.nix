{
  pkgs ? import <nixpkgs> {},
  lib ? import <nixpkgs/lib>,
  invoicesDirectory ? ./invoices,
  defaultAccount ? import ./account.example.nix,
  defaultText ? ''
      vielen Dank für Ihren Auftrag!
      Ich habe gerne für Sie gearbeitet.
      Für meine Tätigkeit stelle ich die folgende Summe in Rechnung.
      Wenn Sie mit unserer Zusammenarbeit zufrieden waren, empfehlen Sie mich gerne weiter.
  '',
  defaultSalutation ? "Sehr geehrte Damen und Herren,",
  defaultClosing ? "Mit freundlichen Grüßen"
}:
let
  renderCompanyAndName = { name ? null, company ? null, ... }: builtins.concatStringsSep ''\\'' (builtins.filter (x: x != null) [ name company ]);
  renderAddress = { street, zip, city }: ''${street}\\ ${toString zip}\ ${city}'';
  renderBank = { bank, iban, bic }: builtins.concatStringsSep ''\\ '' [ bank iban bic ];

  sum = builtins.foldl' builtins.add 0;

  dateFromInvoiceNumber = number: let
    day = builtins.substring 6 2 number;
    month = builtins.substring 4 2 number;
    year = builtins.substring 0 4 number;
    month-german = {
      "01" = "Januar";
      "02" = "Februar";
      "03" = "März";
      "04" = "April";
      "05" = "Mai";
      "06" = "Juni";
      "07" = "Juli";
      "08" = "August";
      "09" = "September";
      "10" = "Oktober";
      "11" = "November";
      "12" = "Dezember";
    }.${month};
  in "${lib.removePrefix "0" day}. ${month-german} ${year}";

  formatNumber = n: let
    components = builtins.split ''\.'' (toString n);
    integral = builtins.elemAt components 0;
    rational = if builtins.length components == 3 then builtins.elemAt components 2 else "00";
  in "${integral},${builtins.substring 0 2 (rational + "00")}";

  invoiceLatex = number: {
    customer,
    date ? dateFromInvoiceNumber number,
    text ? defaultText,
    statements,
    project ? "",
    account ? defaultAccount,
    salutation ? defaultSalutation,
    closing ? defaultClosing,
  }: pkgs.writeText "invoice-${number}.tex" ''
    \documentclass[a4paper]{scrlttr2}
    \usepackage[top=2cm, bottom=1cm, left=2cm, right=2cm]{geometry}
    \usepackage{graphicx}
    \usepackage{libertine,libertinust1math}
    \usepackage[utf8]{inputenc}
    \usepackage[T1]{fontenc}
    \usepackage[ngerman]{babel}
    \usepackage{color}
    \usepackage[hidelinks]{hyperref}

    \usepackage{tabularx,booktabs}

    \setkomavar{fromname}{${account.name}}
    \setkomavar{fromaddress}{${renderAddress account.address}}
    \setkomavar{place}{${account.address.city}}
    \setkomavar{date}{${date}}
    \setkomavar{subject}{Rechnung${lib.optionalString (project != null) ": ${project}"}}
    \setkomavar{invoice}{${number}}
    \setkomavar{frombank}{${renderBank account.account}}

    \setkomavar{firsthead}{%
      \parbox{\linewidth}{\flushright
        \sffamily
        \usekomavar{fromname}\\
        \usekomavar{fromaddress}\\[\baselineskip]
        \footnotesize
        \textbf{\usekomavar*{frombank}}\\
        \usekomavar{frombank}\\[\baselineskip]
        \textbf{Steuernummer}\\
        ${account.taxId}
      }
    }

    \begin{document}
      \begin{letter}{${renderCompanyAndName customer}\\ ${renderAddress customer.address}}
        \opening{${salutation}}
        ${text}
        \begin{center}\sffamily
          \begin{tabularx}{\textwidth}{Xrrr}
            \textbf{Leistung} & \textbf{Rate} & \textbf{Anzahl} & \textbf{Gesamt}\\
              ${toString (builtins.map ({name, rate, units}: ''
                ${name} & ${formatNumber rate} € & ${formatNumber units} & ${formatNumber (units * rate)} €\\
              '') statements)}
            \midrule
            & & \textbf{Summe} & ${formatNumber (sum (builtins.map ({rate, units, ...}: rate * units) statements))} €\\
          \end{tabularx}
        \end{center}
        \ps Gemäß § 19 Abs. 1 UStG wird keine Umsatzsteuer berechnet.
        \closing{${closing}}
      \end{letter}
    \end{document}
  '';

  buildInvoice = number: invoice: let texlive = import ./texlive.nix { texlive = pkgs.texlive; }; in pkgs.runCommand "invoice-${number}.pdf" {} ''
    set -eu
    PATH=$PATH:${lib.makeBinPath [texlive]}
    ${texlive}/bin/pdflatex -interaction=nonstopmode ${invoiceLatex number invoice}
    mv *.pdf $out
  '';

  invoices = lib.mapAttrs' (file: _: let number = lib.removeSuffix ".nix" file; in {
    name = number;
    value = import "${toString invoicesDirectory}/${file}";
  }) (builtins.readDir invoicesDirectory);
in
{
  invoices = builtins.mapAttrs buildInvoice invoices;

  # jq 'to_entries | map(.value |= (.statements | map(.rate * .units) | add)) | from_entries'
  report = pkgs.writeText "report.json" (builtins.toJSON invoices);
}
