
classdef ic_OPTtools_data_controller < handle 
    
    % Copyright (C) 2023 Imperial College London.
    % All rights reserved.
    %
    % This program is free software; you can redistribute it and/or modify
    % it under the terms of the GNU General Public License as published by
    % the Free Software Foundation; either version 2 of the License, or
    % (at your option) any later version.
    %
    % This program is distributed in the hope that it will be useful,
    % but WITHOUT ANY WARRANTY; without even the implied warranty of
    % MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    % GNU General Public License for more details.
    %
    % You should have received a copy of the GNU General Public License along
    % with this program; if not, write to the Free Software Foundation, Inc.,
    % 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
    %
    % This software tool was developed with support from the UK 
    % Engineering and Physical Sciences Council 
    % through  a studentship from the Institute of Chemical Biology 
    % and The Wellcome Trust through a grant entitled 
    % "The Open Microscopy Environment: Image Informatics for Biological Sciences" (Ref: 095931).
   
% ??? WARNING on deletion: Warning: Objects of 'datetime' class exist.  Cannot clear this class or any of its superclasses.    
% With handle classes I have taken to maintaing a list in the figure appdata area 
% maintained by calling a common superclass method from the constructors, 
% and adding a DeleteFcn callback that calls a static superclass method 
% to delete any remaining valid handle objects when a figure closes. 
% A bit of a pain but it seems to work.    
    
    properties(Constant)
        data_settings_filename = strcat(fileparts(which('ic_OPTtools.m')),filesep,'opt_tools_data_settings.xml');
    end
    
    properties(SetObservable = true)
            
        downsampling = 1;
        angle_downsampling = 1; 
        Z_range = []; 
        FBP_interp = 'linear';
        FBP_filter = 'Ram-Lak';
        FBP_fscaling = 1;  
        
        Reconstruction_Method = 'FBP';
        Reconstruction_GPU = 'OFF';
        Reconstruction_Largo = 'OFF';
        
        Prefiltering_Size = 'None';
        mem_info = memory;

        Bleaching_correction = 'Off';
        
        batchsaveformat = '.tif';

        writeparameterfile = 'On';

        % TwIST
        TwIST_TAU = 0.0008; %1
        TwIST_LAMBDA = 1e-4; %2
        TwIST_ALPHA = 0; %3
        TwIST_BETA = 0; %4
        TwIST_STOPCRITERION = 1; %5
        TwIST_TOLERANCEA = 1e-4; %6      
        TwIST_TOLERANCED = 0.0001; %7
        TwIST_DEBIAS = 0; %8
        TwIST_MAXITERA = 10000; %9
        TwIST_MAXITERD = 200; %10
        TwIST_MINITERA = 5; %11
        TwIST_MINITERD = 5; %12
        TwIST_INITIALIZATION = 0; %13
        TwIST_MONOTONE = 1; %14
        TwIST_SPARSE = 1; %15
        TwIST_VERBOSE = 0; %16
        TwIST_TVITER = 10; %17
        TwIST_MAXSVD = 100; %18
        % TwIST        
        
        swap_XY_dimensions = 'Horizontal'; % 'Horizontal is default, and required for proper recon. Vertical will rotate proj before recon.
        registration_method = 'None'; % or "M1" - this is done on loading
        %
        imstack_filename_convention_for_angle = 'C1';
        %
        save_volume_bit_depth = 16; % default 
        %angularcoverage = 360;

        large_projections_batch = 'No';
        registration_shift = 0;
                
    end                    
    
    properties(Transient)
        
        DefaultDirectory = ['C:' filesep];
        IcyDirectory = [];
        noIcy = [];
        
        BatchDstDirectory = [];
        BatchSrcDirectory = [];        
        
        
        SrcDir = [];
        SrcFileList = [];
        DstDir = [];

        brightbgdir = [];
        darkbgdir = [];
        
        current_filename = []; % not sure
        
        file_names = [];
        omero_Image_IDs = [];
        
        previous_filenames = [];
        previous_omero_IDs = [];
        
        angles = []; 
        delays = []; % FLIM
        %
        FLIM_unit = 'ps';
        FLIM_typeDescription = 'Gated';
        
        % current_metadata = []; % ?
        PixelsPhysicalSizeX = []; % as in loaded original
        PixelsPhysicalSizeY = [];
        
        FLIM_proj_load_swap_XY_dimensions = false;
        M1_hshift = []; % registratin corrections kept for the case of re-usage for FLIM
        M1_vshift = [];
        M1_rotation = [];

        TwIST_testslice = 1;

        registration_rotation = 0;
                                        
    end    
        
    properties(Transient,Hidden)
        % Properties that won't be saved to a data_settings_file etc.
        
        menu_controller = [];
        
        isGPU;
        NumWorkers;
        
        proj; % native projection images (processed for co-registration and artifact correction)
        volm; % reconstructed volume
        brightbg;
        darkbg;
        avgproj;
        bleachcorrection;
        bleaching_batch = 'no';

        manual_reg = [];
        
        % memory mapping
        memmap_proj = [];
        memmap_volm = [];
        proj_mapfile_name = [];
        volm_mapfile_name = [];
        
        run_headless = false;
                                       
    end
    
    events
        new_proj_set;
        new_volm_set;
        proj_clear;
        volm_clear;
        proj_and_volm_clear;
    end
            
    methods
        
        function obj = ic_OPTtools_data_controller(RUN_HEADLESS,varargin)            
            %   
