# Virtual Multiplexing Alignment Project Code
A set of relatively simple Matlab scripts that can perform nonlinear alignment of scanned full slides at full resolution in order to create superimposed visualizations of multiple passes of IHC on top of IF on the same slide. IHC is unmixed and hemotoxylin nuclei are aligned with DAPI from IF.  Meant for superimposing multiple staining and scanning passes of the same slide with minimal distortion, this approach is likely to produce poor results for significantly different adjacent sections or if a significant degree of folding or other distortion occurs. Resulting OME tiffs are readable in QuPath https://qupath.github.io/. Depends on OME bfconvert bftools.zip https://docs.openmicroscopy.org/bio-formats/6.0.1/users/comlinetools/index.html being in source directory.  

Anthony Santella and Eric Rosiek MSKCC MCCF

## Installation
* Download code
* Download bfconvert.zip and place next to code
* Put this directory in the Matlab Path.

## Overview
The script is currently set up to align as many sections (whole slides or individually exported and arranged ROI for particular sections) as it finds in a directory structure of exported tiffs from one pass of IF and multiple passes of AEC. For each set of images of a particular ROI within a slide it aligns all AEC passes to IF by aligning a deconvolved hemotoxylin pseudo IF channel to the DAPI in the IF (identified by filename containing dapi in it). The IHC is assumed to be RGB images, the IF multiple images with a single channel in each image.  

Note the script is dependent on bfconvert to compile the aligned but non-pyramidal images output by matlab into a single multiresolution image readable by QuPath.  

The top level driver script multislidealignment_batch_driver.m merely configures path variables by walking through these directories and calls the real driver (alignSlides_multi_IHC.m) which performs actual alignment.  

Within each directory to be aligned, the script assumes the first subdirectory is IF, and that each additional directory is a pass of AEC.  On new data it may be easier to configure variables and call alignSlides_multi_IHC.m directly)

## Short Instructions for de novo alignment:
1.	Save multiple IHC and IF results as tiffs from caseviewer (or other software) at desired final resolution (typically 1:1, full resolution). Note that to avoid creating hard ROI edges due to export masking in the background it is better to use a rectangular ROI to define the regions in caseviewer. Create a directory with structure:

* ROI 1 on slide 1 directory  
  * IF directory e.g. ‘0-iF’
    * IF Channel 1
    * IF Chanel 2
   * ...  
  * IHC 1 directory e.g. ‘1-AEC_pass1’
    * IHC 1 RGB image   
  * …  
  * IHC N directory e.g. ‘N-ACE_passN’ 
    * IHC N RGB image 
* ROI 2 on slide 1 directory
  * … 
* …  

If exporting ROI rather than whole slides ROI should be at least approximately the same shape and location in the slide to ease initial linear alignment. Different slides may have different numbers or rounds of IHC or different numbers of channels in the IF pass. 

2.	Modify path at top level of script (multislidealignment_batch_driver.m)to point to top level directory 

3.	Change unmixing matrix if necessary of IHC passes

4.	Change pixel resolution if necessary 

5.	Run script, final qpath readable image with ome.tiff extension should appear in working directory.

## Debugging Advice:
Catastrophic alignment failure: suggest toggling the alignmode variable to see if the alternate linear alignment works better (Always so far this is due to failure of linear alignment one or the other matlab linear alignment method has worked for all slides seen so far).  

Subtle misalignment: running alignment at higher (say ¼, instead of 1/8) resolution might help, so far all examples tested (scanned at 20x and exported 1:1) have worked when run as individual tissue slice ROI, with about 50/50 success of getting globally good results aligning an entire slide with multiple tissue sections at once.  

Failure of bfconvert to be called and generate final output: this is a system call to a command line program so its likely that the directory containing bfconvert isn’t the working directory. (The current script takes care of this by trying to unzip bfconvert.zip into its self generated collision avoiding working directory, assuming it is available alongside the script when it runs.) 

## Other notes/gotchas: 
One flaw of this method is it doesn’t propagate the channel information metadata to qpath where the channels appear numbered sequentially with numbers.  

The order is IHC1,…, (decon He, stain, residual (if output)) then the IF in the order the files are listed by Matlab’s ls command.  

Note by default residual saving is turned off so 3 IHC images will contribute 6 rather than 9 channels.  

Since channel names do not propagate to the final tiff, it’s best to create a qupath project file add the images to the project and adjust the names of channels in the project (see directly below). Open the project rather than the individual images subsequently.  

Renaming all channels in a Qupath Project:
Create qupath project, add all images from the same experiment (same number of channels, same stains). Modify channel names/colors for first image. Order of channel is described above.  Close Qupath, select yes when prompted to save.  Open project.qpproj file (located in folder chosen when creating project) using notepad++ or desired text editor.
Find channels block under section for first image.  Copy and paste it over all subsequent channel blocks. Save project.qpproj file. Now all images will have the same channel names and channel colors when opened in qupath.

Also note on full slides this is very memory intensive, given matlab typically allows only a max percentage of total system memory to be used there might not be enough matlab memory available even on a system with more than sufficient physical memory (e.g. 500gb). It might be necessary to increase the virtual memory manually in windows to artificially inflate total system memory and ensure the percent it is willing to take is enough memory for matlab.  

Converting for to parfor in top level script would allow mutliple slides to be run in parallel on a sufficently robust machine. 

To do: might be more efficient to pyramidalize individual channels and use OME companion XML file to wrap them together.
