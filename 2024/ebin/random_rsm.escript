#!/usr/bin/env escript

main(["generate"]) ->
    generate_test_messages();
main([MessageType, FilePath]) ->
    Message = random_message(list_to_atom(MessageType)),
    erlang:display(Message),
    file:write_file(FilePath ++ ".src", io_lib:format("~p.~n", [Message])),
    Uper = get_uper(list_to_atom(MessageType), Message),
    file:write_file(FilePath ++ ".bin", Uper),
    Hex = binary:encode_hex(Uper),
    file:write_file(FilePath ++ ".hex", Hex);
main([MessageType]) ->
    Message = random_message(list_to_atom(MessageType)),
    erlang:display(Message);
main(_) ->
    usage().

usage() ->
    io:format("usage:\n from bash shell:\n\n./random_rsm.escript rsm 'filepath'\n\n"),
    halt(1).

random_message(rsm) ->
    {ok, Rsm} = asn1ct:value('RoadSafetyMessage', 'RoadSafetyMessage'),
    RsmFixed = strip_regional(rsm, Rsm),
    RsmFixed;
random_message('VehicleSafetyExtensions') ->
    create_part2(0);
random_message('SpecialVehicleExtensions') ->
    create_part2(1);
random_message('SupplementalVehicleExtensions') ->
    create_part2(2);
