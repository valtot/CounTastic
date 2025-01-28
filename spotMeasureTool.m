classdef spotMeasureTool < handle    
    properties
        Figure
        Axis
        Image
        ImageHandle
        BoxHandle
        MouseIsDown
        p0
        p1
        Dialog
        LowerThreshold
        UpperThreshold
    end
    
    methods
        function tool = spotMeasureTool(I)            
% spotMeasureTool(I)
% A tool to measure the size of a spot by fitting a 2d gaussian to it.
% Input image I should be double, in range [0,1].
% Example:
%   I = webread('https://upload.wikimedia.org/wikipedia/commons/4/44/Ngc6397_hst_blue_straggler.jpg');
%   I = im2double(rgb2gray(I));
%   spotMeasureTool(I)

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
            tool.Image = I;
            
            tool.Figure = figure(...%'MenuBar','none', ...
                                 'NumberTitle','off', ...
                                 'Name','Spot Measure Bot', ...
                                 'CloseRequestFcn',@tool.closeFigure, ...
                                 'WindowButtonMotionFcn', @tool.mouseMove, ...
                                 'WindowButtonDownFcn', @tool.mouseDown, ...
                                 'WindowButtonUpFcn', @tool.mouseUp, ...
                                 'Resize','on');
            tool.Axis = axes('Parent',tool.Figure);
            tool.ImageHandle = imshow(tool.Image);
            hold on
            tool.BoxHandle = plot([-2 -1],[-2 -1],'-y'); % placeholder, outside view, just to get BoxHandle
            hold off
            tool.MouseIsDown = false;

            
            dwidth = 200;
            dborder = 10;
            cwidth = dwidth-2*dborder;
            cheight = 20;
            
            tool.Dialog = dialog('WindowStyle', 'normal',...
                                'Name', 'Thresholds',...
                                'CloseRequestFcn', @tool.closeDialog,...
                                'Position',[100 100 dwidth 3*dborder+2*cheight]);
            
            % upper threshold slider
            tool.UpperThreshold = 1;
            Slider = uicontrol('Parent',tool.Dialog,'Style','slider','Min',0,'Max',1,'Value',tool.UpperThreshold,'Position',[dborder dborder cwidth cheight],'Callback',@tool.sliderManage,'Tag','uts');
            addlistener(Slider,'Value','PostSet',@tool.continuousSliderManage);
                            
            % lower threshold slider
            tool.LowerThreshold = 0;
            Slider = uicontrol('Parent',tool.Dialog,'Style','slider','Min',0,'Max',1,'Value',tool.LowerThreshold,'Position',[dborder 2*dborder+cheight cwidth cheight],'Callback',@tool.sliderManage,'Tag','lts');
            addlistener(Slider,'Value','PostSet',@tool.continuousSliderManage);
            
            uiwait(msgbox({'Draw a rectangle around a spot', 'to estimate sigma of fitting gaussian.'},'Hint','modal'));
            
%             uiwait(tool.Dialog)
        end
        
        function sliderManage(tool,src,callbackdata)
