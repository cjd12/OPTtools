classdef ic_OPTtools_front_end_menu_controller < handle
        
    % Copyright (C) 2013 Imperial College London.
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
    
    properties
        
        % indication
        proj_label;
        volm_label;
        batch_label;

        menu_file_Working_Data_Info;        
        menu_file_new_window;
        menu_file_set_src_single;
        menu_file_set_src_single_imstack;
        menu_file_set_src_dir;
        menu_file_reset_previous;
        menu_file_set_dst_dir;
        menu_file_save_current_volume;
        
        menu_OMERO_login;
        menu_OMERO_Working_Data_Info;
        menu_OMERO_Set_Dataset;
        menu_OMERO_Switch_User;
        menu_OMERO_Connect_To_Another_User;
        menu_OMERO_Connect_To_Logon_User;
        menu_OMERO_Reset_Logon; 
            %
            menu_OMERO_set_single;
            menu_OMERO_set_multiple;
            menu_OMERO_reset_previous;
            
        menu_Batch_Indicator_Src;
        menu_Batch_Indicator_Dst;
        menu_Batch_Src_HD;
        menu_Batch_Src_OMERO;
        menu_Batch_SetDst;
        menu_Batch_save_format;
        menu_Batch_save_format_tiffstack;
        menu_Batch_save_format_OMEtiff;
        menu_Batch_save_format_matlab;
        menu_Batch_RunBatch;
        
        menu_current_registration;

        menu_Batch_Src_slctd_HD;
        menu_Batch_Src_slctd_OMERO;
                                        
        menu_settings_Pixel_Downsampling;
        menu_settings_Angle_Downsampling;

        menu_bleaching_correction;
        menu_bleaching_correction_on;
        menu_bleaching_correction_off;

        menu_settings_Median_Prefiltering_Set_Size;
        menu_settings_Median_Prefiltering_None;
        menu_settings_Median_Prefiltering;
        
        % menu_settings_Angular_Coverage;
        % menu_settings_Angular_Coverage_360;
        % menu_settings_Angular_Coverage_180;

        menu_settings_Rotation_Axis_Orientation;
        menu_settings_Rotation_Axis_Orientation_Horizontal;
        menu_settings_Rotation_Axis_Orientation_Vertical;
                
        menu_settings_Pixel_Downsampling_1;        
        menu_settings_Pixel_Downsampling_2;
        menu_settings_Pixel_Downsampling_4;
        menu_settings_Pixel_Downsampling_8;
        menu_settings_Pixel_Downsampling_16;

        menu_settings_Angle_Downsampling_1;        
        menu_settings_Angle_Downsampling_2;
        menu_settings_Angle_Downsampling_4;
        menu_settings_Angle_Downsampling_8;
        
        menu_settings_Zrange;
        
        menu_settings_Registration;
        menu_settings_Registration_None;
        menu_settings_Registration_M1;
        menu_settings_Registration_M2;
        menu_settings_Registration_M3;

        menu_rerun_registration;
        
        menu_FBP_interp;   
        menu_FBP_interp_nearest;
        menu_FBP_interp_linear;
        menu_FBP_interp_spline;
        menu_FBP_interp_pchip;
        menu_FBP_interp_v5cubic;
    
        menu_FBP_filter;
        menu_FBP_filter_Ram_Lak;
        menu_FBP_filter_Shepp_Logan;
        menu_FBP_filter_Cosine;
        menu_FBP_filter_Hammming;
        menu_FBP_filter_Hann;
        menu_FBP_filter_None;
    
        menu_FBP_freq_scaling;

        menu_FBP_exampleslice;
        
        menu_settings_Method;
        menu_settings_Method_FBP;
        menu_settings_Method_TwIST;
        
        menu_settings_TwIST;
        
        menu_settings_GPU;        
        menu_settings_GPU_ON;
        
        menu_settings_Largo        
        menu_settings_Largo_ON;

        menu_settings_save_bit_depth;
        menu_settings_save_bit_depth_32;
        menu_settings_save_bit_depth_16;

        menu_settings_writeparameterfile;
        menu_settings_writeparameterfile_true;
        menu_settings_writeparameterfile_false;
        
        menu_reconstruction_Go;
                        
        menu_visualization_setup_Icy_directory;
        menu_visualization_start_Icy;
        
        menu_visualization_send_current_proj_to_Icy;
        menu_visualization_send_current_volm_to_Icy;   

        menu_settings_background_select_bright_bg;
        menu_settings_background_select_dark_bg;
        menu_settings_background_label_bright_bg;
        menu_settings_background_label_dark_bg;
        menu_background_options;

        % holy cows
        omero_data_manager;     
        data_controller;

    end
    
    properties(SetObservable = true)

    end
        
    methods
        
        %------------------------------------------------------------------        
        function obj = ic_OPTtools_front_end_menu_controller(handles)
            
            assign_handles(obj,handles);
            set_callbacks(obj);
            
            obj.data_controller.menu_controller = obj;
            
            % automatically start Icy
            if isempty(obj.data_controller.noIcy)
                try
                    icy_figure;
                    icy_closeall;
                catch                                 
                    if ispc && ~isempty(obj.data_controller.IcyDirectory)
                            dos([obj.data_controller.IcyDirectory filesep 'icy']);
                        elseif ismac && ~isempty(obj.data_controller.IcyDirectory)                    
                            unix(['open ' obj.data_controller.IcyDirectory filesep 'icy']); % ?                    
                        elseif isunix
                            unix('icy');                                                
                    else
                        % msgbox('error - Icy directory was not set up');
                    end 
                end
            end
            %  automatically start Icy
                                                                                                
        end
        %------------------------------------------------------------------
        function set_callbacks(obj)
            
             mc = metaclass(obj);
             obj_prop = mc.Properties;
             obj_method = mc.Methods;
                          
             % Search for properties with corresponding callbacks
             for i=1:length(obj_prop)
                prop = obj_prop{i}.Name;
                if strncmp(prop,'menu_',5)
                    method = [prop '_callback'];
                    matching_methods = findobj([obj_method{:}],'Name',method);
                    if ~isempty(matching_methods)               
                        eval(['set(obj.' prop ',''Callback'',@obj.' method ')' ]);
                    end
                end          
             end
             
        end
        %------------------------------------------------------------------                                       
        function menu_file_new_window_callback(obj,~,~)
            ic_OPTtools();
        end
                        
        %------------------------------------------------------------------
        % OMERO
        %------------------------------------------------------------------
        function menu_OMERO_login_callback(obj,~,~)
            obj.omero_data_manager.Omero_logon();
            
            if ~isempty(obj.omero_data_manager.session)
                props = properties(obj);
                OMERO_props = props( strncmp('menu_OMERO',props,10) );
                for i=1:length(OMERO_props)
                    set(obj.(OMERO_props{i}),'Enable','on');
                end
            end            
        end
        %------------------------------------------------------------------
        function menu_OMERO_Set_Dataset_callback(obj,~,~)            
            infostring = obj.omero_data_manager.Set_Dataset();
            if ~isempty(infostring)
                set(obj.menu_OMERO_Working_Data_Info,'Label',infostring,'ForegroundColor','blue');
                set(obj.menu_Batch_Indicator_Src,'Label',infostring,'ForegroundColor','blue');                
            end;
        end                        
        %------------------------------------------------------------------        
        function menu_OMERO_Reset_Logon_callback(obj,~,~)
            obj.omero_data_manager.Omero_logon();
        end
        %------------------------------------------------------------------        
        function menu_OMERO_Switch_User_callback(obj,~,~)
            %delete([ pwd '\' obj.omero_data_manager.omero_logon_filename ]);
            obj.omero_data_manager.Omero_logon_forced();
        end        
        %------------------------------------------------------------------
        function menu_OMERO_Connect_To_Another_User_callback(obj,~,~)
            obj.omero_data_manager.Select_Another_User();
            obj.omero_data_manager.dataset = [];
            obj.data_controller.proj = [];
            obj.data_controller.volm = [];            
            obj.data_controller.on_proj_and_volm_clear;
            set(obj.menu_OMERO_Working_Data_Info,'Label','...','ForegroundColor','red');
        end                            
        %------------------------------------------------------------------
        function menu_OMERO_Connect_To_Logon_User_callback(obj,~,~)            
            obj.omero_data_manager.userid = obj.omero_data_manager.session.getAdminService().getEventContext().userId;
            obj.omero_data_manager.dataset = [];
            obj.data_controller.proj = [];
            obj.data_controller.volm = [];            
            obj.data_controller.on_proj_and_volm_clear;
            set(obj.menu_OMERO_Working_Data_Info,'Label','...','ForegroundColor','red');
        end  
         %------------------------------------------------------------------
        function menu_OMERO_set_single_callback(obj, ~, ~)                                               
            infostring = obj.data_controller.OMERO_load_single(obj.omero_data_manager,true); % verbose
            if ~isempty(infostring)
                set(obj.menu_OMERO_Working_Data_Info,'Label',infostring,'ForegroundColor','blue','Enable','on');
                set(obj.menu_file_Working_Data_Info,'Label','...','Enable','off');                
                obj.data_controller.current_filename = [];
                set(obj.menu_settings_Zrange,'Label','Z range : full');
                obj.data_controller.Z_range = []; % no selection                                    
            end;            
        end
         %------------------------------------------------------------------
        function menu_OMERO_set_multiple_callback(obj, ~, ~)
            obj.data_controller.OMERO_load_multiple(obj.omero_data_manager);
        end
         %------------------------------------------------------------------
        function menu_OMERO_reset_previous_callback(obj, ~, ~)            
            % to do            
        end                       
        
        %------------------------------------------------------------------
        % OMERO
        %------------------------------------------------------------------                                
                                        
         %------------------------------------------------------------------        
        function menu_tools_preferences_callback(obj,~,~)
            profile = ic_OPTtools_profile_controller();
            profile.set_profile();
        end        
         %------------------------------------------------------------------
        function menu_file_set_src_single_callback(obj, ~, ~)
            try
            [file,path] = uigetfile({'*.OME.tiff;*.OME.tif;*.ome.tiff;*.ome.tif;','OME.tiff Files'},'Select OPT data file',obj.data_controller.DefaultDirectory);
            catch
                [file,path] = uigetfile({'*.OME.tiff;*.OME.tif;*.ome.tiff;*.ome.tif;','OME.tiff Files'},'Select OPT data file',pwd);
            end
            if file ~= 0
                verbose = true;
                if isempty(obj.data_controller.get_delays([path file]))                    
                    infostring = obj.data_controller.Set_Src_Single([path file],verbose);
                else
                    infostring = obj.data_controller.Set_Src_FLIM([path file],'sum',verbose);
                end
                if ~isempty(infostring)
                    set(obj.menu_file_Working_Data_Info,'Label',infostring,'ForegroundColor','blue','Enable','on');
                    set(obj.menu_OMERO_Working_Data_Info,'Label','...','Enable','off');
                    set(obj.menu_settings_Zrange,'Label','Z range : full');
                    obj.data_controller.Z_range = []; % no selection                    
                    obj.omero_data_manager.image = [];
                end;                
            end
        end   
         %------------------------------------------------------------------
        function menu_file_set_src_dir_callback(obj, ~, ~)       
            [path] = uigetdir(obj.data_controller.DefaultDirectory,'Select a folder with OPT data files');
            if path ~= 0
                obj.data_controller.Set_Src_Multiple(path);    
            end
        end    
         %------------------------------------------------------------------
        function menu_file_reset_previous_callback(obj, ~, ~)       
            if ~isempty(obj.data_controller.previous_filenames) 
                if 1 == numel(obj.data_controller.previous_filenames) && ...
                   ~strcmp(obj.data_controller.current_filename,char(obj.data_controller.previous_filenames{1}))                
                    infostring = obj.data_controller.Set_Src_Single(char(obj.data_controller.previous_filenames{1}),true); % verbose
                    set(obj.menu_file_Working_Data_Info,'Label',infostring,'ForegroundColor','blue','Enable','on');
                    set(obj.menu_OMERO_Working_Data_Info,'Label','...','Enable','off');                    
                    set(obj.menu_settings_Zrange,'Label','Z range : full');
                    obj.data_controller.Z_range = []; % no selection                    
                end
            end            
        end
         %------------------------------------------------------------------
        function menu_file_set_dst_dir_callback(obj, ~, ~)
            [path] = uigetdir(obj.data_controller.DefaultDirectory,'Select a folder to put reconstructed volume(s)');
            if path ~= 0
                obj.data_controller.Set_Dst_Dir(path);    
            end           
        end    
         %------------------------------------------------------------------       
        function menu_file_save_current_volume_callback(obj,~,~)
            if ~isempty(obj.data_controller.volm)
                [file, path] = uiputfile({'*.OME.tiff','BioFormats multipage TIFF file';...
                    '*.mat','MATLAB file';'*.tif','Stack of separate .tif files'},'Select volume image file name',obj.data_controller.DefaultDirectory);
                if file ~= 0
                    obj.data_controller.save_volume([path filesep file],true);
                    %obj.data_controller.save_volume([path filesep file],false);
                end
            else
                errordlg('Volume was not created - nothing to save');
            end
        end        
    %================================= % call Icy visualizations
        
         %------------------------------------------------------------------        
        function menu_visualization_send_current_proj_to_Icy_callback(obj, ~,~)            
            if ~isempty(obj.data_controller.proj)
                hw = waitbar(0,'Sending projection data to Icy...');
                try
                    f = 1/obj.data_controller.downsampling;
                    if 1 == f
                        [szX,szY,szR] = size(obj.data_controller.proj);
                        
                        output = cast(reshape(obj.data_controller.proj,[szX,szY,1,szR,1]),'single');
                        
                        icy_imshow(output,['proj ' obj.get_current_data_info_string]); % Icy likes XYCZT
                        if ~isempty(hw), delete(hw), drawnow, end
                    else
                        [szX,szY] = size(imresize(obj.data_controller.proj(:,:,1),f));
                        [~,~,szR] = size(obj.data_controller.proj);
                        proj_r = zeros(szX,szY,1,szR,1,class(obj.data_controller.proj));
                        for r = 1:szR
                            proj_r(:,:,1,r,1) = imresize(obj.data_controller.proj(:,:,r),f);
                        end
                        icy_imshow(proj_r,['proj scale 1/' num2str(obj.data_controller.downsampling) ' : ' obj.get_current_data_info_string]); % Icy likes XYCZT 
                        
                        if ~isempty(hw), delete(hw), drawnow, end
                    end
                catch 
                    if ~isempty(hw), delete(hw), drawnow, end
                    errordlg('Error - Icy might be not started or is incorrectly configured.');
                end
            else
                errordlg('No projections - nothing to visualise');
            end
        end
         %------------------------------------------------------------------        
        function menu_visualization_send_current_volm_to_Icy_callback(obj, ~,~)
            
            %FLIM
            if ~isempty(obj.data_controller.delays) && ~isempty(obj.data_controller.memmap_volm)
                hw = waitbar(0,'Sending volume data to Icy...');
                sizeT = numel(obj.data_controller.delays);
                memRef = obj.data_controller.memmap_volm.Data;
                n_planes = numel(memRef);
                sizeZ = n_planes/sizeT; % mmm
                sizeC = 1;
                plane = memRef(1).plane;
                sizeX = size(plane,1);
                sizeY = size(plane,2);
                datatype = class(plane);
                try
                    volm = zeros(sizeX,sizeY,sizeZ,sizeC,sizeT,datatype);
                         for index = 1:n_planes
                             [z, c, t] = ind2sub([sizeZ sizeC sizeT],index);
                             volm(:,:,z,c,t) = memRef(index).plane;
                         end
                    icy_im3show(cast(volm,'single'),['volm scale 1/' num2str(obj.data_controller.downsampling) ' : ' obj.get_current_data_info_string]);
                    if ~isempty(hw), delete(hw), drawnow, end
                    return; % :)
                catch
                    if ~isempty(hw), delete(hw), drawnow, end
                    errordlg('Error - Icy might be not started or is incorrectly configured');  
                    % nothing
                end
                %
            
            %FLIM
            
            elseif ~isempty(obj.data_controller.volm)
                hw = waitbar(0,'Sending volume data to Icy...');
                try
                    icy_im3show(cast(obj.data_controller.volm,'single'),['volm scale 1/' num2str(obj.data_controller.downsampling) ' : ' obj.get_current_data_info_string]);
                    if ~isempty(hw), delete(hw), drawnow, end
                catch
                    if ~isempty(hw), delete(hw), drawnow, end
                    errordlg('Error - Icy might be not started or is incorrectly configured');                    
                end
            else
                errordlg('No volume - nothing to visualise');
            end
        end        
         %------------------------------------------------------------------                
        function menu_visualization_setup_Icy_directory_callback(obj, ~,~)
            [path] = uigetdir(obj.data_controller.DefaultDirectory,'Guide to Icy directory');
            if path ~= 0
                obj.data_controller.IcyDirectory = path;                
            end
            obj.data_controller.noIcy = [];
        end
         %------------------------------------------------------------------                
        function menu_visualization_start_Icy_callback(obj, ~,~)
            
            if ~isempty(obj.data_controller.IcyDirectory)                
                if ispc
                    dos([obj.data_controller.IcyDirectory filesep 'icy']);
                elseif ismac                    
                    unix(['open ' obj.data_controller.IcyDirectory filesep 'icy']); % ?                    
                elseif isunix
                    % ?
                end                                
            else
                msgbox('error - Icy directory was not set up');
            end
            
        end

    %================================= % reconstruction                

         %------------------------------------------------------------------                
        function clear_all(obj,~,~)
                    obj.omero_data_manager.dataset = [];
                    obj.data_controller.proj = [];
                    obj.data_controller.volm = [];            
                    obj.data_controller.on_proj_and_volm_clear;            
                    set(obj.menu_OMERO_Working_Data_Info,'Label','...','ForegroundColor','red');
                    set(obj.menu_Batch_Indicator_Src,'Label','...','ForegroundColor','blue');
                    set(obj.menu_Batch_Indicator_Dst,'Label','...','ForegroundColor','blue');                
                    obj.data_controller.BatchDstDirectory = [];                    
                    obj.data_controller.BatchSrcDirectory = [];                                
                    obj.data_controller.file_names = [];
                    obj.data_controller.omero_Image_IDs = [];
        end    
         %------------------------------------------------------------------            
        function ret = maybe_run_batch_reconstruction(obj,~)

                ret = false;

                batch_src_OK = isdir(obj.data_controller.BatchSrcDirectory) ...
                                || ~isempty(obj.omero_data_manager.dataset) ...
                                || ~isempty(obj.data_controller.omero_Image_IDs);
                %
                batch_dst_OK = isdir(obj.data_controller.BatchDstDirectory);

                if ~(batch_src_OK && batch_dst_OK), return, end;        

                button = questdlg('Do you want to run your batch or the current single volume?',...
                'Choose what exactly you want to do','Batch','Single','Clear All','Batch');
                if strcmp(button,'Batch')                   
                   verbose = true;
                   obj.data_controller.run_batch(obj.omero_data_manager,verbose);                   
                   obj.clear_all;
                   ret = true;                                       
                elseif strcmp(button,'Single')         
                   ret = false; % will try to do Single image reconstruction
                elseif strcmp(button,'Clear All')
                   obj.clear_all;
                   ret = true;                                        
                end                    
        end        

        function menu_Batch_RunBatch_callback(obj,~,~)
               batch_src_OK = isdir(obj.data_controller.BatchSrcDirectory) ...
                   || ~isempty(obj.omero_data_manager.dataset) ...
                   || ~isempty(obj.data_controller.omero_Image_IDs);
               
               batch_dst_OK = isdir(obj.data_controller.BatchDstDirectory);

                if ~(batch_src_OK && batch_dst_OK)
                    msgbox('Please set batch source and destination folders')
                    return
                end 

               button = questdlg('Have you selected your reconstruction settings?',...
                'Settings confirmation', ...
                'Yes, run batch','No, take me back','Yes, run batch');
               switch button
                   case 'Yes, run batch'
                   verbose = true;
                   obj.data_controller.run_batch(obj.omero_data_manager,verbose);                   
                   obj.clear_all;
                   ret = true; 
                   case 'No, take me back'
                       return
               end
        end

        function menu_Batch_save_format_tiffstack_callback(obj,~,~)
            obj.data_controller.batchsaveformat = '.tif';
            set(obj.menu_Batch_save_format,'Label','Save format: Indiv. slices');
        end

        function menu_Batch_save_format_OMEtiff_callback(obj,~,~)
            obj.data_controller.batchsaveformat = '.OME.tiff';
            set(obj.menu_Batch_save_format,'Label','Save format: OME.tiff volm.');
        end

        function menu_Batch_save_format_matlab_callback(obj,~,~)
            obj.data_controller.batchsaveformat = '.mat';
            set(obj.menu_Batch_save_format,'Label','Save format: .MAT volm.');
        end


           %------------------------------------------------------------------                
         function menu_reconstruction_Go_callback(obj, ~,~) 
            % 
            if obj.maybe_run_batch_reconstruction, return, end;             
            %
            if ~isempty(obj.data_controller.proj) && ~isempty(obj.data_controller.angles)
                
                if ~isempty(obj.data_controller.delays)
                    obj.data_controller.perform_reconstruction_FLIM;
                else                
                    if strcmp(obj.data_controller.Reconstruction_Largo,'ON')
                        obj.data_controller.perform_reconstruction_Largo;
                    else
                        %verbose = false;
                        verbose = true;
                        obj.data_controller.volm = obj.data_controller.perform_reconstruction(verbose);
                    end    
                end
            else
                msgbox('No projection data loaded - can not do reconstruction');
            end                            
         end
         
    %================================= % downsampling indicators        
        % 
         %------------------------------------------------------------------
        function menu_settings_Pixel_Downsampling_1_callback(obj, ~,~)
            obj.set_pixel_downsampling(1);            
        end        
         %------------------------------------------------------------------        
        function menu_settings_Pixel_Downsampling_2_callback(obj, ~,~)
            obj.set_pixel_downsampling(2);
        end
         %------------------------------------------------------------------
        function menu_settings_Pixel_Downsampling_4_callback(obj, ~,~)
            obj.set_pixel_downsampling(4);            
        end            
         %------------------------------------------------------------------        
        function menu_settings_Pixel_Downsampling_8_callback(obj, ~,~)
            obj.set_pixel_downsampling(8);            
        end            
         %------------------------------------------------------------------        
        function menu_settings_Pixel_Downsampling_16_callback(obj, ~,~)
            obj.set_pixel_downsampling(16);            
        end            
        %
         %------------------------------------------------------------------     
         % Rotation axis orientation %
         %------------------------------------------------------------------        
         function menu_settings_Rotation_Axis_Orientation_Horizontal_callback(obj, ~,~)
            obj.data_controller.swap_XY_dimensions = 'Horizontal';
            set(obj.menu_settings_Rotation_Axis_Orientation,'Label','Rotation axis orientation: Horizontal');
        end            
         %------------------------------------------------------------------    
        function menu_settings_Rotation_Axis_Orientation_Vertical_callback(obj, ~,~)
            obj.data_controller.swap_XY_dimensions = 'Vertical';
            set(obj.menu_settings_Rotation_Axis_Orientation,'Label','Rotation axis orientation: Vertical');
        end            
         %------------------------------------------------------------------    
         function set_pixel_downsampling(obj,factor,~)
            obj.data_controller.downsampling = factor;
            obj.data_controller.volm = [];
            obj.data_controller.on_volm_clear;
            set(obj.menu_settings_Pixel_Downsampling,'Label',['Pixel downsampling : 1/' num2str(factor)]);                                                 
         end    
         
         % function menu_settings_Angular_Coverage_360_callback(obj,~,~);
         %     obj.data_controller.angularcoverage = 360;
         %     set(obj.menu_settings_Angular_Coverage,'Label',['Angular coverage of projections : 360' char(176)]);
         % end
         % 
         % function menu_settings_Angular_Coverage_180_callback(obj,~,~);
         %     obj.data_controller.angularcoverage = 180;
         %     set(obj.menu_settings_Angular_Coverage,'Label',['Angular coverage of projections : 180' char(176)]);
         % end
        %
         %------------------------------------------------------------------        
        function menu_settings_Angle_Downsampling_1_callback(obj, ~,~)
            obj.data_controller.angle_downsampling = 1;
            obj.data_controller.volm = []; 
            obj.data_controller.on_volm_clear;
            set(obj.menu_settings_Angle_Downsampling,'Label','Angle downsampling 1/1');                                    
        end                    
         %------------------------------------------------------------------        
        function menu_settings_Angle_Downsampling_2_callback(obj, ~,~)
            obj.data_controller.angle_downsampling = 2;
            obj.data_controller.volm = []; 
            obj.data_controller.on_volm_clear;
            set(obj.menu_settings_Angle_Downsampling,'Label','Angle downsampling 1/2');                                                
        end            
         %------------------------------------------------------------------        
        function menu_settings_Angle_Downsampling_4_callback(obj, ~,~)
            obj.data_controller.angle_downsampling = 4;
            obj.data_controller.volm = []; 
            obj.data_controller.on_volm_clear;
            set(obj.menu_settings_Angle_Downsampling,'Label','Angle downsampling 1/4');                                                           
        end            
         %------------------------------------------------------------------
        function menu_settings_Angle_Downsampling_8_callback(obj, ~,~)
            obj.data_controller.angle_downsampling = 8;
            obj.data_controller.volm = []; 
            obj.data_controller.on_volm_clear;
            set(obj.menu_settings_Angle_Downsampling,'Label','Angle downsampling 1/8');            
        end                    
         %------------------------------------------------------------------
        function menu_FBP_interp_nearest_callback(obj, ~,~)
            obj.data_controller.FBP_interp = 'nearest';
            set(obj.menu_FBP_interp,'Label',['FBP interp : ' obj.data_controller.FBP_interp]);
        end            
         %------------------------------------------------------------------        
        function menu_FBP_interp_linear_callback(obj, ~,~)
            obj.data_controller.FBP_interp = 'linear';
            set(obj.menu_FBP_interp,'Label',['FBP interp : ' obj.data_controller.FBP_interp]);            
        end            
         %------------------------------------------------------------------                    
        function menu_FBP_interp_spline_callback(obj, ~,~)
            obj.data_controller.FBP_interp = 'spline';
            set(obj.menu_FBP_interp,'Label',['FBP interp : ' obj.data_controller.FBP_interp]);            
        end            
         %------------------------------------------------------------------                    
        function menu_FBP_interp_pchip_callback(obj, ~,~)
            obj.data_controller.FBP_interp = 'pchip';
            set(obj.menu_FBP_interp,'Label',['FBP interp : ' obj.data_controller.FBP_interp]);            
        end            
         %------------------------------------------------------------------                    
        function menu_FBP_interp_v5cubic_callback(obj, ~,~)
            obj.data_controller.FBP_interp = 'v5cubic';
            set(obj.menu_FBP_interp,'Label',['FBP interp : ' obj.data_controller.FBP_interp]);            
        end            
         %------------------------------------------------------------------                        
        function menu_FBP_filter_Ram_Lak_callback(obj, ~,~)
            obj.data_controller.FBP_filter = 'Ram-Lak';
            set(obj.menu_FBP_filter,'Label',['FBP filter : ' obj.data_controller.FBP_filter]);
        end            
         %------------------------------------------------------------------                    
        function menu_FBP_filter_Shepp_Logan_callback(obj, ~,~)
            obj.data_controller.FBP_filter = 'Shepp-Logan';
            set(obj.menu_FBP_filter,'Label',['FBP filter : ' obj.data_controller.FBP_filter]);
        end            
         %------------------------------------------------------------------                    
        function menu_FBP_filter_Cosine_callback(obj, ~,~)
            obj.data_controller.FBP_filter = 'Cosine';
            set(obj.menu_FBP_filter,'Label',['FBP filter : ' obj.data_controller.FBP_filter]);            
        end            
         %------------------------------------------------------------------                    
        function menu_FBP_filter_Hammming_callback(obj, ~,~)
            obj.data_controller.FBP_filter = 'Hamming';
            set(obj.menu_FBP_filter,'Label',['FBP filter : ' obj.data_controller.FBP_filter]);            
        end            
         %------------------------------------------------------------------                    
        function menu_FBP_filter_Hann_callback(obj, ~,~)
            obj.data_controller.FBP_filter = 'Hann';
            set(obj.menu_FBP_filter,'Label',['FBP filter : ' obj.data_controller.FBP_filter]);                        
        end            
         %------------------------------------------------------------------                    
        function menu_FBP_filter_None_callback(obj, ~,~)
            obj.data_controller.FBP_filter = 'None';
            set(obj.menu_FBP_filter,'Label',['FBP filter : ' obj.data_controller.FBP_filter]);                        
        end            
         %------------------------------------------------------------------                        
        function menu_FBP_freq_scaling_callback(obj, ~,~)
            fscaling = enter_value();
            if ~isnan(fscaling) && fscaling > 0 && fscaling <= 1
                obj.data_controller.FBP_fscaling = fscaling;
                set(obj.menu_FBP_freq_scaling,'Label',['FBP fscaling : ' num2str(fscaling)]);
            else
                errordlg('Please set FBP frequency scaling to a number between 0 and 1')
            end
        end
        %  -------------------------------------------------------------------
        function menu_FBP_exampleslice_callback(obj,~,~)
            if isempty(obj.data_controller.proj)
                errordlg('Please load projection images before attempting reconstruction')
            else
                slicetodo = floor(enter_value());
                [~,sizeY,~] = size(obj.data_controller.proj);
                if slicetodo > sizeY || slicetodo <1 || isnan(slicetodo)
                    errordlg(['Please select a slice within the volume range (1 to ',num2str(sizeY),')']);
                else
                    if strcmp(obj.data_controller.Reconstruction_GPU,'OFF')
                        wait_handle = waitbar(0,'Reconstructing example slice on the CPU');
                        %disp('Reconstructing example slice using the GPU')
                        sinogram = squeeze(obj.data_controller.proj(:,slicetodo,:));
                        reconslice = obj.data_controller.FBP(sinogram);
                    else
                        wait_handle = waitbar(0,'Reconstructing example slice on the GPU');
                        %disp('Reconstructing example slice using the CPU')
                        sinogram = gpuArray(squeeze(obj.data_controller.proj(:,slicetodo,:)));
                        reconslice = gather(obj.data_controller.FBP(sinogram));
                    end
                    figure; imagesc(reconslice); axis equal off tight; colormap gray; title(['Slice number = ',num2str(slicetodo)]);
                    close(wait_handle);
                end
            end
        end

% ================ bleaching correction
        function menu_bleaching_correction_on_callback(obj,~,~)
            obj.data_controller.Bleaching_correction = 'On';
            set(obj.menu_bleaching_correction,'Label','Auto photobleaching correction : On');
        end
        function menu_bleaching_correction_off_callback(obj,~,~)
            obj.data_controller.Bleaching_correction = 'Off';
            set(obj.menu_bleaching_correction,'Label','Auto photobleaching correction : Off');
        end
    %================================= % pre-filtering                        
         %------------------------------------------------------------------                        
        function menu_settings_Median_Prefiltering_Set_Size_callback(obj, ~,~)
             value = fix(enter_value());
             if value > 5, value = 5; end
             obj.data_controller.Prefiltering_Size = value;            
             set(obj.menu_settings_Median_Prefiltering,'Label',['On-Load Median pre-filtering : ' num2str(obj.data_controller.Prefiltering_Size)]);                    
        end
         %------------------------------------------------------------------                                
        function menu_settings_Median_Prefiltering_None_callback(obj, ~,~)
            obj.data_controller.Prefiltering_Size = 'None';
            set(obj.menu_settings_Median_Prefiltering,'Label',['On-Load Median pre-filtering : ' 'None']);                                
        end                
    %================================= % reconstruction options                
         %------------------------------------------------------------------                                        
        function menu_settings_Method_FBP_callback(obj, ~,~)
            obj.data_controller.Reconstruction_Method = 'FBP';
            set(obj.menu_settings_Method,'Label',['Method : ' obj.data_controller.Reconstruction_Method]);
        end
         %------------------------------------------------------------------                                
        function menu_settings_Method_TwIST_callback(obj, ~,~)
            obj.data_controller.Reconstruction_Method = 'FBP-TwIST';
            set(obj.menu_settings_Method,'Label',['Method : ' obj.data_controller.Reconstruction_Method]);            
        end
         %------------------------------------------------------------------                                            
        function menu_settings_GPU_ON_callback(obj, ~,~)
            state = obj.data_controller.Reconstruction_GPU;
            if strcmp(state,'OFF')
                obj.data_controller.Reconstruction_GPU = 'ON';
            elseif strcmp(state,'ON')
                obj.data_controller.Reconstruction_GPU = 'OFF';
            end
            set(obj.menu_settings_GPU,'Label',['GPU : ' obj.data_controller.Reconstruction_GPU]);
            set(obj.menu_settings_GPU_ON,'Label',state);
        end
         %------------------------------------------------------------------                                            
        function menu_settings_Largo_ON_callback(obj, ~,~)
            state = obj.data_controller.Reconstruction_Largo;
            if strcmp(state,'OFF')
                obj.data_controller.Reconstruction_Largo = 'ON';
            elseif strcmp(state,'ON')
                obj.data_controller.Reconstruction_Largo = 'OFF';
            end
            set(obj.menu_settings_Largo,'Label',['Largo : ' obj.data_controller.Reconstruction_Largo]);
            set(obj.menu_settings_Largo_ON,'Label',state);
        end
        
         %------------------------------------------------------------------                                
        function menu_settings_TwIST_callback(obj, ~,~)
            TwIST_settings(obj.data_controller);
        end         
        
         %------------------------------------------------------------------                                        
        function menu_settings_Registration_None_callback(obj, ~,~)
            obj.data_controller.registration_method = 'None';
            set(obj.menu_settings_Registration,'Label',['On-Load registration : None']);
        end
         %------------------------------------------------------------------
        function menu_settings_Registration_M1_callback(obj, ~,~)
            obj.data_controller.registration_method = 'Auto + Manual confirmation';
            set(obj.menu_settings_Registration,'Label',['On-Load registration : Auto + Manual confirmation' ]);
        end
         %------------------------------------------------------------------        
        function menu_settings_Registration_M2_callback(obj, ~,~)
            obj.data_controller.registration_method = 'Rotation axis shift only';
            set(obj.menu_settings_Registration,'Label',['On-Load registration : Auto axis shift']);
        end      

        function menu_settings_Registration_M3_callback(obj, ~,~)
            obj.data_controller.registration_method = 'Manual registration';
            set(obj.menu_settings_Registration,'Label',['On-Load registration : Manual']);
        end   
    %================================= % Z range                 
         
         %------------------------------------------------------------------                
         function menu_settings_Zrange_callback(obj,~,~)
             if ~isempty(obj.data_controller.proj)
                h1 = figure;
                
                %imagesc(obj.data_controller.proj(:,:,1));
                [szX,szY,szR] = size(obj.data_controller.proj);
                for r = 1:10:szR
                     imagesc(obj.data_controller.proj(:,:,r));
                     daspect([1 1 1]);
                     getframe;
                end
                                                                    
                h = imrect; 
                position = wait(h); 
                try close(h1); catch, end;
                
                if ~isempty(position)                                        
                    position = fix(position);                    
                        minZ = position(1);
                        maxZ = position(1) + position(3);
                            if minZ <= 0, minZ = 1; end;
                            if maxZ > szY, maxZ = szY; end;                                        
                    obj.data_controller.Z_range = [minZ maxZ];

                    set(obj.menu_settings_Zrange,'Label',[ 'Z range ' '[' num2str(minZ) ',' num2str(maxZ) ']' ])
                else
                    msgbox('Z range will be switched to default (full data)');
                    set(obj.menu_settings_Zrange,'Label','Z range : full');
                    obj.data_controller.Z_range = []; % no selection
                end
                
             else
                 errordlg('please load projections first');
             end
                          
         end


         %======= save settings

         function menu_settings_save_bit_depth_32_callback(obj,~,~)
             obj.data_controller.save_volume_bit_depth = 32;
             set(obj.menu_settings_save_bit_depth,'Label','Image bit depth: 32-bit');
         end

         function menu_settings_save_bit_depth_16_callback(obj,~,~)
             obj.data_controller.save_volume_bit_depth = 16;
             set(obj.menu_settings_save_bit_depth,'Label','Image bit depth: 16-bit');
         end         

         function menu_settings_writeparameterfile_true_callback(obj,~,~)
             obj.data_controller.writeparameterfile = 'On';
             set(obj.menu_settings_writeparameterfile,'Label','Write parameter .txt file: On');
         end

         function menu_settings_writeparameterfile_false_callback(obj,~,~)
             obj.data_controller.writeparameterfile = 'Off';
             set(obj.menu_settings_writeparameterfile,'Label','Write parameter .txt file: Off');
         end


    %================================= % infostring                 
         
        %------------------------------------------------------------------
        function infostring = get_current_data_info_string(obj,~,~)
            infostring = [];
            if ~isempty(obj.data_controller.current_filename)
                infostring = obj.data_controller.current_filename;
            elseif ~isempty(obj.omero_data_manager.image)                 
                iName = char(java.lang.String(obj.omero_data_manager.image.getName().getValue()));                                
                iId = num2str(obj.omero_data_manager.image.getId().getValue());                        
                infostring = [ 'Image "' iName '" [' iId ']' ];            
            end
        end

% -------- background corrections

        function menu_settings_background_select_bright_bg_callback(obj,~,~)
            [path] = uigetdir(obj.data_controller.DefaultDirectory,'Set bright background image directory');
            if path ~= 0
                obj.data_controller.brightbgdir = path;
                set(obj.menu_settings_background_label_bright_bg,'Label',path);
            
                if isempty(obj.data_controller.darkbgdir)
                    set(obj.menu_background_options,'Label', 'Background corrections : Bright background');
                else
                    set(obj.menu_background_options,'Label', 'Background corrections : Bright + dark background');
                end

            end
        end

        function menu_settings_background_select_dark_bg_callback(obj,~,~)
            [path] = uigetdir(obj.data_controller.DefaultDirectory,'Set bright background image directory');
            if path ~= 0
                obj.data_controller.darkbgdir = path;
                set(obj.menu_settings_background_label_dark_bg,'Label',path);
                if isempty(obj.data_controller.brightbgdir)
                    set(obj.menu_background_options,'Label', 'Background corrections : Dark background');
                else
                    set(obj.menu_background_options,'Label', 'Background corrections : Bright + dark background');
                end
            end
        end




    %================================= % Batch
    
        %------------------------------------------------------------------    
        function menu_Batch_Src_HD_callback(obj,~,~)
            [path] = uigetdir(obj.data_controller.DefaultDirectory,'Set Source directory');
            if path ~= 0
                obj.data_controller.BatchSrcDirectory = path;                
                set(obj.menu_Batch_Indicator_Src,'Label',path,'ForegroundColor','blue');
                obj.data_controller.DefaultDirectory = path;
            end                                               
        end
        %------------------------------------------------------------------        
        function menu_Batch_Src_OMERO_callback(obj,~,~)
            infostring = [];
            try
                infostring = obj.omero_data_manager.Set_Dataset();
            catch
                errordlg('OMERO might be not active - please log on');
                return;
            end
            if ~isempty(infostring)
                set(obj.menu_OMERO_Working_Data_Info,'Label',infostring,'ForegroundColor','blue');
                set(obj.menu_Batch_Indicator_Src,'Label',infostring,'ForegroundColor','blue');                
            end;                        
        end
        %------------------------------------------------------------------        
        function menu_Batch_SetDst_callback(obj,~,~)
            [path] = uigetdir(obj.data_controller.DefaultDirectory,'Set Destination directory');
            if path ~= 0
                obj.data_controller.file_names = [];                
                obj.data_controller.BatchDstDirectory = path;                
                set(obj.menu_Batch_Indicator_Dst,'Label',path,'ForegroundColor','blue');
            end                                               
        end            

        %------------------------------------------------------------------                
        function menu_Batch_Src_slctd_HD_callback(obj,~,~)
            obj.data_controller.file_names = [];
            [filenames, path] = uigetfile({'*.OME.tiff';'*.ome.tiff'},'MultiSelect','on');
            if path ~= 0
                obj.data_controller.file_names = filenames;                
                obj.data_controller.BatchSrcDirectory = path;
                set(obj.menu_Batch_Indicator_Src,'Label',path,'ForegroundColor','blue');
                obj.data_controller.DefaultDirectory = path;                
            end
        end
        %------------------------------------------------------------------                
        function menu_Batch_Src_slctd_OMERO_callback(obj,~,~)
            obj.data_controller.omero_Image_IDs = [];
            try
                infostring = obj.omero_data_manager.Set_Images(obj.data_controller);
            catch
                errordlg('OMERO might be not active - please log on');
                return;
            end
            if ~isempty(infostring)
                set(obj.menu_OMERO_Working_Data_Info,'Label','...','ForegroundColor','blue');
                set(obj.menu_Batch_Indicator_Src,'Label',infostring,'ForegroundColor','blue');                
            end;                      
        end

        
         %------------------------------------------------------------------
        function menu_file_set_src_single_imstack_callback(obj, ~, ~)
            
            button = questdlg('Have you selected your on-load settings?',...
                'On-load settings confirmation', ...
                'Yes, choose projections','No, take me back','Yes, choose projections');
            switch button
                case 'Yes, choose projections'
                    ItemList = uipickfiles('FilterSpec',obj.data_controller.DefaultDirectory,'redirs',1,'output','cell');
                    %
                    if isempty(ItemList) || ~iscell(ItemList), return, end;
                    %
                    if 1~=numel(ItemList) || ~isdir(char(ItemList(1)))
                        errordlg('single folder is expected - can not continue');
                    end
                    %
                    path = char(ItemList{1});
                    verbose = true;
                    %            
                    if isempty(obj.data_controller.imstack_get_delays(path))                    
                        infostring = obj.data_controller.imstack_Set_Src_Single(path,verbose);
                    else
                        infostring = obj.data_controller.imstack_Set_Src_Single_FLIM(path,'sum',verbose);
                    end
                        if ~isempty(infostring)
                            set(obj.menu_file_Working_Data_Info,'Label',infostring,'ForegroundColor','blue','Enable','on');
                            set(obj.menu_OMERO_Working_Data_Info,'Label','...','Enable','off');
                            set(obj.menu_settings_Zrange,'Label','Z range : full');
                            obj.data_controller.Z_range = []; % no selection                    
                            obj.omero_data_manager.image = [];
                        end     
                case 'No, take me back'
                    return
            end
        end   

        function menu_rerun_registration_callback(obj,~,~)
            if ~isempty(obj.data_controller.proj)
                if ~strcmp('None',obj.data_controller.registration_method)
                    obj.data_controller.do_registration;
                else
                    msgbox('Registration method is set to ''None'', no registration will be performed.')
                end
            else
                errordlg('Please load projection images before attempting registration.')
            end
        end
        
        
    %================================= % VANITY       
    
        %------------------------------------------------------------------
        function menu_help_about_callback(obj, ~, ~)
            % to do
        end            
        %------------------------------------------------------------------
        function menu_help_tracker_callback(obj, ~, ~)
            % to do
        end            
        %------------------------------------------------------------------
        function menu_help_bugs_callback(obj, ~, ~)
            % to do
        end
                            
    end
    
end
