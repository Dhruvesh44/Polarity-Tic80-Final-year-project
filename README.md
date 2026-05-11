# Your project name here
Polarity - Tic 80

## Information about this repository

This is the repository that you are going to use **individually** for developing your project. Please use the resources provided in the module to learn about **plagiarism** and how plagiarism awareness can foster your learning.

Regarding the use of this repository, once a feature (or part of it) is developed and **working** or parts of your system are integrated and **working**, define a commit and push it to the remote repository. You may find yourself making a commit after a productive hour of work (or even after 20 minutes!), for example. Choose commit message wisely and be concise.

Please choose the structure of the contents of this repository that suits the needs of your project but do indicate in this file where the main software artefacts are located.



# Polarity - TIC-80 2D Platformer
Author: Dhruvesh Chauhan
Date:   April 2026
Module: CO3201 Computer Science Project
        University of Leicester

## Repository structure

"TIC-80 executable file/ Polarity.tic" - this is where my game cartridge for  tic80 console is, you will need to locate it and import it into tic80 - shown below

"Tic80 lua code/ Polarity.lua" - this file has the lua code

"ITERATION FILES/" - this folder includes files for each iteration that was held - screenshots and descriptions







REQUIREMENTS 
------------
Created and tested on macOS. TIC-80 is cross-platform and works on Windows, Linux, and macOS.

TIC-80 (free) must be installed to run this game.
Download from: https://tic80.com





HOW TO RUN
----------

  1. Install TIC-80 from tic80.com
  2. Open TIC-80 - it loads up a console, locate the Polarity.tic file using: "cd path/to/TIC-80 executable file"
  3. Type: load Polarity.tic
  4. Press Enter
  5. Type: run
  6. Press Enter


CONTROLS
--------
Arrow Left / Right    Move
Arrow Up              Jump
Z                     Flip gravity



GAMEPLAY
--------
- Reach the goal flag at the end of each level to progress
- Avoid or stomp enemies to defeat them
- Collect coins along the way
- Falling into the lava costs a life
- You have 3 lives before game over
- Two levels included, looping back after completion



SYSTEMS IMPLEMENTED
-------------------
- Velocity-based physics with Euler integration
- AABB collision detection
- Dual-state gravity inversion mechanic
- Procedural platform generation
- Enemy patrol AI with ceiling and floor variants
- Level progression - enemies move quicker, platforms get smaller
- Particle feedback system
- FPS runtime performance indicator (top right)



NOTE ON FPS COUNTER
-------------------
The FPS counter displayed in the top right is intentional.
It serves as a runtime performance indicator consistent with
the performance evaluation discussed in the my dissertation.