function write2dev(filePath, bramString, comPortName)
    
    BAUD_RATE = 115200;
    dev = []; 
    
    try
        fprintf('Reading vector data from "%s"...\n', filePath);
        vector = readmatrix(filePath);
        
        if strcmpi(bramString, 'BRAMA')
            bramSel = 'A';
        elseif strcmpi(bramString, 'BRAMB')
            bramSel = 'B';
        else
            error('Invalid BRAM specified. Use "BRAMA" or "BRAMB".');
        end
        
        fprintf('Connecting to %s to write Vector %c...\n', comPortName, bramSel);
        dev = serialport(comPortName, BAUD_RATE, "Timeout", 10);
        flush(dev);       
        
        write(dev, uint8('W'), "uint8");      
        write(dev, uint8(bramSel), "uint8");     
        
        data_to_send = zeros(2 * length(vector), 1, 'uint8');
        for k = 1:length(vector)
            val = uint16(vector(k));
            lo = bitand(val, 255); 
            hi = bitshift(val, -8); 
            data_to_send(2*k - 1) = lo;
            data_to_send(2*k)     = hi;
        end


        CHUNK_SIZE = 64;
        total_bytes = length(data_to_send);
        
        for i = 1:CHUNK_SIZE:total_bytes
            end_idx = min(i + CHUNK_SIZE - 1, total_bytes);
            chunk = data_to_send(i:end_idx);
            
            write(dev, chunk, "uint8");
            pause(0.005); 
        end
        
        fprintf('Vector %c sent successfully (%d elements).\n\n', bramSel, length(vector));
        
    catch ME
        fprintf('\nERROR during write2dev operation: %s\n', ME.message);
        if ~isempty(dev)
            clear dev;
        end
        rethrow(ME);
    finally
        if ~isempty(dev)
            clear dev;
        end
    end
end

% =========================================================================

