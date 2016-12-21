-module(kz_csv_tests).
-include_lib("eunit/include/eunit.hrl").

-ifndef(ZILCH).
-define(ZILCH, 'undefined').
-endif.

associator_test() ->
    OrderedFields = [<<"A">>, <<"B">>, <<"C">>, <<"D">>, <<"E">>],
    CSVHeader = [<<"A">>, <<"E">>, <<"C">>, <<"B">>],
    CSVRow    = [<<"1">>, <<"5">>, <<"3">>, <<"2">>],
    Verify = fun (_Cell) -> 'true' end,
    Verifier = fun (_Field, Cell) -> Verify(Cell) end,
    FAssoc = kz_csv:associator(CSVHeader, OrderedFields, Verifier),
    ?assertEqual({'true', [<<"1">>, <<"2">>, <<"3">>, 'undefined', <<"5">>]}, FAssoc(CSVRow)).

associator_verify_test() ->
    OrderedFields = [<<"A">>, <<"B">>, <<"C">>, <<"D">>, <<"E">>],
    CSVHeader = [<<"A">>, <<"E">>, <<"C">>, <<"B">>],
    CSVRow    = [<<"1">>, <<"5">>, <<"3">>, <<"2">>],
    Verify = fun (_Cell) -> 'false' end,
    Verifier = fun (<<"B">>, Cell) -> Verify(Cell); (_Field, _Cell) -> 'true' end,
    FAssoc = kz_csv:associator(CSVHeader, OrderedFields, Verifier),
    ?assertEqual('false', FAssoc(CSVRow)).

take_row_test_() ->
    CSV1 = <<"a\r\nb\nc\nd\n\re\r\r">>,
    CSV2 = <<"b\nc\nd\n\re\r\r">>,
    CSV3 = <<"c\nd\n\re\r\r">>,
    CSV4 = <<"d\n\re\r\r">>,
    CSV5 = <<"e\r\r">>,
    CSV6 = <<>>,
    CSV7 = <<"\r\r">>,
    [?_assertEqual({[<<"a">>], CSV2}, kz_csv:take_row(CSV1))
    ,?_assertEqual({[<<"b">>], CSV3}, kz_csv:take_row(CSV2))
    ,?_assertEqual({[<<"c">>], CSV4}, kz_csv:take_row(CSV3))
    ,?_assertEqual({[<<"d">>], CSV5}, kz_csv:take_row(CSV4))
    ,?_assertEqual({[<<"e">>], CSV6}, kz_csv:take_row(CSV5))
    ,?_assertEqual('eof', kz_csv:take_row(CSV6))
    ,?_assertEqual('eof', kz_csv:take_row(CSV7))
    ,?_assertEqual({[<<"1">>,<<"B">>], <<>>}, kz_csv:take_row(<<"1,B">>))
    ].

pad_row_to_test_() ->
    [?_assertEqual([?ZILCH], kz_csv:pad_row_to(1, []))
    ,?_assertEqual([?ZILCH], kz_csv:pad_row_to(1, [?ZILCH]))
    ,?_assertEqual([?ZILCH, ?ZILCH, ?ZILCH], kz_csv:pad_row_to(3, [?ZILCH]))
    ].

count_rows_test_() ->
    [?_assertEqual(0, kz_csv:count_rows(<<"a,b,\n,1,2,">>))
    ,?_assertEqual(0, kz_csv:count_rows(<<"abc">>))
    ,?_assertEqual(0, kz_csv:count_rows(<<>>))
    ,?_assertEqual(0, kz_csv:count_rows(<<"a,b,c\n1\n2\n3">>))
    ,?_assertEqual(1, kz_csv:count_rows(<<"a,b,c\n1,2,3">>))
    ,?_assertEqual(3, kz_csv:count_rows(<<"a,b,c\n1,2,3\r\n4,5,6\n7,8,9\n">>))
    ].

row_to_iolist_test_() ->
    [?_assertException('error', 'function_clause', kz_csv:row_to_iolist([]))] ++
        [?_assertEqual(Expected, iolist_to_binary(kz_csv:row_to_iolist(Input)))
         || {Expected, Input} <- [{<<"a,b">>, [<<"a">>, <<"b">>]}
                                 ,{<<"a,,b">>, [<<"a">>, ?ZILCH, <<"b">>]}
                                 ,{<<",,b">>, [?ZILCH, ?ZILCH, <<"b">>]}
                                 ,{<<"a,b,">>, [<<"a">>, <<"b">>, ?ZILCH]}
                                 ,{<<"a,b,,,c">>, [<<"a">>, <<"b">>, ?ZILCH, ?ZILCH, <<"c">>]}
                                 ]
        ].

