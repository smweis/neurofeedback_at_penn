function check_for_new_dicom()
    

    
    global iteration
    global acqTime
    global v1Signal
    global dataTimepoint

    
    path_to_watch = '/Users/iron/Documents/neurofeedback/TOME_3040/DICOMS/'; % FILL IN SCANNER PATH HERE
    initial_dir_length = length(dir(path_to_watch));

    i=0;
    while i<10000000
        i = i+1;
        new_dir_length = length(dir(path_to_watch));
        if new_dir_length > initial_dir_length
            tic % start timer
            
            dir_files = dir(path_to_watch);
            initial_dir_length = length(dir_files);
            
            
            nameStr = dir_files(end).name;
            pathStr = dir_files.folder;
            [acqTime(iteration),v1Signal(iteration),dataTimepoint(iteration)] = plot_at_scanner(nameStr,pathStr);


            plot(dataTimepoint(iteration),v1Signal(iteration),'r.','MarkerSize',20);    
            hold on;


            toc % end timer

            iteration = iteration + 1;
        
        end
        
            
        pause(0.01);
    end
end