%             disp(src.Value)
        end
        
        function continuousSliderManage(tool,src,callbackdata)
            tag = callbackdata.AffectedObject.Tag;
            value = callbackdata.AffectedObject.Value;
            if strcmp(tag,'uts')
                tool.UpperThreshold = value;
            elseif strcmp(tag,'lts')
                tool.LowerThreshold = value;
            end
            I = tool.Image;
            I(I < tool.LowerThreshold) = tool.LowerThreshold;
            I(I > tool.UpperThreshold) = tool.UpperThreshold;
            I = I-min(I(:));
            I = I/max(I(:));
            tool.ImageHandle.CData = I;
        end
        
        function closeDialog(tool,src,callbackdata)
            delete(tool.Figure);
            delete(tool.Dialog);
        end
        
        function closeFigure(tool,src,callbackdata)
            delete(tool.Figure);
            delete(tool.Dialog);
        end
        
        function mouseMove(tool,src,callbackdata)
            if tool.MouseIsDown
                p = tool.Axis.CurrentPoint;
                col = round(p(1,1));
                row = round(p(1,2));

                if row > 0 && row <= size(tool.Image,1) && col > 0 && col <= size(tool.Image,2)
                    row0 = tool.p0(1);
                    col0 = tool.p0(2);

                    rowA = min(row0,row);
                    rowB = max(row0,row);
                    colA = min(col0,col);
                    colB = max(col0,col);

                    set(tool.BoxHandle,'XData',[colA colB colB colA colA],'YData',[rowA rowA rowB rowB rowA]);
                else
                    tool.MouseIsDown = false;
                    tool.p0 = [];
                    tool.p1 = [];
                end
            end
        end
        
        function mouseDown(tool,src,callbackdata)
            p = tool.Axis.CurrentPoint;
            col = round(p(1,1));
            row = round(p(1,2));
            if row > 0 && row <= size(tool.Image,1) && col > 0 && col <= size(tool.Image,2)
                tool.p0 = [row; col];
                tool.MouseIsDown = true;
            end
        end
        
        function mouseUp(tool,src,callbackdata)
            p = tool.Axis.CurrentPoint;
            col = round(p(1,1));
            row = round(p(1,2));
            if row > 0 && row <= size(tool.Image,1) && col > 0 && col <= size(tool.Image,2)
                tool.p1 = [row; col];
                tool.MouseIsDown = false;
                
                set(tool.BoxHandle,'XData',[],'YData',[]);
                
                tool.fitGauss2D();
            end
            tool.p0 = [];
            tool.p1 = [];
        end
        
        function fitGauss2D(tool)
            if ~isempty(tool.p0) && ~isempty(tool.p1)
                pA = tool.p0; pB = tool.p1;
                rowA = min(pA(1),pB(1));
                rowB = max(pA(1),pB(1));
                colA = min(pA(2),pB(2));
                colB = max(pA(2),pB(2));
                BI = tool.Image(rowA:rowB,colA:colB);
                [y,x] = meshgrid(1:size(BI,2),1:size(BI,1));
                [fitresult, zfit, fiterr, zerr, resnorm, rr] = fmgaussfit(x,y,BI);
                evalFit(x,y,BI,zfit,fitresult)
            end
        end
    end
    
    methods (Static)
        function staticFitGauss2D(ImCrop)
            [y,x] = meshgrid(1:size(ImCrop,2),1:size(ImCrop,1));
            [fitresult, zfit, fiterr, zerr, resnorm, rr] = fmgaussfit(x,y,ImCrop);
            evalFit(x,y,ImCrop,zfit,fitresult)
        end
    end
end

function evalFit(x,y,z,zfit,fitresult)

scsz = get(0,'ScreenSize'); % scsz = [left botton width height]
figure('Position',[scsz(3)/4 scsz(4)/4 scsz(3)/2 scsz(4)/2],'NumberTitle','off','Name','Gauss Fit')

sigma = 0.5*(fitresult(3)+fitresult(4));
zlog = -fspecial('log',[size(x,1) size(x,2)], sigma);

zmin = min(min(z(:)),min(zfit(:)));
zmax = max(max(z(:)),max(zfit(:)));
zlog = (zlog-min(zlog(:)))/(max(zlog(:))-min(zlog(:)))*(zmax-zmin)+zmin;

ax1 = subplot(1,3,1);
surf(x,y,z), title('spot')
axis([min(x(:)) max(x(:)) min(y(:)) max(y(:)) zmin zmax]), axis off

ax2 = subplot(1,3,2);
surf(x,y,zfit), title(sprintf('gauss fit | estimated sigma: %.02f', sigma))
% surf(x,y,zfit), title('gauss fit')
axis([min(x(:)) max(x(:)) min(y(:)) max(y(:)) zmin zmax]), axis off

ax3 = subplot(1,3,3);
surf(x,y,zlog), title(sprintf('log fit | estimated sigma: %.02f', sigma))
% surf(x,y,zlog), title('log fit')
axis([min(x(:)) max(x(:)) min(y(:)) max(y(:)) zmin zmax]), axis off

Link = linkprop([ax1, ax2, ax3], ...
       {'CameraUpVector', 'CameraPosition', 'CameraTarget'});
