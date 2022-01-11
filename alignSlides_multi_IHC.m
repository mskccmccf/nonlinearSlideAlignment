function alignSlides_multi_IHC(pathinfo,allIHCpath,currentFolder,unmixmatrix,alignmode,discardresidual,visualize,ifcres,ihcres,alignres,imscale)
% top level driver of actual alignment
% unmixes IHC aligns them together to IHC pass 1 and then adds IF aligned to IHC1 
%outputs all these images as (largely useless) big tiffs, then calls
%bfconvert to turn these into a single pyramidal tiff (this is the time
%consuming step)

%pathinfo-array of input and output locations
%pathinfo{1}=name of top level directory of slide used to create subdirectory to do temp alignment in
%pathinfo{2} full path of top level directory for set of images to be aligned
%pathinfo{3} full path of dapi file to be used to do alignment
%pathinfo{4} name (without path) of output file
%allIHCpath= cell arraywith the full path and filename to each round of IHC to be aligned
%currentfolder- directory that parent script run from, presumed to contain bfconvert.zip and desired destination of final compiled output file 
%unmixmatrix-unmixing matrix to create pseudo-if by unmixing rbg IHC
%alignmode-true uses imregcorr false uses imregtform for linear alignment. For some reason occassionaly a data set fails with one or other
%discardresidual true discards residual channel in output
%visualize -pops up a window with overlay of linear and nonlinear alignments for debugging 
%ifcres, ihcres %resolutions of IF and IH images
%alignres- relative resolution at which aignment is computed e.g. 1/8 tocompute at 1/8th of input resolution
%imscale- relative resolution at which output is created (typically 1)

baseoutput='';% temp save location is working directory 

%unpack zip containing bioformats tools used to concatenate channels into separate workspace for each tissue.
unzip(fullfile(currentFolder,'BioFormats.zip'),fullfile(pathinfo{1}))
workspacename = pathinfo{1};

cd(workspacename)
%strip empty cells that shouldnt be there (and may not now)
for idx = 1:size(allIHCpath)
    if ~isempty(allIHCpath{idx})
        allIHC{idx} = allIHCpath{idx};
    end
end
FMbasedir = pathinfo{2};
fullresmoving_IF = pathinfo{3};
finalimagename = pathinfo{4};

v1=unmixmatrix(:,1);
v2=unmixmatrix(:,2);
v3=unmixmatrix(:,3);

rescale=ihcres./ifcres;

%arbitratily all aligned to 1
ihc1=single(imresize(imread(allIHC{1}),imscale));%IH image
ihc1 = colorUnmix(ihc1,discardresidual,v1,v2,v3);

%save IHC 1 as is
counter=1;
for channel=1:size(ihc1,3)
    testimage=bigimage(ihc1(:,:,channel));
    testoutput=[baseoutput,'split_image_c',num2str(counter),'.tiff'];
    write(testimage,testoutput);
    counter=counter+1;
end

masterHC=abs(single(ihc1(:,:,1)));
clear('ihc1'); %no longer needed, save memory

targetsize=size(masterHC);
Rfixed = imref2d(size(masterHC));
masterHC=imresize(masterHC,alignres);


%now align and save successive IHCs
for i=2:length(allIHC) %for each IHC pass align i
    %now compute alignment of IHC 2 and 3 to IHC 1
    ihci=single(imresize(imread(allIHC{i}),imscale));%IH image
    ihci = colorUnmix(ihci,discardresidual,v1,v2,v3);
    %note rescale param 1 because all IHC assumed on same scanner
    [tformresized,warpfieldresized] = computeAlignment(masterHC,imresize(abs(single(ihci(:,:,1))),alignres),targetsize,alignres,alignmode,visualize);
    %warp IHC2
    ihci=imwarp(ihci,tformresized,'OutputView',Rfixed);
    ihci=imwarp(ihci,warpfieldresized);%dont need to change output view
    for channel=1:size(ihci,3)
        testimage=bigimage(ihci(:,:,channel));
        testoutput=[baseoutput,'split_image_c',num2str(counter),'.tiff'];
        write(testimage,testoutput);
        counter=counter+1;
    end
end
clear('ihci');

%now all IHC is aligned and saved  align IF to IHCmaster
%load IF histone
%apply both change in resolution btw IHC and IF and  image downsampling
fullresmoving_IF=imresize(imread(fullresmoving_IF),imscale*rescale);%moving image to be changed %channel of IF to use
sourcesize=size(fullresmoving_IF);
fullresmoving_IF=imresize(fullresmoving_IF,alignres);%moving image to be changed %channel of IF to use
[tformresized,warpfieldresized] = computeAlignment(masterHC,fullresmoving_IF,targetsize,alignres,alignmode,visualize);

%at this point dont need any of old variables
clear('masterHC');clear('fullresmoving_IF');

%apply resized transform to each channel image in IF directory
FMbasedir = convertStringsToChars(FMbasedir);
imagelistmoving=ls([FMbasedir,'*.tif']);
fullsizewarped=[];
for i=1:size(imagelistmoving,1)
    imtowarp=imresize(imread([FMbasedir,deblank(imagelistmoving(i,:))]),imscale);
    imtowarp=imresize(imtowarp,rescale);%compensate for pixel resolution
    imtowarp=imwarp(imtowarp,tformresized,'OutputView',Rfixed);
    imtowarp=imwarp(imtowarp,warpfieldresized);%dont need to change output view
    fullsizewarped=cat(3,fullsizewarped,imtowarp);
end
%save IF
for channel=1:size(fullsizewarped,3)
    testimage=bigimage(fullsizewarped(:,:,channel));
    testoutput=[baseoutput,'split_image_c',num2str(counter),'.tiff'];
    write(testimage,testoutput);
    counter=counter+1;
end

%create pyramidilization bioformats pattern file for the correct number of
%channels
fid = fopen( strcat('imagenopyramid',num2str(counter-1),'.pattern'), 'wt' );
fprintf( fid, strcat('split_image_c<1-',num2str(counter-1),'>.tiff'));
fclose(fid);

%call bfconvert to create compiled pyramidal file with all channels
[~,~] = system([strcat('bfconvert.bat -tilex 512 -tiley 512 -compression JPEG-2000 -pyramid-resolutions 5 -pyramid-scale 2 -noflat imagenopyramid',num2str(counter-1),'.pattern '),' ', baseoutput,finalimagename]);

%

% delete('*split_image_c*.tiff');
% delete(strcat('imagenopyramid',num2str(counter-1),'.pattern'));

%this doesnt seem to be working parallelization seems to mess it up
%move output to main directory and delete ROI working directory
status = movefile(fullfile(currentFolder,workspacename,finalimagename),currentFolder);
if status == 1
    pause(10)
    cd(currentFolder);
    rmdir(fullfile(currentFolder,workspacename),'s');
end
%}
end
