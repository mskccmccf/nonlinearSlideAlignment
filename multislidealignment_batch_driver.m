%top level driver for aligning batches of exported ROI or whole slides 
%takes a directory of multiple slides with multiple directories for ROIs 
%each with IF and multiple IHC passes of same slide aligns
%everything to IHC pass 1 via either hemotoxin-hemotoxin for IHC or hemotoxin-dapi

clear; close all; clc;
delete(gcp('nocreate'))
%likely to change parameters
tic

%downsampled size of image that is used in computing alignment
%1/8 is typically used if 1:1 export, sometimes 1/4 has been better
alignres=1/8;

%configure unmixing matrix used to create pseudofluoresence from IHC
% alternative set of standard values (HDAB from Fiji)
He = [ 0.6500286;  0.704031;    0.2860126 ];
DAB = [ 0.26814753;  0.57031375;  0.77642715];
ResDab = [ 0.7110272;   0.42318153; 0.5615672 ]; % residual
A=[0.27431306; 0.67963237; 0.6803324];
ResA=[0.7086714; 0.20601025; 0.6747923];

unmixmatrix=[He,A,ResA]; %H+A

%less likely to change parameters
alignmode=true; %if true uses imregcorr if false uses imregtform, unsure why sometimes one works and sometimes the other.
discardresidual=true; %throw out residual channel of pseudo IF IHC  to save space
visualize=false; %pop up figures of aligment steps for debugging

%pixel resolution dependent on scanner only the ratio matters so dont need to change this if you change export resolution
%but might effect alignment of relative ratio is off
%unfortunately not currently passed along in metadata through pipeline
ifcres=.243094;
ihcres=.3250;

imscale=1; %scale at which aligned results are output (1 i.e. scale of exported ROI is typical)

%top level driver walks provided directory, parses out (multiple) IHC and
%one IF image and makes call to align them
%location of directories each of which contain a set of exported images to
%be merged

basedir = uigetdir('','Select Directory Containing ROIs for Alignment');

outputsuffix='alignmentresult.ome.tiff';

%note treats first directory in list of subdirectories provided by pwd as
%IF and subsequent as IHC aligning them in that directory order

%lists directory it was given
currentFolder = pwd;
slides = dir(basedir);
slides(ismember( {slides.name}, {'.', '..'})) = [];
n = 1;
allIHCpath = {};
%iterates over directories in it (meant to correspond to slides)expecting to find within them directories
%corresponding to ROI within those slides, each or the ROI for each slide
%is aligned

%if uncommented this outter loop and modified internal lines would iterate over a set of directories
%containing a set of directories to be aligned, this is kind of specialized
%for s = 1:size(slides,1)%iterate over 'slides' i.e. directories each of which contain multiple ROI
%    if slides(s).isdir == 1
%        slidedir = fullfile(slides(s).folder,slides(s).name);
 %       tissues = dir(slidedir);
 tissues = dir(basedir);
        tissues(ismember( {tissues.name}, {'.', '..'})) = [];
        for j = 1:size(tissues,1) %iterate over ROI directories 
            if tissues(j).isdir == 1
                tissuedir = fullfile(tissues(j).folder,tissues(j).name);
                rounds = dir(tissuedir);
                rounds(ismember( {rounds.name}, {'.', '..'})) = [];
                dirFlags = [rounds.isdir];
                rounds = rounds(dirFlags);
                FMbasedir = fullfile(rounds(1).folder,rounds(1).name) + "\";
                IFchannels = dir(FMbasedir);
                for k = 1:size(IFchannels,1)
                    if IFchannels(k).isdir == 0 && contains(IFchannels(k).name,'DAPI')
                        fullresmoving_IF = fullfile(IFchannels(k).folder,IFchannels(k).name);
                        break
                    end
                end
               % finalimagename=[strrep(slides(s).name,' ','_'),strrep(tissues(j).name,' ','_'),outputsuffix];
               % pathinfo{n,1} = [strrep(slides(s).name,' ','_'),strrep(tissues(j).name,' ','_')];
                finalimagename=[strrep(tissues(j).name,' ','_'),outputsuffix];
                pathinfo{n,1} = strrep(tissues(j).name,' ','_');
    
                pathinfo{n,2} = FMbasedir;
                pathinfo{n,3} = fullresmoving_IF;
                pathinfo{n,4} = finalimagename; 
                
                for k = 2:size(rounds,1)
                    allIHCpath{n,k-1} = getimagedown(fullfile(rounds(k).folder,rounds(k).name));
                end
                n = n + 1;
            end
        end
%    end
%end
%at this all directories have been parsed and set, actually do the
%alignment tasks

%use parfor if want to to align all sections at once on a good workstation, 
%NB this could cause out of memory failure on a machine with less memory
for t = 1:(n-1)
    alignSlides_multi_IHC(pathinfo(t,:),allIHCpath(t,:),currentFolder,unmixmatrix,alignmode,discardresidual,visualize,ifcres,ihcres,alignres,imscale);
end

toc


function imgpath = getimagedown(path)
    list = dir(path);
    for i = 1:size(list,1)
        if list(i).isdir == 0
            imgpath = fullfile(list(i).folder,list(i).name);
            break
        end
    end
end

