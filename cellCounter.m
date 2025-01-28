classdef cellCounter < handle
    properties
        fig_image
        fig_ui

        ax_image
        imgHandle
        pointHandle
        blackSlider
        whiteSlider
        selectRoi
        rotationSlider
        listener

        edtSigma
        edtBright
        edtRound

        imgName
        imageData           % Original loaded image
        mask
        pointsCoord = []    % List of (XY) raw points coordinates
        roi_delPoints = []  % handle of the ROI object for deleting points
        radiusDelPoints = 10
        roiRect
        mutex
        imSize

        modes = {'explore','count'};    % List of app mode names
        mode = 1;                       % app mode. Can be 1 (explore) or 2 (count)


        % Default values for the app
        defVals = struct('blackValue',0,...
            'whiteValue', .7,...
            'saveResizedMask', false,...
            'resizeFactorIm',1,...
            'resizeFactorMask',1,...
            'csvPath',[],...
            'saveCsvPath',[],...
            'saveMaskPath',[],...
            'ROIPath',[],...
            'loadImgPath',[]);
    end

    methods(Access= public)
        %------------------------------------------------------------------
        % CLASS CONSTRUCTOR METHOD
        %------------------------------------------------------------------
        function app = cellCounter(imagePath)
            % app = cellCounter()
            % app = cellCounter(imagePath)
            %
            % cellCounter is a GUI for interactive automatic counting of
            % cells and for the manual refinement of the automatic count


            % Arguments validation
            arguments
                imagePath char = 'coins.png' % Load default Image
            end

            [~, app.imgName, ~] = fileparts(imagePath);
            app.imageData = imread(imagePath);
            app.mask = ones(size(app.imageData));
            screenSize =  get(0, 'ScreenSize');


            % Initialize a mutex to prevent conflicts between functions
            app.mutex = java.util.concurrent.Semaphore(1);

            %--------------------------------------------------------------
            % Main Image figure
            %--------------------------------------------------------------
            width = 1200;
            heigth = 800;
            app.fig_image = figure('Color',[0.1,0.1,0.1],...
                'Position',[(screenSize(3)-width)/2 (screenSize(4)-heigth)/2 width heigth],...
                'Name','Cell Counter',...
                'NumberTitle','off',...
                'WindowKeyPressFcn', @app.keyParser,...
                'CloseRequestFcn',@app.closeFunction,...
                'Pointer','hand');
            % Create the axes
            app.ax_image = axes('Parent',app.fig_image,...
                'Units','normalized',...
                'Position',[0 0 1 .95]);
            % Plot image
            app.imgHandle = imshow(imadjust(app.imageData, [app.defVals.blackValue,app.defVals.whiteValue], [0,1]),...
                'Parent', app.ax_image);

            % For graphical design
            app.ax_image.Title.String = upper(app.modes{app.mode});
            app.ax_image.Title.FontSize = 16;
            app.ax_image.Title.Color = [0,.7,.7];

            % For interactivity
            app.imgHandle.HitTest = 'off';      % The image wont catch button press events
            app.ax_image.PickableParts = 'all'; % The axis will be clickable


            %--------------------------------------------------------------
            % UI and options figure
            %--------------------------------------------------------------
            width = 450;
            heigth = 660;
            app.fig_ui = uifigure('Resize', 'off',...
                'Name', 'Control panel',...
                'NumberTitle','off',...
                'Position',[25, (screenSize(4)-heigth-50), width, heigth],...
                'CloseRequestFcn',@app.closeFunction);
            grid = uigridlayout(app.fig_ui,...
                'ColumnWidth',{'1x','1x'},...
                'RowHeight',{'1x','7x','6x', '4x'});

            loadImgBtn = uibutton('Parent',grid,'Text','LOAD IMAGE',...
                'FontWeight','bold','ButtonPushedFcn',@app.loadImage);
            loadImgBtn.Layout.Row = 1;

            p1 = uipanel('Title','Keyboard shortcuts', 'Parent',grid);
            p1.Layout.Column = 1;
            p1.Layout.Row = 2;
            g1 = uigridlayout(p1,...
                'ColumnWidth',{'1x','1x'},...
                'RowHeight',{'fit','fit','fit','fit','fit','fit'});
            % TEXT
            uilabel('Parent',g1,'Text','SPACEBAR:','FontWeight','bold',...
                'HorizontalAlignment','right');
            uilabel('Parent',g1,'Text','Switch mode');
            uilabel('Parent',g1,'Text','D:','FontWeight','bold',...
                'HorizontalAlignment','right');
            uilabel('Parent',g1,'Text','remove cells');
            uilabel('Parent',g1,'Text','T:','FontWeight','bold',...
                'HorizontalAlignment','right');
            uilabel('Parent',g1,'Text','Toggle Cells');
            uilabel('Parent',g1,'Text','R :','FontWeight','bold',...
                'HorizontalAlignment','right');
            uilabel('Parent',g1,'Text','Draw ROI');
            uilabel('Parent',g1,'Text','F:','FontWeight','bold',...
                'HorizontalAlignment','right');
            uilabel('Parent',g1,'Text','Flip ROI');
            uilabel('Parent',g1,'Text','M :','FontWeight','bold',...
                'HorizontalAlignment','right');
            uilabel('Parent',g1,'Text','Draw Mask');
            uilabel('Parent',g1,'Text','ENTER:','FontWeight','bold',...
                'HorizontalAlignment','right');
            uilabel('Parent',g1,'Text','ROI to Mask');


            p2 = uipanel('Title','Cell count', 'Parent',grid);
            p2.Layout.Column = 2;
            p2.Layout.Row = [1 2];
            g2 = uigridlayout(p2,...
                'ColumnWidth',{'2x','1x', '3x'},...
                'RowHeight',{'1x','1x','fit','fit','fit','1x'});
            % LOAD CSV
            loadBtn = uibutton('Parent',g2,'Text','Load from CSV',...
                'ButtonPushedFcn',@app.loadCSV);
            loadBtn.Layout.Column = [1,3];


            % COUNT CELLs
            autoCBtn = uibutton('Parent',g2,'Text','Auto Count Cells',...
                'ButtonPushedFcn',@app.autoCount);
            autoCBtn.Layout.Column = [1,3];

            % COUNT CELLs
            estimateSigmaBtn = uibutton('Parent',g2,'Text','measure',...
                'ButtonPushedFcn',@app.measureSigma);
            estimateSigmaBtn.Layout.Column = 1;


            app.edtSigma = uieditfield(g2,'numeric','Value',4,'Limits',[1 20],...
                'FontSize',10);
            app.edtSigma.Layout.Column = 2;
            uilabel('Parent',g2,'Text','Sigma (cell size)','FontSize',10);

            app.edtBright = uieditfield(g2,'numeric','Value',6,'Limits',[1 100],...
                'FontSize',10);
            app.edtBright.Layout.Column = [1,2];
            uilabel('Parent',g2,'Text','Brightness [1 100]','FontSize',10);

            app.edtRound = uieditfield(g2,'numeric','Value',0.65,'Limits',[-1 1],...
                'FontSize',10);
            app.edtRound.Layout.Column = [1,2];
            uilabel('Parent',g2,'Text','Roundness [-1 1]','FontSize',10);

            saveBtn = uibutton('Parent',g2,'Text','Save Cell Count to CSV','ButtonPushedFcn',@app.saveCSV);
            saveBtn.Layout.Column = [1,3];

            p3 = uipanel('Title','ROI management', 'Parent',grid);
            p3.Layout.Column = [1,2];
            p3.Layout.Row = 3;
            g3 = uigridlayout('Parent',p3,...
                'ColumnWidth',{'1x','1x'},...
                'RowHeight',{'1x', '2x','2x','2x'});

            lb1 = uilabel('Parent',g3, "Text","ROI type");
            lb1.Layout.Column = 1;
            lb2 = uilabel('Parent',g3, "Text","ROI orientation");
            lb2.Layout.Column = 2;
            app.selectRoi = uiswitch('Parent',g3, 'Items',{'Rectangle','Freehand'} , 'Orientation','horizontal', 'Enable',false);
            app.selectRoi.Layout.Column = 1;
            app.selectRoi.Layout.Row = 2;

            app.rotationSlider = uislider('Parent',g3, 'Limits',[0 360] ,'MajorTicks',[0 90 180 270  360], ...
                'Orientation','horizontal', 'ValueChangedFcn',@app.rotateRoi,'ValueChangingFcn',@app.rotateRoi);
            app.rotationSlider.Layout.Column = 2;
            app.rotationSlider.Layout.Row = 2;

            loadRoiBtn = uibutton('Parent',g3,'Text','Load ROI','ButtonPushedFcn',@app.loadRoi);
            loadRoiBtn.Layout.Column = 1;
            loadRoiBtn.Layout.Row = 3;


            saveBtn = uibutton('Parent',g3,'Text','Load Mask','ButtonPushedFcn',@app.loadMask);
            saveBtn.Layout.Column = 2;
            saveRoiBtn = uibutton('Parent',g3,'Text','Save ROI','ButtonPushedFcn',@app.saveRoi);
            saveRoiBtn.Layout.Column = 1;
            saveBtn = uibutton('Parent',g3,'Text','Save Mask','ButtonPushedFcn',@app.saveMask);
            saveBtn.Layout.Column = 2;


            p4 = uipanel('Title','Adjust Image Brightness', 'Parent',grid);
            p4.Layout.Column = [1,2];
            p4.Layout.Row = 4;
            g4 = uigridlayout('Parent',p4,...
                'ColumnWidth',{'1x','5x'},...
                'RowHeight',{'1x', '1x'});

            % Black Control Slider
            lbBlack = uilabel('Parent',g4,'Text','Black');
            app.blackSlider = uislider('Parent', g4,...
                'Value', app.defVals.blackValue,...
                'Limits', [0, 1],...
                'Tag','blkSl',...
                'ValueChangedFcn',@app.luminanceManager);
            lbBlack.Layout.Column = 1;
            lbBlack.Layout.Row = 1;

            app.blackSlider.Layout.Column = 2;
            app.blackSlider.Layout.Row = 1;
            % White Control Slider
            lbWhite= uilabel('Parent',g4,'Text','White');
            app.whiteSlider = uislider('Parent', g4,...
                'Value', app.defVals.whiteValue,...
                'Limits', [0, 1],...
                'Tag','whtSl',...
                'ValueChangedFcn',@app.luminanceManager);

            lbWhite.Layout.Column = 1;
            lbWhite.Layout.Row = 2;
            app.whiteSlider.Layout.Column = 2;
            app.whiteSlider.Layout.Row = 2;
        end


        %------------------------------------------------------------------
        % CLASS METHODS
        %------------------------------------------------------------------

        function addPoint_callback(app,~,event)
            if event.Button == 1 % Left Click (add a new point)
                newPoint = ceil(event.IntersectionPoint(1:2));
                app.pointsCoord = [app.pointsCoord; newPoint];
                app.updateGraphics()
            elseif event.Button == 3 % Right click (remove points)
                %create a circle polygon
                C = ceil(event.IntersectionPoint(1:2)); % center
                theta = 0: 2*pi/20 :2*pi; % the angle
                circCoord = app.radiusDelPoints * [cos(theta') sin(theta')] + C;
                toDelete = inpolygon(app.pointsCoord(:,1),app.pointsCoord(:,2),circCoord(:,1),circCoord(:,2));
                app.pointsCoord(toDelete,:) = [];
                app.updateGraphics()
            end

        end

        function keyParser(app,~,event)
            key = event.Key;
            switch key
                case 'space' % Toggle app mode Explore<->Count
                    toggleAppMode(app)
                case 'd' % Delete points inside the ROI
                    app.deletePoints();
                case 'm'
                    app.drawMask();
                case 't'
                    app.pointHandle.Visible = ~app.pointHandle.Visible;
                case 'r'
                    app.drawRoi();
                case 'return'
                    app.roi2Mask()
            end
        end

        function toggleAppMode(app)
            app.mode = mod((app.mode), length(app.modes)) + 1;
            if app.mode == 1
                app.ax_image.ButtonDownFcn = [];
                app.ax_image.Title.Color = [0 .7 .7];
                app.fig_image.Pointer = 'hand';
            elseif app.mode == 2
                app.ax_image.ButtonDownFcn = @app.addPoint_callback;
                app.ax_image.Title.Color = [.7 0 0];
                app.fig_image.Pointer = 'crosshair';
            end
            newTit = upper(app.modes{app.mode});
            app.ax_image.Title.String = newTit;
        end

        function deletePoints(app,~,~)
            app.roi_delPoints = drawfreehand(app.ax_image);
            poly = cat(2,app.roi_delPoints.Position(:,1),app.roi_delPoints.Position(:,2));
            toDelete = inpolygon(app.pointsCoord(:,1),app.pointsCoord(:,2),poly(:,1),poly(:,2));
            app.pointsCoord(toDelete,:) = [];
            app.updateGraphics();
            fprintf([ char(datetime('now','TimeZone','local','Format','yyMMdd-HHmm', 'Locale','it_IT')) '- deleted %u cells.\n'], sum(toDelete))
        end

        function updateGraphics(app)
            % Delete the freehand selection for deleting points
            if ishandle(app.roi_delPoints)
                delete(app.roi_delPoints)
            end
            % Delete Roi of the rectangle
            if ishandle(app.roiRect)
                delete(app.roiRect)
            end
            % Delete all drawn points if present
            if ishandle(app.pointHandle)
                delete(app.pointHandle)
            end
            % Redraw all the points
            if ~isempty(app.pointsCoord)
                hold(app.ax_image,'on')
                app.pointHandle = plot(app.pointsCoord(:,1),app.pointsCoord(:,2),...
                    'LineStyle','none','Marker','.','LineWidth',1.1,...
                    'MarkerEdgeColor',[1,0,0],'MarkerSize',12);
                app.pointHandle.HitTest = 'off';
                hold(app.ax_image,'off')
            end
            drawnow
        end

        function luminanceManager(app,src,valueChangedData)
            if strcmp(valueChangedData.Source.Tag, 'blkSl')
                if valueChangedData.Value >= app.whiteSlider.Value
                    src.Value = valueChangedData.PreviousValue;
                    return
                end
                newImage = imadjust(app.imageData,...
                    [valueChangedData.Value, app.whiteSlider.Value],...
                    [0,1]);
                app.imgHandle.CData = newImage;
            elseif strcmp(valueChangedData.Source.Tag, 'whtSl')
                if valueChangedData.Value <= app.blackSlider.Value
                    src.Value = valueChangedData.PreviousValue;
                    return
                end
                newImage = imadjust(app.imageData,...
                    [app.blackSlider.Value, valueChangedData.Value],...
                    [0,1]);
                app.imgHandle.CData = newImage;
            end
        end

        function loadImage(app,~,~)
            tit = 'Choose an Image to count.';
            [file,path] = uigetfile('*',tit, app.defVals.loadImgPath);
            if file ~= 0
                hiresIm = imread([path filesep file]);
                im = imresize(hiresIm,app.defVals.resizeFactorIm);
                app.imSize = size(hiresIm,[1,2]);
