%% Summary Report for Recent Logging Events
% This report was automatically generated using the Datamaster project
%%

clear all

%%
% This Report was Generated using the following version of the Datamaster
% project
dr = DataReporter;
hash = {dr.dm.getEntry.OriginHash};

%% Database Integrity Report
% If you were involved with the creation of the following log files contact
% Alexius Wadell (alw224) ASAP to make the necessary corrections to the
% Logged Details.

dr.checkDetails(hash);
