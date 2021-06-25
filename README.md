### Summary

IO is a web audio-based graph engine written purely in swift just for educational purposes.

The official WebAudio API provides a powerful and versatile system to control audio. It allows developers to choose audio sources, add effects, create visualizations, and more.  Audio operations are handled within a context and have been designed to allow modular routing. All the basic audio operations are performed with nodes , which are linked together to form an audio routing graph. The audio nodes are linked in simple chains and networks by their inputs and outputs. These typically start with one or more sources. The sources provide (samples) in very small time slots, often tens of thousands of these per second. The results of these nodes could be linked to the inputs of others, which mix or modify these transmissions of audio samples in different transmissions.

The ideas was to re-write the official google implementation in swift since original is written in c++. 
In the future it will allow to extend functionally and make it cross-platform. 

#### W3 Specification

See documentation: https://www.w3.org/TR/webaudio/

This specification describes a high-level Web API for processing and synthesizing audio in web applications. The primary paradigm is of an audio routing graph, where a number of AudioNode objects are connected together to define the overall audio rendering. The actual processing will primarily take place in the underlying implementation (typically optimized Assembly / C / C++ code), but direct script processing and synthesis is also supported.

#### Backend

We are using miniaudio to support multi-platform audio (not-fully tested yet)

Online documentation can be found here: https://miniaud.io/docs/
Documentation can also be found at the top of miniaudio.h which is always the most up-to-date and authoritive source of information on how to use miniaudio. All other documentation is generated from this in-code documentation.

####  License

Nahuel Proietto, 2021 - MIT (http://opensource.org/licenses/mit-license.php)
