function sPsImage = selLogPSD(I,psImage,sigma,thr)
% selects spots by quality
%
% inputs
% ------
% I: image
% psImage: point source image mask, obtained with logPSD
% sigma: std dev of gaussian that best fits spots
% thr: correlation threshold; spot is selected if correlation with ideal spot is above this; should be in range [-1,1]
%
% output
% ------
% point source image mask (false everywhere except at location of selected spots)

% Code from https://github.com/cicconet/RiffleShuffle
%
% Copyright (c) 2019 HMS-IDAC
%
% License:
% Permission is hereby granted, free of charge, to any person obtaining a copy
% of this software and associated documentation files (the "Software"), to deal
% in the Software without restriction, including without limitation the rights
% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
% copies of the Software, and to permit persons to whom the Software is
% furnished to do so, subject to the following conditions:
% 
% The above copyright notice and this permission notice shall be included in all
% copies or substantial portions of the Software.
% 
% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
% SOFTWARE.


hks = round(2*sigma);
k = zeros(2*hks+1,2*hks+1);
k(hks+1,hks+1) = 1;
k = imgaussfilt(k,sigma);
k = k/sum(k(:));
k = k(:);

sPsImage = false(size(psImage));
DI = im2double(I);
[r,c] = find(psImage);
for i = 1:length(r)
    r0 = r(i)-hks;
    c0 = c(i)-hks;
    r1 = r(i)+hks;
    c1 = c(i)+hks;
    if r0 >= 1 && r1 <= size(I,1) && c0 >= 1 && c1 <= size(I,2)
        P = DI(r0:r1,c0:c1);
        P = P/sum(P(:));
        if corr(k,P(:)) > thr
            sPsImage(r(i),c(i)) = 1;
        end
    end
end

end