setappdata(gcf, 'StoreTheLink', Link);

rotate3d on

end

% ----------------------------------------------------------------------------------------------------
% code from here on developed by Nathan Orloff
% source: https://www.mathworks.com/matlabcentral/fileexchange/41938-fit-2d-gaussian-with-optimization-toolbox
% license:
%
% Copyright (c) 2013, Nathan Orloff
% All rights reserved.
% 
% Redistribution and use in source and binary forms, with or without
% modification, are permitted provided that the following conditions are
% met:
% 
%     * Redistributions of source code must retain the above copyright
%       notice, this list of conditions and the following disclaimer.
%     * Redistributions in binary form must reproduce the above copyright
%       notice, this list of conditions and the following disclaimer in
%       the documentation and/or other materials provided with the distribution
% 
% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
% AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
% IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
% ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
% LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
% CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
% SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
% INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
% CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
% ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
% POSSIBILITY OF SUCH DAMAGE.
% ----------------------------------------------------------------------------------------------------

function [fitresult, zfit, fiterr, zerr, resnorm, rr] = fmgaussfit(xx,yy,zz)
% FMGAUSSFIT Create/alter optimization OPTIONS structure.
%   [fitresult,..., rr] = fmgaussfit(xx,yy,zz) uses ZZ for the surface 
%   height. XX and YY are vectors or matrices defining the x and y 
%   components of a surface. If XX and YY are vectors, length(XX) = n and 
%   length(YY) = m, where [m,n] = size(Z). In this case, the vertices of the
%   surface faces are (XX(j), YY(i), ZZ(i,j)) triples. To create XX and YY 
%   matrices for arbitrary domains, use the meshgrid function. FMGAUSSFIT
%   uses the lsqcurvefit tool, and the OPTIMZATION TOOLBOX. The initial
%   guess for the gaussian is places at the maxima in the ZZ plane. The fit
%   is restricted to be in the span of XX and YY.
%   See:
%       http://en.wikipedia.org/wiki/Gaussian_function
%          
%   Examples:
%     To fit a 2D gaussian:
%       [fitresult, zfit, fiterr, zerr, resnorm, rr] =
%       fmgaussfit(xx,yy,zz);
%   See also SURF, OMPTMSET, LSQCURVEFIT, NLPARCI, NLPREDCI.

%   Copyright 2013, Nathan Orloff.

%% Condition the data
[xData, yData, zData] = prepareSurfaceData( xx, yy, zz );
xyData = {xData,yData};

%% Set up the startpoint
[amp, ind] = max(zData); % amp is the amplitude.
xo = xData(ind); % guess that it is at the maximum
yo = yData(ind); % guess that it is at the maximum
ang = 45; % angle in degrees.
sy = 1;
sx = 1;
zo = median(zData(:))-std(zData(:));
xmax = max(xData)+2;
ymax = max(yData)+2;
xmin = min(xData)-2;
ymin = min(yData)-2;

%% Set up fittype and options.
Lower = [0, 0, 0, 0, xmin, ymin, 0];
Upper = [Inf, 180, Inf, Inf, xmax, ymax, Inf]; % angles greater than 90 are redundant
StartPoint = [amp, ang, sx, sy, xo, yo, zo];%[amp, sx, sxy, sy, xo, yo, zo];

tols = 1e-16;
options = optimset('Algorithm','trust-region-reflective',...
    'Display','off',...
    'MaxFunEvals',5e2,...
    'MaxIter',5e2,...
    'TolX',tols,...
    'TolFun',tols,...
    'TolCon',tols ,...
    'UseParallel','never');

%% perform the fitting
[fitresult,resnorm,residual] = ...
    lsqcurvefit(@gaussian2D,StartPoint,xyData,zData,Lower,Upper,options);
[fiterr, zfit, zerr] = gaussian2Duncert(fitresult,residual,xyData);
rr = rsquared(zData, zfit, zerr);
zfit = reshape(zfit,size(zz));
zerr = reshape(zerr,size(zz));

end

