# Strike Fighters 2 PBR Shaders

Experimental PBR shaders for Strike Fighters 2. Parameters can be tweaked in PBR_CONFIG.H

## Modder's Note: StrikeFighters2 Extractor.exe

TODO: properly document this with replicable steps

ThirdWire's Extractor util prevents you from extracting certain filetypes from the CAT files by checking the filetypes against a string whitelist of filetypes allowed to be displayed. Using a debugger tool like OllyDbg or CheatEngine you can edit this list in memory to change the viewable files, allowing you to dump hidden files like the FX shaders or WAV soundfiles.

The list is in the ".data" memory block of `strikefighters2 extract.exe` after a CAT file has been opened, usually somewhere around the +CBFA offset. Replace any of the listed filetypes with another to view a hidden filetype (eg "TGA" with "FX " to show shaders, or "INI" with "WAV" for soundfiles.) Note the file extension MUST be 3 unicode characters or less, with a 00 byte value for empty characters (eg when showing FX files,) and separated by a 0x2E byte. Reopen a CAT file for the list to be applied.

Specifically the target byte pattern to modify is the following:

`40 00 4C 00 4F 00 44 00 00 00 44 00 4C 00 43 00 00 00 4F 00 55 00 54 00 00 00 4C 00 53 00 54 00 00 00 49 00 4E 00 49 00 00 00 44 00 44 00 53 00 00 00 54 00 47 00 41 00 00 00 4A 00 50 00 47 00 00 00 42 00 4D 00 50 00 00 00 43 00 4F 00 4C 00 00 00 44 00 4C 00 4C 00 00 00 45 00 78 00 70 00 6F 00 72 00 74 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 02 00 00 00 00 00 00 00 44 BB B6 00 01 00 00`

Found address history:

- 00770BFC
- 007A0BFA
- 00BC0BFA

## Todo Items ##

- Refactor PBR.H references in Terrains
- Fix specular issues on reflection shaders
- Better cubemapping irradiance calculation
- Glowing gunsights
- Sparkly chaff