json_to_iolist_test_() ->
    Records1 = [kz_json:from_list([{<<"A">>, <<"a1">>}])
               ,kz_json:from_list([{<<"A">>, <<"42">>}])
               ],
    Records2 = [kz_json:from_list([{<<"field1">>,?ZILCH}, {<<"field deux">>,<<"QUUX">>}])
               ,kz_json:from_list([{<<"field deux">>, ?ZILCH}])
               ,kz_json:from_list([{<<"field1">>, <<"r'bla.+\\n'">>}])
               ],
    Records3 = [kz_json:from_list([{<<"account_id">>,<<"009afc511c97b2ae693c6cc4920988e8">>}, {<<"e164">>,<<"+14157215234">>}, {<<"cnam.outbound">>,<<"me">>}])
               ,kz_json:from_list([{<<"account_id">>,<<>>}, {<<"e164">>,<<"+14157215235">>}, {<<"cnam.outbound">>,<<>>}])
               ],
    [?_assertEqual(<<"A\na1\n42\n">>, kz_csv:json_to_iolist(Records1))
    ,?_assertEqual(<<"field1,field deux\n,QUUX\n,\nr'bla.+\\n',\n">>, kz_csv:json_to_iolist(Records2))
    ,?_assertEqual(<<"account_id,e164,cnam.outbound\n009afc511c97b2ae693c6cc4920988e8,+14157215234,me\n,+14157215235,\n">>, kz_csv:json_to_iolist(Records3))
    ].

split_test_() ->
    Rows = [{<<"\"0.1651\",\"ZAMBIA, MOBILE\",\"ZAMBIA, MOBILE-26094\",\"ZAMBIA, MOBILE\",\"26094\",\"0\"">>
            ,[<<"\"0.1651\"">>, <<"\"ZAMBIA, MOBILE\"">>, <<"\"ZAMBIA, MOBILE-26094\"">>, <<"\"ZAMBIA, MOBILE\"">>, <<"\"26094\"">>, <<"\"0\"">>]
            }
           ,{<<"\"0.1651\",\"ZAMBIA, MOBILE\",\"ZAMBIA, MOBILE-26094\",\"ZAMBIA, MOBILE\",\"26094\",0">>
            ,[<<"\"0.1651\"">>, <<"\"ZAMBIA, MOBILE\"">>, <<"\"ZAMBIA, MOBILE-26094\"">>, <<"\"ZAMBIA, MOBILE\"">>, <<"\"26094\"">>, <<"0">>]
            }
           ,{<<"0.1651,\"ZAMBIA, MOBILE\",\"ZAMBIA, MOBILE-26094\",\"ZAMBIA, MOBILE\",\"26094\",\"0\"">>
            ,[<<"0.1651">>, <<"\"ZAMBIA, MOBILE\"">>, <<"\"ZAMBIA, MOBILE-26094\"">>, <<"\"ZAMBIA, MOBILE\"">>, <<"\"26094\"">>, <<"\"0\"">>]
            }
           ,{<<",">>, [<<>>, <<>>]}
           ,{<<"test,">>,[<<"test">>,<<>>]}
           ,{<<"test,,">>,[<<"test">>,<<>>,<<>>]}
           ,{<<"test,,foo bar">>,[<<"test">>,<<>>,<<"foo bar">>]}
           ],
    lists:foldl(fun add_split_row_assertions/2, [], Rows).

add_split_row_assertions({Row, Split}, Tests) ->
    {Fields, _} = kz_csv:split_row(Row),
    [{binary_to_list(Row), ?_assertEqual(Split, Fields)} | Tests].

files_test_() ->
    filelib:fold_files("test/", "\.csv$", 'false', fun gen_file_tests/2, []).

gen_file_tests(File, Tests) ->
    {'ok', CSV} = file:read_file(File),
    [{File, ?_assert(0 < (catch kz_csv:count_rows(CSV)))} | Tests].