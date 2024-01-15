# OPTtools

An offshoot of ALYTools (https://github.com/yalexand/ALYtools/), OPTtools is a OPT reconstruction application written in MATLAB.

- [Overview](#overview)
- [System Requirements](#system-requirements)
- [Installation and Running](#installation-and-running)
- [User Guide](#user-guide)
- [License](#license)

# Overview

OPTtools widely uses Open Source code designed by other researchers. Original license sections are always kept. If third-party software is used in code supporting scientific publications, references are provided.
Several applications were reported in the literature, and some are mentioned below.

# System Requirements

## Software
OPTtools requires at least Matlab 2019b, and the Image Processing Toolbox. Icy (http://icy.bioimageanalysis.org/) integration for viewing/rendering 3D images is supported, but optional.
Windows 10 required.
## Hardware
Hardware requirements depend on "Application", but in most cases average desktop specs suffice. NVIDIA GPU may be optionally used to accelerate reconstruction.

# Installation and Running

The OPTtools folder should be added to the MATLAB path, before running the command ic_OPTtools. This can optionally be done in a startup.m file saved in the default MATLAB directory (please consult the MATLAB documentation for more details).

To use Icy visualization, one needs to install Icy, along with 2 plugins: "matlabcommuncator" and "matlabxserver" (this can be done from the plugin manager within Icy). Icy should be installed somewhere on C:\ in a folder with open r/w access.
On first run, the software can automatically find the Icy directory, or the user can manually select it. Alternatively, Icy implementation can be disabled.

# User Guide

Please download the full user guide here:
[OPT_Reconstruction_with_OPTtools_User_Guide.pdf](https://github.com/cjd12/OPTtools/files/13939944/OPT_Reconstruction_with_OPTtools_User_Guide.pdf)

# License
Original ALYtools code is covered by MIT license. Code involving third party designs under GPL v2, is covered by that license.