%                 if size(im,3) > 1
%                     im = rgb2gray(im);
%                 end
                app.imageData = im;
                [~,app.imgName,~] = fileparts(file);
                newImage = imadjust(app.imageData,...
                    [app.blackSlider.Value, app.whiteSlider.Value],...
                    [0,1]);
                app.imgHandle.AlphaData = ones(size(newImage,[1,2]));
                app.mask = ones(size(newImage));
                app.imgHandle.CData = newImage;
                app.ax_image.XLim = [0 size(newImage,2)];
                app.ax_image.YLim = [0 size(newImage,1)];
                app.pointsCoord = [];
                app.defVals.loadImgPath = path;
                app.updateGraphics()
                fprintf([ char(datetime('now','TimeZone','local','Format','yyMMdd-HHmm', 'Locale','it_IT')) '>>> Image: %s Loaded \n'], app.imgName)
                app.fig_image.Name = ['Current Image:' app.imgName];

            end
        end

        function loadCSV(app,~,~)
            tit = 'Choose a CSV file with an existing cell count.';
            [file,path] = uigetfile('*.csv',tit,app.defVals.csvPath);
            if file ~= 0
                try
                    t = readtable([path filesep file]);
                    t.Properties.VariableNames = lower(t.Properties.VariableNames);
                    app.pointsCoord = cat(2, t.x, t.y);
                    app.defVals.csvPath = path;
                    app.updateGraphics();
                    fprintf([ char(datetime('now','TimeZone','local','Format','yyMMdd-HHmm', 'Locale','it_IT')) '>>> Cells in "%s" loaded!\n'], file)
                catch ME
                    fprintf('UNABLE TO LOAD FILE.\n')
                    fprintf('The following error occurred: %s\nMESSAGE: %s\n', ME.identifier, ME.message)
                end
            end

        end

        function saveCSV(app,~,~)
            if isempty(app.pointsCoord)
                fprintf('UNABLE TO SAVE FILE.\nNo cells have been counted yet.\n')
                return
            end
            defName = [app.imgName '.csv'];
            %defName = [app.imgName '_' datestr(now,'yymmdd-hhMM') '.csv'];
            tit = 'Select a file to save the current cell count';
            [file, path] = uiputfile('*', tit, [app.defVals.saveCsvPath filesep defName]);
            if file ~= 0
                t = table(app.pointsCoord(:,1)*(1/app.defVals.resizeFactorIm),app.pointsCoord(:,2)*(1/app.defVals.resizeFactorIm),...
                    'VariableNames',{'x','y'});
                writetable(t,[path filesep file])
                fprintf([char(datetime('now','TimeZone','local','Format','yyMMdd-HHmm', 'Locale','it_IT')) '>>> Cells saved in "%s"!\n'], file)
                app.defVals.saveCsvPath = path;
            end
        end

        function drawMask(app,~,~)
            app.imgHandle.AlphaData = ones(size(app.imageData,[1,2]));
            roi = drawfreehand(app.ax_image);
            app.roiRect = roi;
