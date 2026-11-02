#!/bin/bash
# Writes an lpadmin line for each printer installed on this Mac, ready to paste into
# bosthlm-installation's AppDelegate.applescript, to ~/Downloads/printer.txt.
# Run with:
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/growthagent/find-printers/main/find-printers.sh)"

main() {
  out=~/Downloads/printer.txt
  printers=$(lpstat -e 2>/dev/null)
  if [ -z "$printers" ]; then
    printf '\n\nKunde inte hitta några installerade skrivare på den här datorn.\n\n'
    return
  fi
  drivers=$(lpinfo -m 2>/dev/null)
  {
    # Only office printers (Konica Minolta); others, like home printers, are just named
    office= skipped=
    for p in $printers; do
      nick=$(sed -n 's/^\*NickName: *"\(.*\)".*$/\1/p' "/etc/cups/ppd/$p.ppd" 2>/dev/null)
      if printf '%s' "$nick" | grep -qi konica; then
        office="$office $p"
      else
        printf -- '-- Skipped %s (%s)\n' "$p" "${nick:-unknown model}"
        skipped=1
      fi
    done
    [ -n "$skipped" ] && printf '\n'
    for p in $office; do
      details=$(LC_ALL=C lpstat -l -p "$p")
      desc=$(printf '%s\n' "$details" | sed -n 's/^[[:space:]]*Description: //p')
      loc=$(printf '%s\n' "$details" | sed -n 's/^[[:space:]]*Location: //p')
      uri=$(LC_ALL=C lpstat -v "$p" | sed 's/^device for [^:]*: //')
      nick=$(sed -n 's/^\*NickName: *"\(.*\)".*$/\1/p' "/etc/cups/ppd/$p.ppd")
      # The installed driver whose model name matches the one this printer was set up with
      driver=$(printf '%s\n' "$drivers" | awk -v n="$nick" 'substr($0, length($1) + 2) == n { print "/" $1; exit }')
      printf -- '-- %s (%s)\n' "$desc" "$nick"
      if [ -n "$driver" ]; then
        # Options set to something other than the driver's default
        opts=$(lpoptions -p "$p" -l | awk '
          NR == FNR { d[$1] = $2; next }
          {
            k = $0; sub(/[\/:].*/, "", k)
            line = $0; sub(/^[^:]*: /, "", line)
            n = split(line, c, " ")
            for (i = 1; i <= n; i++)
              if (c[i] ~ /^\*/ && (k in d) && d[k] != substr(c[i], 2)) printf " -o %s=%s", k, substr(c[i], 2)
          }
        ' <(gzcat -f "$driver" | sed -n 's/^\*Default\([^:]*\): *\([^ ]*\).*/\1 \2/p') -)
      else
        printf -- '-- No installed driver matches "%s"; see the options below\n' "$nick"
        driver='?' opts=
      fi
      printf "do shell script \"sudo -S lpadmin -p '%s' -D '%s' -L '%s' -E -v '%s' -P '%s' -o printer-is-shared=False%s\" with administrator privileges\n\n" \
        "$p" "$desc" "$loc" "$uri" "$driver" "$opts"
    done
    [ -n "$office" ] && printf -- '-- ===== All options =====\n\n'
    for p in $office; do
      printf -- '-- %s\n' "$p"
      lpoptions -p "$p" -l
      printf '\n'
    done
  } > "$out" 2>&1
  printf '\n\nHämtade skrivarinformation och sparade den i dina Hämtade filer. Öppna Finder, gå till Hämtade filer och hitta filen "printer.txt". Bifoga den filen i ett mail till niclas@instateam.se.\n\n'
}
main
