# Erlang codecs for J2735 

The Erlang ASN.1 compiler was used to compile UPER and JER codecs for the J2735 specifications for 2016, 2020 and 2024.

The ASN.1 files were downloaded from SAE.

The following adjustments to the ASN.1 files were made to accomodate the Erlang compiler's requirements and quirks:

* The modules had to be organized so that each file contains only one module, with the file name identical to the module name.  For example in the 2016 spec, the `DSRC` module was placed in a file named `DSRC.asn`, and in the 2024 spec, the `MapData` module's file name was changed to `MapData.asn`.

* The 2024 specification contains the "WITH SUCCESSORS" syntax in IMPORT statements.  
The compiler didn't recognize this syntax, so it had to be removed everywhere it appears, and then the 2024 spec compiled just fine.

Compilation was done using the 'erlang:27' Dockerhub image in a dev container.

Erlang escripts to compile the ASN.1 for each year are here:

* [2016/compile_asn1.escript](2016/compile_asn1.escript)
* [2020/compile_asn1.escript](2020/compile_asn1.escript)
* [2024/compile_asn1.escript](2024/compile_asn1.escript)

The generated Erlang source code and .beam bytecode are in the `ebin` directories under each year.  To test with the Erlang command line, connect to the dev container using vscode or CLion, cd into one of the ebin directories, and start the Erlang shell:

```bash
cd 2024/ebin
erl
```

## Example: Decode an UPER SPAT Message Frame to an Erlang term

Read the UPER/hex from a file:
```erlang
{ok, SpatHex} = file:read_file("../examples/spat.hex").
```

Decode hex to binary:
```erlang
SpatBin = binary:decode_hex(SpatHex).
```

Decode the UPER binary to an Erlang term:
```erlang
{ok, Spat} = 'MessageFrame':decode('MessageFrame', SpatBin).
```

Returns the Erlang term:
```erlang
{ok,{'MessageFrame',19,
                    {'SPAT',asn1_NOVALUE,asn1_NOVALUE,
                            [{'IntersectionState',asn1_NOVALUE,
                                                  {'IntersectionReferenceID',asn1_NOVALUE,12111},
                                                  0,[],asn1_NOVALUE,35176,asn1_NOVALUE,
                                                  [{'MovementState',asn1_NOVALUE,2,
                                                                    [{'MovementEvent','protected-Movement-Allowed',
                                                                                      {'TimeChangeDetails',...},
                                                                                      asn1_NOVALUE,...}],
                                                                    asn1_NOVALUE,asn1_NOVALUE},
                                                   {'MovementState',asn1_NOVALUE,4,
                                                                    [{'MovementEvent','stop-And-Remain',{...},...}],
                                                                    asn1_NOVALUE,asn1_NOVALUE},
                                                   {'MovementState',asn1_NOVALUE,6,
                                                                    [{'MovementEvent','protected-Movement-Allowed',...}],
                                                                    asn1_NOVALUE,asn1_NOVALUE},
                                                   {'MovementState',asn1_NOVALUE,8,
                                                                    [{'MovementEvent',...}],
                                                                    asn1_NOVALUE,asn1_NOVALUE},
                                                   {'MovementState',asn1_NOVALUE,1,[{...}],asn1_NOVALUE,...},
                                                   {'MovementState',asn1_NOVALUE,5,[...],...}],
                                                  asn1_NOVALUE,asn1_NOVALUE,asn1_NOVALUE}],
                            asn1_NOVALUE}}}
```

Save the Erlang term to a file:
```erlang
file:write_file("../examples/spat.src", io_lib:format("~p.~n", [Spat])).
```

## Example: Encode an Erlang term for a Road Safety Message as UPER

Load the Erlang term and encode as UPER:
```erlang
{ok, [Rsm]} = file:consult("../examples/rsm.src").
{ok, RsmUper} = 'MessageFrame':encode('MessageFrame', Rsm).
```

returns:
```erlang
{ok,<<0,33,130,183,47,0,135,129,144,169,41,232,106,136,
      177,191,213,25,49,221,94,56,38,191,251,139,52,...>>}
```