%             if ~isempty(varargin{1})
%                 handles = args2struct(varargin);
%                 assign_handles(obj,handles);
%             end

            obj.run_headless = RUN_HEADLESS;
                        
            addlistener(obj,'new_proj_set',@obj.on_new_proj_set);
            addlistener(obj,'new_volm_set',@obj.on_new_volm_set);                        
            addlistener(obj,'proj_clear',@obj.on_proj_clear);                        
            addlistener(obj,'volm_clear',@obj.on_volm_clear);            
            addlistener(obj,'proj_and_volm_clear',@obj.on_proj_and_volm_clear);                                    

            try 
            obj.load_settings([]);
            catch
            end
            
            if (ispc || ismac) && isempty(obj.IcyDirectory) && ~isdeployed && ~obj.run_headless && isempty(obj.noIcy)
                icysetupq = questdlg('Would you like to set up Icy integration?','Icy integration setup','Yes, automatically find Icy directory (PC only)',...
                    'Yes, manually select Icy directory','No, don''t use Icy','Yes, automatically find Icy directory (PC only)');
                switch icysetupq
                    case 'Yes, automatically find Icy directory (PC only)'
                        hw = waitbar(0,'looking for Icy directory..');
                        waitbar(0.1,hw);                
                        if ispc
                               prevdir = pwd;
                               cd('c:\');
                               [~,b] = dos('dir /s /b icy.exe');
                               if ~strcmp(b,'File Not Found')
                                    filenames = textscan(b,'%s','delimiter',char(10));
                                    s = char(filenames{1});
                                    s = s(1,:);
                                    s = strsplit(s,'icy.exe');
                                    obj.IcyDirectory = s{1};
                               end
                               cd(prevdir);
                        elseif ismac
                            errordlg('Sorry, automatic search for Icy directory not currently working for Mac users, please manually select your Icy directory.')
                            obj.IcyDirectory = uigetdir('c:\','Select Icy directory');
                            % to do properly
                        else
                            % to do
                        end                
                        delete(hw); drawnow;
                        addpath(strcat(obj.IcyDirectory,filesep,'plugins',filesep,'ylemontag',filesep,'matlabcommunicator'));
                        addpath(strcat(obj.IcyDirectory,filesep,'plugins',filesep,'ylemontag',filesep,'matlabxserver'));
                        icy_init();
                        return
                    case 'Yes, manually select Icy directory'
                        obj.IcyDirectory = uigetdir('c:\','Select Icy directory');
                        addpath(strcat(obj.IcyDirectory,filesep,'plugins',filesep,'ylemontag',filesep,'matlabcommunicator'));
                        addpath(strcat(obj.IcyDirectory,filesep,'plugins',filesep,'ylemontag',filesep,'matlabxserver'));
                        icy_init();
                        return
                    case 'No, don''t use Icy'
                        obj.noIcy = 1;
                        return
                end
            elseif ~isempty(obj.IcyDirectory) && isempty(obj.noIcy)
                %disp('Adding Icy paths')
                addpath(strcat(obj.IcyDirectory,filesep,'plugins',filesep,'ylemontag',filesep,'matlabcommunicator'));
                addpath(strcat(obj.IcyDirectory,filesep,'plugins',filesep,'ylemontag',filesep,'matlabxserver'));
                icy_init();
            end
            
            % detect GPU
            try
                isgpu = gpuDevice();
            catch    
            end                                  
            obj.isGPU = exist('isgpu','var');
            %
            % if there are more than 4 cores, one can try using parfor
            %par_pool = gcp;
            %obj.NumWorkers = par_pool.NumWorkers;
                                                            
        end
%-------------------------------------------------------------------------%
        function set_TwIST_settings_default(obj,~,~)        
            obj.TwIST_TAU = 0.0008; %1
            obj.TwIST_LAMBDA = 1e-4; %2
            obj.TwIST_ALPHA = 0; %3
            obj.TwIST_BETA = 0; %4
            obj.TwIST_STOPCRITERION = 1; %5
            obj.TwIST_TOLERANCEA = 1e-4; %6      
            obj.TwIST_TOLERANCED = 0.0001; %7
            obj.TwIST_DEBIAS = 0; %8
            obj.TwIST_MAXITERA = 10000; %9
            obj.TwIST_MAXITERD = 200; %10
            obj.TwIST_MINITERA = 5; %11
            obj.TwIST_MINITERD = 5; %12
            obj.TwIST_INITIALIZATION = 0; %13
            obj.TwIST_MONOTONE = 1; %14
            obj.TwIST_SPARSE = 1; %15
            obj.TwIST_VERBOSE = 0; %16
            obj.TwIST_TVITER = 10; %17
            obj.TwIST_MAXSVD = 100; %17;
        end
%-------------------------------------------------------------------------%                
        function save_settings(obj,~,~)        
            settings = [];
            settings.DefaultDirectory = obj.DefaultDirectory;
            settings.IcyDirectory = obj.IcyDirectory;
            settings.noIcy = obj.noIcy;
            settings.downsampling = obj.downsampling;
            settings.angle_downsampling = obj.angle_downsampling;            
            settings.FBP_interp = obj.FBP_interp;
            settings.FBP_filter = obj.FBP_filter;
            settings.FBP_fscaling = obj.FBP_fscaling;
            settings.batchsaveformat = obj.batchsaveformat;
            settings.writeparameterfile = obj.writeparameterfile;
            %settings.angularcoverage = obj.angularcoverage;
            
            settings.Reconstruction_Method =  obj.Reconstruction_Method;
            settings.Reconstruction_GPU =  obj.Reconstruction_GPU;
            settings.Reconstruction_Largo =  obj.Reconstruction_Largo;

            settings.Bleaching_correction = obj.Bleaching_correction;

            % TwIST
            settings.TwIST_TAU = obj.TwIST_TAU;
            settings.TwIST_LAMBDA = obj.TwIST_LAMBDA;
            settings.TwIST_ALPHA = obj.TwIST_ALPHA;
            settings.TwIST_BETA = obj.TwIST_BETA;
            settings.TwIST_STOPCRITERION = obj.TwIST_STOPCRITERION; 
            settings.TwIST_TOLERANCEA = obj.TwIST_TOLERANCEA; 
            settings.TwIST_TOLERANCED = obj.TwIST_TOLERANCED;
            settings.TwIST_DEBIAS = obj.TwIST_DEBIAS;
            settings.TwIST_MAXITERA = obj.TwIST_MAXITERA;
            settings.TwIST_MAXITERD = obj.TwIST_MAXITERD;
            settings.TwIST_MINITERA = obj.TwIST_MINITERA;
            settings.TwIST_MINITERD = obj.TwIST_MINITERD;
            settings.TwIST_INITIALIZATION = obj.TwIST_INITIALIZATION;
            settings.TwIST_MONOTONE = obj.TwIST_MONOTONE;
            settings.TwIST_SPARSE = obj.TwIST_SPARSE;
            settings.TwIST_VERBOSE = obj.TwIST_VERBOSE;
            settings.TwIST_TVITER = obj.TwIST_TVITER;
            settings.TwIST_MAXSVD = obj.TwIST_MAXSVD;
            % TwIST 
                        
            settings.Prefiltering_Size = obj.Prefiltering_Size;
            %
            settings.swap_XY_dimensions = obj.swap_XY_dimensions;
            settings.registration_method = obj.registration_method;
            settings.imstack_filename_convention_for_angle = obj.imstack_filename_convention_for_angle;
            %
            settings.save_volume_bit_depth = obj.save_volume_bit_depth;
            
            %xml_write([pwd filesep obj.data_settings_filename], settings);
            xml_write(obj.data_settings_filename, settings);
        end % save_settings
%-------------------------------------------------------------------------%                        
        function ret = load_settings(obj,filename,~)        
             ret = false;
             if isempty(filename)
                %filename = [pwd filesep obj.data_settings_filename];
                filename = [obj.data_settings_filename];
             end
             %
             try
             if exist(filename,'file')          
                [ settings, ~ ] = xml_read (filename);             
                %
                obj.DefaultDirectory = settings.DefaultDirectory;
                obj.IcyDirectory = settings.IcyDirectory;
                obj.noIcy = settings.noIcy;
                obj.downsampling = settings.downsampling;
                obj.angle_downsampling = settings.angle_downsampling;            
                obj.FBP_interp = settings.FBP_interp;
                obj.FBP_filter = settings.FBP_filter;
                obj.FBP_fscaling = settings.FBP_fscaling;
                obj.batchsaveformat = settings.batchsaveformat;
                obj.writeparameterfile = settings.writeparameterfile;
                %obj.angularcoverage = settings.angularcoverage;
                %
                obj.Reconstruction_Method = settings.Reconstruction_Method;
                obj.Reconstruction_GPU = settings.Reconstruction_GPU;
                obj.Reconstruction_Largo = settings.Reconstruction_Largo;
                obj.Bleaching_correction = settings.Bleaching_correction;
                % TwIST
                obj.TwIST_TAU = settings.TwIST_TAU;
                obj.TwIST_LAMBDA = settings.TwIST_LAMBDA;
                obj.TwIST_ALPHA = settings.TwIST_ALPHA;
                obj.TwIST_BETA = settings.TwIST_BETA;
                obj.TwIST_STOPCRITERION = settings.TwIST_STOPCRITERION;
                obj.TwIST_TOLERANCEA = settings.TwIST_TOLERANCEA;
                obj.TwIST_TOLERANCED = settings.TwIST_TOLERANCED;
                obj.TwIST_DEBIAS = settings.TwIST_DEBIAS;
                obj.TwIST_MAXITERA = settings.TwIST_MAXITERA;
                obj.TwIST_MAXITERD = settings.TwIST_MAXITERD;
                obj.TwIST_MINITERA = settings.TwIST_MINITERA;
                obj.TwIST_MINITERD = settings.TwIST_MINITERD;
                obj.TwIST_INITIALIZATION = settings.TwIST_INITIALIZATION;
                obj.TwIST_MONOTONE = settings.TwIST_MONOTONE;
                obj.TwIST_SPARSE = settings.TwIST_SPARSE;
                obj.TwIST_VERBOSE = settings.TwIST_VERBOSE;
                obj.TwIST_TVITER = settings.TwIST_TVITER;
                obj.TwIST_MAXSVD = settings.TwIST_MAXSVD;
                % TwIST                                        
                obj.Prefiltering_Size = settings.Prefiltering_Size;
                %
                obj.swap_XY_dimensions = settings.swap_XY_dimensions;
                obj.registration_method = settings.registration_method;
                obj.imstack_filename_convention_for_angle = settings.imstack_filename_convention_for_angle;                                
                %
                obj.save_volume_bit_depth = settings.save_volume_bit_depth;                
             end
             ret = true;
             catch
             end
        end
%-------------------------------------------------------------------------%
        function infostring = Set_Src_Single(obj,full_filename,verbose,~)
            %
            infostring = [];
            %            
            obj.delays = obj.get_delays(full_filename);
            if ~isempty(obj.delays), return, end; % can't load FLIM properly
            %
            obj.clear_memory_mapping();
            %            
            obj.proj = [];
            obj.volm = [];            
            obj.on_proj_and_volm_clear;            
            %
            obj.angles = obj.get_angles(full_filename); % temp
            if isempty(obj.angles)
                if verbose
                    errordlg('source does not contain angle specs - can not continue'), 
                end
                return, 
            end;
            %                               
            hw = [];
            waitmsg = 'Loading planes...';
            if verbose
                hw = waitbar(0,waitmsg);
            end
                        
            try
            omedata = bfopen_comp_5_10_2017(full_filename);
            catch err
                if verbose
                    errordlg(err.message);
                end
                if ~isempty(hw)
                    delete(hw); 
                    drawnow;
                end
                return;
            end
            
            if ~isempty(omedata)
                                
            r = loci.formats.ChannelFiller();
            r = loci.formats.ChannelSeparator(r);
            OMEXMLService = loci.formats.services.OMEXMLServiceImpl();
            r.setMetadataStore(OMEXMLService.createOMEXMLMetadata());
            r.setId(full_filename);
            r.setSeries(0);            
            omeMeta = r.getMetadataStore();  
            
            obj.PixelsPhysicalSizeX = 1;
            obj.PixelsPhysicalSizeY = 1;
            try
                obj.PixelsPhysicalSizeX = omeMeta.getPixelsPhysicalSizeX(0).getValue;
                obj.PixelsPhysicalSizeY = omeMeta.getPixelsPhysicalSizeY(0).getValue;
            catch
                disp('no PixelsPhysicalSize info, set to 1');
            end
            
            imgdata = omedata{1,1};                
            n_planes = length(imgdata(:,1));
                                
                for p = 1 : n_planes
                    plane = imgdata{p,1};
                    %   
                    if isempty(obj.proj)
                        [sizeX,sizeY] = size(plane);
                        obj.proj = zeros(sizeX,sizeY,n_planes,class(plane));
                        %
                        obj.current_filename = full_filename;
                        if isempty(obj.previous_filenames)
                            obj.previous_filenames{1} = obj.current_filename;
                        end                                                                                                
                    end %  ini - end
                        %
                        obj.proj(:,:,p) = plane;
                        %
                    if ~isempty(hw), waitbar(p/n_planes,hw); drawnow, end;                    
                    %
                end                                
                if ~isempty(hw), delete(hw), drawnow, end;
                
                % possibly correcting orientation
%                 if strcmp('Y',obj.swap_XY_dimensions) || (strcmp('AUTO',obj.swap_XY_dimensions) && ~obj.proj_rect_orientation_is_OK) % needs to reload with swapped dims
%                     %
%                     waitmsg = 'Oops.. swappig dimensions..';
%                     if verbose
%                         hw = waitbar(0,waitmsg);
%                     end
%                     %
%                     obj.proj = [];                  
%                     %
%                     for p = 1 : n_planes                    
%                         plane = rot90(imgdata{p,1});
%                         %   
%                         if isempty(obj.proj)
%                             [sizeX,sizeY] = size(plane);
%                             obj.proj = zeros(sizeX,sizeY,n_planes,class(plane));
%                             %
%                             obj.current_filename = full_filename;
%                             if isempty(obj.previous_filenames)
%                                 obj.previous_filenames{1} = obj.current_filename;
%                             end                                                                                                
%                         end %  ini - end
%                         %
%                         obj.proj(:,:,p) = plane;
%                         %
%                         if ~isempty(hw), waitbar(p/n_planes,hw); drawnow, end;                    
%                         %
%                     end                                
%                     if ~isempty(hw), delete(hw), drawnow, end;                                                                                
%                     %
%                 end
                % end orientation correcting...

                   % correcting orientation
                if strcmp('Vertical',obj.swap_XY_dimensions)  % needs to reload with swapped dims
                    %
                    waitmsg = 'Changing rotation axis orientation for reconstruction...';
                    if verbose
                        hw = waitbar(0,waitmsg);
                    end
                    %
                    obj.proj = [];                  
                    %
                    for p = 1 : n_planes                    
                        plane = rot90(imgdata{p,1});
                        %   
                        if isempty(obj.proj)
                            [sizeX,sizeY] = size(plane);
                            obj.proj = zeros(sizeX,sizeY,n_planes,class(plane));
                            %
                            obj.current_filename = full_filename;
                            if isempty(obj.previous_filenames)
                                obj.previous_filenames{1} = obj.current_filename;
                            end                                                                                                
                        end %  ini - end
                        %
                        obj.proj(:,:,p) = plane;
                        %
                        if ~isempty(hw), waitbar(p/n_planes,hw); drawnow, end;                    
                        %
                    end                                
                    if ~isempty(hw), delete(hw), drawnow, end;                                                                                
                    %
                end
                % end orientation correcting...

                % do registration if needed
                if ~strcmp('None',obj.registration_method)
                    obj.do_registration;
                end                                
                                                
                if isnumeric(obj.Prefiltering_Size)
                    s = obj.Prefiltering_Size;
                        waitmsg = 'Median pre-filtering....';
                        if verbose
                            hw = waitbar(0,waitmsg);
                        end                                    
                    for p = 1 : n_planes
                        obj.proj(:,:,p) = medfilt2(obj.proj(:,:,p),'symmetric',[s s]);
                        if ~isempty(hw), waitbar(p/n_planes,hw); drawnow, end;     
                    end
                    if ~isempty(hw), delete(hw), drawnow, end;    
                end
                                
                % that might be inadequate for transmission...
                if min(obj.proj(:)) > 2^15
                    obj.proj = obj.proj - 2^15;    % clear the sign bit which is set by labview
                end
%                  % invert if ???
%                  max_val = max(obj.proj(:));
%                  obj.proj = max_val - obj.proj;
                                 
                [filepath,~,~] = fileparts(full_filename);
                obj.DefaultDirectory = filepath;
            end
                        
            obj.on_new_proj_set;
            
            obj.omero_Image_IDs = [];
            
            infostring = obj.current_filename;
            
        end
%-------------------------------------------------------------------------%
        function infostring = Set_Src_FLIM(obj,full_filename,mode,verbose,~)
            %
            obj.clear_memory_mapping;
            %
            obj.FLIM_proj_load_swap_XY_dimensions = false;
            %
            obj.proj = [];
            obj.volm = [];            
            obj.on_proj_and_volm_clear;
            %
            infostring = [];
            obj.angles = obj.get_angles(full_filename); % temp
            if isempty(obj.angles) 
                if verbose
                    errordlg('source does not contain angle specs - can not continue'), 
                end
                return, 
            end;
            %                               
            hw = [];
            waitmsg = 'Loading planes...';
            if verbose
                hw = waitbar(0,waitmsg);
            end
                        
            try
            omedata = bfopen_comp_5_10_2017(full_filename);
            catch err
                errordlg(err.message);
                if ~isempty(hw)
                    delete(hw); 
                    drawnow;
                end
                return;
            end
            
            if ~isempty(omedata)
                                
            r = loci.formats.ChannelFiller();
            r = loci.formats.ChannelSeparator(r);
            OMEXMLService = loci.formats.services.OMEXMLServiceImpl();
            r.setMetadataStore(OMEXMLService.createOMEXMLMetadata());
            r.setId(full_filename);
            r.setSeries(0);            
            omeMeta = r.getMetadataStore();             
            % mmm - needs to check first if it isn't empty..
            obj.PixelsPhysicalSizeX = omeMeta.getPixelsPhysicalSizeX(0).getValue;
            obj.PixelsPhysicalSizeY = omeMeta.getPixelsPhysicalSizeY(0).getValue;
            
            sizeZ = omeMeta.getPixelsSizeZ(0).getValue; 
            sizeT = omeMeta.getPixelsSizeT(0).getValue;
            
            imgdata = omedata{1,1};       
            
            obj.initialize_memmap_proj(omeMeta,imgdata,true); % verbose
                        
                if strcmp('sum',mode) && ... % sum of all FLIM time gates
                       strcmp(omeMeta.getPixelsDimensionOrder(0).getValue,'XYZCT')
                   
                        for p = 1 : sizeZ                    
                            
                            plane = imgdata{p,1};
                            for t = 1:sizeT-1
                                tind  = sizeZ*t + p;
                                plane = plane + imgdata{tind,1};
                            end
                            %   
                            if isempty(obj.proj)
                                [sizeX,sizeY] = size(plane);
                                obj.proj = zeros(sizeX,sizeY,sizeZ,class(plane));
                                %
                                obj.current_filename = full_filename;
                                if isempty(obj.previous_filenames)
                                    obj.previous_filenames{1} = obj.current_filename;
                                end                                                                                                
                            end %  ini - end
                                %
                                obj.proj(:,:,p) = plane;
                                %
                            if ~isempty(hw), waitbar(p/sizeZ,hw); drawnow, end;                    
                        end                                
                        if ~isempty(hw), delete(hw), drawnow, end; 
                        
                   % correcting orientation
                if strcmp('Vertical',obj.swap_XY_dimensions)  % needs to reload with swapped dims
                    %
                    waitmsg = 'Changing rotation axis orientation for reconstruction...';
                    if verbose
                        hw = waitbar(0,waitmsg);
                    end
                    %
                    obj.proj = [];                  
                    %
                    for p = 1 : n_planes                    
                        plane = rot90(imgdata{p,1});
                        %   
                        if isempty(obj.proj)
                            [sizeX,sizeY] = size(plane);
                            obj.proj = zeros(sizeX,sizeY,n_planes,class(plane));
                            %
                            obj.current_filename = full_filename;
                            if isempty(obj.previous_filenames)
                                obj.previous_filenames{1} = obj.current_filename;
                            end                                                                                                
                        end %  ini - end
                        %
                        obj.proj(:,:,p) = plane;
                        %
                        if ~isempty(hw), waitbar(p/n_planes,hw); drawnow, end;                    
                        %
                    end                                
                    if ~isempty(hw), delete(hw), drawnow, end;                                                                                
                    %
                end
                % end orientation correcting...                                    
                    %
                elseif isnumeric(mode) && ... % load the mode-th time gate
                       mode <= sizeT && ... 
                       strcmp(omeMeta.getPixelsDimensionOrder(0).getValue,'XYZCT')
                                                
                        for p = 1 : sizeZ
                            pind =  (mode-1)*sizeZ + p;
                            plane = imgdata{pind,1};
                            %   
                            if isempty(obj.proj)
                                [sizeX,sizeY] = size(plane);
                                obj.proj = zeros(sizeX,sizeY,sizeZ,class(plane));
                                %
                                obj.current_filename = full_filename;
                                if isempty(obj.previous_filenames)
                                    obj.previous_filenames{1} = obj.current_filename;
                                end                                                                                                
                            end %  ini - end
                            %
                            obj.proj(:,:,p) = plane;  
                            %
                            if ~isempty(hw), waitbar(p/sizeZ,hw); drawnow, end;                    
                        end                                
                        if ~isempty(hw), delete(hw), drawnow, end; 
                      %
                     % correcting orientation
                    if strcmp('Y',obj.swap_XY_dimensions) 
                        %
                        obj.FLIM_proj_load_swap_XY_dimensions = true;
                        %
                        waitmsg = 'Changing rotation axis orientation for reconstruction...';
                        if verbose
                            hw = waitbar(0,waitmsg);
                        end
                        %
                        obj.proj = [];                  
                        %
                        for p = 1 : sizeZ                   
                            pind =  (mode-1)*sizeZ + p;                        
                            plane = rot90(imgdata{pind,1});
                            %   
                            if isempty(obj.proj)
                                [sizeX,sizeY] = size(plane);
                                obj.proj = zeros(sizeX,sizeY,sizeZ,class(plane));
                            end %  ini - end
                            %
                            obj.proj(:,:,p) = plane;
                            %
                            if ~isempty(hw), waitbar(p/sizeZ,hw); drawnow, end;                    
                         end                                                                         
                        if ~isempty(hw), delete(hw), drawnow, end;                                                                                
                        %
                    end
                    % end orientation correcting...                    
                                        
                else % if can't load..
                    errordlg('can not continue - plane order XYZCT is expected for FLIM');
                    if ~isempty(hw)
                        delete(hw); 
                        drawnow;
                    end                
                end

                % do registration if needed
                obj.M1_hshift = [];
                obj.M1_vshift = [];
                obj.M1_rotation = [];                
                if ~strcmp('None',obj.registration_method)
                    obj.do_registration;
                end                                
               
                if isnumeric(obj.Prefiltering_Size)
                    s = obj.Prefiltering_Size;
                        waitmsg = 'Median pre-filtering....';
                        if verbose
                            hw = waitbar(0,waitmsg);
                        end                                    
                    for p = 1 : sizeZ                    
                        obj.proj(:,:,p) = medfilt2(obj.proj(:,:,p),'symmetric',[s s]);
                        if ~isempty(hw), waitbar(p/sizeZ,hw); drawnow, end;     
                    end
                    if ~isempty(hw), delete(hw), drawnow, end;    
                end
                                                    
                % that might be inadequate for transmission...
                if min(obj.proj(:)) > 2^15
                    obj.proj = obj.proj - 2^15;    % clear the sign bit which is set by labview
                end
%                  % invert if ???
%                  max_val = max(obj.proj(:));
%                  obj.proj = max_val - obj.proj;
                                 
                [filepath,~,~] = fileparts(full_filename);
                obj.DefaultDirectory = filepath;

                obj.on_new_proj_set;
                
                obj.omero_Image_IDs = [];
                
                infostring = obj.current_filename;  
                                                                
            else
                errordlg('improper input file');
            end
                        
        end
%-------------------------------------------------------------------------%
function save_volume(obj,full_filename,verbose,~)                        
    hw = [];   
    if verbose, hw = waitbar(0,'Saving volume data...'); end                    
    %
    if ~isempty(obj.delays) && contains(lower(full_filename),'.ome.tiff')
        % FLIM
        obj.save_volm_FLIM(full_filename,verbose);
        if verbose, delete(hw), drawnow; end
        % FLIM
        return;
    end
    % mat-file
    if  contains(lower(full_filename),'.mat')
        %
        if strcmp(obj.writeparameterfile,'On')
            if strcmp(obj.registration_method,'Auto + Manual confirmation') | strcmp(obj.registration_method,'Manual registration')
                proptxt = fopen([erase(full_filename,'.mat'),'_Registration_params.txt'],'w');
                fprintf(proptxt,' Shift = %3.1f\r\n Rotation = %3.2f',[obj.registration_shift obj.registration_rotation]);
                fclose(proptxt);
            elseif strcmp(obj.registration_method,'Rotation axis shift only')
                proptxt = fopen([erase(full_filename,'.mat'),'_Registration_params.txt'],'w');
                fprintf(proptxt,'Shift=%3.1f',obj.registration_shift);
                fclose(proptxt);
            end
            if ~isempty(strfind(obj.Reconstruction_Method,'TwIST'))
                
                proptxt2 = fopen([erase(full_filename,'.mat'),'_TwIST_params.txt'],'w');
                fprintf(proptxt2,' Tau = %.4f\r\n Lambda = %.5f\r\n Alpha = %1d\r\n Beta = %1d\r\n Stop Criterion = %1d\r\n ToleranceA = %6.5f\r\n ToleranceD = %.5f\r\n Debias = %1d\r\n MaxIterA %6d\r\n MaxIterD = %4d\r\n MinIterA = %4d\r\n MinIterD = %4d\r\n Inititalisation = %d\r\n Monotone = %d\r\n Sparse = %d\r\n Verbose = %d\r\n TV Iterations = %d\r\n Max SVD = %d',...
                    [obj.TwIST_TAU, obj.TwIST_LAMBDA, obj.TwIST_ALPHA, obj.TwIST_BETA, obj.TwIST_STOPCRITERION, ...
                    obj.TwIST_TOLERANCEA, obj.TwIST_TOLERANCED, obj.TwIST_DEBIAS, obj.TwIST_MAXITERA, ...
                    obj.TwIST_MAXITERD, obj.TwIST_MINITERA, obj.TwIST_MINITERD, obj.TwIST_INITIALIZATION, ...
                    obj.TwIST_MONOTONE, obj.TwIST_SPARSE, obj.TwIST_VERBOSE, obj.TwIST_TVITER, obj.TwIST_MAXSVD]);
                fclose(proptxt2);
            end
        end
        vol = obj.volm;
        save(full_filename,'vol','-v7.3');
        clear('vol');
    elseif contains(lower(full_filename),'.ome.tiff')
    %   
        if strcmp(obj.writeparameterfile,'On')
            if strcmp(obj.registration_method,'Auto + Manual confirmation') | strcmp(obj.registration_method,'Manual registration')
                proptxt = fopen([erase(full_filename,'.ome.tiff'),'_Registration_params.txt'],'w');
                fprintf(proptxt,' Shift = %3.1f\r\n Rotation = %3.2f',[obj.registration_shift obj.registration_rotation]);
                fclose(proptxt);
            elseif strcmp(obj.registration_method,'Rotation axis shift only')
                proptxt = fopen([erase(full_filename,'.ome.tiff'),'_Registration_params.txt'],'w');
                fprintf(proptxt,'Shift = %3.1f',obj.registration_shift);
                fclose(proptxt);
            end
            if ~isempty(strfind(obj.Reconstruction_Method,'TwIST'))
                
                proptxt2 = fopen([erase(full_filename,'.ome.tiff'),'_TwIST_params.txt'],'w');
                fprintf(proptxt2,' Tau = %.4f\r\n Lambda = %.5f\r\n Alpha = %1d\r\n Beta = %1d\r\n Stop Criterion = %1d\r\n ToleranceA = %6.5f\r\n ToleranceD = %.5f\r\n Debias = %1d\r\n MaxIterA %6d\r\n MaxIterD = %4d\r\n MinIterA = %4d\r\n MinIterD = %4d\r\n Inititalisation = %d\r\n Monotone = %d\r\n Sparse = %d\r\n Verbose = %d\r\n TV Iterations = %d\r\n Max SVD = %d',...
                    [obj.TwIST_TAU, obj.TwIST_LAMBDA, obj.TwIST_ALPHA, obj.TwIST_BETA, obj.TwIST_STOPCRITERION, ...
                    obj.TwIST_TOLERANCEA, obj.TwIST_TOLERANCED, obj.TwIST_DEBIAS, obj.TwIST_MAXITERA, ...
                    obj.TwIST_MAXITERD, obj.TwIST_MINITERA, obj.TwIST_MINITERD, obj.TwIST_INITIALIZATION, ...
                    obj.TwIST_MONOTONE, obj.TwIST_SPARSE, obj.TwIST_VERBOSE, obj.TwIST_TVITER, obj.TwIST_MAXSVD]);
                fclose(proptxt2);
            end
        end
        [szX,szY,szZ] = size(obj.volm);
        V = map(obj.volm,0,65535);
        if 32 == obj.save_volume_bit_depth
            % leave as is - single
        elseif 16 == obj.save_volume_bit_depth    
            V = uint16(V);
        end
        if ~isempty(obj.PixelsPhysicalSizeX) && ~isempty(obj.PixelsPhysicalSizeY)
            metadata = createMinimalOMEXMLMetadata(reshape(V,[szX,szY,1,1,szZ]),'XYCTZ');
            toPosFloat = @(x) ome.xml.model.primitives.PositiveFloat(java.lang.Double(x));
            metadata.setPixelsPhysicalSizeX(toPosFloat(obj.PixelsPhysicalSizeX*obj.downsampling),0);
            metadata.setPixelsPhysicalSizeY(toPosFloat(obj.PixelsPhysicalSizeY*obj.downsampling),0);
            metadata.setPixelsPhysicalSizeZ(toPosFloat(obj.PixelsPhysicalSizeX*obj.downsampling),0);                        
            bfsave(reshape(V,[szX,szY,1,1,szZ]),full_filename,'metadata',metadata,'Compression','LZW','BigTiff',true); 
        else
            bfsave(reshape(V,[szX,szY,1,1,szZ]),full_filename,'dimensionOrder','XYCTZ','Compression','LZW','BigTiff',true); 
        end      
    elseif contains(lower(full_filename),'.tif')
    %           
        [szX,szY,szZ] = size(obj.volm);
        mkdir(erase(full_filename,'.tif'));
        
        if strcmp(obj.writeparameterfile,'On')
            if strcmp(obj.registration_method,'Auto + Manual confirmation') | strcmp(obj.registration_method,'Manual registration')
                proptxt = fopen([erase(full_filename,'.tif'),filesep,'Registration_params.txt'],'w');
                fprintf(proptxt,' Shift = %3.1f\r\n Rotation = %3.2f',[obj.registration_shift obj.registration_rotation]);
                fclose(proptxt);
            elseif strcmp(obj.registration_method,'Rotation axis shift only')
                proptxt = fopen([erase(full_filename,'.tif'),filesep,'Registration_params.txt'],'w');
                fprintf(proptxt,'Shift = %3.1f',obj.registration_shift);
                fclose(proptxt);
            end
            if ~isempty(strfind(obj.Reconstruction_Method,'TwIST'))
                
                proptxt2 = fopen([erase(full_filename,'.tif'),filesep,'TwIST_params.txt'],'w');
                fprintf(proptxt2,' Tau = %.4f\r\n Lambda = %.5f\r\n Alpha = %1d\r\n Beta = %1d\r\n Stop Criterion = %1d\r\n ToleranceA = %6.5f\r\n ToleranceD = %.5f\r\n Debias = %1d\r\n MaxIterA %6d\r\n MaxIterD = %4d\r\n MinIterA = %4d\r\n MinIterD = %4d\r\n Inititalisation = %d\r\n Monotone = %d\r\n Sparse = %d\r\n Verbose = %d\r\n TV Iterations = %d\r\n Max SVD = %d',...
                    [obj.TwIST_TAU, obj.TwIST_LAMBDA, obj.TwIST_ALPHA, obj.TwIST_BETA, obj.TwIST_STOPCRITERION, ...
                    obj.TwIST_TOLERANCEA, obj.TwIST_TOLERANCED, obj.TwIST_DEBIAS, obj.TwIST_MAXITERA, ...
                    obj.TwIST_MAXITERD, obj.TwIST_MINITERA, obj.TwIST_MINITERD, obj.TwIST_INITIALIZATION, ...
                    obj.TwIST_MONOTONE, obj.TwIST_SPARSE, obj.TwIST_VERBOSE, obj.TwIST_TVITER, obj.TwIST_MAXSVD]);
                fclose(proptxt2);
            end
        end
        
        if 16 == obj.save_volume_bit_depth
            V = map(obj.volm,0,65535);
            V = uint16(V);
            for i = 1:szZ
                imwrite(V(:,:,i),strcat(erase(full_filename,'.tif'),'/slice',num2str(i,'%04d'),'.tif'));
                waitbar(i/szZ,hw)
            end
        elseif 32 == obj.save_volume_bit_depth
            V = map(obj.volm,0,(2^32)-1);
            V = uint32(V);
            for i = 1:szZ
                t = Tiff(strcat(erase(full_filename,'.tif'),'/slice',num2str(i,'%04d'),'.tif'),'w');
                tagstruct.ImageLength     = size(V,1);
                tagstruct.ImageWidth      = size(V,2);
                tagstruct.Photometric     = Tiff.Photometric.MinIsBlack;
                tagstruct.BitsPerSample   = 32;
                tagstruct.SamplesPerPixel = 1;
                tagstruct.RowsPerStrip    = 16;
                tagstruct.PlanarConfiguration = Tiff.PlanarConfiguration.Chunky;
                tagstruct.Software        = 'MATLAB';
                t.setTag(tagstruct);
                t.write(V(:,:,i));
                t.close();
                waitbar(i/szZ,hw)
            end
        end


        % old protocol
        % V = map(obj.volm,0,65535);
        % if 32 == obj.save_volume_bit_depth
        %     % leave as is - single
        % 
        % elseif 16 == obj.save_volume_bit_depth    
        %     V = uint16(V);
        % end
        % mkdir(erase(full_filename,'.tif'));
        % for i = 1:szZ
        %     imwrite(V(:,:,i),strcat(erase(full_filename,'.tif'),'/slice',num2str(i,'%04d'),'.tif'));
        %     waitbar(i/szZ,hw)
        % end

    end
    if verbose, delete(hw), drawnow; end;
end
%-------------------------------------------------------------------------%
        function res = proj_rect_orientation_is_OK(obj,~,~)

            [sizeX,sizeY,n_planes] = size(obj.proj);
             
            ps1_acc = [];
            for k=1:2:sizeY
                s1 = squeeze(double(obj.proj(:,k,:)));
                s = sum(s1);
                F = fftshift(fft(s));
                ps = F.*conj(F);                
                if isempty(ps1_acc) ps1_acc = zeros(size(ps)); end;
                ps1_acc = ps1_acc + ps;
            end
            %
            ps2_acc = [];
            for k=1:2:sizeX
                s2 = squeeze(double(obj.proj(k,:,:)));
                s = sum(s2);
                F = fftshift(fft(s));
                ps = F.*conj(F);                
                if isempty(ps2_acc) ps2_acc = zeros(size(ps)); end;
                ps2_acc = ps2_acc + ps;
            end
            %
            ps1_acc = ps1_acc/(sizeY/2);
            ps2_acc = ps2_acc/(sizeX/2);
            %
            N = fix(length(ps1_acc))/2;            
            %                        
            y1 = ps1_acc(N+2:2*N);
            y2 = ps2_acc(N+2:2*N);            
            
            discr_param = mean(log(y2./y1));
            
%             figure();
%             plot((1:N-1),log(y1),'b.-',(1:N-1),log(y2),'r.-');
%             xlabel(num2str(discr_param));
            
            res = true;
            if (discr_param < 0), res = false; end;
                                                               
        end
%-------------------------------------------------------------------------%
        function delete(obj)
            obj.clear_memory_mapping;
            %
            if ~obj.run_headless
                ButtonName = questdlg('Do you want to save current settings?', ...
                             'Settings saving on exit', ...
                             'Yes', 'No - quit without saving settings', 'Yes');
                if strcmp(ButtonName,'Yes')                                                 
                    try
                        obj.save_settings;
                    catch
                        disp('Error while trying to save settings: not saved');
                    end
                    close all; % radical
                end
            end

        end
%-------------------------------------------------------------------------%        
        function reconstruction = FBP(obj,sinogram,~)
            step = obj.angle_downsampling;                 
            n_angles = numel(obj.angles);
            acting_angles = obj.angles(1:step:n_angles);
            [N,~] = size(sinogram); 
            sinogram = obj.pad_sinogram_for_iradon(sinogram);
            reconstruction = iradon(sinogram,acting_angles,obj.FBP_interp,obj.FBP_filter,obj.FBP_fscaling,N);
        end        
%-------------------------------------------------------------------------%        
        function reconstruction = FBP_TwIST(obj,sinogram,~)
                                                
            % denoising function;    %Change if necessary - strength of total variarion
            tv_iters = obj.TwIST_TVITER;            
            Psi = @(x,th)  tvdenoise(x,2/th,tv_iters);

            if strcmp(obj.Reconstruction_GPU,'OFF')

                step = obj.angle_downsampling;                 
                n_angles = numel(obj.angles);
                acting_angles = obj.angles(1:step:n_angles);            
                
                [N,~] = size(sinogram);                                            
                % 
                hR = @(x)  radon(x, acting_angles);
                hRT = @(x) iradon(x, acting_angles,obj.FBP_interp,obj.FBP_filter,obj.FBP_fscaling,N);
                                                
                % set the penalty function, to compute the objective
                Phi = @(x) TVnorm(x);
                tau = obj.TwIST_TAU;
                % input (padded) sinogram  
                y = obj.pad_sinogram_for_iradon(sinogram);

                 [reconstruction,dummy1,obj_twist,...
                    times_twist,dummy2,mse_twist]= ...
                         TwIST(y,hR,...
                         tau,...
                         'AT', hRT, ...
                         'Psi', Psi, ...
                         'Phi',Phi, ...
                         'Lambda', obj.TwIST_LAMBDA, ...                     
                         'Monotone',obj.TwIST_MONOTONE,...
                         'MAXITERA', obj.TwIST_MAXITERA, ...
                         'MAXITERD', obj.TwIST_MAXITERD, ...                     
                         'Initialization',obj.TwIST_INITIALIZATION,...
                         'StopCriterion',obj.TwIST_STOPCRITERION,...
                         'ToleranceA',obj.TwIST_TOLERANCEA,...
                         'ToleranceD',obj.TwIST_TOLERANCED,...
                         'Verbose', obj.TwIST_VERBOSE,...
                         'max_svd',obj.TwIST_MAXSVD);
                     
            else % if strcmp(obj.Reconstruction_GPU,'ON') && obj.isGPU
                                              
                % TERES'A FIX - WORKS
                % disp(obj.angles)
                % disp('now the calculated ones')
                % Na_ = length(obj.angles);
                %                  a_max_ = obj.angles(Na_);
                %                  a_min_ = 0;
                %                  angle = (a_max_ - a_min_)/Na_; 
                % angles_total = linspace(0,a_max_ - angle,Na_);      % for hRT
                % 
                % Rangles = angles_total;
                % Rangles_half = Rangles(Rangles<180);                % for hR 
                % Rangles_half2 = Rangles(Rangles>=180)-180;
                % disp(Rangles);
                % disp('now halves');
                % disp(Rangles_half);
                % disp(Rangles_half2)
                [N,~] = size(sinogram); 

                %hR = @(x)  hR2(x, Rangles_half, Rangles_half2);
                hR = @(x) radon(x, obj.angles);
                hRT = @(x) iradon(x, obj.angles,obj.FBP_interp,obj.FBP_filter,obj.FBP_fscaling,N);
                % TERES'A FIX - WORKS

                % set the penalty function, to compute the objective
                Phi = @(x) TVnorm_gpu(x);
                tau = gpuArray(obj.TwIST_TAU);
                % input (padded) sinogram  
                y = (obj.pad_sinogram_for_iradon(sinogram));

                rescale = max(y(:));
                y=y./rescale;
                
                 [reconstruction,dummy1,obj_twist,...
                    times_twist,dummy2,mse_twist]= ...
                         TwIST_gpu_OPT(y,hR,...
                         tau,...
                         'AT', hRT, ...
                         'Psi', Psi, ...
                         'Phi',Phi, ...
                         'Lambda', obj.TwIST_LAMBDA, ...                     
                         'Monotone',obj.TwIST_MONOTONE,...
                         'MAXITERA', obj.TwIST_MAXITERA, ...
                         'MAXITERD', obj.TwIST_MAXITERD, ...                     
                         'Initialization',obj.TwIST_INITIALIZATION,...
                         'StopCriterion',obj.TwIST_STOPCRITERION,...
                         'ToleranceA',obj.TwIST_TOLERANCEA,...
                         'ToleranceD',obj.TwIST_TOLERANCED,...
                         'Verbose', obj.TwIST_VERBOSE,...
                         'max_svd',obj.TwIST_MAXSVD);
                 reconstruction = (reconstruction).*rescale;
            end
            
        end        
%-------------------------------------------------------------------------%
        function V = perform_reconstruction(obj,verbose,~)
            
            use_GPU = strcmp(obj.Reconstruction_GPU,'ON');
                        
            RF = []; % reconstruction function
            if strcmp(obj.Reconstruction_Method,'FBP')
                RF = @obj.FBP;
            elseif ~isempty(strfind(obj.Reconstruction_Method,'TwIST'))
                RF = @obj.FBP_TwIST;
            else
                % shouldn't come here
                return;
            end
                                                            
            V = [];                
            obj.on_volm_clear;

            [sizeX,sizeY,sizeZ] = size(obj.proj); 
             
            n_angles = numel(obj.angles);
             
            if sizeZ ~= n_angles
                errordlg('Incompatible settings - can not continue');
                return;
            end
                                    
            s = [];
            if use_GPU && obj.isGPU
                s = [obj.Reconstruction_Method ' GPU reconstruction.. please wait...'];
            elseif ~use_GPU
                s = [obj.Reconstruction_Method ' reconstruction.. please wait...'];
                par_pool = gcp;
                obj.NumWorkers = par_pool.NumWorkers;
            else                     
                errordlg('can not run FBP (GPU) without GPU');
                return;
            end
                          
            hw = [];
            if verbose
                hw = waitbar(0,s);
            end
                          
            f = 1/obj.downsampling;
            [szX_r,szY_r] = size(imresize(zeros(sizeX,sizeY),f));                 
             
            %                                                   
            y_min = 1;
            y_max = sizeY;
            YL = sizeY;
            if ~isempty(obj.Z_range)
                y_min = obj.Z_range(1);
                y_max = obj.Z_range(2);
                YL = y_max - y_min;                             
            end                         
                        
                 if use_GPU && obj.isGPU 
                                          
                     if 1 == f % no downsampling

                         gpu_proj = gpuArray(cast(obj.proj(:,y_min:y_max,:),'single'));
                         gpu_volm = [];
                         allon_gpu = [];
                         
                         for y = 1 : YL                                       
                            sinogram = squeeze(gpu_proj(:,y,:)); 
                            %sinogram = obj.pad_sinogram_for_iradon(sinogram);
                            reconstruction = RF(sinogram);
                            if isempty(gpu_volm)
                                [sizeR1,sizeR2] = size(reconstruction);
                                try
                                    gpu_volmtest = gpuArray(single(zeros(sizeR1,sizeR2,YL*2))); % to prevent running out of GPU memory
                                    clear gpu_voltest;
                                    gpu_volm = gpuArray(single(zeros(sizeR1,sizeR2,YL))); % XYZ
                                    allon_gpu = 1;
                                catch
                                    %errordlg('The reconstructed volume cannot fit in GPU memory. Try enabling the Largo option.')
                                    gpu_volm = 1;
                                    allon_gpu = [];
                                end
                            end                            
                            if isempty(allon_gpu)
                                V(:,:,y) = gather(reconstruction);
                            else
                                gpu_volm(:,:,y) = single(reconstruction);
                                
                            end
                            if ~isempty(hw), waitbar(y/YL,hw); drawnow, end;
                         end                           
                         if ~isempty(allon_gpu)
                            V = gather(gpu_volm);
                         end
                         
                     else % with downsampling                         
                         
                         proj_r = [];
                         gpu_volm = [];
                         allon_gpu = [];
                         
                         for r = 1:sizeZ
                            if isempty(proj_r) 
                                [szX_r,szY_r] = size(imresize(obj.proj(:,y_min:y_max,r),f));
                                proj_r = zeros(szX_r,szY_r,sizeZ,'single');
                            end
                            proj_r(:,:,r) = imresize(obj.proj(:,y_min:y_max,r),f);
                         end
                         gpu_proj_r = gpuArray(proj_r);
                         clear('proj_r');                         
                         %
                         for y = 1 : szY_r 
                            sinogram = squeeze(gpu_proj_r(:,y,:));
                            %sinogram = obj.pad_sinogram_for_iradon(sinogram);
                            reconstruction = RF(sinogram);                            
                            if isempty(gpu_volm)
                                [sizeR1,sizeR2] = size(reconstruction);
                                try
                                    gpu_volm = gpuArray(single(zeros(sizeR1,sizeR2,szY_r))); % XYZ
                                    allon_gpu = 1;
                                catch
                                    %errordlg('The reconstructed volume cannot fit in GPU memory. Try enabling the Largo option.')
                                    gpu_volm = 1;
                                    allon_gpu = [];
                                end
                            end                            
                            if isempty(allon_gpu)
                                V(:,:,y) = gather(reconstruction);
                            else
                                gpu_volm(:,:,y) = reconstruction;
                            end
                            if ~isempty(hw), waitbar(y/szY_r,hw); drawnow, end;
                         end                           
                         if ~isempty(allon_gpu)
                            V = gather(gpu_volm);
                         end
                         
                     end
                 % special case - using parfor
                 elseif ~use_GPU && strcmp(obj.Reconstruction_Method,'FBP') && obj.NumWorkers >= 4
                     if ~isempty(hw), delete(hw), drawnow, end;
                     if 1 == f % no downsampling
                         
                         tic
                                sinogram = squeeze(double(obj.proj(:,y_min,:)));
                                 %sinogram = obj.pad_sinogram_by_width_percentage(sinogram,0.1);
                                    [Nlines,~] = size(sinogram);
                                    Ladd = fix(0.1*Nlines);
                                    %sinogram = padarray(sinogram,[Ladd 0], 'replicate' ,'pre');
                                    %sinogram = padarray(sinogram,[Ladd 0], 'replicate' ,'post');
                                 %sinogram = obj.pad_sinogram_by_width_percentage(sinogram,0.1);                            
                                reconstruction = RF(sinogram);
                                [sizeR1,sizeR2] = size(reconstruction);
                                V = zeros(sizeR1,sizeR2,YL,'single'); % XYZ                        
                                PR = obj.proj;
                                step = obj.angle_downsampling;                 
                                n_angles = numel(obj.angles);
                                interp = obj.FBP_interp;
                                filter = obj.FBP_filter;
                                fscaling = obj.FBP_fscaling;
                                acting_angles = obj.angles(1:step:n_angles);                                
                         if verbose       
                            hbar = parfor_progressbar(YL,'parfor reconstruction, please wait');  %create the parfor capable progress bar
                         else
                            hbar = []; 
                         end
                         parfor y = 1 : YL
                            sinogram = squeeze(double(PR(:,y_min+y-1,:)));
                             %sinogram = obj.pad_sinogram_by_width_percentage(sinogram,0.1);
                                [Nlines,~] = size(sinogram);
                                Ladd = fix(0.1*Nlines);
                                sinogram = padarray(sinogram,[Ladd 0], 'replicate' ,'pre');
                                sinogram = padarray(sinogram,[Ladd 0], 'replicate' ,'post');
                             %sinogram = obj.pad_sinogram_by_width_percentage(sinogram,0.1);                            
                            reconstruction = iradon(sinogram,acting_angles,interp,filter,fscaling);
                            V(:,:,y) = reconstruction;
                            if verbose hbar.iterate(20); end
                         end
                         close(hbar);
                         toc

                     else % with downsampling                         
                         
                         proj_r = [];
                         for r = 1:sizeZ
                            if isempty(proj_r) 
                                [szX_r,szY_r] = size(imresize(obj.proj(:,y_min:y_max,r),f));
                                proj_r = zeros(szX_r,szY_r,sizeZ,'single');
                            end
                            proj_r(:,:,r) = imresize(obj.proj(:,y_min:y_max,r),f);
                         end
                         %
                         tic
                         sinogram = squeeze(double(proj_r(:,1,:)));
                         %sinogram = obj.pad_sinogram_for_iradon(sinogram);
                         reconstruction = RF(sinogram);                                                        
                         [sizeR1,sizeR2] = size(reconstruction);                         
                         V = zeros(sizeR1,sizeR2,szY_r,'single'); % XYZ
                                step = obj.angle_downsampling;                 
                                n_angles = numel(obj.angles);
                                interp = obj.FBP_interp;
                                filter = obj.FBP_filter;
                                fscaling = obj.FBP_fscaling;
                                acting_angles = obj.angles(1:step:n_angles);
                         if verbose       
                            hbar = parfor_progressbar(szY_r,'parfor reconstruction, please wait');  %create the parfor capable progress bar
                         else
                            hbar = []; 
                         end
                         parfor y = 1 : szY_r
                            sinogram = squeeze(double(proj_r(:,y,:)));
                             %sinogram = obj.pad_sinogram_by_width_percentage(sinogram,0.1);
                                [Nlines,~] = size(sinogram);
                                Ladd = fix(0.1*Nlines);
                                sinogram = padarray(sinogram,[Ladd 0], 'replicate' ,'pre');
                                sinogram = padarray(sinogram,[Ladd 0], 'replicate' ,'post');
                             %sinogram = obj.pad_sinogram_by_width_percentage(sinogram,0.1);                            
                            reconstruction = iradon(sinogram,acting_angles,interp,filter,fscaling);
                            V(:,:,y) = reconstruction;
                            if verbose hbar.iterate(20); end
                         end
                         close(hbar);
                         toc
                                                                          
                     end
                                                     
                     % special case - using parfor
                 elseif ~use_GPU
                                          
                     if 1 == f % no downsampling
                                                                           
                         for y = 1 : YL                                       
                            sinogram = squeeze(double(obj.proj(:,y_min+y-1,:)));
                            %sinogram = obj.pad_sinogram_for_iradon(sinogram);
                            % 
                            reconstruction = RF(sinogram);
                            if isempty(V)
                                [sizeR1,sizeR2] = size(reconstruction);
                                V = zeros(sizeR1,sizeR2,YL,'single'); % XYZ
                            end
                            %
                            V(:,:,y) = reconstruction;
                            %
                            if ~isempty(hw), waitbar(y/YL,hw); drawnow, end;
                         end                                                 
                         
                     else % with downsampling                         
                         
                         proj_r = [];
                         for r = 1:sizeZ
                            if isempty(proj_r) 
                                [szX_r,szY_r] = size(imresize(obj.proj(:,y_min:y_max,r),f));
                                proj_r = zeros(szX_r,szY_r,sizeZ,'single');
                            end
                            proj_r(:,:,r) = imresize(obj.proj(:,y_min:y_max,r),f);
                         end
                         %
                         for y = 1 : szY_r 
                            sinogram = squeeze(double(proj_r(:,y,:))); 
                            %sinogram = obj.pad_sinogram_for_iradon(sinogram);
                            reconstruction = RF(sinogram);                                                        
                            if isempty(V)
                                [sizeR1,sizeR2] = size(reconstruction);
                                V = zeros(sizeR1,sizeR2,szY_r,'single'); % XYZ
                            end
                            %
                            V(:,:,y) = reconstruction;
                            %
                            if ~isempty(hw), waitbar(y/szY_r,hw); drawnow, end;
                         end
                         
                     end
                                      
                 end                     
                                                               
             V( V <= 0 ) = 0; % mm? 
             
             if ~isempty(hw), delete(hw), drawnow, end;
             
             obj.on_new_volm_set;
        end
%-------------------------------------------------------------------------%         
function padded_sinogram = pad_sinogram_by_width_percentage(obj,sinogram,p,~)
    if p < 0.01 || p >0.5 
        padded_sinogram = sinogram;
        return;
    end
    [N,~] = size(sinogram);
    L = fix(p*N);
    R = padarray(sinogram,[L 0], 'replicate' ,'pre');
    padded_sinogram = padarray(R,[L 0], 'replicate' ,'post');
end
%-------------------------------------------------------------------------% 
function padded_sinogram = pad_sinogram_for_iradon(obj,sinogram,~)
            
           [N,n_angles] = size(sinogram);
           szproj = [N N];
            
           zpt = ceil((2*ceil(norm(szproj-floor((szproj-1)/2)-1))+3 - N)/2);
           zpb = floor((2*ceil(norm(szproj-floor((szproj-1)/2)-1))+3 - N)/2);
           %st = abs(zpb - zpt); 
                        
           R = single(padarray(sinogram,[zpt 0], 'replicate' ,'pre'));
           R = single(padarray(R,[zpb 0], 'replicate' ,'post'));                                                                                                                                   
           padded_sinogram = R;                                                
end
%-------------------------------------------------------------------------% 
        function perform_reconstruction_Largo(obj,~) % uses memory mapping            
            
             if 1 ~= obj.downsampling
                 errordlg('only 1/1 proj-volm scale, full size, is supported, can not continue')
                 return; 
             end  

             obj.volm = [];                
             obj.on_volm_clear;
                          
             [sizeX,sizeY,sizeZ] = size(obj.proj);
             sizeontempdisk = java.io.File(tempdir).getFreeSpace();
             if sizeontempdisk <= sizeX*sizeY*sizeZ*8
                 errordlg('Not enough disk space in tempdir - please clear some space before continuing.')
                 return
             end
             wait_handle = waitbar(0,'Creating projection memory-map file...');
             [mapfile_name_proj,memmap_PROJ] = initialize_memmap([sizeX sizeY sizeZ],1,'pixels',class(obj.proj),'ini_data',obj.proj);                 
             close(wait_handle);
       
             % to free some RAM
             obj.proj = [];                
             obj.on_proj_clear;
             
             %PROJ = memmap_PROJ.Data.pixels; % reference
             
             RF = []; % reconstruction function
             if strcmp(obj.Reconstruction_Method,'FBP')            
                RF = @obj.FBP;
             elseif ~isempty(strfind(obj.Reconstruction_Method,'TwIST'))
                RF = @obj.FBP_TwIST;
             end             
                                                        
             % to define reconstruction size
             sinogram = squeeze(cast(memmap_PROJ.Data.pixels(:,1,:),'single'));
             %sinogram = obj.pad_sinogram_by_width_percentage(sinogram,0.41);      
             %sinogram = obj.pad_sinogram_for_iradon(sinogram);   
             if strcmp(obj.Reconstruction_GPU,'ON') && obj.isGPU  
                         gpu_sinogram = squeeze(gpuArray(sinogram));
                         reconstruction = gather(RF(gpu_sinogram));
                         [size_volm_X,size_volm_Y] = size(reconstruction);                                               
             elseif strcmp(obj.Reconstruction_GPU,'OFF')                                                                                                                     
                         reconstruction = RF(sinogram);
                         [size_volm_X,size_volm_Y] = size(reconstruction);
                         par_pool = gcp;
                         obj.NumWorkers = par_pool.NumWorkers;
             end                     
             % to define reconstruction size - ends
             %
             % output_datatype = class(reconstruction); % fair
             % output_datatype = 'uint16'; % some economy on RAM..             
             output_datatype = 'single';
             try
                obj.volm = zeros(size_volm_X,size_volm_Y,sizeY,output_datatype);                
             catch
                clear('memmap_PROJ');
                delete(mapfile_name_proj);
                error('Insufficient memory to store reconstructed volume')
                return;
             end
                                       
             % main loop - starts
             verbose = true;
             if verbose
                wait_handle=waitbar(0,'Reconstructing and memory mapping, please wait...');
             end
             %                       
             if strcmp(obj.Reconstruction_GPU,'ON') && obj.isGPU                                                           
                 for y = 1 : sizeY
                    sinogram = squeeze(cast(memmap_PROJ.Data.pixels(:,y,:),'single'));
                    %sinogram = obj.pad_sinogram_for_iradon(sinogram);
                    gpu_sinogram = squeeze(gpuArray(sinogram));
                    gpu_recon = RF(gpu_sinogram);
                    gpu_recon( gpu_recon < 0 ) = 0;
                    reconstruction = gather(gpu_recon);
                    reconstruction( reconstruction <= 0 ) = 0; % yepp
                    obj.volm(:,:,y) = cast(reconstruction,output_datatype);
                    if verbose, waitbar(y/sizeY,wait_handle), end;                    
                 end      
             elseif strcmp(obj.Reconstruction_GPU,'OFF') && strcmp(obj.Reconstruction_Method,'FBP') && obj.NumWorkers >= 4
                 % parfor case
                         tic
                         sinogram = squeeze(cast(memmap_PROJ.Data.pixels(:,1,:),'single'));
                         %sinogram = obj.pad_sinogram_by_width_percentage(sinogram,0.1);
                            [Nlines,~] = size(sinogram);
                            Ladd = fix(0.1*Nlines);
                            %sinogram = padarray(sinogram,[Ladd 0], 'replicate' ,'pre');
                            %sinogram = padarray(sinogram,[Ladd 0], 'replicate' ,'post');
                         %sinogram = obj.pad_sinogram_by_width_percentage(sinogram,0.1);                                                                                                       
                         reconstruction = RF(sinogram);                                                        
                         [sizeR1,sizeR2] = size(reconstruction);
                         obj.volm = [];
                         V = zeros(sizeR1,sizeR2,sizeY,output_datatype); % XYZ
                                step = obj.angle_downsampling;                 
                                n_angles = numel(obj.angles);
                                interp = obj.FBP_interp;
                                filter = obj.FBP_filter;
                                fscaling = obj.FBP_fscaling;
                                acting_angles = obj.angles(1:step:n_angles);
                         if verbose       
                            hbar = parfor_progressbar(sizeY,'parfor reconstruction, please wait');  %create the parfor capable progress bar
                         else
                            hbar = []; 
                         end
                         parfor y = 1 : sizeY
                            sinogram = squeeze(cast(memmap_PROJ.Data.pixels(:,y,:),'single'));
                             %sinogram = obj.pad_sinogram_by_width_percentage(sinogram,0.1);
                                [Nlines,~] = size(sinogram);
                                Ladd = fix(0.1*Nlines);
                                sinogram = padarray(sinogram,[Ladd 0], 'replicate' ,'pre');
                                sinogram = padarray(sinogram,[Ladd 0], 'replicate' ,'post');
                             %sinogram = obj.pad_sinogram_by_width_percentage(sinogram,0.1);                            
                            reconstruction = iradon(sinogram,acting_angles,interp,filter,fscaling);
                            reconstruction( reconstruction <= 0 ) = 0; 
                            V(:,:,y) = cast(reconstruction,output_datatype);
                            if verbose hbar.iterate(20); end
                         end
                         close(hbar);
                         obj.volm = V;
                         toc                 
             elseif strcmp(obj.Reconstruction_GPU,'OFF')                                                                                                                     
                 for y = 1 : sizeY
                    sinogram = squeeze(cast(memmap_PROJ.Data.pixels(:,y,:),'single'));
                    %sinogram = obj.pad_sinogram_for_iradon(sinogram);
                    reconstruction = RF(sinogram);
                    reconstruction( reconstruction <= 0 ) = 0;
                    obj.volm(:,:,y) = cast(reconstruction,output_datatype);
                    if verbose, waitbar(y/sizeY,wait_handle), end;                    
                 end
             end                     
             if verbose, close(wait_handle), end;             
             % main loop - ends                       
             
             obj.on_new_volm_set;  
                          
             clear('memmap_PROJ');
             delete(mapfile_name_proj);
        end
%-------------------------------------------------------------------------%
        function infostring  = OMERO_load_single(obj,omero_data_manager,verbose,~)           

            infostring = [];
            
            chooser = OMEuiUtils.OMEROImageChooser(omero_data_manager.client,omero_data_manager.userid, false); % single image
            images = chooser.getSelectedImages();
            image = images(1);
            
            if isempty(image), return, end;

            angleS = obj.OMERO_get_angles(omero_data_manager,image);
            if isempty(angleS), errordlg('source does not contain angle specs - can not continue'), return, end;
                        
            infostring = obj.OMERO_load_image(omero_data_manager,image,verbose);
                                                
        end
%-------------------------------------------------------------------------%
        function infostring  = OMERO_load_image(obj,omero_data_manager,image,verbose,~)
            
            obj.clear_memory_mapping; % mmmm             
            
            omero_data_manager.image = image;
            
            % obj.omero_Image_IDs{1} = omero_data_manager.image.getId.getValue;
                             
            pixelsList = omero_data_manager.image.copyPixels();    
            pixels = pixelsList.get(0);
                        
            SizeZ = pixels.getSizeZ().getValue();
            
            obj.PixelsPhysicalSizeX = pixels.getPhysicalSizeX.getValue;
            obj.PixelsPhysicalSizeY = pixels.getPhysicalSizeY.getValue;
        
            pixelsId = pixels.getId().getValue();
            rawPixelsStore = omero_data_manager.session.createRawPixelsStore(); 
            rawPixelsStore.setPixelsId(pixelsId, false);    
                        
            obj.angles = obj.OMERO_get_angles(omero_data_manager,omero_data_manager.image);            
            obj.delays = obj.OMERO_get_delays(omero_data_manager,omero_data_manager.image);
            
            if ~isempty(obj.delays)
                obj.initialize_memmap_proj_OMERO(omero_data_manager,image,verbose); %
            end
            
            % if isempty(obj.angles), errordlg('source does not contain angle specs - can not continue'), return, end;
                                                    
            waitmsg = 'Loading planes form Omero, please wait ...';
            hw = [];
            if verbose
                hw = waitbar(0,waitmsg);
            end            
                
            obj.proj = [];
            obj.volm = [];
            obj.on_proj_and_volm_clear;
                
            n_planes = SizeZ;
                            
            for p = 1 : SizeZ
                
                    z = p-1;
                    c = 0;
                    t = 0;
                    rawPlane = rawPixelsStore.getPlane(z,c,t);                    
                    plane = toMatrix(rawPlane, pixels)';                     
                    %
                    if isempty(obj.proj)
                        [sizeX,sizeY] = size(plane);
                        obj.proj = zeros(sizeX,sizeY,n_planes,class(plane));
                        
                    end %  ini - end
                    %
                    obj.proj(:,:,p) = plane;
                    %
                    if ~isempty(hw), waitbar(p/n_planes,hw); drawnow, end;
                    %
            end
            if ~isempty(hw), delete(hw), drawnow; end;   
            
                % possibly correcting orientation
                if strcmp('Vertical',obj.swap_XY_dimensions) 
                    waitmsg = 'Changing rotation axis orientation for reconstruction...';
                    if verbose
                        hw = waitbar(0,waitmsg);
                    end
                    %
                    obj.proj = [];                  
                    %
                    for p = 1 : SizeZ
                            z = p-1;
                            c = 0;
                            t = 0;
                            rawPlane = rawPixelsStore.getPlane(z,c,t);                    
                            plane = rot90(toMatrix(rawPlane, pixels)');
                            %
                            if isempty(obj.proj)
                                [sizeX,sizeY] = size(plane);
                                obj.proj = zeros(sizeX,sizeY,n_planes,class(plane));

                            end %  ini - end
                            %
                            obj.proj(:,:,p) = plane;
                            %
                            if ~isempty(hw), waitbar(p/n_planes,hw); drawnow, end;
                            %
                    end                          
                    if ~isempty(hw), delete(hw), drawnow, end;                                                                                
                    %
                end

                if isnumeric(obj.Prefiltering_Size)
                    s = obj.Prefiltering_Size;
                        waitmsg = 'Median pre-filtering....';
                        if verbose
                            hw = waitbar(0,waitmsg);
                        end                                    
                    for p = 1 : n_planes
                        obj.proj(:,:,p) = medfilt2(obj.proj(:,:,p),'symmetric',[s s]);
                        if ~isempty(hw), waitbar(p/n_planes,hw); drawnow, end;     
                    end
                    if ~isempty(hw), delete(hw), drawnow, end;    
                end
                                
                % that might be inadequate for transmission...
                if min(obj.proj(:)) > 2^15
                    obj.proj = obj.proj - 2^15;    % clear the sign bit which is set by labview
                end
%                  % invert if ???
%                  max_val = max(obj.proj(:));
%                  obj.proj = max_val - obj.proj;
                         
            rawPixelsStore.close();           
            
            obj.on_new_proj_set;
            
            obj.current_filename = [];
            
            iName = char(java.lang.String(omero_data_manager.image.getName().getValue()));            
            iId = num2str(omero_data_manager.image.getId().getValue());            
            infostring = [ 'Image "' iName '" [' iId ']' ] ;            
             
        end        
         %------------------------------------------------------------------        
            function on_new_proj_set(obj, ~,~)
                if isempty(obj.menu_controller), return, end;
                %
                set(obj.menu_controller.proj_label,'ForegroundColor','blue');
                set(obj.menu_controller.volm_label,'ForegroundColor','red');
            end            
         %------------------------------------------------------------------            
            function on_new_volm_set(obj, ~,~)
                if isempty(obj.menu_controller), return, end;
                %                
                set(obj.menu_controller.volm_label,'ForegroundColor','blue');                
            end
         %------------------------------------------------------------------            
            function on_proj_clear(obj, ~,~)
                if isempty(obj.menu_controller), return, end;
                %                
                set(obj.menu_controller.proj_label,'ForegroundColor','red');                
            end
         %------------------------------------------------------------------            
            function on_volm_clear(obj, ~,~)
                if isempty(obj.menu_controller), return, end;
                %                
                set(obj.menu_controller.volm_label,'ForegroundColor','red');                
            end
         %------------------------------------------------------------------            
            function on_proj_and_volm_clear(obj, ~,~)
                if isempty(obj.menu_controller), return, end;
                %                
                set(obj.menu_controller.volm_label,'ForegroundColor','red');                                
                set(obj.menu_controller.proj_label,'ForegroundColor','red');                                
            end                        
%-------------------------------------------------------------------------%        
        function ret = get_angles(obj,full_filename,~)
            
            ret = [];
            
            r = []; % "reader"
            
            try
            
                r = loci.formats.ChannelFiller();
                r = loci.formats.ChannelSeparator(r);

                OMEXMLService = loci.formats.services.OMEXMLServiceImpl();
                r.setMetadataStore(OMEXMLService.createOMEXMLMetadata());
                r.setId(full_filename);
                %
                modlo = r.getModuloZ();
                if ~isempty(modlo)

                     if ~isempty(modlo.labels)
                         ret = str2num(modlo.labels)';
                     end

                     if ~isempty(modlo.start)
                         if modlo.end > modlo.start
                            nsteps = round((modlo.end - modlo.start)/modlo.step);
                            ret = 0:nsteps;
                            ret = ret*modlo.step;
                            ret = ret + modlo.start;
                         end
                     end
                     
                end
                        
            catch
            end
            
            if isempty(ret) && ~isempty(r)
                try % try this as last resort
                    omeMeta = r.getMetadataStore();                     
                    sizeZ = omeMeta.getPixelsSizeZ(0).getValue;
                     if  sizeZ > 89
                        ret = 360/sizeZ*(0:sizeZ-1);
                     end
                catch
                end
            end
            
        end
%-------------------------------------------------------------------------%        
        function ret = get_delays(obj,full_filename,~)
            
            ret = [];
            
            obj.delays = ret; % mmmm
            
            try
            
                r = loci.formats.ChannelFiller();
                r = loci.formats.ChannelSeparator(r);

                OMEXMLService = loci.formats.services.OMEXMLServiceImpl();
                r.setMetadataStore(OMEXMLService.createOMEXMLMetadata());
                r.setId(full_filename);
                %
                modlo = r.getModuloT();
                if ~isempty(modlo)

                     if ~isempty(modlo.labels)
                         ret = str2num(modlo.labels)';
                     end

                     if ~isempty(modlo.start)
                         if modlo.end > modlo.start
                            nsteps = round((modlo.end - modlo.start)/modlo.step);
                            ret = 0:nsteps;
                            ret = ret*modlo.step;
                            ret = ret + modlo.start;
                         end
                     end
                     
                end
                        
            catch
            end
            
                                                                             obj.FLIM_unit = char(modlo.unit);
            obj.FLIM_typeDescription = char(modlo.typeDescription);
                        
            obj.delays = ret; % mmmm
            
        end                
%-------------------------------------------------------------------------%
        function ret = OMERO_get_angles(obj,omero_data_manager,image,~)
            
           ret = [];
     
           try
                                            
                objId = java.lang.Long(image.getId().getValue());
                %
                annotators = java.util.ArrayList;    
                metadataService = omero_data_manager.session.getMetadataService();
                map = metadataService.loadAnnotations('omero.model.Image', java.util.Arrays.asList(objId), java.util.Arrays.asList( 'ome.model.annotations.XmlAnnotation'), annotators, omero.sys.ParametersI());
                annotations = map.get(objId);
                %        
                s = [];
                for j = 0:annotations.size()-1
                    str = char(annotations.get(j).getTextValue.getValue);
                    if ~isempty(strfind(str,'OPT')) && ~isempty(strfind(str,'ModuloAlongZ')) % add some more checks to make t safer?
                        s = str;
                        break;
                    end
                end 
                                                                                                                                               
                if isempty(s), return, end;

                [parseResult,~] = xmlreadstring(s);
                tree = xml_read(parseResult);
                if isfield(tree,'ModuloAlongZ')
                     modlo = tree.ModuloAlongZ;
                end;               

                if isfield(modlo.ATTRIBUTE,'Start')

                    start = modlo.ATTRIBUTE.Start;
                    step = modlo.ATTRIBUTE.Step;
                    e = modlo.ATTRIBUTE.End; 
                    nsteps = round((e - start)/step);
                    ret = 0:nsteps;
                    ret = ret*step;
                    ret = ret + start;

                else
                    if isnumeric(modlo.Label)
                        ret = modlo.Label;
                    else
                        ret = cell2mat(modlo.Label);
                    end
                end
            
            catch
            end
                        
        end                     
%-------------------------------------------------------------------------%        
        function ret = OMERO_get_delays(obj,omero_data_manager,image,~)
            
           ret = [];
     
           try
                                            
                objId = java.lang.Long(image.getId().getValue());
                %
                annotators = java.util.ArrayList;    
                metadataService = omero_data_manager.session.getMetadataService();
                map = metadataService.loadAnnotations('omero.model.Image', java.util.Arrays.asList(objId), java.util.Arrays.asList( 'ome.model.annotations.XmlAnnotation'), annotators, omero.sys.ParametersI());
                annotations = map.get(objId);
                %        
                s = [];
                for j = 0:annotations.size()-1
                    str = char(annotations.get(j).getTextValue.getValue);
                    if ~isempty(strfind(str,'lifetime')) && ~isempty(strfind(str,'ModuloAlongT')) % add some more checks to make t safer?
                        s = str;
                        break;
                    end
                end 
                                                                                                                                               
                if isempty(s), return, end;

                [parseResult,~] = xmlreadstring(s);
                tree = xml_read(parseResult);
                if isfield(tree,'ModuloAlongT')
                     modlo = tree.ModuloAlongT;
                end;               

                if isfield(modlo.ATTRIBUTE,'Start')

                    start = modlo.ATTRIBUTE.Start;
                    step = modlo.ATTRIBUTE.Step;
                    e = modlo.ATTRIBUTE.End; 
                    nsteps = round((e - start)/step);
                    ret = 0:nsteps;
                    ret = ret*step;
                    ret = ret + start;

                else
                    if isnumeric(modlo.Label)
                        ret = modlo.Label;
                    else
                        ret = cell2mat(modlo.Label);
                    end
                end
                
                obj.FLIM_unit = modlo.ATTRIBUTE.Unit;
                obj.FLIM_typeDescription = modlo.ATTRIBUTE.TypeDescription;
            
            catch
            end
                        
        end                        
%-------------------------------------------------------------------------%                
        function res = do_reconstruction_on_Z_chunk(obj,zrange)
                        
             RF = []; % reconstruction function
             if strcmp(obj.Reconstruction_Method,'FBP')            
                RF = @obj.FBP;
             elseif ~isempty(strfind(obj.Reconstruction_Method,'TwIST'))
                RF = @obj.FBP_TwIST;
             end
                        
             res = [];
             if isempty(zrange) || 2~=numel(zrange) || ~(zrange(1)<zrange(2)) || ~(1==obj.downsampling)
                 return; 
             end;                             

             [sizeX,sizeY,sizeZ] = size(obj.proj); 
             
             n_angles = numel(obj.angles);
             
             if sizeZ ~= n_angles
                 errormsg('Incompatible settings - can not continue');
                 return;
             end
                              
                 step = obj.angle_downsampling;                 
                 acting_angles = obj.angles(1:step:n_angles);
                 %                                                   
                 y_min = zrange(1);
                 y_max = zrange(2);
                 YL = y_max - y_min + 1; % mmmm
                                                   
                 if strcmp(obj.Reconstruction_GPU,'ON') && obj.isGPU 
                                          
                         gpu_proj = gpuArray(cast(obj.proj(:,y_min:y_max,:),'single'));
                         gpu_volm = [];
                         
                         for y = 1 : YL                                       
                            sinogram = squeeze(gpu_proj(:,y,:));
                            %sinogram = obj.pad_sinogram_by_width_percentage(sinogram,0.41);
                            reconstruction = RF(sinogram);
                            if isempty(gpu_volm)
                                [sizeR1,sizeR2] = size(reconstruction);
                                gpu_volm = gpuArray(single(zeros(sizeR1,sizeR2,YL))); % XYZ
                            end                            
                            gpu_volm(:,:,y) = reconstruction;                            
                         end                           
                         res = gather(gpu_volm);
                                              
                 elseif strcmp(obj.Reconstruction_GPU,'OFF')
                                                                                                                     
                         for y = 1 : YL                                       
                            sinogram = squeeze(double(obj.proj(:,y_min+y-1,:)));
                            %sinogram = obj.pad_sinogram_by_width_percentage(sinogram,0.41);
                            % 
                            reconstruction = RF(sinogram);
                            if isempty(obj.volm)
                                [sizeR1,sizeR2] = size(reconstruction);
                                obj.volm = zeros(sizeR1,sizeR2,YL,'single'); % XYZ
                            end
                            %
                            res(:,:,y) = reconstruction;
                         end                                                                                                                
                 end                     
                                                               
             res( res <= 0 ) = 0; % mm? 
             
        end
%-------------------------------------------------------------------------%                
        function run_batch(obj,omero_data_manager,verbose,~)
                                                  
            if strcmp(obj.Reconstruction_Largo,'ON') && 1 ~= obj.downsampling
                errordlg('only 1/1 proj-volm scale, full size, is supported, can not continue');
                return;                     
            end
            % 
            if ~isempty(obj.menu_controller)                            
                s1 = get(obj.menu_controller.menu_OMERO_Working_Data_Info,'Label');
                s2 = get(obj.menu_controller.menu_Batch_Indicator_Src,'Label');
            end;
            %
            if exist('s1','var') && exist('s2','var') ... 
               && ( strcmp(s1,s2) || ~isempty(obj.omero_Image_IDs) ) ... 
               && ~isempty(omero_data_manager.session) % images should be loaded from OMERO
                %
                imageList = [];
                if ~isempty(obj.omero_Image_IDs)
                    imageList = obj.omero_Image_IDs;
                else
                    imageList = getImages(omero_data_manager.session, 'dataset', omero_data_manager.dataset.getId.getValue);
                end
                
                if isempty(imageList)
                    errordlg(['Dataset ' pName ' have no images'])
                    return;
                end;
                %
                waitmsg = 'Batch processing...';
                if verbose
                    hw = waitbar(0,waitmsg);
                end
                for k = 1:length(imageList) 
                        if exist('hw','var')
                            waitbar((k-1)/length(imageList),hw); drawnow
                        end
                        tic
                        infostring = obj.OMERO_load_image(omero_data_manager,imageList(k),false);
                        disp(infostring);
                        disp(['loading time = ' num2str(toc)]);                                                
                        if ~isempty(infostring)                    
                            tic
                            if ~isempty(obj.delays) %FLIM                                
                                obj.perform_reconstruction_FLIM;
                            else
                                if strcmp(obj.Reconstruction_Largo,'ON')
                                    obj.perform_reconstruction_Largo;
                                else
                                    obj.volm = obj.perform_reconstruction(false);
                                end
                            end
                            disp(['reconstruction time = ' num2str(toc)]);
                            %
                            % save volume on disk - presume OME.tiff filenames everywhere
                            tic
                            iName = char(java.lang.String(imageList(k).getName().getValue()));                            
                            L = length(iName);
                            if strcmp(obj.batchsaveformat,'.OME.tiff')
                                savefilename = [iName(1:L-9) '_VOLUME.OME.tiff'];
                            elseif strcmp(obj.batchsaveformat,'.tif')
                                savefilename = [iName(1:L-9) '_VOLUME.tif'];
                            else strcmp(obj.batchsaveformat,'.mat')
                                savefilename = [iName(1:L-9) 'VOLUME.mat'];
                            end
                            if isempty(obj.delays) % non-FLIM
                                obj.save_volume([obj.BatchDstDirectory filesep savefilename],false); % silent
                            else
                                obj.save_volm_FLIM([obj.BatchDstDirectory filesep savefilename],false); % silent
                            end
                            disp([obj.BatchDstDirectory filesep savefilename]);
                            disp(['saving time = ' num2str(toc)]);                            
                        end   
                        if exist('hw','var')
                            waitbar(k/length(imageList),hw);drawnow;
                        end
                end 
                obj.omero_Image_IDs = [];
                if exist('hw','var')
                    delete(hw);drawnow;
                end
                
            else % images should be loaded from HD
                
                if ~isdir(obj.BatchSrcDirectory)
                    errordlg('wrong BatchSrcDirectory, can not continue'), return;                    
                end                    

                if ~isempty(obj.file_names)
                    names_list = obj.file_names;
                else                    
                    files = dir([obj.BatchSrcDirectory filesep '*.OME.tiff']);
                    num_files = length(files);
                    if 0 ~= num_files
                        names_list = cell(1,num_files);
                        for k = 1:num_files
                            names_list{k} = char(files(k).name);
                        end
                    end
                end

                if 0~=length(files)
                   waitmsg = 'Batch processing...';
                    if verbose
                        hw = waitbar(0,waitmsg);
                    end
                   for k=1:numel(names_list)
                        if exist('hw','var'), waitbar((k-1)/numel(names_list),hw); drawnow; end;
                        fname = [obj.BatchSrcDirectory filesep names_list{k}];                    
                        tic
                        infostring = obj.Set_Src_Single(fname,false);
                        disp(infostring);
                        disp(['loading time = ' num2str(toc)]);                                                    
                        if isempty(infostring)
                            tic
                            infostring = obj.Set_Src_FLIM(fname,'sum',false);
                            disp(infostring);                            
                        end
                        if ~isempty(infostring)
                            tic
                            if ~isempty(obj.delays) %FLIM
                                obj.perform_reconstruction_FLIM;
                            else
                                if strcmp(obj.Reconstruction_Largo,'ON')
                                    obj.perform_reconstruction_Largo;
                                else
                                    obj.volm = obj.perform_reconstruction(false);
                                end
                            end
                            disp(['reconstruction time = ' num2str(toc)]);
                            %
                            % save volume on disk
                            iName = names_list{k};
                            L = length(iName);
                            if strcmp(obj.batchsaveformat,'.OME.tiff')
                                savefilename = [iName(1:L-9) '_VOLUME.OME.tiff'];
                            elseif strcmp(obj.batchsaveformat,'.tif')
                                savefilename = [iName(1:L-9) '_VOLUME.tif'];
                            else strcmp(obj.batchsaveformat,'.mat')
                                savefilename = [iName(1:L-9) 'VOLUME.mat'];
                            end
                            tic
                            if isempty(obj.delays) % non-FLIM
                                obj.save_volume([obj.BatchDstDirectory filesep savefilename],false); % silent
                            else
                                obj.save_volm_FLIM([obj.BatchDstDirectory filesep savefilename],false); % silent
                            end
                            disp([obj.BatchDstDirectory filesep savefilename]);
                            disp(['saving time = ' num2str(toc)]);                            
                        end                    
                        if exist('hw','var'), waitbar(k/numel(names_list),hw); drawnow; end;
                   end
                   if exist('hw','var'), delete(hw);drawnow; end
                else
                    %%%%%%%%%%%%%% try stack layout here - start
                    disp('looking for image stacks')
                    files = dir(obj.BatchSrcDirectory);
                    dir_names = [];
                    for k=1:length(files)
                        curname = files(k).name;
                        if isdir([obj.BatchSrcDirectory filesep curname]) && ~strcmp(curname,'.') && ~strcmp(curname,'..')
                            dir_names = [dir_names; {curname}];
                        end                                
                    end
                    try 
                        waitmsg = 'Batch processing...';
                        if verbose 
                            hw = waitbar(0,waitmsg);  
                        end
                        for k=1:length(dir_names)
                            %disp('entered folder')
                            if exist('hw','var'), waitbar((k-1)/length(dir_names),hw); drawnow; end;
                            pth = [obj.BatchSrcDirectory filesep char(dir_names(k))];
                            %disp(pth)
                            if isempty(obj.imstack_get_delays(pth))
                                disp(['Loaded image stack ' num2str(k) ' of ' num2str(length(dir_names))])
                                tic
                                infostring = obj.imstack_Set_Src_Single(pth,true);
                                %disp('Loaded image stack')
                                disp(infostring);
                                disp(['loading time = ' num2str(toc)]);                                                            
                            else
                                disp('option2')
                                tic
                                infostring = obj.imstack_Set_Src_Single_FLIM(pth,'sum',false);
                                disp(infostring);
                                disp(['loading time = ' num2str(toc)]);
                            end
                            if ~isempty(infostring)
                                tic
                                obj.Z_range = []; % no selection
                                if ~isempty(obj.delays) %FLIM
                                    obj.perform_reconstruction_FLIM;
                                else
                                    if strcmp(obj.Reconstruction_Largo,'ON')
                                        obj.perform_reconstruction_Largo;
                                    else
                                        obj.volm = obj.perform_reconstruction(false);
                                    end
                                end
                                disp(['reconstruction time = ' num2str(toc)]);
                                %
                                % save volume on disk
                                tic
                                iName = char(dir_names(k));
                                %savefilename = [iName '_VOLUME.OME.tiff'];
                                if strcmp(obj.batchsaveformat,'.OME.tiff')
                                    savefilename = [iName '_VOLUME.OME.tiff'];
                                elseif strcmp(obj.batchsaveformat,'.tif')
                                    savefilename = [iName '_VOLUME.tif'];
                                else strcmp(obj.batchsaveformat,'.mat')
                                    savefilename = [iName 'VOLUME.mat'];
                                end
                                if isempty(obj.delays) % non-FLIM
                                    obj.save_volume([obj.BatchDstDirectory filesep savefilename],true); % silent
                                else
                                    obj.save_volm_FLIM([obj.BatchDstDirectory filesep savefilename],false); % silent
                                end
                                disp([obj.BatchDstDirectory filesep savefilename]);
                                disp(['saving time = ' num2str(toc)]);                                
                            end                    
                        end
                        if exist('hw','var'), delete(hw);drawnow; end;
                    catch                        
                    end
                    %%%%%%%%%%%%%% try stack layout here - ends
                end
                
            end 
            
        end
%-------------------------------------------------------------------------%        
% memory mapping
        function clear_memory_mapping(obj,~,~)

                obj.memmap_proj = []; 
                obj.memmap_volm = []; 

                if exist(obj.proj_mapfile_name,'file')
                    delete(obj.proj_mapfile_name);
                end

                if exist(obj.volm_mapfile_name,'file')
                    delete(obj.volm_mapfile_name);
                end            
        end
%-------------------------------------------------------------------------%        
        function initialize_memmap_proj(obj,omeMeta,imgdata,verbose,~) % XYZCT at C=1

            obj.proj_mapfile_name = global_tempname;
            
            sizeY = omeMeta.getPixelsSizeX(0).getValue;
            sizeX = omeMeta.getPixelsSizeY(0).getValue;           
            sizeZ = omeMeta.getPixelsSizeZ(0).getValue;            
            sizeC = omeMeta.getPixelsSizeC(0).getValue;            
            sizeT = omeMeta.getPixelsSizeT(0).getValue;            

            n_planes = sizeZ*sizeC*sizeT;
            
            [obj.proj_mapfile_name,obj.memmap_proj] = initialize_memmap([sizeX sizeY],n_planes,'plane',class(imgdata{1,1}));

            if verbose
                wait_handle=waitbar(0,'Initializing memory mapping...');
            end;
            
            for t = 1 : sizeT
                for z = 1 : sizeZ
                    index = z + (t-1)*sizeZ;                    
                    obj.memmap_proj.Data(index).plane = imgdata{index,1};
                    if verbose, waitbar(index/n_planes,wait_handle), end;
                end
            end            
            if verbose, close(wait_handle), end;
            
        end
%-------------------------------------------------------------------------%        
        function load_proj_from_memmap(obj,t,~) % t is the index of FLIM time
                        
            if isempty(obj.memmap_proj) || isempty(obj.delays) || t > numel(obj.delays)
                return;
            end;
            
            sizeT = numel(obj.delays);
            n_planes = numel(obj.memmap_proj.Data);
            sizeZ = n_planes/sizeT;
            
            obj.proj = [];
            memRef = obj.memmap_proj.Data;
                    for z = 1 : sizeZ
                       index = z + (t-1)*sizeZ;
                       plane = memRef(index).plane;
                       
                       if strcmp('Vertical',obj.swap_XY_dimensions) || obj.FLIM_proj_load_swap_XY_dimensions
                           plane = rot90(plane);
                       end

                       if ~isempty(obj.M1_vshift)
                           plane = obj.M1_imshift(plane,obj.M1_hshift,obj.M1_vshift,-obj.M1_rotation);
                       end
                       
                       s = obj.Prefiltering_Size;
                       if isnumeric(s)
                           plane = medfilt2(plane,'symmetric',[s s]); 
                       end
                                                                     
                       if isempty(obj.proj)
                           obj.proj = zeros(size(plane,1),size(plane,2),sizeZ,class(plane));
                       end
                       obj.proj(:,:,z) = plane;
                    end                        
        end
%-------------------------------------------------------------------------%        
        function initialize_memmap_volm_FLIM(obj,verbose,~) % XYZCT at C=1

            if isempty(numel(obj.delays)) || isempty(obj.volm), return, end;             
            % 
            obj.memmap_volm = [];
            if exist(obj.volm_mapfile_name,'file')
                delete(obj.volm_mapfile_name);
            end 
                                    
            [sizeX, sizeY, sizeZ] = size(obj.volm);
            sizeC = 1;
            sizeT = numel(obj.delays);            
            n_planes = sizeZ*sizeC*sizeT;
            
            [obj.volm_mapfile_name,obj.memmap_volm] = initialize_memmap([sizeX sizeY],n_planes,'plane',class(obj.volm));                        

            if verbose
                wait_handle=waitbar(0,'Initializing volm memory mapping...');
                for z = 1 : sizeZ
                       obj.memmap_volm.Data(z).plane = obj.volm(:,:,z);
                       if verbose, waitbar(z/sizeZ,wait_handle), end;
                end
                close(wait_handle);
            end

        end                              
%-------------------------------------------------------------------------%        
        function upload_volm_to_memmap(obj,t,verbose) % XYZCT at C=1
            
            if verbose
                wait_handle=waitbar(0,['Uploading current volm to memmap, t = ' num2str(t)]);
            end;
            
            sizeZ = size(obj.volm,3);
            
            for z = 1 : sizeZ
                index = z + (t-1)*sizeZ;
                obj.memmap_volm.Data(index).plane = obj.volm(:,:,z);
                if verbose, waitbar(index/sizeZ,wait_handle), end;
            end                        

            if verbose, close(wait_handle), end;
                                                            
        end        
%-------------------------------------------------------------------------% 
        function initialize_memmap_proj_OMERO(obj,omero_data_manager,image,verbose,~) % XYZCT at C=1
            
            obj.memmap_proj = [];
            if exist(obj.proj_mapfile_name,'file')
                delete(obj.proj_mapfile_name);
            end                         
            obj.proj_mapfile_name = global_tempname;
                                                     
            pixelsList = image.copyPixels();    
            pixels = pixelsList.get(0);
                                           
            pixelsId = pixels.getId().getValue();
            rawPixelsStore = omero_data_manager.session.createRawPixelsStore(); 
            rawPixelsStore.setPixelsId(pixelsId, false);    

            sizeX = pixels.getSizeY.getValue;
            sizeY = pixels.getSizeX.getValue;       
            sizeZ = pixels.getSizeZ.getValue;           
            sizeC = pixels.getSizeC.getValue;
            sizeT = pixels.getSizeT.getValue;
            
            rawPlane = rawPixelsStore.getPlane(0,0,0);                    
            plane = toMatrix(rawPlane, pixels)';                                 
            
            n_planes = sizeZ*sizeC*sizeT;

            [obj.proj_mapfile_name,obj.memmap_proj] = initialize_memmap([sizeX sizeY],n_planes,'plane',class(plane));

            if verbose
                wait_handle=waitbar(0,'Initializing memory mapping...');
            end;
            
            for t = 1 : sizeT
                for z = 1 : sizeZ
                    index = z + (t-1)*sizeZ;                   
                    rawPlane = rawPixelsStore.getPlane(z-1,0,t-1);                    
                    plane = toMatrix(rawPlane, pixels)';                                 
                    %
                    s = obj.Prefiltering_Size;
                    if ~isnumeric(s)
                        obj.memmap_proj.Data(index).plane = plane;
                    else
                        obj.memmap_proj.Data(index).plane = medfilt2(plane,'symmetric',[s s]); 
                    end
                    %
                    obj.memmap_proj.Data(index).plane = plane;
                    if verbose, waitbar(index/n_planes,wait_handle), end;
                end
            end            

            if verbose, close(wait_handle), end;
                                       
            rawPixelsStore.close();
            
        end
%-------------------------------------------------------------------------%         
        function save_volm_FLIM(obj,full_filename,verbose,~) % from memmap to OME.tiff
            %
            if exist(full_filename,'file')
                delete(full_filename);
            end                                     
            %
            if isempty(obj.memmap_volm) || isempty(obj.delays), return, end;

            sizeT = numel(obj.delays);
            memRef = obj.memmap_volm.Data;
            n_planes = numel(memRef);
            sizeZ = n_planes/sizeT; % mmm
            sizeC = 1;
            plane = memRef(1).plane;
            sizeX = size(plane,1);
            sizeY = size(plane,2);
            datatype = class(plane); % 'uint16'; % mmmmm

            toInt = @(x) ome.xml.model.primitives.PositiveInteger(java.lang.Integer(x));
            OMEXMLService = loci.formats.services.OMEXMLServiceImpl();
            metadata = OMEXMLService.createOMEXMLMetadata();
            metadata.createRoot();
            metadata.setImageID('Image:0', 0);
            metadata.setPixelsID('Pixels:0', 0);
            metadata.setPixelsBinDataBigEndian(java.lang.Boolean.TRUE, 0, 0);

            % Set pixels type
            pixelTypeEnumHandler = ome.xml.model.enums.handlers.PixelTypeEnumHandler();
            if strcmp(datatype,'single')
                pixelsType = pixelTypeEnumHandler.getEnumeration('float');
            else
                pixelsType = pixelTypeEnumHandler.getEnumeration(datatype);
            end
            metadata.setPixelsType(pixelsType, 0);

            % Set dimension order
            dimensionOrderEnumHandler = ome.xml.model.enums.handlers.DimensionOrderEnumHandler();
            dimensionOrder = dimensionOrderEnumHandler.getEnumeration('XYZCT');
            metadata.setPixelsDimensionOrder(dimensionOrder, 0);

            % Set channels ID and samples per pixel
            for i = 1: sizeC
                metadata.setChannelID(['Channel:0:' num2str(i-1)], 0, i-1);
                metadata.setChannelSamplesPerPixel(toInt(1), 0, i-1);
            end

            metadata.setPixelsSizeX(toInt(sizeX), 0);
            metadata.setPixelsSizeY(toInt(sizeY), 0);
            metadata.setPixelsSizeZ(toInt(sizeZ), 0);
            metadata.setPixelsSizeC(toInt(sizeC), 0);
            metadata.setPixelsSizeT(toInt(sizeT), 0);   
            %            
            metadata.setPixelsPhysicalSizeX(ome.xml.model.primitives.PositiveFloat(java.lang.Double(1)),0);
            metadata.setPixelsPhysicalSizeY(ome.xml.model.primitives.PositiveFloat(java.lang.Double(1)),0); 
            if ~isempty(obj.PixelsPhysicalSizeX) && ~isempty(obj.PixelsPhysicalSizeY)
                toPosFloat = @(x) ome.xml.model.primitives.PositiveFloat(java.lang.Double(x));
                metadata.setPixelsPhysicalSizeX(toPosFloat(obj.PixelsPhysicalSizeX*obj.downsampling),0);
                metadata.setPixelsPhysicalSizeY(toPosFloat(obj.PixelsPhysicalSizeY*obj.downsampling),0);
                metadata.setPixelsPhysicalSizeZ(toPosFloat(obj.PixelsPhysicalSizeX*obj.downsampling),0);
            end                                                            
            %            
            modlo = loci.formats.CoreMetadata();% FLIM
            modlo.moduloT.type = loci.formats.FormatTools.LIFETIME;                        
            modlo.moduloT.unit = obj.FLIM_unit;
            modlo.moduloT.typeDescription = obj.FLIM_typeDescription;                                                         
            modlo.moduloT.labels = javaArray('java.lang.String',length(obj.delays));                   
            
            for i=1:length(obj.delays)
                modlo.moduloT.labels(i)= java.lang.String(num2str(obj.delays(i)));
            end                                                                                            
            %  
            OMEXMLService.addModuloAlong(metadata, modlo, 0);     
            %
            % Create ImageWriter
            writer = loci.formats.ImageWriter();
            writer.setWriteSequentially(true);
            writer.setMetadataRetrieve(metadata);        

            writer.setCompression('LZW');
            writer.getWriter(full_filename).setBigTiff(true);

            writer.setId(full_filename);

                % Load conversion tools for saving planes
                switch datatype
                    case {'int8', 'uint8'}
                        getBytes = @(x) x(:);
                    case {'uint16','int16'}
                        getBytes = @(x) loci.common.DataTools.shortsToBytes(x(:), 0);
                    case {'uint32','int32'}
                        getBytes = @(x) loci.common.DataTools.intsToBytes(x(:), 0);
                    case {'single'}
                        getBytes = @(x) loci.common.DataTools.floatsToBytes(x(:), 0);
                    case 'double'
                        getBytes = @(x) loci.common.DataTools.doublesToBytes(x(:), 0);
                end

                if verbose
                    wait_handle=waitbar(0,['Saving planes to ' full_filename]);
                end;     

                for index = 1 : n_planes
                    plane = cast(memRef(index).plane,datatype);
                    writer.saveBytes(index-1, getBytes(plane));
                    if verbose, waitbar(index/n_planes,wait_handle), end;
                end
                if verbose, close(wait_handle), end;

                writer.close();        
        end
%-------------------------------------------------------------------------% 
        function perform_reconstruction_FLIM(obj,~,~) 
                        % this block is just clearing memmap - start
                        obj.memmap_volm = [];
                        if exist(obj.volm_mapfile_name,'file')
                            delete(obj.volm_mapfile_name);
                        end 
                        % this block is just clearing memmap - ends                                                                        
                        sizeT = numel(obj.delays);
                        verbose = true;
                        for t = 1 : sizeT
                                obj.load_proj_from_memmap(t);                            
                                if strcmp(obj.Reconstruction_Largo,'ON')
                                    obj.perform_reconstruction_Largo;
                                else
                                    obj.volm = obj.perform_reconstruction(verbose);
                                end    
                            if isempty(obj.memmap_volm) 
                                obj.initialize_memmap_volm_FLIM(true);
                            end
                            obj.upload_volm_to_memmap(t,verbose);
                        end              
        end
%-------------------------------------------------------------------------%         
        function infostring = imstack_Set_Src_Single(obj,pth,verbose,~)
            
            infostring = [];
            obj.mem_info = memory;
            max_array_size = obj.mem_info.MaxPossibleArrayBytes;
            
            if ~isdir(pth), return, end % shouldn't happen
            
            % load in background images and do averaging now %
            if ~isempty(obj.brightbgdir)
                bgwait = waitbar()
                ext = '*.tif';
                D = dir( fullfile(obj.brightbgdir,ext) );
                if isempty(D), ext = '*.tiff';D = dir( fullfile(obj.brightbgdir,ext) ); end
                if isempty(D), return, end
                obj.brightbg = (single(imread([obj.brightbgdir filesep char(D(1).name)]))./size(D,1));
                for k = 2:size(D,1)
                     obj.brightbg = obj.brightbg + (single(imread([obj.brightbgdir filesep char(D(k).name)]))./size(D,1));
                end
            end

            if ~isempty(obj.darkbgdir)
                ext = '*.tif';
                D = dir( fullfile(obj.darkbgdir,ext) );
                if isempty(D), ext = '*.tiff';D = dir( fullfile(obj.darkbgdir,ext) ); end
                if isempty(D), return, end
                obj.darkbg = (single(imread([obj.darkbgdir filesep char(D(1).name)]))./size(D,1));;
                for k = 2:size(D,1)
                     obj.darkbg = obj.darkbg + (single(imread([obj.darkbgdir filesep char(D(k).name)]))./size(D,1));
                end
            end

           
            ext = '*.tif';
            D = dir( fullfile(pth,ext) );
            if isempty(D), ext = '*.tiff';D = dir( fullfile(pth,ext) ); end
            if isempty(D), return, end
            %
            obj.get_angles_from_imstack_filenames({D.name});
            if isempty(obj.angles)
                msgstr = 'imstack_Set_Src_Single: can not deduce angles, can not continue';
                if verbose
                    errordlg(msgstr); 
                else
                    disp(msgstr); 
                end
                return;
            end
            %
            n_planes = numel(obj.angles);
            %
            obj.proj = [];
            %            
                if verbose
                    str = strsplit(pth,filesep);
                    wait_handle = waitbar(0,['Reading planes from ', char(str(length(str)))]);
                    wait_handle.Children.Title.Interpreter = 'none';
                end                 
                %      

                k=1;
                plane = imread([pth filesep char(D(k).name)]);

                % background correction here %
                if ~isempty(obj.brightbgdir) && ~isempty(obj.darkbgdir)
                    % both corrections
                    plane = (single(plane)-obj.darkbg)./(obj.brightbg-obj.darkbg);
                    
                elseif ~isempty(obj.brightbgdir) && isempty(obj.darkbgdir)
                    % just bright correction
                    plane = single(plane)./obj.brightbg;

                elseif isempty(obj.brightbgdir) && ~isempty(obj.darkbgdir)
                    % just dark frame correction
                    plane = single(plane)-obj.darkbg;
                end

               
                
                obj.avgproj(1) = mean(plane(:));
                


                s = obj.Prefiltering_Size;
                if isnumeric(s)
                    plane = medfilt2(plane,'symmetric',[s s]); 
                end

                % swap XY dimensions immediately if needed
                if strcmp('Vertical',obj.swap_XY_dimensions)
                    plane = rot90(plane);
                end
                
                % Check if the final reconstructed volume could possibly
                % fit in memory - to avoid problems down the line
                [szx,szy] = size(plane);
                if 4.*szx*szx*szy > max_array_size
                    if verbose, close(wait_handle), end;
                    batchquestion = questdlg('Projection images are too large - reconstructed volume will not fit in memory. Is it okay to autmatically create a batch job and reconstruct this volume? You will not have a chance to edit recon. settings.',...
                        'Images too large: okay to batch process?','Yes: I''m happy with my settings','No: cancel loading','Yes: I''m happy with my settings');
                    switch batchquestion
                        case 'Yes: I''m happy with my settings'
                            % Crop projections into chunks based on memory
                            % size and save in relevant directories
                            if ~strcmp(obj.registration_method,'Auto + Manual confirmation') && ~strcmp(obj.registration_method,'Manual registration')
                                
                                n_stacks = ceil((4.*szx*szx*szy)/(max_array_size/3));
                                if verbose
                                    wait_handle = waitbar(0,'Cropping and re-saving projections...');
                                end
    
                                for i = 1:n_stacks
                                    % create folders to store cropped projs
                                    if ~exist(strcat(pth,filesep,'cropped_projections_for_batch_processing',filesep,'section_',num2str(i,'%02d'),'_of_',num2str(n_stacks,'%02d')),'dir')
                                        [status,msg] = mkdir(strcat(pth,filesep,'cropped_projections_for_batch_processing',filesep,'section_',num2str(i,'%02d'),'_of_',num2str(n_stacks,'%02d')));
                                        disp(status)
                                        disp(msg)
                                    end
                                end
                                for k = 1:n_planes
                                    plane = imread([pth filesep char(D(k).name)]);
                                    % do background correction here
                                    if ~isempty(obj.brightbgdir) && ~isempty(obj.darkbgdir)
                                        % both corrections
                                        plane = (single(plane)-obj.darkbg)./(obj.brightbg-obj.darkbg);
                                        plane(plane<0)=0;
                                        
                                    elseif ~isempty(obj.brightbgdir) && isempty(obj.darkbgdir)
                                        % just bright correction
                                        plane = single(plane)./obj.brightbg;
                    
                                    elseif isempty(obj.brightbgdir) && ~isempty(obj.darkbgdir)
                                        % just dark frame correction
                                        plane = single(plane)-obj.darkbg;
                                        plane(plane<0)=0;
                                    end
                                    obj.avgproj(k) = mean(plane(:));
                        
                                    % do median filtration if needed
                                    s = obj.Prefiltering_Size;
                                    if isnumeric(s)
                                        plane = medfilt2(plane,'symmetric',[s s]); 
                                    end
                
                                    % swap XY dimensions immediately if needed
                                    if strcmp('Vertical',obj.swap_XY_dimensions)
                                        plane = rot90(plane);
                                    end
                                    
                                    for i = 1:n_stacks
                                        % crop and save relevant parts
                                        tosave = plane(:,(i-1)*ceil(szy/n_stacks)+1:min((i)*ceil(szy/n_stacks),size(plane,2)));
                                        imwrite(uint16(tosave),strcat(pth,filesep,'cropped_projections_for_batch_processing',filesep,'section_',num2str(i,'%02d'),...
                                            '_of_',num2str(n_stacks,'%02d'),filesep,'projection',num2str(k,'%04d'),'.tif'));
                                    end
    
                                    if verbose, waitbar(k/n_planes,wait_handle), end
                                end
    
                                delete(wait_handle); drawnow;

                                if strcmp(obj.Bleaching_correction,'On')
                                    bleachfit = fit((1:size(obj.avgproj,2))',obj.avgproj','exp1');
                                    obj.bleachcorrection = bleachfit((1:size(obj.avgproj,2))');
                                    figure; plot(obj.bleachcorrection); title('Exponential fit to mean projection intensity'); xlabel('Projection number'); ylabel('Mean image intensity');
                                    hold on; scatter((1:size(obj.avgproj,2))',obj.avgproj'); hold off;
                                    bleaching_okay = questdlg('Does the photobleaching fitting look reasonable?','Bleaching correction confirmation','Yes, apply correction','No, continue without correction','Yes, apply correction');
                                    switch bleaching_okay
                                        case 'Yes, apply correction'
                                        case 'No, continue without correction'
                                            obj.Bleaching_correction = 'No';
                                    end
                                end
    
                                old_orientation = obj.swap_XY_dimensions;
                                obj.swap_XY_dimensions = 'Horizontal';
                                obj.BatchSrcDirectory = strcat(pth,filesep,'cropped_projections_for_batch_processing');
    
                                % Implementing a custom batch process, so not
                                % actually necessary to pass off to standard function.
    
                                %set(obj.menu_controller.menu_settings_Rotation_Axis_Orientation,'Label','Rotation axis orientation: Horizontal');
                                
                                savepth = strcat(pth,filesep,'reconstructed_slices');
                                mkdir(savepth);
                             
                                try 
                                    
                                    if verbose 
                                        hw = waitbar(0,'Processing as batch dataset...');  
                                    end
                                    maxsave = 0;
                                    obj.bleaching_batch = 'yes';
                                    for k=1:(n_stacks)
                                        %disp('entered folder')
                                        if exist('hw','var'), waitbar((k-1)/(n_stacks),hw); drawnow; end;
                                        pth2 = strcat(pth,filesep,'cropped_projections_for_batch_processing',filesep,'section_',num2str(k,'%01d'),'_of_',num2str(n_stacks,'%d'));
                                        %disp(pth)
                                        if isempty(obj.imstack_get_delays(pth2))
                                            disp(['Loaded image stack ' num2str(k) ' of ' num2str((n_stacks))])
                                            tic
                                            infostring = obj.imstack_Set_Src_Single(pth2,true);
                                            %disp('Loaded image stack')
                                            %disp(infostring);
                                            %disp(['loading time = ' num2str(toc)]);                                                            
                                        else
                                            disp('option2')
                                            tic
                                            infostring = obj.imstack_Set_Src_Single_FLIM(pth,'sum',false);
                                            %disp(infostring);
                                            %disp(['loading time = ' num2str(toc)]);
                                        end
                                        if k==1
                                            obj.large_projections_batch = 'Yes';
                                            % bypass registration for folders after first
                                            % one.
                                        end
                                        if ~isempty(infostring)
                                            tic
                                            obj.Z_range = []; % no selection
                                            if ~isempty(obj.delays) %FLIM
                                                obj.perform_reconstruction_FLIM;
                                            else
                                                if strcmp(obj.Reconstruction_Largo,'ON')
                                                    obj.perform_reconstruction_Largo;
                                                else
                                                    obj.volm = obj.perform_reconstruction(false);
                                                end
                                            end
                                            %disp(['reconstruction time = ' num2str(toc)]);
                                            %
                                            % save volume on disk
                                            
    
                                            if isempty(obj.delays) % non-FLIM
                                                hw2 = waitbar(0,'Saving section...');  
                                                [~,~,szZ] = size(obj.volm);
                                                %V = map(obj.volm,0,65535);
                                                %if 32 == obj.save_volume_bit_depth
                                                    % leave as is - single
                                                    for i = 1:szZ
                                                        V = squeeze(obj.volm(:,:,i));
                                                        
                                                        V = uint32((V./250).*((2^32)-1));
                                                        if max(V(:))>maxsave
                                                            maxsave = max(V(:));
                                                        end
    
                                                        t = Tiff(strcat(savepth,filesep,'slice',num2str((k-1)*ceil(szy/n_stacks)+i,'%04d'),'.tif'),'w');
                                                        tagstruct.ImageLength     = size(V,1);
                                                        tagstruct.ImageWidth      = size(V,2);
                                                        tagstruct.Photometric     = Tiff.Photometric.MinIsBlack;
                                                        tagstruct.BitsPerSample   = 32;
                                                        tagstruct.SamplesPerPixel = 1;
                                                        tagstruct.RowsPerStrip    = 16;
                                                        tagstruct.PlanarConfiguration = Tiff.PlanarConfiguration.Chunky;
                                                        tagstruct.Software        = 'MATLAB';
                                                        t.setTag(tagstruct);
                                                        t.write(V);
                                                        t.close();
    
                                                        %imwrite(V,strcat(savepth,filesep,'slice',num2str((k-1)*ceil(szy/n_stacks)+i,'%04d'),'.tif'));
                                                        waitbar(i/szZ,hw2)
                                                    end
                                                %elseif 16 == obj.save_volume_bit_depth
                                                %    for i = 1:szZ
                                                %        V = map(squeeze(obj.volm(:,:,i)),0,65535);
                                                %        V = uint16(V);
                                                %        imwrite(V,strcat(savepth,filesep,'slice',num2str((k-1)*ceil(szy/n_stacks)+i,'%04d'),'.tif'));
                                                %        waitbar(i/szZ,hw2)
                                                %    end
                                                %end
                                                
                                                % for i = 1:szZ
                                                %     imwrite(V(:,:,i),strcat(savepth,filesep,'slice',num2str((k-1)*ceil(szy/n_stacks)+i,'%04d'),'.tif'));
                                                %     waitbar(i/szZ,hw2)
                                                % end
                                                delete(hw2); drawnow;
                                            else
                                                obj.save_volm_FLIM([savepth filesep strcat('recon',num2str(n_stacks,'%01d'))],false); % silent
                                            end
                                            %disp([obj.BatchDstDirectory filesep savefilename]);
                                            %disp(['saving time = ' num2str(toc)]);                                
                                        end                    
                                    end
                                    if exist('hw','var'), delete(hw);drawnow; end;
                                    obj.large_projections_batch = 'No';
                                    obj.bleaching_batch = 'no';
                                    obj.swap_XY_dimensions = old_orientation;
                                catch 
    
                                
    
                                
                                end
    
                                % cleanup
                                % delete cropped projections?
                                % read 32-bit reconstructions and normalise,
                                % save as 16-bit? (if setting is appropriate)
                                if 16 == obj.save_volume_bit_depth
                                    hwsave = waitbar(0,'Normalising saved slices...');
                                    for i = 1:szy
                                        waitbar(i/szy,hwsave)
                                        temp = imread(strcat(savepth,filesep,'slice',num2str(i,'%04d'),'.tif'));
                                        temp = single(temp);
                                        temp = temp./single(maxsave);
                                        imwrite(uint16(temp.*((2^16)-1)),strcat(savepth,filesep,'slice',num2str(i,'%04d'),'.tif'));
                                    end
                                    delete(hwsave)
                                end
    
                                obj.proj = [];
                                obj.volm = [];
    
                                % offer to delete cropped projections??
    
                                deletecrops = questdlg('Would you like to delete the generated cropped projection images?','Delete cropped projections?',...
                                    'Yes','No','Yes');
                                switch deletecrops
                                    case 'Yes'
                                        delete(strcat(pth,filesep,'cropped_projections_for_batch_processing'));
                                    case 'No'
                                        return
                                end
    
    
    
                                return
                            else
                                errordlg('Automatic batching for large datasets does not support rotation of projection images, please select auto translation only, or no registration.')
                                return
                            end

                        case 'No: cancel loading'
                            %if verbose, close(wait_handle), end;
                            plane = [];
                            return
                    end
                end

                if isempty(obj.proj)
                    % [szx,szy] = size(plane);
                    obj.proj = zeros(szx,szy,n_planes,class(plane));
                end

                obj.proj(:,:,k)=plane;
                if verbose, waitbar(k/n_planes,wait_handle), end;
                
                
                for k=2:n_planes
                    plane = imread([pth filesep char(D(k).name)]);

                    % background correction here %
                    if ~isempty(obj.brightbgdir) && ~isempty(obj.darkbgdir)
                        % both corrections
                        plane = (single(plane)-obj.darkbg)./(obj.brightbg-obj.darkbg);
                        
                    elseif ~isempty(obj.brightbgdir) && isempty(obj.darkbgdir)
                        % just bright correction
                        plane = single(plane)./obj.brightbg;
    
                    elseif isempty(obj.brightbgdir) && ~isempty(obj.darkbgdir)
                        % just dark frame correction
                        plane = single(plane)-obj.darkbg;
                    end
                    
                     obj.avgproj(k) = mean(plane(:));

                    % do median filtration if needed
                    s = obj.Prefiltering_Size;
                    if isnumeric(s)
                        plane = medfilt2(plane,'symmetric',[s s]); 
                    end

                    % swap XY dimensions immediately if needed
                    if strcmp('Vertical',obj.swap_XY_dimensions)
                        plane = rot90(plane);
                    end
                    
                    %disp([num2str(szx) num2str(szy)])
                    obj.proj(:,:,k)=plane;

                    if verbose
                        if ~isempty(obj.brightbgdir) || ~isempty(obj.darkbgdir)
                            waitbar(k/n_planes,wait_handle,['Reading planes with background correction from ' char(str(length(str)))]);
                            wait_handle.Children.Title.Interpreter = 'none';
                        else
                            waitbar(k/n_planes,wait_handle);
                        end
                    end
                end                                
                
                
                if min(obj.proj(:)) > 2^15
                    obj.proj = obj.proj - 2^15;    % clear the sign bit which is set by labview
                end
                
                % possibly correcting orientation
                % if strcmp('Vertical',obj.swap_XY_dimensions)  % needs to reload with swapped dims
                %     %
                %     waitmsg = 'Changing rotation axis orientation for reconstruction...';
                %     if verbose
                %         hw = waitbar(0,waitmsg);
                %     end
                %     %
                %     obj.proj = [];                  
                %     %
                %     for p = 1 : n_planes    
                %         plane = imread([pth filesep char(D(p).name)]);
                %         plane = rot90(plane);
                %         %   
                %         if isempty(obj.proj)
                %             [sizeX,sizeY] = size(plane);
                %             obj.proj = zeros(sizeX,sizeY,n_planes,class(plane));                            
                %         end %  ini - end
                %         %
                %         obj.proj(:,:,p) = plane;
                %         %
                %         if ~isempty(hw), waitbar(p/n_planes,hw); drawnow, end;                                            
                %     end                                
                %     if ~isempty(hw), delete(hw), drawnow, end;                                                                                
                %     %
                % end
                % end orientation correcting...
                
                if strcmp(obj.Bleaching_correction,'On')
                    if ~strcmp(obj.bleaching_batch,'yes') % ensure same correction for all batched reconstructions
                        bleachfit = fit((1:size(obj.avgproj,2))',obj.avgproj','exp1');
                        obj.bleachcorrection = bleachfit((1:size(obj.avgproj,2))');
                    
                        figure; plot(obj.bleachcorrection); title('Exponential fit to mean projection intensity'); xlabel('Projection number'); ylabel('Mean image intensity');
                        hold on; scatter((1:size(obj.avgproj,2))',obj.avgproj'); hold off;
                        bleaching_okay = questdlg('Does the photobleaching fitting look reasonable?','Bleaching correction confirmation','Yes, apply correction','No, continue without correction','Yes, apply correction');
                        switch bleaching_okay
                            case 'Yes, apply correction'
                                %disp('clickedyes')
                            case 'No, continue without correction'
                                obj.Bleaching_correction = 'Off';
                        end
                    end
                end
                if strcmp(obj.Bleaching_correction,'On')
                    %disp('now doing correction')
                    for kk = 1:n_planes
                        if verbose, waitbar(kk/n_planes,wait_handle,'Applying photobleaching correction...'); end
                        obj.proj(:,:,kk) = (single(obj.proj(:,:,kk)).*single(mean(obj.bleachcorrection(:))))./single((obj.bleachcorrection(kk)));
                        
                    end
                end
                if verbose, close(wait_handle), end;

                % do registration if needed
                if ~strcmp('None',obj.registration_method)
                    obj.do_registration;
                end                                
                                            
            infostring = pth;
            
            obj.DefaultDirectory = pth;
            
            obj.on_new_proj_set;
            
            obj.omero_Image_IDs = [];
                                                
        end
%-------------------------------------------------------------------------%         
        function infostring = imstack_Set_Src_Single_FLIM(obj,pth,verbose,~)
            infostring = [];
            %
            % to do
            %
        end
%-------------------------------------------------------------------------%
        function ret = imstack_get_delays(obj,pth,~)            
            ret = [];
            %
            % to do
            %                                                
            try
            catch
                return;
            end
        end
%-------------------------------------------------------------------------%
        function get_angles_from_imstack_filenames(obj,D_in,~) % D is an array with imgstack Directory's filenames 
            %
                D = sort_nat(D_in);
                         
                try
                    obj.angles = zeros(1,numel(D));
                    for k=1:numel(D)
                        out = parse_string_for_attribute_value(char(D{k}),{'Rot'});
                        val = out{1}.value;
                        if ~isnumeric(val)
                            obj.angles = [];
                            break;
                        end               
                        obj.angles(k)=val;
                    end
                    if sum(isnan(obj.angles)) > 0 || sum(isinf(obj.angles)) > 0
                        obj.angles = [];
                    else                
                        return;
                    end
                catch
                    obj.angles = [];
                end
                
                % next attempt if 'Rot' convention fails - simply try to cast
                % everyhting before extension as numeric
                if isempty(obj.angles)
                    obj.angles = zeros(1,numel(D));
                    try
                        for k=1:numel(D)
                            str = char(D{k});
                            pointpos = strfind(str,'.');
                             val = str2double(str(1:pointpos-1));
                             if ~isnumeric(val)
                                 obj.angles = [];
                                 break;
                             end
                             obj.angles(k) = val;
                        end
                     if sum(isnan(obj.angles)) > 0 || sum(isinf(obj.angles)) > 0
                        obj.angles = [];
                     else                
                        return;
                     end
                    catch
                        obj.angles = [];                        
                    end    
                end
                %
                if isempty(obj.angles)  
                    obj.angles = zeros(1,numel(D));
                    try
                        obj.angles = (0:numel(D)-1)*360/numel(D);
                        if sum(isnan(obj.angles)) > 0 || sum(isinf(obj.angles)) > 0
                            obj.angles = [];
                        else                
                            return;
                        end           
                    catch
                        obj.angles = [];
                    end
                end 
                %
                if isempty(obj.angles)  
                    obj.angles = zeros(1,numel(D));
                    try
                        if isnumeric(obj.imstack_filename_convention_for_angle)
                            obj.angles = obj.imstack_filename_convention_for_angle;
                        end
                        if sum(isnan(obj.angles)) > 0 || sum(isinf(obj.angles)) > 0
                            obj.angles = [];
                        else                
                            return;
                        end                       
                    catch
                        obj.angles = [];
                    end
                end                 
            %
            %
            % IF FAILED, ADD HERE MORE METHODS TO GET ANGLES FROM FILNAMES 
            %
            %
            if sum(isnan(obj.angles)) > 0 || sum(isinf(obj.angles)) > 0
                obj.angles = [];
            end
        end      
%-------------------------------------------------------------------------%
        function do_registration(obj,~)
            switch obj.registration_method
                case 'Auto + Manual confirmation' 
                    obj.M1_do_registration;
                case 'Rotation axis shift only' 
                    obj.M2_do_registration;  
                case 'Manual registration'
                    obj.M3_do_registration;
            end
        end        
%-------------------------------------------------------------------------%
        function M2_do_registration(obj,~)
            [sizeX,sizeY,n_planes] = size(obj.proj);
            if strcmp('No',obj.large_projections_batch)
                
                sizeinmem = prod(size(obj.proj(:))).*4;
                [~,sysmem] = memory;
                %disp([num2str(sizeinmem) ' ' num2str(sysmem.PhysicalMemory.Available)])
                sizeontempdisk = java.io.File(tempdir).getFreeSpace();
                if sizeontempdisk <= sizeinmem
                    errordlg('Not enough disk space in tempdir - please clear some space before continuing.')
                    return
                end
                wait_handle = waitbar(0,'Creating projection memory-map file...');
                [mapfile_name_proj,memmap_PROJ] = initialize_memmap([sizeX sizeY n_planes],1,'pixels',class(obj.proj),'ini_data',obj.proj);                 
                close(wait_handle);
                        
                obj.proj = [];                
    
                %PROJ = memmap_PROJ.Data.pixels; % memmap projections copy for safety
                %offset = min(memmap_PROJ.Data.pixels(:));
                %offsets = zeros(n_planes);
                for i=1:n_planes
                    offsets(i) = min(min(memmap_PROJ.Data.pixels(:,:,i)));
                end
                offset = min(offsets);
    
                %PROJ = PROJ-offset;
                %
                % take some (nimg) images with their diametric opposites
                nangles = numel(obj.angles);
                P = nangles/2;
                nimg = 16;
                u = zeros(sizeX,sizeY,2,nimg,1); % XYCZT
                %
                angle_incr = floor(nangles/nimg/2); % to avoid repetition
                for k=1:nimg
                    i_1 = angle_incr*(k-1) + 1;
                    % counter index (of diametrically opposite projection)
                    if i_1<=P 
                        ci_1 = i_1 + P; 
                    else ci_1 = i_1 - P; 
                    end
                    u(:,:,1,k,1) = memmap_PROJ.Data.pixels(:,:,i_1)-offset;
                    u(:,:,2,k,1) = flipud(memmap_PROJ.Data.pixels(:,:,ci_1))-offset;
                end                                  
                %
                s1 = 3;
                s2 = 7;
                quality = zeros(1,nimg); % to use as weights
                shifts = zeros(1,nimg);            
                hw = [];
                waitmsg = ['Calculating corrections with ' obj.registration_method];
                if ~obj.run_headless
                    hw = waitbar(0,waitmsg);
                end                        
                for k=1:nimg
                    fixed = squeeze(u(:,:,1,k,1));
                    warped = squeeze(u(:,:,2,k,1));                
    %                     fixed = imresize(fixed,[sizeX round(sizeY/4)]);
    %                     warped = imresize(warped,[sizeX round(sizeY/4)]);
                    %
                    sigma = 3;                
                    [gf1,gf2] = gsderiv(fixed,sigma,1);
                    [gw1,gw2] = gsderiv(warped,sigma,1);
                    fixed = sqrt(gf1.*gf1 + gf2.*gf2);
                    warped = sqrt(gw1.*gw1 + gw2.*gw2);
                    %
                    z = xcorr2_fft(fixed,warped);
                    %
                    g1 = gsderiv(z,s1,0);
                    g2 = gsderiv(z,s2,0);
                    z = (g1-g2);
                    %
                    z(z<0)=0;
                    %
                    [wc,hc] = size(z);
                    wc=fix(wc/2);
                    hc=fix(hc/2);
                    %
                    maxz = max(z(:));
                    [x,y] = find(z==maxz(1,1));
                    %
                    quality(k) = z(x,y)/mean(z(:));
                    shifts(k) = x-wc;
                    %
                    if ~isempty(hw), waitbar(k/nimg,hw); drawnow, end
                end
                if ~isempty(hw), delete(hw), drawnow, end
                %    
                shift_weighted = sum(shifts.*quality)/sum(quality);
                shift_median = median(shifts);
                disp(['Rotation axis shift: weighted = ' num2str(shift_weighted)  ', median = ' num2str(shift_median)]);
                %            
                hw = [];
                waitmsg = ['Introducing corrections with ' obj.registration_method];
                if ~obj.run_headless
                    hw = waitbar(0,waitmsg);
                end
                %                        
                %s = round(shift_median/2); % safest possible
                obj.registration_shift = shift_median;
                set(obj.menu_controller.menu_current_registration,'Label',['Current registration: Shift: ',num2str(obj.registration_shift),...
                    ', Rot.: ',num2str(obj.registration_rotation),char(176)]);

                if shift_median>0
                    s = ceil(shift_median/2);
                    for k = 1:n_planes
                        I = memmap_PROJ.Data.pixels(:,:,k)-offset;
                        if isempty(obj.proj) % proper place to crop the image?
                                [szx,szy] = size(I);
                                obj.proj = zeros(szx-2*s,szy,n_planes,class(I));
                        end                
                            Icorr = imtranslate(I,[0,-shift_median/2]);
                            obj.proj(:,:,k) = Icorr(s+1:szx-s,:);
                        if ~isempty(hw), waitbar(k/n_planes,hw); drawnow, end
                    end
                elseif shift_median == 0
                    for k = 1:n_planes
                        obj.proj(:,:,k) = memmap_PROJ.Data.pixels(:,:,k)-offset;
                    end
                else
                    s = ceil(-shift_median/2);
                    for k = 1:n_planes
                        I = memmap_PROJ.Data.pixels(:,:,k)-offset;
                        if isempty(obj.proj) % proper place to crop the image?
                                [szx,szy] = size(I);
                                obj.proj = zeros(szx-2*s,szy,n_planes,class(I));
                        end                
                            Icorr = imtranslate(I,[0,-shift_median/2]);
                            obj.proj(:,:,k) = Icorr(s+1:szx-s,:);
                        if ~isempty(hw), waitbar(k/n_planes,hw); drawnow, end
                    end
                end
                if ~isempty(hw), delete(hw), drawnow, end
                %
                clear('memmap_PROJ');
                delete(mapfile_name_proj);
            else
                for i=1:n_planes
                    offsets(i) = min(min(obj.proj(:,:,i)));
                end
                offset = min(offsets);
                hw3 = [];
                waitmsg = ['Introducing corrections with ' obj.registration_method];
                if ~obj.run_headless
                    hw3 = waitbar(0,waitmsg);
                end
                if obj.registration_shift>0
                    disp('Performing registration with saved shift')
                    s = ceil(obj.registration_shift/2);
                    for k = 1:n_planes
                        I = memmap_PROJ.Data.pixels(:,:,k)-offset;
                        if isempty(obj.proj) % proper place to crop the image?
                                [szx,szy] = size(I);
                                obj.proj = zeros(szx-2*s,szy,n_planes,class(I));
                        end                
                            Icorr = imtranslate(I,[0,-obj.registration_shift/2]);
                            obj.proj(:,:,k) = Icorr(s+1:szx-s,:);
                        if ~isempty(hw), waitbar(k/n_planes,hw); drawnow, end
                    end
                elseif obj.registration_shift == 0
                    for k = 1:n_planes
                        obj.proj(:,:,k) = memmap_PROJ.Data.pixels(:,:,k)-offset;
                    end
                else
                    s = ceil(-obj.registration_shift/2);
                    for k = 1:n_planes
                        I = memmap_PROJ.Data.pixels(:,:,k)-offset;
                        if isempty(obj.proj) % proper place to crop the image?
                                [szx,szy] = size(I);
                                obj.proj = zeros(szx-2*s,szy,n_planes,class(I));
                        end                
                            Icorr = imtranslate(I,[0,-obj.registration_shift/2]);
                            obj.proj(:,:,k) = Icorr(s+1:szx-s,:);
                        if ~isempty(hw), waitbar(k/n_planes,hw); drawnow, end
                    end
                end
                if ~isempty(hw3), delete(hw3), drawnow, end
                %

            end

        end        
%-------------------------------------------------------------------------%


        function M1_do_registration(obj,~) % new semi-manual full registration
            [sizeX,sizeY,n_planes] = size(obj.proj);
            sizeinmem = prod(size(obj.proj(:))).*4;
            [~,sysmem] = memory;
            %disp([num2str(sizeinmem) ' ' num2str(sysmem.PhysicalMemory.Available)])
            sizeontempdisk = java.io.File(tempdir).getFreeSpace();
            if sizeontempdisk <= sizeinmem
                errordlg('Not enough disk space in tempdir - please clear some space before continuing.')
                return
            end
            wait_handle = waitbar(0,'Creating projection memory-map file...');
            [mapfile_name_proj,memmap_PROJ] = initialize_memmap([sizeX sizeY n_planes],1,'pixels',class(obj.proj),'ini_data',obj.proj);                 
            close(wait_handle);
            %disp(mapfile_name_proj)     
            obj.proj = [];                

            %PROJ = memmap_PROJ.Data.pixels; % memmap projections copy for safety
            %offset = min(memmap_PROJ.Data.pixels(:));
            %offsets = zeros(n_planes);
            for i=1:n_planes
                offsets(i) = min(min(memmap_PROJ.Data.pixels(:,:,i)));
            end
            offset = min(offsets);

            %obj.proj = obj.proj-offset;

            %PROJ = PROJ-offset;
            %
            % take some (nimg) images with their diametric opposites
            nangles = numel(obj.angles);
            P = nangles/2;
            nimg = 16;
            u = zeros(sizeX,sizeY,2,nimg,1); % XYCZT
            %
            angle_incr = floor(nangles/nimg/2); % to avoid repetition
            for k=1:nimg
                i_1 = angle_incr*(k-1) + 1;
                % counter index (of diametrically opposite projection)
                if i_1<=P 
                    ci_1 = i_1 + P; 
                else ci_1 = i_1 - P; 
                end
                u(:,:,1,k,1) = memmap_PROJ.Data.pixels(:,:,i_1)-offset;
                u(:,:,2,k,1) = flipud(memmap_PROJ.Data.pixels(:,:,ci_1))-offset;
            end                                  
            %
            s1 = 3;
            s2 = 7;
            quality = zeros(1,nimg); % to use as weights
            shifts = zeros(1,nimg);            
            hw = [];
            waitmsg = 'Calculating optimum rotation axis shift...';
            if ~obj.run_headless
                hw = waitbar(0,waitmsg);
            end                        
            for k=1:nimg
                fixed = squeeze(u(:,:,1,k,1));
                warped = squeeze(u(:,:,2,k,1));                
%                     fixed = imresize(fixed,[sizeX round(sizeY/4)]);
%                     warped = imresize(warped,[sizeX round(sizeY/4)]);
                %
                sigma = 3;                
                [gf1,gf2] = gsderiv(fixed,sigma,1);
                [gw1,gw2] = gsderiv(warped,sigma,1);
                fixed = sqrt(gf1.*gf1 + gf2.*gf2);
                warped = sqrt(gw1.*gw1 + gw2.*gw2);
                %
                z = xcorr2_fft(fixed,warped);
                %
                g1 = gsderiv(z,s1,0);
                g2 = gsderiv(z,s2,0);
                z = (g1-g2);
                %
                z(z<0)=0;
                %
                [wc,hc] = size(z);
                wc=fix(wc/2);
                hc=fix(hc/2);
                %
                maxz = max(z(:));
                [x,y] = find(z==maxz(1,1));
                %
                quality(k) = z(x,y)/mean(z(:));
                shifts(k) = x-wc;
                %
                if ~isempty(hw), waitbar(k/nimg,hw); drawnow, end
            end
            
            %    
            shift_weighted = sum(shifts.*quality)/sum(quality);
            shift_median = median(shifts);
            disp(['Rotation axis shift: weighted = ' num2str(shift_weighted)  ', median = ' num2str(shift_median)]);
            %            
            % hw = [];
            % waitmsg = 'Translating projection images to centre rotation axis...';
            % if ~obj.run_headless
            %     hw = waitbar(0,waitmsg);
            % end
            %                        
            %s = ceil(shift_median/2); % safest possible

            % if s < 0
            %     for k = 1:n_planes
            %         memmap_PROJ.Data.pixels(:,:,k) = flipud(memmap_PROJ.Data.pixels(:,:,k));
            %     end
            %     s = -s;
            % end

            % UI figure to confirm registration here, before saving shifted
            % projections

            if shift_median>0
                s=ceil(shift_median/2);
                %tform = affine2d(eye(3));
                %tform.T(3,2) = -s;
                for k = 1:2
                    I = memmap_PROJ.Data.pixels(:,:,(k-1)*floor(n_planes/2)+1)-offset;
                    [szx,szy] = size(I);
                    Icorr = imtranslate(I,[0,-shift_median/2]);
                    comparison(:,:,k) = Icorr(s+1:szx-s,:);
                end
            elseif shift_median==0
                for k = 1:2
                    comparison(:,:,k) = memmap_PROJ.Data.pixels(:,:,(k-1)*floor(n_planes/2)+1)-offset;
                end
            else
                s = ceil(-shift_median/2);
                %tform = affine2d(eye(3));
                %tform.T(3,2) = s;
                for k = 1:2
                    I = (memmap_PROJ.Data.pixels(:,:,((k-1)*floor(n_planes/2))+1)-offset);
                    [szx,szy] = size(I);
                    Icorr = imtranslate(I,[0,-shift_median/2]);
                    comparison(:,:,k) = (Icorr(s+1:szx-s,:));
                end

            end
            
            conf_reg = uifigure('Name','Correct alignment confirmation');
            g = uigridlayout(conf_reg,[4 3]);
            g.RowHeight = {'1x','fit','fit','fit'};
            g.ColumnWidth = {'1x','fit','1x'};
            a = uiimage(g);
            rgb = zeros(size(comparison,1),size(comparison,2),3);
            im1 = im2double(comparison(:,:,1));
            im2 = im2double(comparison(:,:,2));
            rgb(:,:,1) = im1./max(max(im1));
            rgb(:,:,2) = flipud(im2)./max(max(im2));
            rgb(:,:,3) = (rgb(:,:,1)+rgb(:,:,2))/2;
            a.ImageSource = rgb.^0.5;
            a.Layout.Row = 1;
            a.Layout.Column = [1 3];
            b = uibutton(g,"Text",'Yes, save my projection images',"ButtonPushedFcn",@(src,event) obj.M1_registration_confirmation(conf_reg,n_planes,memmap_PROJ,offset,shift_median));
            b.Layout.Row = 3;
            b.Layout.Column = 2;
            c = uilabel(g,"Text",'Are the two projection images completely overlapped?');
            c.Layout.Row = 2;
            c.Layout.Column = 2;
            d = uibutton(g,"Text",'No, run manual registration',"ButtonPushedFcn",@(src,event) obj.M1_manual_registration(conf_reg));
            d.Layout.Row = 4;
            d.Layout.Column = 2;
            

            if ~isempty(hw), delete(hw), drawnow, end


            uiwait(conf_reg)
            %disp('deletenow')
            if obj.manual_reg == 0
                clear('memmap_PROJ');
                delete(mapfile_name_proj);
                disp('Sucessfully stored registered projections')
            else
                disp('Manual registration running')
                %clear('memmap_PROJ');
                %delete(mapfile_name_proj);
                %don't need to clear the memory map here, will use it for
                %manual registration. will clear it after done.


                % UI to do manual calibration here.
                man_reg = uifigure('Name','Manual projection registration');

                % Comparing two projections code.
                % s is shift, p is starting projection, 1:n_proj/2, r is
                % rotataion

                % defaults
                data.p=1;
                data.r=0;
                %data.s=round(shift_median);
                data.s=shift_median;

                guidata(man_reg,data);

                g = uigridlayout(man_reg,[5 5]);
                g.RowHeight = {'1x','fit','fit','fit','fit'};
                g.ColumnWidth = {'1x','fit','fit','fit','1x'};
                a = uiimage(g);

                if data.s>0
                    s=ceil(data.s/2); %/2
                    %tform = affine2d(eye(3));
                    %tform.T(3,2) = -s;
                    for k = 1:2
                        I = memmap_PROJ.Data.pixels(:,:,((k-1)*floor(n_planes/2))+data.p)-offset;
                        [szx,szy] = size(I);
                        Icorr = imtranslate(I,[0,-data.s/2]);
                        comparison(:,:,k) = Icorr(s+1:szx-s,:);
                    end
                elseif data.s == 0
                    for k = 1:2
                        comparison(:,:,k) = memmap_PROJ.Data.pixels(:,:,((k-1)*floor(n_planes/2))+data.p)-offset;
                    end
                else
                    s = ceil(-data.s/2);%/2
                    %tform = affine2d(eye(3));
                    %tform.T(3,2) = s;
                    for k = 1:2
                        I = (memmap_PROJ.Data.pixels(:,:,((k-1)*floor(n_planes/2))+data.p)-offset);
                        [szx,szy] = size(I);
                        Icorr = imtranslate(I,[0,-data.s/2]);
                        comparison(:,:,k) = (Icorr(s+1:szx-s,:));
                    end
                end

                rgb = zeros(size(comparison,1),size(comparison,2),3);
                im1 = im2double(comparison(:,:,1));
                im2 = im2double(comparison(:,:,2));
                rgb(:,:,1) = im1./max(max(im1));
                rgb(:,:,2) = flipud(im2)./max(max(im2));
                rgb(:,:,3) = (rgb(:,:,1)+rgb(:,:,2))/2;
                a.ImageSource = rgb.^0.5;
                a.Layout.Row = 1;
                a.Layout.Column = [1 5];
                b = uibutton(g,"Text",'Save registered projections');
                set(b,'ButtonPushedFcn',{@obj.M1_manual_registration_save_button,memmap_PROJ,n_planes,offset,man_reg});
                b.Layout.Row = 5;
                b.Layout.Column = 3;
                c = uislider(g);
                c.Limits = [1 floor(n_planes/2)];
                c.Value = data.p;
                set(c,'ValueChangedFcn',{@obj.M1_select_start_projection,memmap_PROJ,n_planes,offset,a});
                c.Layout.Row = 2;
                c.Layout.Column = [2 4];
                cl = uilabel(g);
                cl.Text = 'Projection pair to view:';
                cl.Layout.Row = 2;
                cl.Layout.Column = 1;
                d = uispinner(g);
                d.Limits = [-floor(size(comparison,1)/2) floor(size(comparison,1)/2)];
                d.Value = data.s;
                set(d,'ValueChangedFcn',{@obj.M1_select_shift,memmap_PROJ,n_planes,offset,a});
                d.Layout.Row = 3;
                d.Layout.Column = 3;
                dl = uilabel(g);
                dl.Text = 'Lateral shift:';
                dl.Layout.Row = 3;
                dl.Layout.Column = 1;
                e = uispinner(g,'ValueDisplayFormat','%.2f');
                e.Limits = [-10 10];
                e.Step = 0.1;
                e.Value = data.r;
                set(e,'ValueChangedFcn',{@obj.M1_select_rot,memmap_PROJ,n_planes,offset,a});
                e.Layout.Row = 4;
                e.Layout.Column = 3;
                el = uilabel(g);
                el.Text = 'Rotation:';
                el.Layout.Row = 4;
                el.Layout.Column = 1;
                % e = uilabel(man_reg,"Text",'Choose example projection:');
                % e.Layout.Row = 2;
                % e.Layout.Column = 1;
                % f = uilabel(man_reg,"Text",'Choose projection shift:');
                % f.Layout.Row = 3;
                % f.Layout.Column = 1;

                uiwait(man_reg);
                clear('memmap_PROJ');
                delete(mapfile_name_proj);

            end

            
        end

        function M3_do_registration(obj,~) % directly using manual registration
            [sizeX,sizeY,n_planes] = size(obj.proj);
            sizeinmem = prod(size(obj.proj(:))).*4;
            [~,sysmem] = memory;
            %disp([num2str(sizeinmem) ' ' num2str(sysmem.PhysicalMemory.Available)])
            sizeontempdisk = java.io.File(tempdir).getFreeSpace();
            if sizeontempdisk <= sizeinmem
                errordlg('Not enough disk space in tempdir - please clear some space before continuing.')
                return
            end
            wait_handle = waitbar(0,'Creating projection memory-map file...');
            [mapfile_name_proj,memmap_PROJ] = initialize_memmap([sizeX sizeY n_planes],1,'pixels',class(obj.proj),'ini_data',obj.proj);                 
            close(wait_handle);
            %disp(mapfile_name_proj)     
            obj.proj = [];                

            %PROJ = memmap_PROJ.Data.pixels; % memmap projections copy for safety
            %offset = min(memmap_PROJ.Data.pixels(:));
            %offsets = zeros(n_planes);
            for i=1:n_planes
                offsets(i) = min(min(memmap_PROJ.Data.pixels(:,:,i)));
            end
            offset = min(offsets);

            nangles = numel(obj.angles);

            % UI to do manual calibration here.
            man_reg = uifigure('Name','Manual projection registration');

            % Comparing two projections code.
            % s is shift, p is starting projection, 1:n_proj/2, r is
            % rotataion

            % defaults
            data.p=1;
            data.r=0;
            data.s=0;

            guidata(man_reg,data);

            g = uigridlayout(man_reg,[5 5]);
            g.RowHeight = {'1x','fit','fit','fit','fit'};
            g.ColumnWidth = {'1x','fit','fit','fit','1x'};
            a = uiimage(g);

            if data.s>0
                s=ceil(data.s/2);
                %tform = affine2d(eye(3));
                %tform.T(3,2) = -s;
                for k = 1:2
                    I = memmap_PROJ.Data.pixels(:,:,((k-1)*floor(n_planes/2))+data.p)-offset;
                    [szx,szy] = size(I);
                    %Icorr = imwarp(I,tform,'OutputView',imref2d(size(I)));
                    Icorr = imtranslate(I,[0,-data.s/2]);
                    comparison(:,:,k) = Icorr(s+1:szx-s,:);
                end
            elseif data.s == 0
                for k = 1:2
                    comparison(:,:,k) = memmap_PROJ.Data.pixels(:,:,((k-1)*floor(n_planes/2))+data.p)-offset;
                end
            else
                s = ceil(-data.s/2);
                %tform = affine2d(eye(3));
                %tform.T(3,2) = s;
                for k = 1:2
                    I = (memmap_PROJ.Data.pixels(:,:,((k-1)*floor(n_planes/2))+data.p)-offset);
                    [szx,szy] = size(I);
                    %Icorr = imwarp(I,tform,'OutputView',imref2d(size(I)));
                    Icorr = imtranslate(I,[0,-data.s/2]);
                    comparison(:,:,k) = (Icorr(s+1:szx-s,:));
                end
            end

            rgb = zeros(size(comparison,1),size(comparison,2),3);
            im1 = im2double(comparison(:,:,1));
            im2 = im2double(comparison(:,:,2));
            rgb(:,:,1) = im1./max(max(im1));
            rgb(:,:,2) = flipud(im2)./max(max(im2));
            rgb(:,:,3) = (rgb(:,:,1)+rgb(:,:,2))/2;
            a.ImageSource = rgb.^0.5;
            a.Layout.Row = 1;
            a.Layout.Column = [1 5];
            b = uibutton(g,"Text",'Save registered projections');
            set(b,'ButtonPushedFcn',{@obj.M1_manual_registration_save_button,memmap_PROJ,n_planes,offset,man_reg});
            b.Layout.Row = 5;
            b.Layout.Column = 3;
            c = uislider(g);
            c.Limits = [1 floor(n_planes/2)];
            c.Value = data.p;
            set(c,'ValueChangedFcn',{@obj.M1_select_start_projection,memmap_PROJ,n_planes,offset,a});
            c.Layout.Row = 2;
            c.Layout.Column = [2 4];
            cl = uilabel(g);
            cl.Text = 'Projection pair to view:';
            cl.Layout.Row = 2;
            cl.Layout.Column = 1;
            d = uispinner(g);
            d.Limits = [-floor(size(comparison,1)/2) floor(size(comparison,1)/2)];
            d.Value = data.s;
            set(d,'ValueChangedFcn',{@obj.M1_select_shift,memmap_PROJ,n_planes,offset,a});
            d.Layout.Row = 3;
            d.Layout.Column = 3;
            dl = uilabel(g);
            dl.Text = 'Lateral shift:';
            dl.Layout.Row = 3;
            dl.Layout.Column = 1;
            e = uispinner(g,'ValueDisplayFormat','%.2f');
            e.Limits = [-10 10];
            e.Step = 0.1;
            e.Value = data.r;
            set(e,'ValueChangedFcn',{@obj.M1_select_rot,memmap_PROJ,n_planes,offset,a});
            e.Layout.Row = 4;
            e.Layout.Column = 3;
            el = uilabel(g);
            el.Text = 'Rotation:';
            el.Layout.Row = 4;
            el.Layout.Column = 1;
            % e = uilabel(man_reg,"Text",'Choose example projection:');
            % e.Layout.Row = 2;
            % e.Layout.Column = 1;
            % f = uilabel(man_reg,"Text",'Choose projection shift:');
            % f.Layout.Row = 3;
            % f.Layout.Column = 1;

            uiwait(man_reg);
            clear('memmap_PROJ');
            delete(mapfile_name_proj);           
        end

        function [] = M1_manual_registration_save_button(obj,src,event,memmap_PROJ,n_planes,offset,man_reg)
            data = guidata(src);
            obj.manual_registration_save(memmap_PROJ,n_planes,offset,data.s,data.r);
            
            close(man_reg)
        end

        function manual_registration_save(obj,memmap_PROJ,n_planes,offset,s,r,~)
            hw = [];
            waitmsg = 'Saving registered projection images...';
            if ~obj.run_headless
                hw = waitbar(0,waitmsg);
            end
            if s>0
                crops=ceil(s/2);
                %tform = affine2d(eye(3));
                %tform.T(3,2) = -s;
                for k = 1:n_planes
                    I = memmap_PROJ.Data.pixels(:,:,k)-offset;
                    [szx,szy] = size(I);
                    I = imrotate(I,r,'crop');
                    Icorr = imtranslate(I,[0,-s/2]);
                    obj.proj(:,:,k) = Icorr(ceil(abs(tand(r))*szy/2)+crops+1:szx-(crops+ceil(abs(tand(r))*szy/2)),1+ceil(abs(tand(r))*szx/2):end-ceil(abs(tand(r))*szx/2));
                    if ~isempty(hw), waitbar(k/n_planes,hw); drawnow, end
                end
            elseif s == 0
                for k = 1:n_planes
                    I = imrotate(memmap_PROJ.Data.pixels(:,:,k)-offset,r,'crop');
                    obj.proj(:,:,k) = I(ceil(abs(tand(r))*size(I,2)/2)+1:size(I,1)-(ceil(abs(tand(r))*size(I,2)/2)),1+ceil(abs(tand(r)*size(I,1)/2)):end-ceil(abs(tand(r)*size(I,1)/2)));
                    if ~isempty(hw), waitbar(k/n_planes,hw); drawnow, end
                end
            else
                crops = ceil(-s/2);
                % tform = affine2d(eye(3));
                % tform.T(3,2) = s;
                for k = 1:n_planes
                    I = (memmap_PROJ.Data.pixels(:,:,k)-offset);
                    [szx,szy] = size(I);
                    I = imrotate(I,r,'crop');
                    Icorr = imtranslate(I,[0,-s/2]);
                    obj.proj(:,:,k) = Icorr(ceil(abs(tand(r))*szy/2)+crops+1:szx-(crops+ceil(abs(tand(r))*szy/2)),1+ceil(abs(tand(r)*szx/2)):end-ceil(abs(tand(r)*szx/2)));
                    if ~isempty(hw), waitbar(k/n_planes,hw); drawnow, end
                end
            end
            obj.registration_shift = s;
            obj.registration_rotation = r;
            set(obj.menu_controller.menu_current_registration,'Label',['Current registration: Shift: ',num2str(obj.registration_shift),...
                    ', Rot.: ',num2str(obj.registration_rotation),char(176)]);
            close(hw);

        end
        
        function M1_select_start_projection(obj,src,event,memmap_PROJ,n_planes,offset,a)
            data = guidata(src);
            data.p = round(event.Value);
            if data.s>=1
                s=ceil(data.s/2);
                %tform = affine2d(eye(3));
                %tform.T(3,2) = -s;
                for k = 1:2
                    I = memmap_PROJ.Data.pixels(:,:,((k-1)*floor(n_planes/2))+data.p)-offset;
                    [szx,szy] = size(I);
                    I = imrotate(I,data.r,'crop');
                    Icorr = imtranslate(I,[0,-data.s/2]);
                    comparison(:,:,k) = Icorr(ceil(abs(tand(data.r))*szy/2)+s+1:szx-(s+ceil(abs(tand(data.r))*szy/2)),1+ceil(abs(tand(data.r))*szx/2):end-ceil(abs(tand(data.r))*szx/2));
                end
            elseif data.s == 0
                for k = 1:2
                    I = imrotate(memmap_PROJ.Data.pixels(:,:,((k-1)*floor(n_planes/2))+data.p)-offset,data.r,'crop');
                    comparison(:,:,k) = I(ceil(abs(tand(data.r))*size(I,2)/2)+1:size(I,1)-(ceil(abs(tand(data.r))*size(I,2)/2)),1+ceil(abs(tand(data.r)*size(I,1)/2)):end-ceil(abs(tand(data.r)*size(I,1)/2)));
                end
            else
                s = ceil(-data.s/2);
                %tform = affine2d(eye(3));
                %tform.T(3,2) = s;
                for k = 1:2
                    I = (memmap_PROJ.Data.pixels(:,:,((k-1)*floor(n_planes/2))+data.p)-offset);
                    [szx,szy] = size(I);
                    I = imrotate(I,data.r,'crop');
                    Icorr = imtranslate(I,[0,-data.s/2]);
                    comparison(:,:,k) = Icorr(ceil(abs(tand(data.r))*szy/2)+s+1:szx-(s+ceil(abs(tand(data.r))*szy/2)),1+ceil(abs(tand(data.r)*szx/2)):end-ceil(abs(tand(data.r)*szx/2)));
                end
            end
            rgb = zeros(size(comparison,1),size(comparison,2),3);
            im1 = im2double(comparison(:,:,1));
            im2 = im2double(comparison(:,:,2));
            rgb(:,:,1) = im1./max(max(im1));
            rgb(:,:,2) = flipud(im2)./max(max(im2));
            rgb(:,:,3) = (rgb(:,:,1)+rgb(:,:,2))/2;
            a.ImageSource = rgb.^0.5;

            guidata(src,data);
        end

        function M1_select_shift(obj,src,event,memmap_PROJ,n_planes,offset,a)
            data = guidata(src);
            data.s = round(event.Value);
            if data.s>0
                s=ceil(data.s/2);
                %tform = affine2d(eye(3));
                %tform.T(3,2) = -s;
                for k = 1:2
                    I = memmap_PROJ.Data.pixels(:,:,((k-1)*floor(n_planes/2))+data.p)-offset;
                    [szx,szy] = size(I);
                    I = imrotate(I,data.r,'crop');
                    %Icorr = imwarp(I,tform,'OutputView',imref2d(size(I)));
                    Icorr = imtranslate(I,[0,-data.s/2]);
                    comparison(:,:,k) = Icorr(ceil(abs(tand(data.r))*szy/2)+s+1:szx-(s+ceil(abs(tand(data.r))*szy/2)),1+ceil(abs(tand(data.r))*szx/2):end-ceil(abs(tand(data.r))*szx/2));
                end
            elseif data.s == 0
                for k = 1:2
                    I = imrotate(memmap_PROJ.Data.pixels(:,:,((k-1)*floor(n_planes/2))+data.p)-offset,data.r,'crop');
                    comparison(:,:,k) = I(ceil(abs(tand(data.r))*size(I,2)/2)+1:size(I,1)-(ceil(abs(tand(data.r))*size(I,2)/2)),1+ceil(abs(tand(data.r)*size(I,1)/2)):end-ceil(abs(tand(data.r)*size(I,1)/2)));
                end
            else
                s = ceil(-data.s/2);
                %tform = affine2d(eye(3));
                %tform.T(3,2) = s;
                for k = 1:2
                    I = (memmap_PROJ.Data.pixels(:,:,((k-1)*floor(n_planes/2))+data.p)-offset);
                    [szx,szy] = size(I);
                    I = imrotate(I,data.r,'crop');
                    Icorr = imtranslate(I,[0,-data.s/2]);
                    comparison(:,:,k) = Icorr(ceil(abs(tand(data.r))*szy/2)+s+1:szx-(s+ceil(abs(tand(data.r))*szy/2)),1+ceil(abs(tand(data.r)*szx/2)):end-ceil(abs(tand(data.r)*szx/2)));
                end
            end

            rgb = zeros(size(comparison,1),size(comparison,2),3);
            im1 = im2double(comparison(:,:,1));
            im2 = im2double(comparison(:,:,2));
            rgb(:,:,1) = im1./max(max(im1));
            rgb(:,:,2) = flipud(im2)./max(max(im2));
            rgb(:,:,3) = (rgb(:,:,1)+rgb(:,:,2))/2;
            a.ImageSource = rgb.^0.5;

            guidata(src,data);
        end

        function M1_select_rot(obj,src,event,memmap_PROJ,n_planes,offset,a)
            data = guidata(src);
            data.r = (event.Value);

            if data.s>0
                s=ceil(data.s/2);
                %tform = affine2d(eye(3));
                %tform.T(3,2) = -s;
                for k = 1:2
                    I = memmap_PROJ.Data.pixels(:,:,((k-1)*floor(n_planes/2))+data.p)-offset;
                    [szx,szy] = size(I);
                    I = imrotate(I,data.r,'crop');
                    Icorr = imtranslate(I,[0,-data.s/2]);
                    comparison(:,:,k) = Icorr(ceil(abs(tand(data.r))*szy/2)+s+1:szx-(s+ceil(abs(tand(data.r))*szy/2)),1+ceil(abs(tand(data.r))*szx/2):end-ceil(abs(tand(data.r))*szx/2));
                end
            elseif data.s == 0
                for k = 1:2
                    I = imrotate(memmap_PROJ.Data.pixels(:,:,((k-1)*floor(n_planes/2))+data.p)-offset,data.r,'crop');
                    comparison(:,:,k) = I(ceil(abs(tand(data.r))*size(I,2)/2)+1:size(I,1)-(ceil(abs(tand(data.r))*size(I,2)/2)),1+ceil(abs(tand(data.r)*size(I,1)/2)):end-ceil(abs(tand(data.r)*size(I,1)/2)));
                end
            else
                s = ceil(-data.s/2);
                %tform = affine2d(eye(3));
                %tform.T(3,2) = s;
                for k = 1:2
                    I = (memmap_PROJ.Data.pixels(:,:,((k-1)*floor(n_planes/2))+data.p)-offset);
                    [szx,szy] = size(I);
                    I = imrotate(I,data.r,'crop');
                    Icorr = imtranslate(I,[0,-data.s/2]);
                    comparison(:,:,k) = Icorr(ceil(abs(tand(data.r))*szy/2)+s+1:szx-(s+ceil(abs(tand(data.r))*szy/2)),1+ceil(abs(tand(data.r)*szx/2)):end-ceil(abs(tand(data.r)*szx/2)));
                end
            end

            rgb = zeros(size(comparison,1),size(comparison,2),3);
            im1 = im2double(comparison(:,:,1));
            im2 = im2double(comparison(:,:,2));
            rgb(:,:,1) = im1./max(max(im1));
            rgb(:,:,2) = flipud(im2)./max(max(im2));
            rgb(:,:,3) = (rgb(:,:,1)+rgb(:,:,2))/2;
            a.ImageSource = rgb.^0.5;

            guidata(src,data);
        end

        function M1_registration_confirmation(obj,conf_reg,n_planes,memmap_PROJ,offset,shift_median,~)
            obj.manual_reg = 0;
            hw = [];
            waitmsg = 'Saving registered projection images...';
            if ~obj.run_headless
                hw = waitbar(0,waitmsg);
            end
            %obj.proj = [];
            if shift_median>0
                s = ceil(shift_median/2);
            elseif shift_median<0
                s = ceil(-shift_median/2);
            end
            if abs(shift_median)>0
                %tform = affine2d(eye(3));                    
                %tform.T(3,2) = - s;                
                for k = 1:n_planes
                    I = memmap_PROJ.Data.pixels(:,:,k)-offset;
                    if isempty(obj.proj) % proper place to crop the image?
                            [szx,szy] = size(I);
                            obj.proj = zeros(szx-2*s,szy,n_planes,class(I));
                    end                
                        Icorr = imtranslate(I,[0,-shift_median/2]);
                        obj.proj(:,:,k) = Icorr(s+1:szx-s,:);
                    if ~isempty(hw), waitbar(k/n_planes,hw); drawnow, end
                end
            else
                for k = 1:n_planes
                    obj.proj(:,:,k) = memmap_PROJ.Data.pixels(:,:,k)-offset;
                end
            end
            if ~isempty(hw), delete(hw), drawnow, end
            obj.registration_shift = shift_median;
            close(conf_reg)
            
        end

        function M1_manual_registration(obj,conf_reg,~)
            %temp = waitbar(0,'Loading manual registration tool');
            obj.manual_reg = 1;
            close(conf_reg)
            %close(temp)
        end



%         function M1_do_registration(obj,~) % by Samuel Davis
%             %            
%             [sizeX,sizeY,n_planes] = size(obj.proj);
%             wait_handle = waitbar(0,'Creating projection memory-map file...');
%             [mapfile_name_proj,memmap_PROJ] = initialize_memmap([sizeX sizeY n_planes],1,'pixels',class(obj.proj),'ini_data',obj.proj);                 
%             close(wait_handle);
% 
%             obj.proj = [];                
% 
%             PROJ = memmap_PROJ.Data.pixels; % reference
%             offset = min(PROJ(:));
%             PROJ = PROJ-offset;
% 
%             %
%             M1_brightness_quantile_threshold = 0.8;
%             M1_max_shift = 20;
%             %M1_window = 50;
% 
%             verbose = ~isdeployed;
% 
%             hw = [];
%             waitmsg = 'Gathering the data to calculate corrections.. please wait..';                                
%             if verbose
%                hw = waitbar(0,waitmsg);
%             end
% 
%             hshift = 0;
%             rotation = 0;
%             finished = 0;
%             count = 0;
% 
%             while ~finished && count < 20
%                 if verbose
%                     waitbar(count/20,hw)
%                 end
%                 count = count+1;
% 
%                 sizeCheck = size(obj.M1_imshift(PROJ(:,:,1),0,hshift,-rotation));
%                 newproj = zeros(sizeCheck(1),sizeCheck(2),size(PROJ,3));
%                 for i = 1:size(newproj,3)
%                     newproj(:,:,i) = obj.M1_imshift(PROJ(:,:,i),0,hshift,-rotation);
%                 end 
%                 projBrightness = squeeze(mean(mean(newproj,1),2));
% 
%                 sample = zeros(size(PROJ,2),1);
% 
%                 tic
%                 for y=1:size(PROJ,2)
%                     sino = squeeze(cast(newproj(:,y,:),'single'));
%                     sample(y) = mean(sino(:));
%                 end
%                 %disp(toc)
% 
%                 T = quantile(sample, M1_brightness_quantile_threshold);
%                 brightEnough = sample > T;
% 
%                 %nRegions = 16;
%                 %regions = ceil([1,(1:nRegions)*size(sizeCheck,2)/nRegions]);
%                 %for i = 1:nRegions
%                 %    [~,dim] = sort(sample(regions(i):regions(i+1)));
%                 %    brightEnough(dim(1:(end-10))+regions(i)-1) = 0;
%                 %end
% 
%                 % The shift correction and spearman correlation for individual slices are then
%                 % found
% 
%                 if obj.isGPU
%                     shift = gpuArray(NaN(length(brightEnough),1));
%                     r = gpuArray(NaN(length(brightEnough),1));
%                 else
%                     shift = NaN(length(brightEnough),1);
%                     r = NaN(length(brightEnough),1);
%                 end
% 
%                 tic
% 
%                 for n = 1:length(brightEnough)
%                     if brightEnough(n)
%                         sino = squeeze(newproj(:,n,:));
%                         %[shift(n), r(n)] = obj.M1_quickMidindex(sino,20,2);
%                         %[shift(n), r(n)] = obj.M1_quickMidindex(sino,M1_max_shift);
%                         shift(n) = -obj.M1_TangShift(sino);
%                     end    
%                 end
% 
%                 %disp(toc)
% 
%                 if obj.isGPU
%                     shift = gather(shift);
%                 end
% 
%                 % filter out shifts which imply large image rotation
%                 for n = 1:2
%                     delt = abs(shift-mean(shift,"omitnan"));
%                     shift(delt>9) = NaN;
%                 end
% 
%                 % slice numbers relative to centre of image, filtered, and then cropped
%                 ns = (1:length(brightEnough))'-length(brightEnough)/2;
%                 ns = ns(~isnan(shift));
%                 shift = shift(~isnan(shift));
%                 % figure(2); histogram2(ns,shift,'YBinEdges',-21:2:21,'DisplayStyle','tile','ShowEmptyBins','on');
%                 %drawnow;
%                 tic
% 
%                 if length(ns) > 1
%                     fitobject = fit(ns,shift,'poly1','Robust','on');
%                     newshift = round(fitobject.p2);
%                     newrotation = fitobject.p1;
%                 else
%                     newshift = 0;
%                     newrotation = 0;                    
%                 end
%                 %disp(['fitting ' num2str(toc) 's'])
%                 disp([ abs(tan(newrotation)) 1/size(newproj,2) newshift]);
% 
%                 if (abs(tan(newrotation)) < 1/size(newproj,2)) && (abs(newshift) < 2) 
%                     finished = 1;
%                 else
%                     hshift = hshift + newshift;
%                     rotation = rotation + newrotation/2;
%                 end
%             end 
%             %close(2)
%             if verbose && ~isempty(hw), delete(hw), drawnow, end
% 
%             vshift = hshift;
%             hshift = 0;
%             % ?
%             %
%             obj.M1_hshift = hshift; % keep it for the case of re-usage for FLIM
%             obj.M1_vshift = vshift;
%             obj.M1_rotation = rotation;
%             %
%             disp(['Shift: ' num2str(vshift) ', Rotation: ' num2str(rotation)])
%             hw = [];
%             waitmsg = 'Introducing corrections..';
%             if verbose
%                 hw = waitbar(0,waitmsg);
%             end
%             %                        
%             for k = 1:n_planes
%                 I = padarray(PROJ(:,:,k),[20 20],'replicate','both');
%                 Ishift = obj.M1_imshift(I,hshift,vshift,-rotation);
%                 Ishift = Ishift(21:end-20,21:end-20);
%                     if isempty(obj.proj)
%                         [szx,szy] = size(Ishift);
%                         obj.proj = zeros(szx,szy,n_planes,class(Ishift));
%                     end                
%                 obj.proj(:,:,k) = Ishift;
%                 if ~isempty(hw), waitbar(k/n_planes,hw); drawnow, end
%             end
%             if ~isempty(hw), delete(hw), drawnow, end
%             %
%             clear('memmap_PROJ');
%             delete(mapfile_name_proj);
% 
%         end        
% %-------------------------------------------------------------------------%
% function [hshift, r] = M1_quickMidindex(obj,sino,maxshift)
% 
%     if obj.isGPU
%         sino = gpuArray(sino);
%     end
% 
%     for i = 1:(maxshift+1)
%         shiftsino = obj.M1_sinoshift(sino',i,maxshift+1,0,0);
%         slice = iradon(shiftsino',obj.angles,'linear','Hann');
%         %figure
%         %imshow(slice,[])
%         %icy_imshow(slice);
%         spectrum_peak2(i) = sqrt(sum(abs(slice(:).^2)));
%     end
% 
%     [sorted2, I2] = sort(spectrum_peak2,'descend');
% 
%     diff = abs(I2-I2(1));
% 
%     if obj.isGPU
%         r = corr(gather(diff(:)),gather(sorted2(:)),'type','Spearman');
%     else
%         r = corr(diff(:),sorted2(:),'type','Spearman');
%     end
% 
%     %figure
%     %plot(-maxshift:2:maxshift,spectrum_peak2);
%     %ylabel('Peak Intensity/a.u.')
%     %xlabel('rotation axis shift/pixels')
%     %box off    
%     %drawnow
% 
%     %if r < -0.6
%         hshift = maxshift - 2*I2(1) + 2;
%     %else
%     %    hshift = NaN;
%     %end
% end
% %-------------------------------------------------------------------------%
% function shift = M1_TangShift(obj,sino)
% 
%     if obj.isGPU
%         sino = gather(sino);
%     end
% 
%     sino = double(sino)./max(sino(:)); 
% 
%     entsino = entropyfilt(sino);
% 
%     se = strel('disk', 20);
%     Ie = imerode(entsino, se);
%     Iobr = imreconstruct(Ie, entsino);
% 
%     Iobrd = imdilate(Iobr, se);
%     Iobrcbr = imreconstruct(imcomplement(Iobrd), imcomplement(Iobr));
%     Iobrcbr = imcomplement(Iobrcbr);
% 
%     h = fspecial('sobel');
%     % invert kernel to detect vertical edges
%     horz = imfilter(Iobrcbr,h);
%     %figure(1); subplot(1,3,2); imagesc(horz);
%     h = h';
%     vert = imfilter(Iobrcbr,h);
%     %figure(2); subplot(1,3,2); imagesc(vert);    
%     %angle = atan2(vert,horz);
%     angle = vert./horz;
%     %figure(3); subplot(1,3,2); imagesc(angle);    
% 
%     horz(1,:) = 0;
%     horz(end,:) = 0;
% 
%     [~,top] = min(horz,[],1);
%     [~,bottom] = max(horz,[],1);
% 
%     topangles = angle(top+size(angle,1)*(0:(size(angle,2)-1)));
%     bottomangles = angle(bottom+size(angle,1)*(0:(size(angle,2)-1)));
% 
% 
% 
% 
%     peaks = find(abs(topangles)<0.1);
%     bottoms = find(abs(bottomangles)<0.1);
% 
% 
%     shiftbottom = mod(bottoms+size(sino,2)/2-1,size(sino,2))+1;
%     inter = intersect(peaks,shiftbottom);
% 
%     %figure(1); hold; plot(top); plot(bottom); plot(inter,top(inter),'b*'); plot(mod(inter+size(sino,2)/2-1,size(sino,2))+1,bottom(mod(inter+size(sino,2)/2-1,size(sino,2))+1),'r*'); hold;
% 
% 
%     if ~isempty(inter)
%         shift = zeros(1,length(inter));
%         for i = 1:length(inter)
%             shift(i) = top(inter(i))-(size(sino,1)-bottom(mod(inter(i)+size(sino,2)/2-1,size(sino,2))+1));
%         end
%         shift = median(shift);
%     else
%         shift = NaN;
%     end
% end
% %-------------------------------------------------------------------------%
% function shiftedSino = M1_sinoshift(obj,sino,n,steps,shift,split)
% 
%         numOfParallelProjections = size(sino,2);
%         numOfAngularProjections = size(sino,1);
% 
%         if split == 1
%             sino1 = sino(shift:(numOfAngularProjections/2+shift-1),n:(numOfParallelProjections+n-steps));
%             sino2 = fliplr(sino1);
%             shiftedSino = cat(1,sino1,sino2);
%         else
%             shiftedSino = sino(:,n:(numOfParallelProjections+n-steps));
%         end       
% end
% %-------------------------------------------------------------------------%
% function shiftedImage = M1_imshift(obj,img,hShift,vShift,rotation)
% 
%         hsize = size(img,2);
%         vsize = size(img,1);
% 
%         if hShift < 0
%             img = img(:,(1-hShift):hsize);
%         else
%             img = img(:,1:(hsize-hShift));
%         end
% 
%         if vShift < 0
%             img = img((1-vShift):vsize,:);
%         else
%             img = img(1:(vsize-vShift),:);
%         end
%         if nargin > 3
%             if tan(rotation) > 1/min(hsize,vsize)
%                 img = imrotate(img,rotation*180/pi,'bicubic');
%             end
%         end
%         shiftedImage = img;
% end
%-------------------------------------------------------------------------%
function ret = split_original(obj,DST_DIR,base_name,N,~) % NO FLIM
    %
    prefix = '_ic_split_';
    %
    ret = false;
    if ~isdir(DST_DIR) || isempty(obj.proj)
        disp('either input parameters are bad, or no data loaded, can not continue');
        return;
    end
    % presume RAM is enough big
    [ sizeX sizeY np ] = size(obj.proj);
        
    bsz = floor(sizeY/N);
    excess = rem(sizeY,N);
    sizes = ones(1,N-1)*bsz;
    sizes = [sizes bsz+excess];
    %
    for k=1:N
        start_ind = (k-1)*bsz+1;
        end_ind = k*bsz;
        if k==N
            end_ind = end_ind + excess;
        end
        buf = obj.proj(:,start_ind:end_ind,:);
        disp([start_ind end_ind]);
        % save "buf" as OME.tiff with current angles
        ometiffilename = [DST_DIR filesep base_name prefix num2str(k) '.OME.tiff'];                
        %
        sizeZ = np;
        sizeC = 1;
        sizeT = 1;
        angle_start = obj.angles(1);
        angle_end = obj.angles(numel(obj.angles));
        angle_step = obj.angles(2) - obj.angles(1);
        for i=1:sizeZ
                z = i;
                c = 1;
                t = 1;
                I = squeeze(buf(:,:,i));
                telapsed = add_plane_to_OMEtiff_with_metadata_ZCT(I, [z c t], [sizeZ sizeC sizeT], [], ometiffilename, ...
                    'ModuloZ_Type', 'Rotation', ...
                    'ModuloZ_TypeDescription', 'OPT', ...
                    'ModuloZ_Unit', 'degree', ...
                    'ModuloZ_Start', angle_start, ...
                    'ModuloZ_Step', angle_step, ...
                    'ModuloZ_End', angle_end, ...
                    'BigTiff', true);
        end
        %                        
    end
    
    ret = true;
end
%-------------------------------------------------------------------------%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


    end % methods
end % class



