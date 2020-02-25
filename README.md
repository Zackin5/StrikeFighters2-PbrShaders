# Strike Fighters 2 PBR Shaders

Experimental PBR shaders for Strike Fighters 2. Parameters can be tweaked in PBR_CONFIG.H

## Modder's Note: StrikeFighters2 Extractor.exe

ThirdWire's Extractor util prevents you from extracting certain filetypes from the CAT files by checking the filetypes against a string list of filetypes allowed to be displayed. Using a debugger tool like OllyDbg or CheatEngine you can edit this list in memory to change the viewable files, allowing you to dump hidden files like the FX shaders or WAV soundfiles.

The list starts in-memory at the 00770BFC address, replace any of the listed filetypes with another to view a hidden filetype (eg "TGA" with "FX " to show shaders, or "INI" with "WAV" for soundfiles.) Note the file extension MUST be 3 unicode characters or less, with a 00 byte value for empty characters (eg when showing FX files.)
