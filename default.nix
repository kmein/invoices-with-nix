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
  fmap = f: x: if x == null then null else f x;

  renderCompanyAndName = { name ? null, company ? null, ... }: builtins.concatStringsSep ''\\'' (builtins.filter (x: x != null) [ name (fmap (x: ''\textbf{${x}}'') company) ]);
  renderAddress = { street, zip, city, country ? null }: ''${street}\\ ${toString zip}\ ${city}${lib.optionalString (country != null) ''\\ ${country}''}'';
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

  toCents = n: builtins.floor (n * 100);

  zeroPad = l: s: if builtins.stringLength s < l then zeroPad l "0${s}" else s;

  formatPercent = p: "${formatCents (toCents (p * 100))}\\%";

  formatNumber = n: formatCents (toCents n);

  formatCents = n: let
    integral = builtins.div n 100;
    rational = lib.mod n 100;
  in "${toString integral},${zeroPad 2 (toString rational)}";

  invoiceLatex = number: {
    customer,
    date ? dateFromInvoiceNumber number,
    text ? defaultText,
    statements,
    project ? null,
    yourref ? null,
    account ? defaultAccount,
    salutation ? defaultSalutation,
    closing ? defaultClosing,
  }: let
    total = sum (map ({rate, units, ...}: toCents (rate * units)) statements);
    taxTotal = statements: sum (map ({rate, units, taxRate ? 0.19, ...}: toCents (rate * units * taxRate)) statements);
    taxAmounts = lib.groupBy (x: formatPercent (x.taxRate or 0.19)) statements;
  in pkgs.writeText "invoice-${number}.tex" ''
    \documentclass[a4paper]{scrlttr2}
    \usepackage[top=2cm, bottom=1cm, left=2cm, right=2cm]{geometry}
    \usepackage{graphicx}
    \usepackage{libertine,libertinust1math}
    \usepackage[utf8]{inputenc}
    \usepackage[T1]{fontenc}
    \usepackage[ngerman]{babel}
    \usepackage{color}
    \usepackage{enumitem}
    \usepackage[hidelinks]{hyperref}

    \usepackage{tabularx,booktabs}

    \setkomavar{fromname}{${account.name}}
    \setkomavar{fromaddress}{${renderAddress account.address}}
    ${lib.optionalString (account.email != null) ''\setkomavar{fromemail}{${account.email}}''}
    \setkomavar{place}{${account.address.city}}
    \setkomavar{date}{${date}}
    \setkomavar{subject}{Rechnung${lib.optionalString (project != null) ": ${project}"}}
    \setkomavar{invoice}{${number}}
    \setkomavar{frombank}{${renderBank account.account}}
    ${lib.optionalString (yourref != null) ''\setkomavar{yourref}{${yourref}}''}

    \setkomavar{firsthead}{%
      \parbox{\linewidth}{\flushright
        \usekomavar{fromname}\\
        \usekomavar{fromaddress}\\[\baselineskip]
        \footnotesize
        ${lib.optionalString (account.email != null) ''
          \textbf{\usekomavar*{fromemail}}\\
          \usekomavar{fromemail}\\[\baselineskip]
        ''}
        \textbf{${account.taxId.type or "Steuernummer"}}\\
        ${account.taxId.number}\\[\baselineskip]
        \textbf{\usekomavar*{frombank}}\\
        \usekomavar{frombank}
      }
    }

    \begin{document}
      \begin{letter}{${renderCompanyAndName customer}\\ ${renderAddress customer.address}}
        \opening{${salutation}}
        ${text}
        \begin{center}
          \begin{tabularx}{\textwidth}{Xrrr}
            \textbf{Leistung} & \textbf{Preis} & \textbf{Anzahl} & \textbf{Gesamt}\\
              ${toString (builtins.map ({name, rate, units, taxRate ? 0.19}: ''
                ${name}${lib.optionalString (!account.kleinunternehmer) ''\hfill \small{${formatPercent (taxRate)}}''} & ${formatCents (toCents rate)} € & ${formatNumber units} & ${formatCents (toCents (units * rate))} € \\
              '') statements)}
            \midrule
            & & ${if account.kleinunternehmer then "\\textbf{Summe}" else "Nettopreis"} & ${formatCents total} €\\
            ${lib.optionalString (!account.kleinunternehmer) (lib.concatStrings (lib.mapAttrsToList (taxRateString: statements: ''& & zzgl. ${taxRateString} USt & ${formatCents (taxTotal statements)} €\\'') taxAmounts))}
            ${lib.optionalString (!account.kleinunternehmer) ''& & \textbf{Summe} & ${formatCents (total + taxTotal statements)} €\\''}
          \end{tabularx}
        \end{center}
        ${lib.optionalString (account.kleinunternehmer or false) ''\ps Gemäß \href{https://www.gesetze-im-internet.de/ustg_1980/__19.html}{§ 19 Abs. 1 UStG} berechne ich keine Umsatzsteuer.''}
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
