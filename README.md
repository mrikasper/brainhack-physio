# BrainHack-Physio

- Physiological Noise Correction using the PhysIO Toolbox - Examples for the [BrainHack 23, Toronto](https://brainhackto.github.io/global-toronto-12-2023/)
- Project Proposal, with links, references: https://brainhack.org/global2023/project/project_71/
- Chat to us on MatterMost: https://mattermost.brainhack.org/brainhack/channels/physio

## Purpose
This small repository sets up a simple preprocessing (realignment, smoothing) and single subject fMRI analysis using the modeled physiological noise.

## Installation
1. You will need to install SPM12
2. You will need to install the PhysIO Toolbox
    - The `PhysIO/code` folder should end up in `spm12/toolbox/PhysIO`


## Getting Started

1. Create the following folder structure:
   ```
   project/
           data/
                sub-46/             (copy from OpenNeuro.org fmri) and osf.io (physio))
                       func/        (functional data from OpenNeuro)
                       anat/        (structural data from OpenNeuro)
                       physio/      (physiological logfiles from osf.io)
           code/brainhack-physio/   (this repository)
   ```
2. Open the main script `brainhack_physio_main` in Matlab
3. Follow the instructions there to adapt paths to your environment
4. For each subject to try, download copy the fMRI and physiological recording data 
5. Run `brainhack_physio_main` (play button) in Matlab. 
    - For starters, the interactive mode (`isInteraxtive = true`) is recommended
    - In this mode, each step is displayed in the SPM Batch Editor, and you have to press the play button (and wait) to execute
    - After the step finishes, press Enter in the command window

