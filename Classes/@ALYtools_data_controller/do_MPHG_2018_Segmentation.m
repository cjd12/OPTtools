            function sgm = do_MPHG_2018_Segmentation(obj,send_to_Icy,~) 

            sgm = [];
                                   
            u_nuc = sum(double(obj.imgdata(:,:,:,obj.MPHG_chNuc,1)),3); 
            u_cell = sum(double(obj.imgdata(:,:,:,obj.MPHG_chCell,1)),3); 
            u_gran = sum(double(obj.imgdata(:,:,:,obj.MPHG_chGran,1)),3); 
             
            % segment nukes        
                % HARDCODED SETUPS
                nuc_scale = fix(obj.u2pix(16));
                nuc_threshold = 0.1;
                nuc_smoothing = fix(obj.u2pix(3));
                nuc_min_area = fix(obj.u22pix2(144));
                nuc_rel_bg_scale = 2.5;            
                minimal_gran_size = fix(obj.u2pix(0.5));
                % HARDCODED SETUPS
            
            sgm_nukes = nth_segmentation(u_nuc, ...
                nuc_scale, ...
                nuc_rel_bg_scale, ...
                nuc_threshold, ...
                nuc_smoothing, ...
                nuc_min_area);            
            sgm_nukes(sgm_nukes~=0)=1;               
            
            sgm_nukes = imfill(sgm_nukes,'holes');              
            sgm_nukes = imclearborder(sgm_nukes);
            
            if 0==sum(sgm_nukes), return, end
                       
            % break nuclear clumps
            nuc_breacking_distmap_smoothing_scale = nuc_smoothing;            
            z2 = bwlabel(sgm_nukes);
            D = bwdist(~z2); %distance map                
               D = medfilt2(D,[nuc_breacking_distmap_smoothing_scale nuc_breacking_distmap_smoothing_scale]);
            D = -D;
            D(~z2) = -Inf;                                        
            L = watershed(D);                                                                                
            % remove background    
            stats = regionprops(L,'Area');    
            bckgind = find([stats.Area]==max([stats.Area]));
            L(L==bckgind) = 0;
            sgm_nukes = (L>0);
            sgm_nukes = bwareaopen(sgm_nukes,nuc_min_area);
            % segment nukes
                                        
            %%%%%%%%%%%%%%%%%% CELLS
            %
            % important parameter - controls width of "collar"
            % FAC = 1.5;
            FAC = 1;
            %
            dist_from_nuc = fix(nuc_scale*FAC); 
            z2 = imdilate(sgm_nukes,strel('disk',dist_from_nuc,0));
            sgm_cells = z2; 
            
            % break cell clumps
            z2 = bwmorph(sgm_nukes,'thicken',Inf);
            sep_lines = ~z2;
            sep_lines(~sgm_cells)=0;
            sgm_cells(sep_lines)=0;
            
            % remove orphan pieces of cellular stuff..
            L_n = bwlabel(sgm_nukes);
            stats_n = regionprops(L_n,'Area','Centroid');    
            L_c = bwlabel(sgm_cells);                                    
            %
            for n = 1:numel(stats_n)
                xcn = fix(stats_n(n).Centroid(2));
                ycn = fix(stats_n(n).Centroid(1));
                cell_label = L_c(xcn,ycn);
                L_c(L_c==cell_label)=0;
            end            
            sgm_cells(L_c~=0)=0;          
            
            %
            sgm_cells = imclearborder(sgm_cells);
            sgm_nukes = sgm_nukes & sgm_cells;
            
            if 0==sum(sgm_cells), return, end
            %
            
            % backup PR setups                                    
            obj_PR_K = obj.PR_K;
            obj_PR_S1 = obj.PR_S1;
            obj_PR_S2 = obj.PR_S2;
            obj_PR_a = obj.PR_a;
            obj_PR_t = obj.PR_t;
            obj_PR_mode = obj.PR_mode;
            obj_PR_min_size = obj.PR_min_size;
            obj_PR_ref_channel = obj.PR_ref_channel;
            % set up PR params
            obj.PR_K = 2.5;
            obj.PR_S1 = 2*sqrt(minimal_gran_size);
            obj.PR_S2 = 10*sqrt(minimal_gran_size);
            obj.PR_a = 0.5;
            obj.PR_t = 0.001;
            obj.PR_mode = 'Peak';
            obj.PR_min_size = minimal_gran_size;
            obj.PR_ref_channel = obj.MPHG_chGran;            
            % apply PR segmentation   
            sgm_gran = obj.do_PR_Segmentation(false);
            % restore PR setups
            obj.PR_K = obj_PR_K;
            obj.PR_S1 = obj_PR_S1;
            obj.PR_S2 = obj_PR_S2;
            obj.PR_a = obj_PR_a;
            obj.PR_t = obj_PR_t;
            obj.PR_mode = obj_PR_mode;
            obj.PR_min_size = obj_PR_min_size;
            obj.PR_ref_channel = obj_PR_ref_channel;
                        
            sgm_gran = sgm_gran & sgm_cells; % &~ sgm_nukes;                                               
            % segment pathogen stuff                 
                                                                    
            sgm = cat(3,u_cell,u_gran,u_nuc,sgm_cells,double(sgm_gran),sgm_nukes);
            
                if send_to_Icy                
                    try
                        icyvol(:,:,1,1,1) = u_cell;
                        icyvol(:,:,2,1,1) = u_gran;
                        icyvol(:,:,3,1,1) = u_nuc;                        
                        icyvol(:,:,4,1,1) = sgm_cells;
                        icyvol(:,:,5,1,1) = sgm_nukes;
                        icyvol(:,:,6,1,1) = double(sgm_gran);
                        %
                        notification = [obj.current_filename ' - Segmentation: MPHG'];
                        if isempty(obj.h_Icy_segmentation_adjustment)
                            obj.h_Icy_segmentation_adjustment = icy_imshow(icyvol,notification);
                        else
                            icy_imshow(obj.h_Icy_segmentation_adjustment,icyvol,notification);
                        end
                    catch
                        errordlg('problem with Icy, - might be not running');
                    end                
                end                                                                                                  
        end                

