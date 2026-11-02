# find-printers

Writes an `lpadmin` line for each Konica Minolta printer installed on a Mac, ready to paste into
`bosthlm-installation`'s `AppDelegate.applescript`, to `~/Downloads/printer.txt`. Other printers,
like home printers, are only listed by name.

Run in Terminal:

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/growthagent/find-printers/main/find-printers.sh)"
```
