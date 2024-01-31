function handles = setup_menu(obj,handles)

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

    %================================= settings    
    
    pixel_downsampling = handles.data_controller.downsampling;
    angle_downsampling = handles.data_controller.angle_downsampling;

    bleaching_correction = handles.data_controller.Bleaching_correction;
    
    FBP_interp = handles.data_controller.FBP_interp;
    FBP_filter = handles.data_controller.FBP_filter;
    FBP_fscaling = handles.data_controller.FBP_fscaling; 
    
    settings_Method = handles.data_controller.Reconstruction_Method;
    settings_GPU = handles.data_controller.Reconstruction_GPU;
    isGPU = handles.data_controller.isGPU;
        
    settings_Largo = handles.data_controller.Reconstruction_Largo;
    
    settings_Prefiltering_Size = handles.data_controller.Prefiltering_Size;
    
    settings_Registration = handles.data_controller.registration_method;

    settings_swapDimension = handles.data_controller.swap_XY_dimensions;

    settings_save_bit_depth = handles.data_controller.save_volume_bit_depth;

    settings_writeparameterfile = handles.data_controller.writeparameterfile;
    
    %settings_angular_coverage = handles.data_controller.angularcoverage;
    
    %================================= file

    menu_file = uimenu(obj.window,'Label','File');
    
    handles.menu_file_Working_Data_Info = uimenu(menu_file,'Label','...','ForegroundColor','red','Enable','off');    
    handles.menu_file_new_window = uimenu(menu_file,'Label','New Window','Accelerator','N');
    handles.menu_file_set_src_single = uimenu(menu_file,'Label','Load single - OME.tiff','Separator','on');
    handles.menu_file_set_src_single_imstack = uimenu(menu_file,'Label','Load single - image stack');
    % handles.menu_file_set_src_dir = uimenu(menu_file,'Label','Set Src - multiple files (directory)');
    handles.menu_file_reset_previous = uimenu(menu_file,'Label','Reset to previous');    
    % handles.menu_file_set_dst_dir = uimenu(menu_file,'Label','Set Dst - directory','Separator','on');
    handles.menu_file_save_current_volume = uimenu(menu_file,'Label','Save current volume','Separator','on');
            
    %================================= OMERO
    %{
    menu_OMERO = uimenu(obj.window,'Label','OMERO');

    handles.menu_OMERO_Working_Data_Info = uimenu(menu_OMERO,'Label','...','ForegroundColor','red','Enable','off');
    handles.menu_OMERO_login = uimenu(menu_OMERO,'Label','Log in to OMERO');    

    menu_OMERO_Set_Data = uimenu(menu_OMERO,'Label','Set User');
    handles.menu_OMERO_Switch_User = uimenu(menu_OMERO_Set_Data,'Label','Switch User...','Separator','on','Enable','off');    

    handles.menu_OMERO_Connect_To_Another_User = uimenu(menu_OMERO_Set_Data,'Label','Connect to another User...','Enable','off');    
    handles.menu_OMERO_Connect_To_Logon_User = uimenu(menu_OMERO_Set_Data,'Label','Connect to Logon User...','Enable','off');    

    handles.menu_OMERO_Reset_Logon = uimenu(menu_OMERO_Set_Data,'Label','Restore Logon','Separator','on','Enable','off');                
    
    handles.menu_OMERO_set_single = uimenu(menu_OMERO,'Label','Load single Image','Separator','on','Enable','off');
    % handles.menu_OMERO_set_multiple = uimenu(menu_OMERO,'Label','Set Src - multiple Images','Enable','off');
    % handles.menu_OMERO_reset_previous = uimenu(menu_OMERO,'Label','Reset to previous','Enable','off');    
            
    %}

    
    %================================= settings
    
    menu_settings = uimenu(obj.window,'Label','Settings');
    
    pre_load_label = uimenu(menu_settings,'Label','On-load settings:','Enable','off','Separator','on');

    menu_settings_Rotation_Axis_Orientation = uimenu(menu_settings,'Label',['Rotation axis orientation : ' num2str(settings_swapDimension)],'Separator','On');
    handles.menu_settings_Rotation_Axis_Orientation_Horizontal = uimenu(menu_settings_Rotation_Axis_Orientation,'Label','Horizontal');    
    handles.menu_settings_Rotation_Axis_Orientation_Vertical = uimenu(menu_settings_Rotation_Axis_Orientation,'Label','Vertical');
    %handles.menu_settings_Rotation_Axis_Orientation_Automatic = uimenu(menu_settings_Rotation_Axis_Orientation,'Label','Detect automatically');
    
    handles.menu_settings_Rotation_Axis_Orientation = menu_settings_Rotation_Axis_Orientation;

    menu_settings_Registration = uimenu(menu_settings,'Label',['On-Load registration : ' settings_Registration],'Separator','Off');
    handles.menu_settings_Registration_M1 = uimenu(menu_settings_Registration,'Label','Automatic axis shift with optional manual registration');
    handles.menu_settings_Registration_M2 = uimenu(menu_settings_Registration,'Label','Automatic rotation axis shift (translation) only');
    handles.menu_settings_Registration_M3 = uimenu(menu_settings_Registration,'Label','Manual registration');
    handles.menu_settings_Registration_None = uimenu(menu_settings_Registration,'Label','None');
    
    

        
    menu_settings_Median_Prefiltering = uimenu(menu_settings,'Label',['On-Load Median pre-filtering : ' num2str(settings_Prefiltering_Size)],'Separator','Off');
    handles.menu_settings_Median_Prefiltering_Set_Size = uimenu(menu_settings_Median_Prefiltering,'Label','Set size');    
    handles.menu_settings_Median_Prefiltering_None = uimenu(menu_settings_Median_Prefiltering,'Label','None');        
    
    handles.menu_settings_Median_Prefiltering = menu_settings_Median_Prefiltering;
    
    menu_settings_Pixel_Downsampling = uimenu(menu_settings,'Label',['Pixel downsampling : 1/' num2str(pixel_downsampling)],'Separator','Off');
    % menu_settings_Angle_Downsampling = uimenu(menu_settings,'Label',['Angle downsampling : 1/' num2str(angle_downsampling)]);

    handles.menu_settings_Pixel_Downsampling_1 = uimenu(menu_settings_Pixel_Downsampling,'Label','1/1');    
    handles.menu_settings_Pixel_Downsampling_2 = uimenu(menu_settings_Pixel_Downsampling,'Label','1/2');
    handles.menu_settings_Pixel_Downsampling_4 = uimenu(menu_settings_Pixel_Downsampling,'Label','1/4');
    handles.menu_settings_Pixel_Downsampling_8 = uimenu(menu_settings_Pixel_Downsampling,'Label','1/8');
    handles.menu_settings_Pixel_Downsampling_16 = uimenu(menu_settings_Pixel_Downsampling,'Label','1/16');
    %     handles.menu_settings_Angle_Downsampling_1 = uimenu(menu_settings_Angle_Downsampling,'Label','1/1');    
    %     handles.menu_settings_Angle_Downsampling_2 = uimenu(menu_settings_Angle_Downsampling,'Label','1/2');
    %     handles.menu_settings_Angle_Downsampling_4 = uimenu(menu_settings_Angle_Downsampling,'Label','1/4');
    %     handles.menu_settings_Angle_Downsampling_8 = uimenu(menu_settings_Angle_Downsampling,'Label','1/8');
    
    handles.menu_settings_Pixel_Downsampling = menu_settings_Pixel_Downsampling;    
    %     handles.menu_settings_Angle_Downsampling = menu_settings_Angle_Downsampling;
    
    % menu_settings_Angular_Coverage = uimenu(menu_settings,'Label',['Angular coverage of projections : ' num2str(settings_angular_coverage) char(176)],'Separator','Off');
    % handles.menu_settings_Angular_Coverage_360 = uimenu(menu_settings_Angular_Coverage,'Label',['360' char(176)]);
    % handles.menu_settings_Angular_Coverage_180 = uimenu(menu_settings_Angular_Coverage,'Label',['180' char(176)]);
    % handles.menu_settings_Angular_Coverage = menu_settings_Angular_Coverage;
    
    menu_background_options = uimenu(menu_settings,'Label',['Background corrections : None']);
    handles.menu_background_options = menu_background_options;

    handles.menu_settings_background_select_bright_bg = uimenu(menu_background_options,'Label','Select bright background image directory:');
    handles.menu_settings_background_label_bright_bg = uimenu(menu_background_options,'Label','...','Enable','off');
    handles.menu_settings_background_select_dark_bg = uimenu(menu_background_options,'Label','Select dark background image directory:','Separator','on');
    handles.menu_settings_background_label_dark_bg = uimenu(menu_background_options,'Label','...','Enable','off');

    menu_bleaching_correction = uimenu(menu_settings,'Label',['Auto photobleaching correction : ',bleaching_correction]);
    handles.menu_bleaching_correction = menu_bleaching_correction;
    handles.menu_bleaching_correction_on = uimenu(menu_bleaching_correction,'Label','On');
    handles.menu_bleaching_correction_off = uimenu(menu_bleaching_correction,'Label','Off');

    menu_current_registration = uimenu(menu_settings,'Label',['Current registration: Shift: ',num2str(handles.data_controller.registration_shift),...
        ', Rot.: ',num2str(handles.data_controller.registration_rotation),char(176)],'Enable','Off','Separator','On');
    handles.menu_current_registration = menu_current_registration;
    %menu_rerun_registration = uimenu(menu_settings,'Label','Re-run registration','Separator','Off');
    %handles.menu_rerun_registration = menu_rerun_registration;

