#!/bin/bash
# Collects info about the printers installed on this Mac and saves it to ~/Downloads/printer.txt.
# Printers reachable from the current network are listed first.
# Run with:
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/growthagent/find-printers/main/find-printers.sh)"

main() {
  out=~/Downloads/printer.txt
  printers=$(lpstat -e 2>/dev/null)
  if [ -z "$printers" ]; then
    printf '\n\nKunde inte hitta några installerade skrivare på den här datorn.\n\n'
    return
  fi
  tmp=$(mktemp -d) || return 1
  mkdir "$tmp/err"
  # Bonjour printers advertised on this network right now
  ippfind -T 4 _ipp._tcp _ipps._tcp _pdl-datastream._tcp _printer._tcp -s > "$tmp/bonjour" 2> "$tmp/err/ippfind"
  # Check every installed printer in parallel; each one appends "<printer> <status>" to $tmp/status
  for p in $printers; do
    (
      uri=$(LC_ALL=C lpstat -v "$p" 2>/dev/null | sed 's/^device for [^:]*: //')
      scheme=${uri%%://*}
      case $scheme in
        dnssd|mdns)
          name=$(printf '%s' "$uri" | sed -E 's#^[a-z]+://##; s#[/?].*$##; s#\._[^.]+\._(tcp|udp)\..*$##')
          name=$(printf '%b' "${name//%/\\x}")
          if grep -qxF "$name" "$tmp/bonjour"; then s=online; else s=offline; fi ;;
        usb|ippusb)
          s=usb ;;
        *)
          hp=$(printf '%s' "$uri" | sed -E 's#^[a-z]+://##; s#^[^@/]*@##; s#[/?].*$##')
          case $hp in *:*) host=${hp%:*}; port=${hp##*:} ;; *) host=$hp; port= ;; esac
          if [ -z "$port" ]; then
            case $scheme in
              ipp|ipps) port=631 ;; http) port=80 ;; https) port=443 ;;
              socket) port=9100 ;; lpd) port=515 ;; smb) port=445 ;;
            esac
          fi
          if [ -z "$port" ]; then
            s=unknown
          elif nc -z -v -G 3 -w 3 "$host" "$port" 2> "$tmp/err/$p"; then
            s=online
          else
            s=offline
          fi ;;
      esac
      echo "$p $s" >> "$tmp/status"
    ) &
  done
  wait
  {
    for s in online usb unknown offline; do
      for p in $(awk -v s="$s" '$2 == s { print $1 }' "$tmp/status" | sort); do
        printf '===== %s (%s) =====\n' "$p" "$s"
        LC_ALL=C lpstat -v "$p"
        lpoptions -p "$p"
        lpoptions -p "$p" -l
        printf '\n'
      done
    done
    printf '===== diagnostics =====\n'
    printf 'macOS %s\n\n' "$(sw_vers -productVersion)"
    printf -- '--- bonjour printers ---\n'
    cat "$tmp/bonjour" "$tmp/err/ippfind"
    printf '\n--- connection errors ---\n'
    for f in "$tmp"/err/*; do
      [ "${f##*/}" = ippfind ] || [ ! -s "$f" ] || printf '%s: %s\n' "${f##*/}" "$(tr '\n' ' ' < "$f")"
    done
  } > "$out" 2>&1
  printf '\n\nHämtade skrivarinformation och sparade den i dina Hämtade filer. Öppna Finder, gå till Hämtade filer och hitta filen "printer.txt". Bifoga den filen i ett mail till niclas@instateam.se.\n\n'
  rm -rf "$tmp"
}
main
