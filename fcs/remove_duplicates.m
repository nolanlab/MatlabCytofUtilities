function [v0,inds]=remove_duplicates(v)
%[v0,inds]=remove_duplicates(v) removes consecutively repeated entries in a
%vector, and gives the indices of the unique entries wrt the original
%vector

if size(v,2) ~= 1
    v=v';
end
if size(v,2) ~= 1
    error('v must be a vector')
end

[s,iv]=sort(v);
d=diff(s);

z=find(d==0);
z1=z+1;

unis=true(size(v));
unis(z)=false;
unis(z1)=false;
inds=iv(unis);
v0=v(inds);
