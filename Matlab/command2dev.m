function result = command2dev(commandString, varargin)
    BAUD_RATE = 115200;
    comPortName = varargin{end};
    dev = [];
    
    try
        cmd = '';
        expected_bytes = 6; 
        
        switch lower(commandString)
            case 'eucdist'
                cmd = 'E';
            case 'dotprod'
                cmd = 'D';
            otherwise
                error('Unknown command: "%s". Only eucDist and dotProd are supported.', commandString);
        end
        
        fprintf('Executing "%s" command on FPGA via %s...\n', commandString, comPortName);
        
        dev = serialport(comPortName, BAUD_RATE, "Timeout", 10);
        flush(dev);
        
        write(dev, uint8('C'), "uint8");
        write(dev, uint8(cmd), "uint8");
        
    
        raw = read(dev, expected_bytes, "uint8");
        
        if numel(raw) ~= expected_bytes
             error('Incomplete read: Expected %d bytes, got %d', expected_bytes, numel(raw));
        end

        
        raw_val = 0;
        for k = 1:6
            raw_val = raw_val + double(raw(k)) * 2^(8*(k-1));
        end
        

        if raw_val >= 2^47
            raw_val = raw_val - 2^48;
        end
        
  
        result = raw_val * 2^(-16);
        
        fprintf('Command "%s" complete. Received %d bytes. Value: %f\n\n', commandString, numel(raw), result);
        
    catch ME
        fprintf('\nERROR during command2dev operation: %s\n', ME.message);
        result = NaN; % Return NaN on failure
    finally
        if ~isempty(dev)
            clear dev;
        end
    end
end