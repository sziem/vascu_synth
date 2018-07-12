# vascu_synth
contains vascu synth sources with slight edits and instruction on how to use it.

Original Vascu Synth sources are from https://github.com/midas-journal/midas-journal-794

The software manual can be found at http://hdl.handle.net/10380/3260
Jassi P., Hamarneh G. VascuSynth: Vascular Tree Synthesis Software. 2011 Apr. 

The paper covering the parameters in detail can be found at http://www.cs.sfu.ca/~hamarneh/ecopy/cmig2010.pdf
G. Hamarneh and P. Jassi,  "VascuSynth:  Simulating vascular trees for generating volumetric image
data with ground truth segmentation and tree analysis", Computerized Medical Imaging and Graphics, vol. 34, no. 8, pp. 605–616, 2010

# Edits:
- updated CMakeLists to be compatible with newer ITK_LIBRARIES
- VascuSynth now generates png-files.
- image_names now numbered with 4 digits.

# Compilation
sources are contained in "sources"

Compilation was successful with 
- GCC 5.4
- CMake 3.5.1
- ITK 4.13 with compatibility mode for ITK 3

If ITK is installed on a standard library search path, then installation of vascu_synth was easy as

  cd (directory containing vascu-synth sources)
  
  mkdir ../build_vascu_synth
  
  cd ../build_vascu_synth
  
  cmake ../(directory containing vascu-synth sources)
  
  (possibly check ccmake . ).
  
  make

--> VascuSynth binary generated in build_vascu_synth directory.

# Test installation:
example configuration files are contained in "example_config"

To create a test volume using these parameter files, copy them to the same directory, where the vascu_synth binary is, cd there and issue the following command (the last argument testNoise is optional):

./VascuSynth paramFiles.txt imageNames.txt 0.04 testNoise.txt

Note that depending on the configuration, running vascu_synth can take quite long.

# Run with custom configuration:
A python script is provided, which contains functions that you can use to create your own configuration files.

I found that vascu synth is quite peculiar to its input and I don't understand 100%, why some of the formatting was necessary, but the
version provided worked for me.

Some hints:
- maximum volume size that I could create is around (1000, 1000, 100).  One dimension can never be much more than 100 (although I was able to go to like 110 with a larger box_size).  Otherwise there is a malloc error.
- the newline character must be \r\n and some files can have newline at the end of file, while others can't
- if the input is False, it does not always raise an Error.  Sometimes it just does not continue.  This is particularly bad, since running it takes long even in the first place.
- setting all pixels to a value in the first line of the demand map seems necessary.

# Comments:
Looking at the max_projections of the output of VascuSynth, it seems that it always propagates in the z-direction (2nd axis)
