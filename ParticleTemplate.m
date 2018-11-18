% Donn?es bathym?triques provenant de
% http://www.gebco.net/data_and_products/gridded_bathymetry_data/
% taille de la grille : 30s d'arc, soit un demi-mille marin (926 m) en
% longitude

%% Section 1
% Chargement et affichage des donn?es altim?triques
clear all;
Z=load('map.asc');
[I J]=size(Z);                      % Map dimensions
%figure(1);contour(Z,50);            % Level curves plotting
%set(gca,'Nextplot','replace');

%% section 2
% Initialisation des param?tres
N = 50;                % Number of time steps.
t = 1:1:N;              % Time.
v0=1;                   % initial speed along x1
% x = zeros(N,2);         % Hidden states.
% y = zeros(N,1);         % Observations.
x(1,1) = 30;            % Initial state.
x(1,2) = 170;           % Initial state.
Rreal = 10^2;           % Measurement noise real variance.
R=10^2;                 % Measurement noise used for estimation
Qreal = [0.1 0;0 10];   % Process noise real variance.
Q = Qreal;             % Process noise in y variance used for estimation
initVar = [100 0;0 100];    % Initial variance of the states.
numSamples=200;         % Number of Particles per time step.

%% Section 3
% Generation de la trajectoire et des mesures
for t=2:N
    x(t,:)=x(t-1,:)+[v0 0]+randn(1,2)*sqrt(Qreal); % trajectory (process) (time, position-> [x,y])
end
%filtrage de la trajectoire, pour "adoucissement"
alpha=0.01;
b=1-alpha;
a=[1 -alpha];
x=filter(b,a,x);    % removes noise from trajectory in y
%mesures
v = sqrt(Rreal)*randn(N,1); % measurement noise
for t=1:N
    y(t,1) = interp2(Z,x(t,1),x(t,2)) + v(t,1); % measurement (depth -> z)
end


%% section 4
% Particules initiales (prior)
xxu=zeros(N,2,numSamples);
xu=sqrt(initVar)*randn(2,numSamples);
q=ones(1,numSamples);
xu(1,:)=xu(1,:)+x(1,1);     % Creation of 100 realizations of a gaussian random var following N(x(t=1,1), initVar) --> X dimension
xu(2,:)=xu(2,:)+x(1,2);     % Creation of 100 realizations of a gaussian random var following N(x(t=1,2), initVar) --> Y dimension

% hx=line(x(:,1),x(:,2),'LineStyle','-','Marker','none','Color','black');%trac? de la trajectoire compl?te
% hxpos=line(0,0,'LineStyle','none',...
%     'Marker','o','MarkerSize',7,'MarkerEdgeColor','black','MarkerFaceColor','black');%trac? de la positioncourante
% hxu=line(0,0,'LineStyle','none','Marker','o');%trac? des particules
% hxell=line(0,0,'LineStyle','-','Marker','none');%trac? de l'ellipse


%% Section 5
% Update et prediction
% clf(1);
% clf(2);
clf(3);
clf(4);
clf(5);

Neff_hist = zeros(1,N-1);
EstX_hist = zeros(2,N-1);

for t=1:N-1
    %Predict
    %from the set of particles xu generate a new set xu
    xu=xu + [v0 0]' + sqrt(Q)*randn(2,numSamples);      % Random dispersion 
    
    %Importance wheights
    for k=1:numSamples  %k-th particle
        m(k)=interp2(Z,xu(1,k),xu(2,k));    %mesures predites pour chaque particules
    end
    %from the set of weights q compute the new set of weights q
    q=q.*exp(-1/(2*R)*(m-y(t,1).*ones(size(m))).^2)/sqrt(2*pi*R);
    [ii jj]=find(xu(1,:)>J | xu(1,:)<1 | xu(2,:)>I | xu(2,:)<1 );
    q(jj)=0; %Elimine les eventuelles particules "hors du cadre"
    q=q./sum(q);
    
    %Resampling
    Neff=1/sum(q.^2);
    Neff_hist(t) = Neff;
    if Neff<0.75*numSamples %|| isnan(Neff)
        %Resamplpling
        method='uniform';
        switch method
            case 'none'
                xur=xu;
                q=q;
            case 'uniform'
                [xur,q] = resample(xu,q);
            case 'multinomial'
                
        end
                xu=xur;
    end
    
    %Stockage dans xxu
    xxu(t,:,:)=xu;
    %mise a jour affichages
%     pause(0.001);
%     set(hxu,'Xdata',reshape(xu(1,:),1,numSamples),...
%         'Ydata',reshape(xu(2,:),1,numSamples));
%     %     set(hx,'Xdata',x(1:t,1),'Ydata',x(1:t,2));
%     set(hxpos,'Xdata',x(t,1),'Ydata',x(t,2));
    %Ellipsoid
    X0=mean(xu,2);
    EstX_hist(:,t) = X0;
    M=(xu-X0*ones(1,length(xu)))*(xu-X0*ones(1,length(xu)))'/length(xu);
    [U,S,V]=svd(M);
    a=0:0.1:2*pi;
    ell0=[sqrt(S(1,1))*cos(a);sqrt(S(2,2))*sin(a)];
    ell=X0*ones(1,length(a))+V'*ell0;
    %set(hxell,'Xdata',ell(1,:),'Ydata',ell(2,:),'LineWidth',2,'Color','r'); 
    
%     figure(2);
%     plot(1:numSamples, sort(q));
%     title("Particle weight in iteration "+t)
    
    sum(q);
end

figure(3)
plot(1:N-1,Neff_hist)
title("Effective number of particles through time")
xlabel("time [s]")
ylabel("Neff")

figure(4)
plot(1:N-1,EstX_hist(1,:),'color','r'); hold on;
plot(1:N,x(:,1),'color','b')
legend('estimation','trajectory')
title("Estimation in the X axis through time")
xlabel("time [s]")
ylabel("X")

figure(5)
plot(1:N-1,EstX_hist(2,:),'color','r'); hold on;
plot(1:N,x(:,2),'color','b')
legend('estimation','trajectory')
title("Estimation in the Y axis through time")
xlabel("time [s]")
ylabel("Y")

%% Section 6 - Average performance tests

M = 1;     % Number of algorithm iterations

diff_norms = zeros(M,2);     % Difference norm vector

for i=1:M
    disp("Ongoing iteration: "+i)
    clf(3);
    clf(4);
    clf(5);

    it_loop;
    
    post_treatment;
    
    diff_norms(i,1) = norm(EstX_hist(1,:)-x(:,1));  % X-axis difference
    diff_norms(i,2) = norm(EstX_hist(2,:)-x(:,2));  % Y-axis difference
end

diff_norms
mean_vec = mean(diff_norms,1);
disp("Mean of norm-2 X-axis differences = " + mean_vec(1,1))
disp("Mean of norm-2 Y-axis differences = " + mean_vec(1,2))