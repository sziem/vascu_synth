# vascu_synth
contains vascu synth sources with slight edits and instruction on how to use it.

Vascu Synth sources are from https://github.com/midas-journal/midas-journal-794

Edits:
- updated CMakeLists to be compatible with newer ITK_LIBRARIES
- VascuSynth now generates png-files.

Compilation was successful with 
- GCC 5.4
- CMake 3.5.1
- ITK 4.13 with compatibility mode for ITK 3

If ITK is installed on a standard library search path, then installation of vascu_synth was easy as

cd (directory containing vascu-synth sources)
mkdir ../build_vascu_synth
cd ../build_vascu_synth
cmake ../(directory containing vascu-synth sources)
possibly check ccmake . to check if everything is ok.
make

--> VascuSynth binary generated in build_vascu_synth directory.
