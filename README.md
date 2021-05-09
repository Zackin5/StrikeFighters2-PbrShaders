# Strike Fighters 2 PBR Shaders

Experimental PBR shaders for Strike Fighters 2. Parameters can be tweaked in PBR_CONFIG.H

## Modder's Note: StrikeFighters2 Extractor.exe

TODO: properly document this with replicable steps

ThirdWire's Extractor util prevents you from extracting certain filetypes from the CAT files by checking the filetypes against a string whitelist of filetypes allowed to be displayed. Using a debugger tool like OllyDbg or CheatEngine you can edit this list in memory to change the viewable files, allowing you to dump hidden files like the FX shaders or WAV soundfiles.

The list is in the ".data" memory block of `strikefighters2 extract.exe` after a CAT file has been opened, usually somewhere around the +CBFA offset. Replace any of the listed filetypes with another to view a hidden filetype (eg "TGA" with "FX " to show shaders, or "INI" with "WAV" for soundfiles.) Note the file extension MUST be 3 unicode characters or less, with a 00 byte value for empty characters (eg when showing FX files,) and separated by a 0x2E byte. Reopen a CAT file for the list to be applied.

Found address history:

- 00770BFC
- 007A0BFA

## Todo Items ##

- Refactor PBR.H references in Terrains
- Fix specular issues on reflection shaders
- Better cubemapping irradiance calculation
- Glowing gunsights
- Sparkly chaff