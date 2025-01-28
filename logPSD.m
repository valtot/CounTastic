function [locs,imgLoG]  = logPSD(img, mask, sigma, alpha)


% Copyright (c) 2019 HMS-IDAC
% 
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

if ~isa(img, 'double')
    img = double(img);
end

% Gaussian kernel
w = ceil(4*sigma);
x = -w:w;
g = exp(-x.^2/(2*sigma^2));

% convolutions
imgXT = padarrayXT(img, [w w], 'symmetric');
fg = conv2(g', g, imgXT, 'valid');

% Laplacian of Gaussian
gx2 = g.*x.^2;
imgLoG = 2*fg/sigma^2 - (conv2(g, gx2, imgXT, 'valid')+conv2(gx2, g, imgXT, 'valid'))/sigma^4;
imgLoG = imgLoG / (2*pi*sigma^2);

% select by robust statistics
PSMags = imregionalmax(imgLoG).*imgLoG;
mPSMags = PSMags > 0;

% psmags = PSMags(not(mask) & mPSMags); % background
psmags = PSMags(mask & mPSMags); % foreground

rm = median(psmags); % robust mean
rs = mad(psmags,1);
sigma = 1.4826*rs; % robust std

imgLoG = PSMags.*(PSMags > rm+alpha*sigma).*mask;
[rows,cols] = find(imgLoG);
locs = [rows cols];

end