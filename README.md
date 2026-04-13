This is my own attempt to make a custom bazzite rebase, with a few addons installed for my Mechrevo WUJIE14XA laptop.
Feel free to use it at your own risk, i'm not a developer, or a die hard Linux engineer, i just try to do some stuff in my free time, and grow my knowledge on the road :-)

How to use?

1) Do a normal fresh bazzite desktop install from a bootable usb.
2) after first boot, open a terminal, and rebase your install to this repo:
Command in terminal: rpm-ostree rebase ostree-unverified-registry:ghcr.io/jefkesneltrekker/bazzite-mechrevo:latest
3) Normally after succesfull rebase, you would automaticly get this warning:
Apply your rpm-ostree change with the command: systemctl reboot

13-4-2026 -> Added the Tuxedo driver for Motorcomm Microelectronics. YT6801 Gigabit Ethernet Controller.
