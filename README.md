I was tired of having KiCAD yell at me for attempting to use custom paths.  

So, I am forced to build yet another flake-based dev environment for it so I can provision my projects in a nixy way and add version control as perhaps a bonus.

To do: 
- get kicad working in my nix flake style (I don't have time to test this right now but I wanted to get the rough framework up so I can come back and work on this later)
- pull in external dependencies in a nixy way rather than simply having the folders sitting in this repo (all kinds of licensing implications if I don't figure this out perhaps)
- 