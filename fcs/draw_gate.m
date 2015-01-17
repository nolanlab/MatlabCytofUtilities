function [ingate,x,y]=draw_gate(varargin)
% [ingate,x,y]=draw_gate(varargin) 
% Returns a boolean vector of whether the points in the plot are inside a
% polygon created by mouse-clicking on the plot. The user should left-click
% to create the vertices of the polygon, and can terminate the polygon
% either by right-clicking or pressing return. The points are assumed to be
% the first child added to the parent axes, which can optionally be
% specificied as an input argument.

if nargin==0
    ax=gca;
else
    ax=varargin{1};
end

[x,y]=getline(ax);

hold on
line([x; x(1)],[y; y(1)])
hold off

ch=get(ax,'children');

% if length(ch)>1
%     error('>1 axes children')
% end

ingate=inpolygon(get(ch(end),'XData'),get(ch(end),'YData'),x,y);

