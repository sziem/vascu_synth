# vascu_synth
contains vascu synth sources with slight edits and instruction on how to use it.

Vascu Synth sources are from https://github.com/midas-journal/midas-journal-794

The software manual can be found at http://hdl.handle.net/10380/3260
Jassi P., Hamarneh G. VascuSynth: Vascular Tree Synthesis Software. 2011 Apr. 

The paper covering the parameters in detail can be found at http://www.cs.sfu.ca/~hamarneh/ecopy/cmig2010.pdf
G. Hamarneh and P. Jassi,  "VascuSynth:  Simulating vascular trees for generating volumetric image
data with ground truth segmentation and tree analysis", Computerized Medical Imaging and Graphics, vol. 34, no. 8, pp. 605–616, 2010

# Edits:
- updated CMakeLists to be compatible with newer ITK_LIBRARIES
- VascuSynth now generates png-files.

# Compilation was successful with 
- GCC 5.4
- CMake 3.5.1
- ITK 4.13 with compatibility mode for ITK 3

If ITK is installed on a standard library search path, then installation of vascu_synth was easy as

  cd (directory containing vascu-synth sources)
  
  mkdir ../build_vascu_synth
  
  cd ../build_vascu_synth
  
  cmake ../(directory containing vascu-synth sources)
  
  (possibly check ccmake .    to check if everything is ok).
  
  make

--> VascuSynth binary generated in build_vascu_synth directory.

# Testing
To create a test volume using the parameter files in this folder once VascuSynth has been built and compiled (in the source directory), issue the following command:

../Source/VascuSynth paramFiles.txt imageNames.txt 0.04 testNoise.txt
