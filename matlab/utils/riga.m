function riga(nome, misurato, teorico, unita)
%RIGA Stampa una riga "misurato vs teorico".
if nargin < 4, unita = ''; end
fprintf('  %-42s misurato = %10.3f %-5s teorico = %10.3f %s\n', nome, misurato, unita, teorico, unita);
end
