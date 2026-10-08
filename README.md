# StudioPresence v3.0.7 (security-reviewed fork)

A plugin to connect your Studio with Discord!  
Heavily inspired by [DRPC by RigidStudios](https://devforum.roblox.com/t/1086405)

# Examples

<img width="335" height="638" alt="examples" src="https://github.com/user-attachments/assets/e232ba09-89f8-4e0d-94c0-02ea84607d23" />


# Installation

• Open the latest successful [Package run in this fork](https://github.com/daytondeltap/StudioPresence/actions/workflows/package.yml). Download the server artifact for your operating system and **StudioPresence-Plugin** from that same run.
• Extract the server archive, and install `studiopresence.rbxm` as a local Roblox Studio plugin. The companion plugin from this fork uses the hardened loopback endpoint.
• Open Discord, then run the server. Rebuilds do not modify upstream releases or the Roblox marketplace plugin.

*Additional steps for **MacOS** users*
1. Download the Mac server
2. Extract it using the archive utility from the App Store
3. [Open your terminal](https://support.apple.com/guide/terminal/open-or-quit-terminal-apd5265185d-f365-44cb-8b09-71a064a42125) and type `chmod u+x ` and then drag the server file into your terminal, press enter and it will turn the server into an executable file.
4. Open the executable file. Builds are not Apple-notarized; if macOS blocks it, verify its source and checksum before deciding whether to allow it.

*Additional optional steps for **Windows** users for automatic boot, not required.*
1. Locate the `startup.vbs` file
2. Press Win + R and open `shell:startup`
3. Drag `startup.vbs` into the folder that opens
4. Edit `startup.vbs` with notepad
5. Copy the path to the server exe file
6. Replace `PATH_TO_EXE` with said path, make sure there is only one set of quotation marks  
This will automatically start the server without opening a command window


If antivirus flags a download, keep it quarantined and investigate the exact detection. This review does not establish that every executable is safe. Do not disable antivirus or add blanket exclusions. See [SECURITY.md](SECURITY.md) for findings, build instructions and review limits.

_Note: The cmd window needs to be open in order for the plugin to work!_

If the activity doesn't show up, double check you have activity privacy enabled!

**If you have any issues, *reply to this devforum thread* or contact me via my [twitter](https://twitter.com/iArxic)!**

# Special thanks to

[Coyenn](https://github.com/Coyenn) - v2  
[xhayper](https://github.com/xhayper) - v3.0.1  
[Rigid Studios](https://devforum.roblox.com/u/Rigid_Studios) - Original DRPC  
[Eltobb](https://devforum.roblox.com/u/Elttob) - Vanilla icons (Modified)  
[pruzae](https://devforum.roblox.com/u/pruzae) - MacOS installation guide  
[purn8r](https://devforum.roblox.com/u/purn8r) - Windows automatic boot guide
[UncleTyrone](https://devforum.roblox.com/u/UncleTyrone) - v3.0.5
[Papgy](https://devforum.roblox.com/u/Papgy) - v3.0.6


*PS: If you're a scripter you can check out my [RoCommit](https://devforum.roblox.com/t/rocommit-git-like-webhook-logging/1886532) plugin!  
And if you're a builder you can check out [Color Offset](https://devforum.roblox.com/t/color-offset-plugin-add-color-variations-to-your-builds/2333459) plugin!*
