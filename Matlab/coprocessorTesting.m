clear all; 

N_ELEMENTS=1024;  
BIT_WIDTH = 10;

COM_port = "COM4";

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


A=floor(rand(N_ELEMENTS,1)*2^BIT_WIDTH);
B=floor(rand(N_ELEMENTS,1)*2^BIT_WIDTH);

h= fopen('VectorA.txt', 'w');
fprintf(h, '%i\n', A);
fclose(h);

h= fopen('VectorB.txt', 'w');
fprintf(h, '%i\n', B);
fclose(h);

dot_host = sum(A .* B);
euc_host = sqrt(sum((A-B).^2));


write2dev('vectorA.txt','BRAMA',COM_port); 
write2dev('vectorB.txt','BRAMB',COM_port); 

euc_device = command2dev('eucDist', COM_port);
dot_device = command2dev('dotProd', COM_port);


euc_diff = euc_host - euc_device;
dot_diff = dot_host - dot_device;
