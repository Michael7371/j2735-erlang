#!/usr/bin/env escript

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



strip_regional(rsm, Rsm) ->
    setelement(4, Rsm, asn1_NOVALUE);
strip_regional('SupplementalVehicleExtensions', SVE) ->
    SVE1 = setelement(11, SVE, asn1_NOVALUE),
    VC = element(3, SVE),
    VCStripped = strip_regional('VehicleClassification', VC),
    SVE2 = setelement(3, SVE1, VCStripped),
    SVE2;
strip_regional('SpecialVehicleExtensions', SVE) ->
    ED = element(3, SVE),
    EDStripped = strip_regional('EventDescription', ED),
    setelement(3, SVE, EDStripped);
strip_regional('VehicleClassification', VC) when is_tuple(VC) ->
    setelement(10, VC, asn1_NOVALUE);
strip_regional('EventDescription', ED) when is_tuple(ED) ->
    setelement(7, ED, asn1_NOVALUE).



get_uper(rsm, Rsm) ->
    {ok, Uper} = 'RoadSafetyMessage':encode('RoadSafetyMessage', Rsm),
    Uper;
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