%-----------------------------RECONSTRUCTION SETTINGS
    
    recon_label = uimenu(menu_settings,'Label','Reconstruction settings:','Enable','off','Separator','On');

    handles.menu_settings_Zrange = uimenu(menu_settings,'Label','Z range : full','Separator','On'); 

    %
    menu_settings_Method = uimenu(menu_settings,'Label',['Reconstruction method : ' settings_Method],'Separator','On');    
        handles.menu_settings_Method_FBP = uimenu(menu_settings_Method,'Label','FBP');
        handles.menu_settings_Method_TwIST = uimenu(menu_settings_Method,'Label','FBP-TwIST');
        %
        if isGPU
            if strcmp(settings_GPU,'ON')
                set_menu = 'ON';
                set_fun = 'OFF';
            elseif strcmp(settings_GPU,'OFF')
                set_menu = 'OFF';
                set_fun = 'ON'; 
            end;
            menu_settings_GPU = uimenu(menu_settings,'Label',['GPU : ' set_menu]);    
            handles.menu_settings_GPU_ON = uimenu(menu_settings_GPU,'Label',set_fun);                          
        else
            menu_settings_GPU = uimenu(menu_settings,'Label',['GPU : ' 'OFF']);    
            handles.menu_settings_GPU_ON = uimenu(menu_settings_GPU,'Label','ON');
            set(handles.menu_settings_GPU_ON,'Enable','off')
        end
        %
        if strcmp(settings_Largo,'ON')
            set_menu = 'ON';
            set_fun = 'OFF';
        elseif strcmp(settings_Largo,'OFF')
            set_menu = 'OFF';
            set_fun = 'ON'; 
        end;
    menu_settings_Largo = uimenu(menu_settings,'Label',['Largo : ' set_menu]);    
        handles.menu_settings_Largo_ON = uimenu(menu_settings_Largo,'Label',set_fun);          
        
    %    
    handles.menu_settings_Method = menu_settings_Method;
    handles.menu_settings_GPU = menu_settings_GPU;
    handles.menu_settings_Largo = menu_settings_Largo;
    handles.menu_settings_Registration = menu_settings_Registration;
    %
        
    menu_FBP_interp = uimenu(menu_settings,'Label',['FBP interpolation : ' FBP_interp],'Separator','On');    
        handles.menu_FBP_interp_nearest = uimenu(menu_FBP_interp,'Label','Nearest-neighbor');    
        handles.menu_FBP_interp_linear = uimenu(menu_FBP_interp,'Label','Linear');    
        handles.menu_FBP_interp_spline = uimenu(menu_FBP_interp,'Label','Spline');    
        handles.menu_FBP_interp_pchip = uimenu(menu_FBP_interp,'Label','Shape-preserving piecewise cubic (''pchip'')');    
        handles.menu_FBP_interp_v5cubic = uimenu(menu_FBP_interp,'Label','Cubic convolution used in MATLAB 5 (''v5cubic'')');    
    
    menu_FBP_filter = uimenu(menu_settings,'Label',['FBP filter : ' FBP_filter]);
        handles.menu_FBP_filter_Ram_Lak = uimenu(menu_FBP_filter,'Label','Ram-Lak');
        handles.menu_FBP_filter_Shepp_Logan = uimenu(menu_FBP_filter,'Label','Shepp-Logan');
        handles.menu_FBP_filter_Cosine = uimenu(menu_FBP_filter,'Label','Cosine');        
        handles.menu_FBP_filter_Hammming = uimenu(menu_FBP_filter,'Label','Hamming');
        handles.menu_FBP_filter_Hann = uimenu(menu_FBP_filter,'Label','Hann');
        handles.menu_FBP_filter_None = uimenu(menu_FBP_filter,'Label','None');        
    
    handles.menu_FBP_freq_scaling = uimenu(menu_settings,'Label',['FBP frequency scaling : ' num2str(FBP_fscaling)]);    
    handles.menu_FBP_interp = menu_FBP_interp;
    handles.menu_FBP_filter = menu_FBP_filter;

    menu_FBP_exampleslice = uimenu(menu_settings,'Label','Reconstruct example slice using FBP');
    handles.menu_FBP_exampleslice = menu_FBP_exampleslice;
    
    handles.menu_settings_TwIST = uimenu(menu_settings,'Label','TwIST Parameters...','Separator','On');
    
    save_label = uimenu(menu_settings,'Label','Save settings:','Enable','off','Separator','on');

    menu_settings_save_bit_depth = uimenu(menu_settings,'Label',['Image bit depth: ' num2str(settings_save_bit_depth) '-bit'],'Separator','on');
    handles.menu_settings_save_bit_depth_32 = uimenu(menu_settings_save_bit_depth,'Label','32-bit');
    handles.menu_settings_save_bit_depth_16 = uimenu(menu_settings_save_bit_depth,'Label','16-bit');
    handles.menu_settings_save_bit_depth = menu_settings_save_bit_depth;

    menu_settings_writeparameterfile = uimenu(menu_settings,'Label',['Write parameter .txt file: ' num2str(settings_writeparameterfile)]);
    handles.menu_settings_writeparameterfile = menu_settings_writeparameterfile;
    handles.menu_settings_writeparameterfile_true = uimenu(menu_settings_writeparameterfile,'Label','On');
    handles.menu_settings_writeparameterfile_false = uimenu(menu_settings_writeparameterfile,'Label','Off');

    %================================= reconstruction
    
    menu_reconstruction = uimenu(obj.window,'Label','Run reconstruction');        
    handles.menu_reconstruction_Go = uimenu(menu_reconstruction,'Label','Go');    
        
    %================================= visualization
    
    menu_visualization = uimenu(obj.window,'Label','Icy');
    menu_visualization_Icy_setup = uimenu(menu_visualization,'Label','Setup');        
    handles.menu_visualization_setup_Icy_directory = uimenu(menu_visualization_Icy_setup,'Label','Set Icy directory');    
    handles.menu_visualization_start_Icy = uimenu(menu_visualization_Icy_setup,'Label','Start Icy');
    %
    handles.menu_visualization_send_current_proj_to_Icy = uimenu(menu_visualization,'Label','Send current Projections','Separator','on');
    handles.menu_visualization_send_current_volm_to_Icy = uimenu(menu_visualization,'Label','Send current Volume');    
    
    %================================= help   
    
