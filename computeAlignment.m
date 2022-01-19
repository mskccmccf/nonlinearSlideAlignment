function [tformresized,warpfieldresized] = computeAlignment(smallresfixed_IH,smallresmoving_IF,targetsize,alignres,alignmode,visualize)
%computes the actual alignment between images as given, then upsamples it to ouptput size
%smallresfixed_IH -fixed image already downsampled to resolution for computing alignment
%smallresmoving_IF -moving ditto (not actually IF if AEC to AEC pass)
%targetsize size of final output image (which alignment is upsampled to
%alignres-resolution of alignment relative to original used in upsampling alignment
%alignmode true uses imregcorr for linear alignment, false uses imregtform
%visualize- visualize results for debugging

%bacground correction on both before computing alignmeht
bk=imerode(medfilt2(smallresfixed_IH),offsetstrel('ball',5,5));
smallresfixed_IH=max(smallresfixed_IH-bk,0);
bk=imerode(medfilt2(smallresmoving_IF),offsetstrel('ball',5,5));
%right now this is strictly not ncessary bc is a uint but might change
%sometime and keeping treatment uniform.
smallresmoving_IF=max(smallresmoving_IF-bk,0);

%second step linear alignment
%one of two methods based on alignmode flag
if (alignmode)
    tform=imregcorr(smallresmoving_IF,smallresfixed_IH,'rigid');
else
    [optimizer,metric]=imregconfig('multimodal');
    tform=imregtform(smallresmoving_IF,smallresfixed_IH,'rigid',optimizer,metric);
end
Rfixed = imref2d(size(smallresfixed_IH));
ifcmovingrlin = imwarp(smallresmoving_IF,tform,'OutputView',Rfixed);
if (visualize)
    imshowpair(smallresfixed_IH,ifcmovingrlin*10);title('linear alingment');
end

%normalize bf nonlinear, not sure this actually helps.
ifcmovingrlin_n=min(1,single(ifcmovingrlin)./single(prctile(max(ifcmovingrlin),70)));
smallresfixed_IH_n=min(1,smallresfixed_IH./prctile(max(smallresfixed_IH),70));

%third step nonlinear alignment
[warpfield,smallregisteredifc]=imregdemons(ifcmovingrlin_n,smallresfixed_IH_n,[500 500 100 10  ],'PyramidLevels',4,'AccumulatedFieldSmoothing',1.3);

if (visualize)
    figure;imshowpair(smallresfixed_IH_n,min(1,smallregisteredifc));title('1 to 16 nonlinear alignment 4level norm_v2');
    figure;
    visimage=cat(3,smallresfixed_IH,smallregisteredifc,abs(max(warpfield,[],3)*2));
    imagesc(visimage);
    title('aligned images and warpfield');
end


%at this point have the small transform and need to upscale to apply to
%full size image
tformresized=tform;
%rescaling of tform
tformresized.T(3,1:2)=tformresized.T(3,1:2)*(1/alignres);
warpfieldresized=(imresize(single(warpfield),[targetsize(1),targetsize(2)]).*(1/alignres));

end