random_message('ObstacleDetection') ->
    {ok, OD} = asn1ct:value('RoadSafetyMessage', 'ObstacleDetection'),
    % The 'description' field of ObstacleDetection is an ITIS code with
    % value constraint (523..541), should be encoded as 5 bits.
    % This constraint doesn't seem to be treated as PER
    % visible in the Erlang generated code, (it is encoded with 16 bits,
    % and the asn1c codec can't read it, so remove it.
    OD1 = setelement(4, OD, asn1_NOVALUE),
    OD1;
random_message('DisabledVehicle') ->
    % StatusDetails field of DisabledVehicle also is type ITIScodes(523..541),
    % has the same issue as ObstactleDetection
    {ok, DV} = asn1ct:value('RoadSafetyMessage', 'DisabledVehicle'),
    DV1 = setelement(2, DV, asn1_NOVALUE),
    DV1;
random_message(_) ->
    io:format("Unknown message type").

create_part2(0) ->
    {ok, VSE} = asn1ct:value('Common', 'VehicleSafetyExtensions'),
    VSE;
create_part2(1) ->
    {ok, SVE} = asn1ct:value('RoadSafetyMessage', 'SpecialVehicleExtensions'),
    strip_regional('SpecialVehicleExtensions', SVE);
create_part2(2) ->
    {ok, SVE} = asn1ct:value('RoadSafetyMessage', 'SupplementalVehicleExtensions'),
    SVE1 = strip_regional('SupplementalVehicleExtensions', SVE),
    % Fix ObstacleDetection (constrained ITIS codes issue)
    SVE2 = setelement(7, SVE1, random_message('ObstacleDetection')),
    % A non-optional field, StatusDetails, of DisabledVehicle also is type ITIScodes(523..541),
    % has the same issue as ObstactleDetection, so have to remove DisabledVehicle:
    SVE3 = setelement(8, SVE2, asn1_NOVALUE),
    SVE3.

% Strip regional extensions from all relevant structures
strip_regional(rsm, Rsm) ->
    try
        % Get the CommonContainer
        CommonContainer = element(2, Rsm),
        % Strip regional from EventInfo
        EventInfo = element(2, CommonContainer),
        EventInfoStripped = strip_regional(eventInfo, EventInfo),
        
        % Update CommonContainer with stripped EventInfo
        CommonContainerStripped = setelement(2, CommonContainer, EventInfoStripped),
        
        % Get RegionInfo list and ensure it's a list
        RegionInfoList = case element(3, CommonContainer) of
            List when is_list(List) -> List;
            _ -> []
        end,
        % Strip regional from each RegionInfo
        RegionInfoListStripped = [strip_regional(regionInfo, RI) || RI <- RegionInfoList],
        
        % Update CommonContainer with stripped RegionInfo list
        CommonContainerFinal = setelement(3, CommonContainerStripped, RegionInfoListStripped),
        
        % Strip CrossLinking if present
        CrossLinkingStripped = case element(4, CommonContainer) of
            {crossLinking, Audio, Visual, Events} ->
                {crossLinking, Audio, Visual, Events};
            CrossLinkOther when is_tuple(CrossLinkOther); CrossLinkOther =:= undefined ->
                CrossLinkOther;
            _ -> undefined
        end,
        CommonContainerWithCL = setelement(4, CommonContainerFinal, CrossLinkingStripped),
        
        % Get containers list and strip regional from each container
        ContainersStripped = case element(3, Rsm) of
            Containers when is_list(Containers) ->
                [strip_regional(container, C) || C <- Containers];
            ContainerOther when is_tuple(ContainerOther); ContainerOther =:= undefined ->
                ContainerOther;
            _ -> []
        end,
        
        % Update RSM with stripped CommonContainer and Containers
        RsmWithCommon = setelement(2, Rsm, CommonContainerWithCL),
        setelement(3, RsmWithCommon, ContainersStripped)
    catch
        _:_ ->
            % If any error occurs, return the original RSM
            Rsm
    end;

strip_regional(container, {Type, Container}) ->
    ContainerStripped = case Type of
        rszContainer -> 
            strip_regional(rszContainer, Container);
        curveContainer -> 
            strip_regional(curveContainer, Container);
        situationalContainer -> 
            strip_regional(situationalContainer, Container);
        _ -> 
            Container
    end,
    {Type, ContainerStripped};

strip_regional(rszContainer, Container) ->
    % Handle RSZ container
    RegionInfo = element(2, Container),
    RegionInfoStripped = strip_regional(regionInfo, RegionInfo),
    setelement(2, Container, RegionInfoStripped);

strip_regional(curveContainer, Container) ->
    % Handle Curve container
    RegionInfo = element(5, Container),
    RegionInfoStripped = strip_regional(regionInfo, RegionInfo),
    setelement(5, Container, RegionInfoStripped);

strip_regional(situationalContainer, Container) ->
    % Handle Situational container - has Position3D in Obstructions and RegionInfo
    {obstructions, Pos3D} = element(2, Container),
    Pos3DStripped = strip_regional(position3D, Pos3D),
    ContainerWithPos3D = setelement(2, Container, {obstructions, Pos3DStripped}),
    
    RegionInfo = element(5, ContainerWithPos3D),
    RegionInfoStripped = strip_regional(regionInfo, RegionInfo),
    setelement(5, ContainerWithPos3D, RegionInfoStripped);

strip_regional(eventInfo, EventInfo) ->
    case EventInfo of
        {eventInfo, EventId, Priority, Heading, StartTime, StopTime, Recurrences, 
         EventFlags, Description, TypeEvent, _Regional} ->
            {eventInfo, EventId, Priority, Heading, StartTime, StopTime, Recurrences, 
             EventFlags, Description, TypeEvent, []};
        {eventInfo, _EventId, _Priority, _Heading, _StartTime, _StopTime, _Recurrences, 
         _EventFlags, _Description, _TypeEvent} = OriginalEventInfo ->
            OriginalEventInfo;
        _ ->
            EventInfo
    end;

strip_regional(regionInfo, RegionInfo) ->
    case RegionInfo of
        {regionInfo, Pos3D, Type, Value, Desc, Priority, {paths, Paths}} ->
            % Strip regional from Position3D and paths
            Pos3DStripped = strip_regional(position3D, Pos3D),
            PathsStripped = [strip_regional(path, P) || P <- Paths],
            {regionInfo, Pos3DStripped, Type, Value, Desc, Priority, {paths, PathsStripped}};
        {regionInfo, Pos3D, Type, Value, Desc, Priority, {broadRegion, BroadRegion}} ->
            % Strip regional from Position3D and broadRegion
            Pos3DStripped = strip_regional(position3D, Pos3D),
            BroadRegionStripped = strip_regional(broadRegion, BroadRegion),
            {regionInfo, Pos3DStripped, Type, Value, Desc, Priority, {broadRegion, BroadRegionStripped}};
        {regionInfo, Pos3D, Type, Value, Desc, Priority, Other} ->
            % Strip regional from Position3D
            Pos3DStripped = strip_regional(position3D, Pos3D),
            {regionInfo, Pos3DStripped, Type, Value, Desc, Priority, Other};
        _ ->
            RegionInfo
    end;

strip_regional(broadRegion, BroadRegion) ->
    case BroadRegion of
        {broadRegion, ApplicableHeading, {circle, Circle}} ->
            CircleStripped = strip_regional(circle, Circle),
            {broadRegion, ApplicableHeading, {circle, CircleStripped}};
        {broadRegion, ApplicableHeading, {polygon, Nodes}} ->
            NodesStripped = [strip_regional(node, N) || N <- Nodes],
            {broadRegion, ApplicableHeading, {polygon, NodesStripped}};
        _ ->
            BroadRegion
    end;

strip_regional(path, Path) ->
    case Path of
        {path, ID, Nodes} ->
            NodesStripped = [strip_regional(node, N) || N <- Nodes],
            {path, ID, NodesStripped};
        _ ->
            Path
    end;

strip_regional(node, Node) ->
    case Node of
        {'node-3Dabsolute', Pos3D} ->
            {'node-3Dabsolute', strip_regional(position3D, Pos3D)};
        {'node-3Doffset', Offset3D} ->
            {'node-3Doffset', Offset3D};
        _ ->
            Node
    end;

strip_regional(circle, Circle) ->
    case Circle of
        {circle, Pos3D, Radius, Units} ->
            {circle, strip_regional(position3D, Pos3D), Radius, Units};
        _ ->
            Circle
    end;

strip_regional(position3D, Pos3D) ->
    try
        case Pos3D of
            {position3D, Lat, Long, Elev, _Regional} when is_number(Lat), 
                                                         is_number(Long), 
                                                         is_number(Elev) ->
                {position3D, Lat, Long, Elev, []};
            {position3D, Lat, Long, Elev} when is_number(Lat),
                                             is_number(Long),
                                             is_number(Elev) ->
                Pos3D;
            _ when is_tuple(Pos3D) ->
                case tuple_size(Pos3D) > 0 of
                    true -> setelement(tuple_size(Pos3D), Pos3D, []);
                    false -> Pos3D
                end;
            _ ->
                Pos3D
        end
    catch
        _:_ ->
            Pos3D
    end;

strip_regional(_, Data) ->
    Data.

% Move deep_strip_regional function before any get_uper definitions
deep_strip_regional(Data) when is_tuple(Data) ->
    case Data of
        {position3D, Lat, Long, Elev, _Regional} when is_number(Lat), 
                                                     is_number(Long), 
                                                     is_number(Elev) ->
            {position3D, Lat, Long, Elev, asn1_NOVALUE};
        {'RegionalExtension', _, _} ->
            asn1_NOVALUE;
        {regionalExtension, _, _} ->
            asn1_NOVALUE;
        {'EventInfo', Id, Priority, Heading, StartTime, StopTime, Recurrences,
         EventFlags, Description, TypeEvent, _Regional} ->
            {'EventInfo', Id, Priority, Heading, StartTime, StopTime, Recurrences,
             EventFlags, Description, TypeEvent, asn1_NOVALUE};
        {Type, _Content} when Type =:= 'RegionalExtension'; 
                             Type =:= regionalExtension ->
            asn1_NOVALUE;
        Tuple ->
            list_to_tuple([deep_strip_regional(Element) || Element <- tuple_to_list(Tuple)])
    end;
deep_strip_regional(Data) when is_list(Data) ->
    case Data of
        [{regionalExtension, _, _} | _] -> asn1_NOVALUE;
        [{'RegionalExtension', _, _} | _] -> asn1_NOVALUE;
        _ -> [deep_strip_regional(Element) || Element <- Data]
    end;
deep_strip_regional(Data) ->
    Data.

% Keep all get_uper functions together
get_uper(rsm, Rsm) ->
    try
        SafeRsm = deep_strip_regional(Rsm),
        case 'RoadSafetyMessage':encode('RoadSafetyMessage', SafeRsm) of
            {ok, Uper} -> Uper;
            Error -> 
                io:format("Encoding error: ~p~n", [Error]),
                throw(encoding_failed)
        end
    catch
        E:R:S -> 
            io:format("Error encoding RSM: ~p:~p~nStacktrace: ~p~n", [E, R, S]),
            throw(encoding_failed)
    end;
get_uper('VehicleSafetyExtensions', VSE) ->
    {ok, Uper} = 'Common':encode('VehicleSafetyExtensions', VSE),
    Uper;
get_uper('SupplementalVehicleExtensions', SVE) ->
    {ok, Uper} = 'RoadSafetyMessage':encode('SupplementalVehicleExtensions', SVE),
    Uper;
get_uper('ObstacleDetection', OD) ->
    {ok, Uper} = 'RoadSafetyMessage':encode('ObstacleDetection', OD),
    Uper;
get_uper('DisabledVehicle', DV) ->
    {ok, Uper} = 'RoadSafetyMessage':encode('DisabledVehicle', DV),
    Uper;
get_uper(_, _) ->
    io:format("get_uper: Unknown message type").

% get_jer(rsm, Rsm) ->
%     {ok, Jer} = 'RoadSafetyMessage':jer_encode('RoadSafetyMessage', Rsm),
%     Jer;
% get_jer(_, _) ->
%     io:format("get_jer: Unknown message type").

% Helper function to generate multiple test messages
generate_test_messages() ->
    [begin
        Filename = "rsm_" ++ integer_to_list(N),
        main(["rsm", Filename])
     end || N <- lists:seq(1, 5)].