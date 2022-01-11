function [fullresfixed_IH] = colorUnmix(fullresfixed_IH,discardresidual,v1,v2,v3)
%color unmix an image given 3 stain vectors returns 3 unmixed pseudo FL
%images
%fullresfixed_IH -rgb image to unmix 
%discardresidual- whether to return residual channel 
%v1,v2,v3  unmixing matrix as 3 vectors  

% combine stain vectors to deconvolution matrix
    HDABtoRGB = [v1/norm(v1) v2/norm(v2) v3/norm(v3)]';
    HDABtoRGB = [v1 v2 v3]';
  
    RGBtoHDAB = inv(HDABtoRGB);
    minvals=-([255,255,255]*RGBtoHDAB); %not sure how this is supposed to work
    imsize=size(fullresfixed_IH);
    fullresfixed_IH= single(reshape((fullresfixed_IH),[],3)) * RGBtoHDAB;
    fullresfixed_IH = reshape(-1*fullresfixed_IH,imsize);
    %make response on 255,255,255 =0
    for i=1:3
       fullresfixed_IH(:,:,i)=max(fullresfixed_IH(:,:,i),minvals(i))-minvals(i);
       fullresfixed_IH(:,:,i)=fullresfixed_IH(:,:,i)./(max(max(fullresfixed_IH(:,:,i))));
    end
%    figure;imagesc(real(testim_mod(:,:,1)))
    if(discardresidual)
        fullresfixed_IH=uint8(255.*fullresfixed_IH(:,:,1:2));
    else
        fullresfixed_IH=uint8(255.*fullresfixed_IH);
    end
end


