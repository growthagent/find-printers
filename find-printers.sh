#!/bin/bash
# Collects info about the printers this Mac can reach and saves it to ~/Downloads/printer.txt.
# Run with:
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/growthagent/find-printers/main/find-printers.sh)"

main() {
  out=~/Downloads/printer.txt
  tmp=$(mktemp -d) || return 1
  # Bonjour printers advertised on this network right now
  ippfind -T 4 _ipp._tcp _ipps._tcp _pdl-datastream._tcp _printer._tcp -s > "$tmp/bonjour" 2>/dev/null
  # Check every installed printer in parallel
  for p in $(lpstat -e 2>/dev/null); do
    (
      uri=$(LC_ALL=C lpstat -v "$p" 2>/dev/null | sed 's/^device for [^:]*: //')
      scheme=${uri%%://*}
      case $scheme in
        dnssd|mdns)
          name=$(printf '%s' "$uri" | sed -E 's#^[a-z]+://##; s#[/?].*$##; s#\._[^.]+\._(tcp|udp)\..*$##')
          name=$(printf '%b' "${name//%/\\x}")
          grep -qxF "$name" "$tmp/bonjour" ;;
        *)
          hp=$(printf '%s' "$uri" | sed -E 's#^[a-z]+://##; s#^[^@/]*@##; s#[/?].*$##')
          case $hp in *:*) host=${hp%:*}; port=${hp##*:} ;; *) host=$hp; port= ;; esac
          if [ -z "$port" ]; then
            case $scheme in
              ipp|ipps) port=631 ;; http) port=80 ;; https) port=443 ;;
              socket) port=9100 ;; lpd) port=515 ;; smb) port=445 ;; *) exit 1 ;;
            esac
          fi
          nc -z -G 3 -w 3 "$host" "$port" ;;
      esac && echo "$p" >> "$tmp/online"
    ) &
  done
  wait
  if [ -s "$tmp/online" ]; then
    {
      for p in $(sort "$tmp/online"); do
        printf '===== %s =====\n' "$p"
        LC_ALL=C lpstat -v "$p"
        lpoptions -p "$p"
        lpoptions -p "$p" -l
        printf '\n'
      done
    } > "$out" 2>&1
    printf '\n\nHämtade skrivarinformation och sparade den i dina Hämtade filer. Öppna Finder, gå till Hämtade filer och hitta filen "printer.txt". Bifoga den filen i ett mail till niclas@instateam.se.\n\n'
  else
    printf '\n\nKunde inte hitta någon skrivare på det här nätverket.\n\n'
  fi
  rm -rf "$tmp"
}
main
