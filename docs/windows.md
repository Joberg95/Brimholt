Brimholt for Windows
====================

Brimholt.exe is the whole game; no install is needed. Keep the other files beside it:
Brimholt.console.exe (the same game with a console window, for running a server and reading
its log) and liblimboai.windows.template_release.x86_64.dll (the bots' AI; its MIT license
is LimboAI-LICENSE.txt).

FIRST START
Windows SmartScreen may say "Windows protected your PC" because the game is not code-signed.
Click "More info", then "Run anyway".

PLAYING TOGETHER ON A LAN
1. One person starts Brimholt.exe and clicks "Host a game". Everyone starts as an
   Adventurer and chooses a vocation in the game (see the trainers in Cinder Crossing).
   Windows Firewall asks whether Brimholt may communicate: allow it on private networks.
   (The game uses UDP port 1234.)
2. The host finds their IPv4 address: open Command Prompt, run "ipconfig", and read the
   "IPv4 Address" of the network adapter (for example 192.168.1.20).
3. Everyone else starts Brimholt.exe, types that address, and clicks "Join".

Up to twelve players. Everyone must use the same version of the game.

DEDICATED SERVER (optional; the host plays no character)
In Command Prompt, in the game folder:
    Brimholt.console.exe --headless -- --headless-server
Add --port=1235 after the "--" on the server and every player to use another port.
Close the window or press Ctrl+C to stop it (characters are saved every 30 seconds and when
the server stops normally).

SAVED CHARACTERS
The host saves every character, so you return as you left. Files live in
    %APPDATA%\Godot\app_userdata\Brimholt\
  saves\            the host's character saves and signing key (host only)
  identity.cfg      your secret identity: the host uses it to recognise you
Keep identity.cfg private, and copy it to another PC to play your characters there. Two
players on one PC: start the second one with  Brimholt.exe -- --profile=second

This is a trusted-LAN game: do not open its port to the Internet.
