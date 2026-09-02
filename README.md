<!-- Improved compatibility of back to top link: See: https://github.com/othneildrew/Best-README-Template/pull/73 -->
<a id="readme-top"></a>
<!--
*** Thanks for checking out the Best-README-Template. If you have a suggestion
*** that would make this better, please fork the repo and create a pull request
*** or simply open an issue with the tag "enhancement".
*** Don't forget to give the project a star!
*** Thanks again! Now go create something AMAZING! :D
-->



<!-- PROJECT SHIELDS -->
<!--
*** I'm using markdown "reference style" links for readability.
*** Reference links are enclosed in brackets [ ] instead of parentheses ( ).
*** See the bottom of this document for the declaration of the reference variables
*** for contributors-url, forks-url, etc. This is an optional, concise syntax you may use.
*** https://www.markdownguide.org/basic-syntax/#reference-style-links
-->






<h3 align="center">FPGA Synthesizer</h3>

  <p align="center">
    A musical synthesizer that runs on an Artix-7 Cmod A7-35T
    <br />
    <br />
    <a href="https://github.com/github_username/repo_name">View Demo</a>
    
  </p>
</div>






<!-- ABOUT THE PROJECT -->
## Overview

[![Product Name Screen Shot][product-screenshot]](https://example.com)

Includes 10-Voice Polyphony with Filters, Detune Oscillators, Phase Modulation, and ADSR. All with Variable controls.

Includes a Mono Sequencer with in-key randomization options.

Waveforms and Timing decisions are generated on the FPGA, while the User Interface and Variable controls are delegated to the PI.

A Modular System that supports up to 64 Potentiometers for Variable controls.

Connects to any MIDI keyboard through a standard MIDI DIN cable.






<p align="right">(<a href="#readme-top">back to top</a>)</p>



### Built With

* [![Verilog][Verilog.com]][Verilog-url]
* [![Kicad][Kicad.org]][Kicad-url]
* [![Vivado][AMD.com]][Vivado-url]
* [![Python][Python.org]][Python-url]
* [![MIDI][MIDI.org]][MIDI-url]
* [![PI][raspberrypi.com]][pi-url]
* [![FastAPI][fastapi.tiangolo.com]][FastAPI-url]


<p align="right">(<a href="#readme-top">back to top</a>)</p>

### Main Hardware

Artix-7 Cmod A7-35T

Adafruit I2S Stereo Decoder - UDA1334A Breakout

Raspberry Pi 4 Model B

Full Hardware list is in the BOM

## Functional overview


### Artix-7 Cmod A7-35T FPGA


The FPGA generates the base waveforms and timing sequences through MMCM.

More complex waveforms use wavetables with a saw wave as their reference.

Note and MIDI Values are stored as LUTs.

Filters and effects then alter the waveform with predictable algorithms and formulas.

The FPGA then parses MIDI data to send the waveform to a DAC.

### Raspberry Pi 4 Model B

The Pi handles everything on the User end.

The User Interface allows for a modular system of up to 64 potentiometers, but also allows for a fully digital system with no analog components.

Allows for a fully customizable sequencer system with in-key randomizers and timing variables.

### PCB

Includes Gerber Files and a full BOM.

The prototype was first breadboarded and then designed in KiCad.


<img width="2085" height="1251" alt="Schematic" src="https://github.com/user-attachments/assets/b73fe187-ac6b-45b8-b760-4336670b296b" />

<img width="1871" height="827" alt="PCB" src="https://github.com/user-attachments/assets/bbdbc200-9539-4353-8682-b59a3f504ef0" />

<img width="1952" height="824" alt="3dBoard" src="https://github.com/user-attachments/assets/7dd59e40-ecd2-411e-b3ba-69e3a4b7e46a" />







<!-- CONTACT -->
## Contact

Connor Wilson - Cwilsonx100@gmail.com

<p align="right">(<a href="#readme-top">back to top</a>)</p>





<p align="right">(<a href="#readme-top">back to top</a>)</p>



<!-- MARKDOWN LINKS & IMAGES -->
<!-- https://www.markdownguide.org/basic-syntax/#reference-style-links -->
[contributors-shield]: https://img.shields.io/github/contributors/github_username/repo_name.svg?style=for-the-badge
[contributors-url]: https://github.com/github_username/repo_name/graphs/contributors
[forks-shield]: https://img.shields.io/github/forks/github_username/repo_name.svg?style=for-the-badge
[forks-url]: https://github.com/github_username/repo_name/network/members
[stars-shield]: https://img.shields.io/github/stars/github_username/repo_name.svg?style=for-the-badge
[stars-url]: https://github.com/github_username/repo_name/stargazers
[issues-shield]: https://img.shields.io/github/issues/github_username/repo_name.svg?style=for-the-badge
[issues-url]: https://github.com/github_username/repo_name/issues
[license-shield]: https://img.shields.io/github/license/github_username/repo_name.svg?style=for-the-badge
[license-url]: https://github.com/github_username/repo_name/blob/master/LICENSE.txt
[PCB-Pic]: https://github.com/cwilsonx100/FPGA-Synthesizer/Images/PCB.png
[linkedin-url]: https://linkedin.com/in/linkedin_username
[product-screenshot]: images/screenshot.png
<!-- Shields.io badges. You can a comprehensive list with many more badges at: https://github.com/inttter/md-badges -->
[Verilog.com]: https://img.shields.io/badge/Hardware-Verilog-blue
[Verilog-url]: https://www.verilog.com/
[Kicad.org]: https://img.shields.io/badge/Hardware-KiCad-blue
[Kicad-url]: https://www.kicad.org/
[AMD.com]: https://img.shields.io/badge/EDA-Vivado-blue
[Vivado-url]: https://www.amd.com/en/products/software/adaptive-socs-and-fpgas/vivado.html
[Python.org]: https://img.shields.io/badge/Python-3776AB?logo=python&logoColor=fff
[Python-url]: https://www.python.org/
[MIDI.org]: https://img.shields.io/badge/-MIDI-000000?style=for-the-badge&logo=midi&logoColor=white
[MIDI-url]: https://midi.org/
[raspberrypi.com]: https://img.shields.io/badge/-RaspberryPi-C51A4A?style=for-the-badge&logo=Raspberry-Pi
[PI-url]: https://www.raspberrypi.com/
[fastapi.tiangolo.com]: https://img.shields.io/badge/FastAPI-005571?style=for-the-badge&logo=fastapi
[FastAPI-url]: https://fastapi.tiangolo.com/
[Bootstrap.com]: https://img.shields.io/badge/Bootstrap-563D7C?style=for-the-badge&logo=bootstrap&logoColor=white
[Bootstrap-url]: https://getbootstrap.com
[JQuery.com]: https://img.shields.io/badge/jQuery-0769AD?style=for-the-badge&logo=jquery&logoColor=white
[JQuery-url]: https://jquery.com 