%             app.mask = roi.createMask();
%             app.imgHandle.AlphaData = (~app.mask).*0.3 + app.mask;
%             delete(roi)
%             fprintf('Selected ROI. Total area: %u pixels.\n', sum(app.mask(:)))
        end


        function drawRoi(app,~,~)
            roi = drawrectangle(app.ax_image, Rotatable=true);

%             roi = drawfreehand(app.ax_image);
            app.updateGraphics()
            app.roiRect = roi;
            app.listener = addlistener(app.roiRect,'MovingROI',@(src,evt) updateSlider(app, src,evt));
            fprintf('Drawn Rectangular ROI\n');
        end

        function roi2Mask(app, ~,~)
%             if isa(app.roiRect, 'images.roi.Rectangle')
                app.mask = app.roiRect.createMask();
                app.imgHandle.AlphaData = (~app.mask).*0.3 + app.mask;
                delete(app.roiRect)
                fprintf('Mask created. Total area: %u pixels.\n', sum(app.mask(:)))
%             end
        end

        function autoCount(app,~,~)
            app.fig_image.Pointer = 'watch';
            app.fig_ui.Pointer = 'watch';
            % Preprocessing Parameters
            gaussSigma = 20;
            topHatSize = 1;
            closeSize = 1;
            % Cell Detection Parameters
            sigma = app.edtSigma.Value;
            % 'distance to background distribution' threshold; decrease to detect more spots (range [0,~100])
            dist2BackDistThr =  app.edtBright.Value;
            % 'similarity to ideal spot' threshold; decrease to select more spots (range [-1,1])
            spotinessThreshold = app.edtRound.Value;

            %##### STEPS FOR CUSTOM CELL COUNT ######
            imProc = app.imageData - imgaussfilt(app.imageData,gaussSigma);
            imProc = imProc - imtophat(imProc,strel('disk',topHatSize));
            imProc = imclose(imProc,strel('disk',closeSize));
            %##### ORIGINAL STEPS FOR CFOS ######
            % imProc = app.imageData;

            [~,ptSrcImg] = logPSD(imProc, app.mask, sigma, dist2BackDistThr);
            ptSrcImg = selLogPSD(imProc, ptSrcImg, sigma, spotinessThreshold);

            [r,c] = find(ptSrcImg);
            app.pointsCoord = cat(2,c,r);

            app.updateGraphics();
            app.fig_image.Pointer = 'arrow';
            app.fig_ui.Pointer = 'arrow';
        end

        function loadRoi(app, ~, ~)
            if ~ishandle(app.imgHandle)
                warning('No image is present. No ROIs can be loaded')
                return
            end

            if  isa(app.roiRect, 'images.roi.Rectangle')
                warning('ROI already present. It will be overwritten.')
            end
            title = 'Choose a .mat file with a ROI.';
            [file,path] = uigetfile('*.mat',title,app.defVals.ROIPath);
            if file ~= 0
                try
                    matf = load([path filesep file]);
                    app.updateGraphics();
                    app.roiRect = drawrectangle('Position',matf.roi.Position, 'FixedAspectRatio',true, ...
                        'AspectRatio', matf.roi.AspectRatio,...
                        'RotationAngle',matf.roi.RotationAngle,...
                        'Rotatable',true,...
                        'InteractionsAllowed','none' , ...
                        'color', 'red' );
                    app.roiRect.InteractionsAllowed = 'translate';

                    addlistener(app.roiRect,'MovingROI',@( src,evt) app.blockResize(src, evt) );
                    fprintf([ char(datetime('now','TimeZone','local','Format','yyMMdd-HHmm', 'Locale','it_IT')) '>>> ROI in "%s" loaded!\n'], file)
                catch ME
                    fprintf('UNABLE TO LOAD FILE.\n')
                    fprintf('The following error occurred: %s\nMESSAGE: %s\n', ME.identifier, ME.message)
                end
            end
        end


        function loadMask(app, ~, ~)
            if ~ishandle(app.imgHandle)
                warning('No image is present. No Mask can be loaded')
                return
            end

            if  ishandle(app.mask)
                warning('Mask already present. It will be overwritten.')
            end
            title = 'Choose a .png file for the mask.';
            [file,path] = uigetfile('*.png',title,app.defVals.saveMaskPath);
            if file ~= 0
                try
                    maskfile = [path filesep file];
                    maskLoaded = imread(maskfile);
                    s = readJsonFile([path filesep replace(file, '.png', '.json')]);
                    if s.resizeFactorIm==1
                        maskLoaded = imresize(maskLoaded, size(app.imageData), 'nearest');
                    end
                    app.updateGraphics();
                    app.mask = maskLoaded;
                    app.imgHandle.AlphaData = (~app.mask).*0.3 + app.mask;

                catch ME
                    fprintf('UNABLE TO LOAD FILE.\n')
                    fprintf('The following error occurred: %s\nMESSAGE: %s\n', ME.identifier, ME.message)
                end
            end
        end

        function saveMask(app,~,~)

            defName = [app.imgName '_mask-'  char(datetime('now','TimeZone','local','Format','yyMMdd-HHmm', 'Locale','it_IT')) '.png'];
            tit = 'Select a file to save the current cell count';
            [file, path] = uiputfile('*.png', tit, [app.defVals.saveMaskPath filesep defName]);

            if file ~= 0
                s = struct('originalImSize', [],'resizeFactor',[],'totalAreaPx',[]);
                resizedMask = imresize(app.mask, app.imSize, 'nearest');
                s.totalAreaPx = sum(resizedMask,"all");
                s.originalImSize = app.imSize;
                if app.defVals.saveResizedMask
                    maskMatrix = app.mask;
                    s.originaImSize = app.defVals.resizeFactorIm*app.defVals.resizeFactorMask;

                else
                    maskMatrix = resizedMask;
                    s.resizeFactor = 1;

                end

                fid=fopen([path filesep replace(file, '.png', '.json')],'w') ;
                encodedJSON = jsonencode(s,PrettyPrint=true);
                fprintf(fid, encodedJSON);
                fclose(fid);
                imwrite(maskMatrix, [path filesep file])
                fprintf([ char(datetime('now','TimeZone','local','Format','yyMMdd-HHmm', 'Locale','it_IT')) 'Mask saved in "%s"!\n'], file)
                app.defVals.saveMaskPath = path;
            end
        end



        function saveRoi(app,~,~)
            defName = [app.imgName '_roi-'  char(datetime('now','TimeZone','local','Format','yyMMdd-HHmm', 'Locale','it_IT')) '.mat'];
            tit = 'Select a file to save the current cell count';
            [file, path] = uiputfile('*', tit, [app.defVals.ROIPath filesep defName]);

            if file ~= 0
                roi = app.roiRect;
                save([path filesep file], 'roi')
                fprintf([ char(datetime('now','TimeZone','local','Format','yyMMdd-HHmm', 'Locale','it_IT')) 'Roi saved in "%s"!\n'], file)
                app.defVals.ROIPath = path;
            end
        end

        function blockResize(app, ~,evt)
            app.mutex.acquire();
            previousPosition = evt.PreviousPosition;
            currentPosition = evt.CurrentPosition;

            if previousPosition(3) ~= currentPosition(3)||previousPosition(4) ~= currentPosition(4)
                app.roiRect.Position = previousPosition;
            end

            if evt.PreviousRotationAngle ~= evt.CurrentRotationAngle
                app.rotationSlider.Value = evt.CurrentRotationAngle;
            end
            app.mutex.release();
        end

        function updateSlider(app, ~, evt)
            % Acquire the mutex to prevent conflicts with other functions
            app.mutex.acquire();

            if evt.PreviousRotationAngle ~= evt.CurrentRotationAngle
                app.rotationSlider.Value = evt.CurrentRotationAngle;
            end
            app.mutex.release();

        end

        function rotateRoi(app, ~,~)
            app.mutex.acquire();
            if ishandle(app.roiRect)
                app.roiRect.RotationAngle = app.rotationSlider.Value;
            end
            app.mutex.release();

        end

        function measureSigma(app, ~,~)
            if ishandle(app.imgHandle)
                im = normalize(im2double(app.imageData));
                spotMeasureTool(im);
            end
        end

        function closeFunction(app,~,~)
            delete(app.fig_image)
            delete(app.fig_ui)
        end


    end
end