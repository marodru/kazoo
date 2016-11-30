%%%-------------------------------------------------------------------
%%% @copyright (C) 2016, 2600Hz
%%% @doc
%%% @end
%%% @contributors
%%%   Pierre Fenoll
%%%-------------------------------------------------------------------
-module(knm_numbers_test).

-include_lib("eunit/include/eunit.hrl").
-include("knm.hrl").


-define(NOT_NUM, <<"NOT a number">>).

n_x(X, Ret) ->
    lists:nth(X, maps:get(ok, Ret)).

pn_x(X, Ret) ->
    knm_number:phone_number(n_x(X, Ret)).


get_test_() ->
    Ret = knm_numbers:get([?TEST_AVAILABLE_NUM]),
    [?_assertEqual(#{}, maps:get(ko, Ret))
    ,?_assertMatch([_], maps:get(ok, Ret))
    ,?_assertEqual(?TEST_AVAILABLE_NUM, knm_phone_number:number(pn_x(1, Ret)))
    ,?_assertMatch(#{ko := #{?NOT_NUM := not_reconcilable}}
                  ,knm_numbers:get([?NOT_NUM], [])
                  )
    ,?_assertMatch(#{ko := #{?TEST_CREATE_NUM := not_found}}
                  ,knm_numbers:get([?TEST_CREATE_NUM], [])
                  )
    ,?_assertMatch(#{ko := #{?NOT_NUM := not_reconcilable}
                    ,ok := [_]
                    }
                  ,knm_numbers:get([?TEST_AVAILABLE_NUM, ?NOT_NUM])
                  )
    ,?_assertMatch(#{ko := #{?NOT_NUM := not_reconcilable}
                    ,ok := [_]
                    }
                  ,knm_numbers:get([?TEST_AVAILABLE_NUM, ?NOT_NUM
                                   ,?TEST_AVAILABLE_NUM, ?NOT_NUM])
                  )
    ,?_assertMatch(#{ko := #{?NOT_NUM := not_reconcilable
                            ,?TEST_CREATE_NUM := not_found
                            }
                    ,ok := [_]
                    }
                  ,knm_numbers:get([?TEST_AVAILABLE_NUM, ?NOT_NUM
                                   ,?TEST_AVAILABLE_NUM, ?NOT_NUM
                                   ,?TEST_CREATE_NUM])
                  )
    ].


create_test_e911() ->
    kz_json:from_list(
      [{?E911_STREET1, <<"301 marina blvd.">>}
      ,{?E911_CITY, <<"San Francisco">>}
      ,{?E911_STATE, <<"CA">>}
      ,{?E911_ZIP, <<"94123">>}
      ]).

create_test_() ->
    E911 = create_test_e911(),
    JObj = kz_json:from_list([{?FEATURE_E911, E911}]),
    Options = [{'auth_by', ?MASTER_ACCOUNT_ID}
              ,{'assign_to', ?RESELLER_ACCOUNT_ID}
              ,{<<"auth_by_account">>, kz_json:new()}
              ],
    Ret = knm_numbers:create([?TEST_AVAILABLE_NUM], [{'public_fields', JObj}|Options]),
    [?_assertEqual(#{}, maps:get(ko, Ret))
    ,?_assertMatch([_], maps:get(ok, Ret))
    ,?_assertEqual(true, knm_number:is_number(n_x(1, Ret)))
    ,?_assertEqual(true, knm_phone_number:is_phone_number(pn_x(1, Ret)))
    ,{"Verify feature is properly set"
     ,?_assertEqual(E911, knm_phone_number:feature(pn_x(1, Ret), ?FEATURE_E911))
     }
    ,{"Verify we are keeping track of intermediary address_id"
     ,?_assertEqual(<<"421564943280637078">>
                   ,kz_json:get_value(<<"address_id">>, knm_phone_number:carrier_data(pn_x(1, Ret)))
                   )
     }
    ,?_assertMatch(#{ko := #{?NOT_NUM := _
                            ,?TEST_CREATE_NUM := _
                            }
                    ,ok := [_]
                    }
                  ,knm_numbers:create([?TEST_AVAILABLE_NUM, ?NOT_NUM, ?TEST_CREATE_NUM], Options)
                  )
    ].