Encode as hex:
```erlang
RsmHex = binary:encode_hex(RsmUper).
```
returns:
```erlang
<<"002182B72F00878190A929E86A88B1BFD51931DD5E3826BFFB8B343AFB6741300FE5C32BA3BBDE67193178F6B7A4C55D7F92AC0F0491F9F41C7F"...>>
```
then save the hex:
```erlang
file:write_file("../examples/rsm_saved.hex", RsmHex).
```

## JER Test
The encode/decode functionality for UPER works well and seems to be very solid.  

On the other hand, the JER codecs appear to be in a more preliminary state. The JER encoding seems to have issues with information object classes and/or open types.  

For example trying to encode a MessageFrame to JER returns an error:

```erlang
'MessageFrame':jer_encode('MessageFrame', Spat).
```

But extracting the payload from the message frame and encoding that works:  

```erlang
{'MessageFrame', 19, SpatPayload} = Spat.
{ok, SpatJer} = 'SPAT':jer_encode('SPAT', SpatPayload).
file:write_file("../examples/spat.json", SpatJer).
```

Output:


`{"intersections":[{"id":{"id":12111},"revision":0,"status":"0000","timeStamp":35176,"states":[{"signalGroup":2,"state-time-speed":[{"eventState":"protected-Movement-Allowed","timing":{"minEndTime":22120,"maxEndTime":22121}}]},{"signalGroup":4,"state-time-speed":[{"eventState":"stop-And-Remain","timing":{"minEndTime":22181,"maxEndTime":22181}}]},{"signalGroup":6,"state-time-speed":[{"eventState":"protected-Movement-Allowed","timing":{"minEndTime":22120,"maxEndTime":22121}}]},{"signalGroup":8,"state-time-speed":[{"eventState":"stop-And-Remain","timing":{"minEndTime":21852,"maxEndTime":21852}}]},{"signalGroup":1,"state-time-speed":[{"eventState":"stop-And-Remain","timing":{"minEndTime":21852,"maxEndTime":21852}}]},{"signalGroup":5,"state-time-speed":[{"eventState":"stop-And-Remain","timing":{"minEndTime":21852,"maxEndTime":21852}}]}]}]}`





Regex to match all RegionalExtensions:

asn1_NOVALUE

```
\[\s*(\{\s*'RegionalExtension'[\s\S\n]*?\}\s*)+\]
\s*(\{\s*'LaneAttributes_regional'[\s\S\n]*?\}\s*)
\s*(\{\s*'NodeOffsetPointXY_regional'[\s\S\n]*?\}\s*)
\s*(\{\s*'SignalControlZone_zone'[\s\S\n]*?\}\s*)

```


MAP:
```erlang
{ok, MapNodeAttribute} = asn1ct:value('Common', 'NodeAttributeSetXY').

{ok, [MapNodeAttributeSetReload]} = file:consult("../examples/NodeAttributeSetXY.src").
{ok, MapNodeAttributeSetUper} = 'Common':encode('NodeAttributeSetXY', MapNodeAttributeSetReload).


{ok, MapNodeAttribute} = asn1ct:value('Common', 'NodeXY').
file:write_file("../examples/NodeXY.src", io_lib:format("~p.~n", [MapNodeAttribute])).

{ok, [MapNodeXYReload]} = file:consult("../examples/NodeXY.src").
{ok, MapNodeXYUper} = 'Common':encode('NodeXY', MapNodeXYReload).


{ok, MapNodeAttribute} = asn1ct:value('MapData', 'GenericLane').
file:write_file("../examples/generic_lane.src", io_lib:format("~p.~n", [MapNodeAttribute])).

{ok, [GenericLaneReload]} = file:consult("../examples/generic_lane.src").
{ok, GenericLaneUper} = 'MapData':encode('GenericLane', GenericLaneReload).


{ok, MapData} = asn1ct:value('MapData', 'MapData').
file:write_file("../examples/map_manual.src", io_lib:format("~p.~n", [MapData])).

{ok, [MapReload]} = file:consult("../examples/map_manual.src").
{ok, MapUper} = 'MapData':encode('MapData', MapReload).
```