function rr = rsquared(z,zf,ze)
% reduced chi-squared
dz = z-zf;
rr = 1./(numel(z)-8).*sum(dz.^2./ze.^2); % minus 8 because there are 7 fit parameters +1 (DOF)
end

function z = gaussian2D(par,xy)
% compute 2D gaussian
z = par(7) + ...
    par(1)*exp(-(((xy{1}-par(5)).*cosd(par(2))+(xy{2}-par(6)).*sind(par(2)))./par(3)).^2-...
    ((-(xy{1}-par(5)).*sind(par(2))+(xy{2}-par(6)).*cosd(par(2)))./par(4)).^2);
end

function [dpar,zf,dzf] = gaussian2Duncert(par,resid,xy)
% get the confidence intervals
J = guassian2DJacobian(par,xy);
parci = nlparci(par,resid,'Jacobian',J);
dpar = (diff(parci,[],2)./2)';
[zf,dzf] = nlpredci(@gaussian2D,xy,par,resid,'Jacobian',J);
end

function J = guassian2DJacobian(par,xy)
% compute the jacobian
x = xy{1}; y = xy{2};
J(:,1) = exp(- (cosd(par(2)).*(x - par(5)) + sind(par(2)).*(y - par(6))).^2./par(3).^2 - (cosd(par(2)).*(y - par(6)) - sind(par(2)).*(x - par(5))).^2./par(4).^2);
J(:,2) = -par(1).*exp(- (cosd(par(2)).*(x - par(5)) + sind(par(2)).*(y - par(6))).^2./par(3).^2 - (cosd(par(2)).*(y - par(6)) - sind(par(2)).*(x - par(5))).^2./par(4).^2).*((2.*(cosd(par(2)).*(x - par(5)) + sind(par(2)).*(y - par(6))).*(cosd(par(2)).*(y - par(6)) - sind(par(2)).*(x - par(5))))./par(3).^2 - (2.*(cosd(par(2)).*(x - par(5)) + sind(par(2)).*(y - par(6))).*(cosd(par(2)).*(y - par(6)) - sind(par(2)).*(x - par(5))))./par(4).^2);
J(:,3) = (2.*par(1).*exp(- (cosd(par(2)).*(x - par(5)) + sind(par(2)).*(y - par(6))).^2./par(3).^2 - (cosd(par(2)).*(y - par(6)) - sind(par(2)).*(x - par(5))).^2./par(4).^2).*(cosd(par(2)).*(x - par(5)) + sind(par(2)).*(y - par(6))).^2)./par(3)^3;
J(:,4) = (2.*par(1).*exp(- (cosd(par(2)).*(x - par(5)) + sind(par(2)).*(y - par(6))).^2./par(3).^2 - (cosd(par(2)).*(y - par(6)) - sind(par(2)).*(x - par(5))).^2./par(4).^2).*(cosd(par(2)).*(y - par(6)) - sind(par(2)).*(x - par(5))).^2)./par(4)^3;
J(:,5) = par(1).*exp(- (cosd(par(2)).*(x - par(5)) + sind(par(2)).*(y - par(6))).^2./par(3).^2 - (cosd(par(2)).*(y - par(6)) - sind(par(2)).*(x - par(5))).^2./par(4).^2).*((2.*cosd(par(2)).*(cosd(par(2)).*(x - par(5)) + sind(par(2)).*(y - par(6))))./par(3).^2 - (2.*sind(par(2)).*(cosd(par(2)).*(y - par(6)) - sind(par(2)).*(x - par(5))))./par(4).^2);
J(:,6) = par(1).*exp(- (cosd(par(2)).*(x - par(5)) + sind(par(2)).*(y - par(6))).^2./par(3).^2 - (cosd(par(2)).*(y - par(6)) - sind(par(2)).*(x - par(5))).^2./par(4).^2).*((2.*cosd(par(2)).*(cosd(par(2)).*(y - par(6)) - sind(par(2)).*(x - par(5))))./par(4).^2 + (2.*sind(par(2)).*(cosd(par(2)).*(x - par(5)) + sind(par(2)).*(y - par(6))))./par(3).^2);
J(:,7) = ones(size(x));
end