%     menu_help = uimenu(obj.window,'Label','Help');
%     handles.menu_help_about = uimenu(menu_help,'Label','About...');
%     handles.menu_help_tracker = uimenu(menu_help,'Label','Open Issue Tracker...');
%     handles.menu_help_bugs = uimenu(menu_help,'Label','File Bug Report...');

    %================================= indication    
    
    handles.proj_label = uimenu(obj.window,'Label','Proj','ForegroundColor','red');    
    handles.volm_label = uimenu(obj.window,'Label','Volume','ForegroundColor','red');    
    % handles.batch_label = uimenu(obj.window,'Label','batch','ForegroundColor','red');    
        

        %================================= Batch
    
    menu_Batch = uimenu(obj.window,'Label','Batch');

    menu_Batch_SetSrc = uimenu(menu_Batch,'Label','Set Source...');
    handles.menu_Batch_Src_HD = uimenu(menu_Batch_SetSrc,'Label','Folder');
%    handles.menu_Batch_Src_OMERO = uimenu(menu_Batch_SetSrc,'Label','OMERO Dataset');
    

    menu_Batch_SetSrc_slctd = uimenu(menu_Batch,'Label','Or, select individual...');
    handles.menu_Batch_Src_slctd_HD = uimenu(menu_Batch_SetSrc_slctd,'Label','Image files');
%    handles.menu_Batch_Src_slctd_OMERO = uimenu(menu_Batch_SetSrc_slctd,'Label','OMERO Images');

    handles.menu_Batch_Indicator_Src = uimenu(menu_Batch,'Label','...','ForegroundColor','red','Enable','off'); 

    handles.menu_Batch_SetDst = uimenu(menu_Batch,'Label','Set Destination folder','Separator','on');

    handles.menu_Batch_Indicator_Dst = uimenu(menu_Batch,'Label','...','ForegroundColor','red','Enable','off');  

    menu_Batch_save_format = uimenu(menu_Batch,'Label','Save format:','Separator','on');
    handles.menu_Batch_save_format_tiffstack = uimenu(menu_Batch_save_format,'Label','Individual .tiff files per slice');
    handles.menu_Batch_save_format_OMEtiff = uimenu(menu_Batch_save_format,'Label','Single OME.tiff per volm.');
    handles.menu_Batch_save_format_matlab = uimenu(menu_Batch_save_format,'Label','Single MATLAB file per volm.');
    handles.menu_Batch_save_format = menu_Batch_save_format;

    handles.menu_Batch_RunBatch = uimenu(menu_Batch,'Label','Start Batch processing now','Separator','on');
end


