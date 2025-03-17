#!/usr/bin/env escript

main([Module, MessageType, FilePath]) ->
    Message = random_message(list_to_atom(Module), list_to_atom(MessageType)),
    erlang:display(Message);
    % file:write_file(FilePath ++ ".src", io_lib:format("~p.~n", [Message])),
    % Uper = get_uper(list_to_atom(Module), list_to_atom(MessageType), Message),
    % erlang:display(Uper),
    % file:write_file(FilePath ++ ".bin", Uper),
    % Hex = binary:encode_hex(Uper),
    % file:write_file(FilePath ++ ".hex", Hex),
    % erlang:display(Hex);
main([Module, MessageType]) ->
    Message = random_message(list_to_atom(Module), list_to_atom(MessageType)),
    erlang:display(Message);
main(_) ->
    usage().


usage() ->
    io:format("usage:\n from bash shell:\n\n./random_map.escript MapData MapData 'filepath'\n\n"),
    halt(1).

fix_element(Index, Tuple, Type)  when is_number(Index) and is_tuple(Tuple) and is_atom(Type) ->
    setelement(Index, Tuple, fix(Type, element(Index, Tuple)));
fix_element(Index, Tuple, Type) ->
    io:format("fix_element: wrong types ~s, ~s, ~s~n", [Index, Tuple, Type]).

random_fixed(Module, Type) ->
    {ok, Message} = asn1ct:value(Module, Type),
    fix(Type, Message).

random_message(Module, Type) ->
    random_fixed(Module, Type).
    

strip_regional(map, Map) ->
    setelement(10, Map, asn1_NOVALUE);
strip_regional('IntersectionGeometry', IG) ->
    setelement(10, IG, asn1_NOVALUE);
strip_regional('Position3D', P) ->
    setelement(5, P, asn1_NOVALUE);
strip_regional('GenericLane', L) ->
    setelement(11, L, asn1_NOVALUE);
strip_regional('LaneAttributes', L) ->
    setelement(5, L, asn1_NOVALUE);
strip_regional('ComputedLane', CL) ->
    setelement(8, CL, asn1_NOVALUE);
strip_regional('NodeSetXY', NS) ->
    [N || N <- NS, element(1, element(2, N)) =/= regional];
strip_regional('RoadSegment', RS) ->
    setelement(9, RS, asn1_NOVALUE);
strip_regional(Unk, _) ->
    io:format("strip_regional: Unknown message type ~s~n", [Unk]).



% fix/2
fix('MapData', Map) ->
    Map1 = strip_regional(map, Map),
    Map2 = fix_element(6, Map1, 'IntersectionGeometryList'),
    Map3 = fix_element(7, Map2, 'RoadSegmentList'),
    Map5 = fix_element(9, Map3, 'RestrictionClassList'),
    Map5;
fix('LaneList', LL) ->
    [fix('GenericLane', L) || L <- LL];
fix('RoadLaneSetList', LL) ->
    [fix('GenericLane', L) || L <- LL];
fix('GenericLane', L) ->
    % Strip regional
    L0 = strip_regional('GenericLane', L),
    % Fix laneAttriutes
    L1 = fix_element(6, L0, 'LaneAttributes'),
    % Fix nodeList
    L2 = fix_element(8, L1, 'NodeListXY'),
    L2;
fix('LaneAttributes', L) ->
    strip_regional('LaneAttributes', L);
fix('IntersectionGeometryList', IGL) ->
    [fix('IntersectionGeometry', I) || I <- IGL];
fix('IntersectionGeometry',IG) ->
    % Remove regional
    IG1 = strip_regional('IntersectionGeometry', IG),
    % Fix Position3D
    IG2 = fix_element(5, IG1, 'Position3D'),
    % Fix laneSet
    IG4 = fix_element(8, IG2, 'LaneList'),
    % Remove preemptPriorityData/SignalControlZone -- only includes regional
    setelement(9, IG4, asn1_NOVALUE);
fix('ComputedLane', CL) ->
    strip_regional('ComputedLane', CL);
fix('NodeListXY', NL) ->
    fix('NodeListXY', element(1, NL), NL);
fix('NodeSetXY', NS) ->
    % Strip attributes
    NS2 = fix_attributes('NodeSetXY', NS),
    % Remove regional nodes
    NS3 = strip_regional('NodeSetXY', NS2),
    % At least 2 nodes are required. Add nodes if less.
    NS4 = ensure_2_nodes(NS3),
    NS4;
fix('Position3D', P) ->
    strip_regional('Position3D', P);
fix('RoadSegmentList', RSL) ->
    [ fix('RoadSegment', RS) || RS <- RSL];
fix('RoadSegment', RS) ->
    RS1 = strip_regional('RoadSegment', RS),
    % Fix refPoint
    RS2 = fix_element(5, RS1, 'Position3D'),
    % Fix roadLaneSet
    RS3 = fix_element(8, RS2, 'RoadLaneSetList'),
    RS3;
fix('RestrictionUserTypeList', RL) ->
    [ fix('RestrictionUserType', R) || R <- RL];
fix('RestrictionUserType', R) ->
    case element(1, R) of
        % Regenerate until regional is replaced
        regional -> random_message('MapData', 'RestrictionUserType');
        _ -> R
    end;
fix('RestrictionClassList', RCL) ->
    [ fix('RestrictionClassAssignment', R) || R <- RCL];
fix('RestrictionClassAssignment', RCA) ->
    fix_element(3, RCA, 'RestrictionUserTypeList');
fix(_, Unk) ->
    Unk.

strip_attributes('NodeSetXY', NS) ->
    [setelement(3, NS1, asn1_NOVALUE) || NS1 <- NS].

fix_attributes('NodeSetXY', NS) ->
    [fix_node_attributes(N) || N <- NS].

fix_node_attributes(Node) ->
    case element(3, Node) of
        asn1_NOVALUE -> Node;
        {'NodeAttributeSetXY', LocalNodes, Enabled, Disabled, Data, Dwidth, DElevation, _Regionals} ->
            % Filter out any regional attributes from Data list
            CleanData = lists:filter(
                fun(D) -> 
                    case D of
                        {regional, _} -> false;
                        {'RegionalExtension', _, _} -> false;
                        _ -> true
                    end
                end, 
                Data),
            % Keep all fields but clean up Data and set Regionals to asn1_NOVALUE
            NewAttrs = {'NodeAttributeSetXY', 
                       LocalNodes, 
                       Enabled, 
                       Disabled, 
                       CleanData, 
                       Dwidth, 
                       DElevation, 
                       asn1_NOVALUE},
            setelement(3, Node, NewAttrs);
        Other ->
            % For any other unexpected format, strip it entirely
            setelement(3, Node, asn1_NOVALUE)
    end.

ensure_2_nodes(NS) when length(NS) < 2 ->
    AddNode = [ random_message('Common', 'NodeXY') | NS],
    Stripped = fix_attributes('NodeSetXY', strip_regional('NodeSetXY', AddNode)),
    ensure_2_nodes(Stripped);
ensure_2_nodes(NS) when length(NS) >= 2 ->
    NS.


% fix/3
fix('NodeListXY', nodes, NL) ->
    setelement(2, NL, fix('NodeSetXY', element(2, NL)));
fix('NodeListXY', computed, NL) -> setelement(2, NL, fix('ComputedLane', element(2, NL)));
fix(_,_,_) ->
    io:format("fix/3 no match").

get_uper(Module, Type, Term) ->
    {ok, Uper} = Module:encode(Type, Term),
    Uper.




