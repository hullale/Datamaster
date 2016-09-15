function [entry, index] = getEntry(dm,varargin)
    %Function to retrieve directory entries from Datamaster
    %StartDate/EndData must be either a datetime or string of the format
    %MM/dd/uuuu
    
    
    %Define avaiable Fieldnames on the MoTeC Detail Panel
    fieldNames =  {'Event','Venue','Length','Driver','VehicleID','VehicleNumber',...
        'VehicleDesc','EngineID','Session','StartLap','Short','Long'};
    
    %Create Persistent Input Parser to handle reading inputs
    persistent p
    if isempty(p)% || true
        p = inputParser;
        p.FunctionName = 'getEntry';
        addRequired(p,'obj',@(x) isa(x,'Datamaster'));
        addOptional(p,'Hash','',@(x) dm.validateHash(x));
        
        %Add a Parameter for Each fieldname
        for i = 1:length(fieldNames)
            addParameter(p,fieldNames{i},    [],     @(x) ischar(x) || iscell(x));
        end
        
        % Add Parameter to search by channel
        addParameter(p,'channel',   [],     @(x) ischar(x) || iscell(x));
        
        % Add a Parameter to a date range of intererst
        addParameter(p,'StartDate', [],     @(x) validateDate(x));
        addParameter(p,'EndDate',   [],     @(x) validateDate(x));
        
        % Add Parameters to control how many results are returned
        addParameter(p,'Return',    [],         @isfloat);
        addParameter(p,'Sort',      [],         @ischar);
    end
    
    %Parse Inputs and expand to vectors
    parse(p,dm,varargin{:});
    Hash = p.Results.Hash;
    channel = p.Results.channel;
    StartDate = p.Results.StartDate;
    EndDate = p.Results.EndDate;
    
    %Grab the Details List
    persistent Details
    if isempty(Details)
        Details = [dm.mDir.Details];
    end
    
    if nargin == 1
        index = true(1,dm.numEnteries);
    elseif ~strcmp(Hash,'')
        %Return Database enteries for that contain the supplied hash
        
        %Force Hash into a cell array
        if ~iscell(Hash)
            Hash = {Hash};
        end
        
        %Find Entry
        index = false(1,dm.numEnteries);
        for i = 1:length(Hash)
            cur_index = strcmp(Hash{i},{dm.mDir.OriginHash}) | strcmp(Hash{i},{dm.mDir.FinalHash});
            
            %Check if multiple entries matched -> May indicated duplication in
            %the directory
            if sum(cur_index) > 1
                warning('Expected only one entry match. Directory may contain duplicates');
            end
            
            %Combine with prior results
            if ~isempty(cur_index)
                index = cur_index | index;
            end
        end
    else %Search by Request
        
        %Match Index -> Assume Match Until Not a Match
        index = true(1,dm.numEnteries);
        
        %% Search in Field
        % Check if a search has been requested for each field
        for i = 1:length(fieldNames)
            if ~isempty(p.Results.(fieldNames{i}))
                % Search Field for Requested String
                index = index & FieldMatch(Details,index,fieldNames{i},p.Results.(fieldNames{i}));
            end
        end
        
        %% Search for Date Range
        
        %Convert to datetime if needed
        warning('off','MATLAB:datetime:AmbiguousDateString');
        if ischar(StartDate)
            StartDate = datetime(StartDate,'format','MM/dd/uu');
        end
        if ischar(EndDate)
            EndDate = datetime(EndDate,'format','MM/dd/uu');
        end
        warning('on','MATLAB:datetime:AmbiguousDateString');
        
        if ~isempty(StartDate) && ~isempty(EndDate)
            index = index & isbetween([Details.Datetime],StartDate,EndDate);
        elseif ~isempty(StartDate)
            index = index & ([Details.Datetime] >= StartDate);
        elseif ~isempty(EndDate)
            index = index & ([Details.Datetime] <= EndDate);
        end
        
        %% Search by Parameters
        if ~isempty(channel)
            Parameters = {dm.mDir.Parameters};
            
            %Force into cell array
            if ~iscell(channel)
                channel = {channel};
            end
            for i = 1:length(channel)
                index = index & cellfun(@(x) any(strcmpi(x,channel{i})),Parameters);
            end
        end
    end
    
    %% Sort Results
    %Check if anything is returned before sorting
    if ~isempty(p.Results.Sort) && ~isempty(index) && sum(index~=0)>0
        %% Sort the Results
        switch p.Results.Sort
            case 'newest'
                % Sort Newest to Oldest
                [~,sortIndex] = sort([Details.Datetime],'ascend');
            case 'oldest'
                %Sort Oldest to Newest
                [~,sortIndex] = sort([Details.Datetime],'descend');
            case 'rand'
                sortIndex = randperm(length(index));
            otherwise
                error('Unrecognized Sort Type');
        end
        
        %Convert Logical to Order Indexing
        index = sortIndex(index(sortIndex));
    end
    
    %% Limit Number of Results
    if ~isempty(p.Results.Return)
        %Only return the first n enteries
        index((p.Results.Return+1):end) = [];
    end
    
    %% Return Entry to User
    entry = dm.mDir(index);
end

function index = FieldMatch(Details,index,Field,Options)
    %Check to see if the option string is in the field
    
    %Force options into a cell
    if ~iscell(Options)
        Options = {Options};
    end
    
    %Regexp to Check
    regexpStr = ['(' strjoin(Options,'|') ')'];
    
    for i = find(index)
        %Search for Options in Field
        index(i) = any(regexpi(Details(i).(Field),regexpStr));
    end
end

function valid = validateDate(x)
    if isa(x,'datetime') && length(x)==1
        valid = true;
    elseif ischar(x)
        %Check if the correct dataformat is used
        valid = any(regexpi(x,'\d{1,2}/\d{1,2}/\d{4}'));
    else
        valid = false;
    end
end