%%%-------------------------------------------------------------------
%%% @copyright (C) 2016, 2600Hz INC
%%% @doc
%%% Handle prepend feature
%%% @end
%%% @contributors
%%%   Peter Defebvre
%%%   Pierre Fenoll
%%%-------------------------------------------------------------------
-module(knm_providers).

-include("knm.hrl").

-export([save/1]).
-export([delete/1]).
-export([available_features/1
        ,service_name/2
        ]).
-export([e911_caller_name/2]).

-define(DEFAULT_CNAM_PROVIDER, <<"knm_cnam_notifier">>).
-define(DEFAULT_E911_PROVIDER, <<"knm_dash_e911">>).

-define(CNAM_PROVIDER(AccountId),
        kapps_account_config:get_from_reseller(AccountId, ?KNM_CONFIG_CAT, <<"cnam_provider">>, ?DEFAULT_CNAM_PROVIDER)).

-define(E911_PROVIDER(AccountId),
        kapps_account_config:get_from_reseller(AccountId, ?KNM_CONFIG_CAT, <<"e911_provider">>, ?DEFAULT_E911_PROVIDER)).

-define(KAZOO_NUMBER_FEATURES, [?FEATURE_FAILOVER
                               ,?FEATURE_PREPEND
                               ,?FEATURE_FORCE_OUTBOUND
                               ,?FEATURE_RINGBACK
                               ]).

-define(EXTERNAL_NUMBER_FEATURES, [?FEATURE_CNAM
                                  ,?FEATURE_E911
                                  ,?FEATURE_PORT
                                  ]).

-record(feature_parameters, {is_local = 'false' :: boolean()
                            ,assigned_to :: api_binary()
                            ,allowed_features = [] :: ne_binaries()
                            ,denied_features = [] :: ne_binaries()
                            }).
-type feature_parameters() :: #feature_parameters{}.

%%--------------------------------------------------------------------
%% @public
%% @doc
%% @end
%%--------------------------------------------------------------------
-spec save(knm_number:knm_number()) -> knm_number:knm_number().
save(Number) ->
    exec(Number, 'save').

%%--------------------------------------------------------------------
%% @public
%% @doc
%% @end
%%--------------------------------------------------------------------
-spec delete(knm_number:knm_number()) -> knm_number:knm_number().
delete(Number) ->
    exec(Number, 'delete').

%%--------------------------------------------------------------------
%% @public
%% @doc
%% List features a number is allowedby its reseller to enable.
%% @end
%%--------------------------------------------------------------------
-spec available_features(knm_phone_number:knm_phone_number()) -> ne_binaries().
available_features(#feature_parameters{}=Parameters) ->
    Allowed =
        [legacy_provider_to_feature(Feature)
         || Feature <- allowed_features(Parameters)
        ],
    Denied =
        [legacy_provider_to_feature(Feature)
         || Feature <- denied_features(Parameters)
        ],
    [Feature
     || Feature <- lists:usort(Allowed),
        (not lists:member(Feature, Denied))
    ];
available_features(Thing) ->
    Parameters =
      case knm_phone_number:is_phone_number(Thing) of
          'true' ->
              #feature_parameters{
               is_local = knm_phone_number:module_name(Thing) =:= ?CARRIER_LOCAL
               ,assigned_to = knm_phone_number:assigned_to(Thing)
               ,allowed_features = []
               ,denied_features = []
               };
        'false' ->
              #feature_parameters{
               is_local = lists:member(<<"local">>, kz_json:get_value(<<"features">>, Thing, []))
               ,assigned_to = kz_json:get_value(<<"assigned_to">>, Thing)
               ,allowed_features = kz_json:get_value(<<"allowed_features">>, Thing, [])
               ,denied_features = kz_json:get_value(<<"denied_features">>, Thing, [])
               }
      end,
    available_features(Parameters).

-spec allowed_features(feature_parameters()) -> ne_binaries().
allowed_features(Parameters) ->
    reseller_allowed_features(Parameters)
      ++ number_allowed_features(Parameters).

-spec reseller_allowed_features(feature_parameters()) -> ne_binaries().
reseller_allowed_features(#feature_parameters{assigned_to = 'undefined'}) ->
    system_allowed_features();
reseller_allowed_features(#feature_parameters{assigned_to = AccountId}) ->
    case kapps_account_config:get_from_reseller(AccountId
                                               ,?KNM_CONFIG_CAT
                                               ,[<<"features">>, <<"allow">>]
                                               )
    of
        'undefined' -> system_allowed_features();
        Providers -> Providers
    end.

-spec system_allowed_features() -> ne_binaries().
system_allowed_features() ->
    case kapps_config:get(?KNM_CONFIG_CAT
                         ,<<"providers">>
                         )
    of
        'undefined' ->
            kapps_config:get(?KNM_CONFIG_CAT
                            ,[<<"features">>, <<"allow">>]
                            ,?KAZOO_NUMBER_FEATURES);
        Providers ->
            kapps_config:get(?KNM_CONFIG_CAT
                            ,[<<"features">>, <<"allow">>]
                            ,Providers)
    end.

-spec number_allowed_features(feature_parameters()) -> ne_binaries().
number_allowed_features(#feature_parameters{allowed_features = AllowedFeatures}) ->
    AllowedFeatures.

-spec denied_features(feature_parameters()) -> ne_binaries().
denied_features(Parameters) ->
    reseller_denied_features(Parameters)
      ++ local_denied_features(Parameters)
      ++ number_denied_features(Parameters).

-spec reseller_denied_features(feature_parameters()) -> ne_binaries().
reseller_denied_features(#feature_parameters{assigned_to = 'undefined'}) ->
    ?EXTERNAL_NUMBER_FEATURES;
reseller_denied_features(#feature_parameters{assigned_to = AccountId}) ->
    case kapps_account_config:get_from_reseller(AccountId
                                               ,?KNM_CONFIG_CAT
                                               ,[<<"features">>, <<"deny">>]
                                               )
    of
        'undefined' -> [];
        Providers -> Providers
    end.

-spec local_denied_features(feature_parameters()) -> ne_binaries().
local_denied_features(#feature_parameters{is_local = 'false'}) -> [];
local_denied_features(#feature_parameters{is_local = 'true'}) ->
    ?EXTERNAL_NUMBER_FEATURES.

-spec number_denied_features(feature_parameters()) -> ne_binaries().
number_denied_features(#feature_parameters{denied_features = DeniedFeatures}) ->
    DeniedFeatures.

-spec legacy_provider_to_feature(ne_binary()) -> ne_binary().
legacy_provider_to_feature(<<"wnm_", Rest/binary>>) -> legacy_provider_to_feature(Rest);
legacy_provider_to_feature(<<"knm_", Rest/binary>>) -> legacy_provider_to_feature(Rest);
legacy_provider_to_feature(<<"cnam_notifier">>) -> ?FEATURE_CNAM;
legacy_provider_to_feature(<<"dash_e911">>) -> ?FEATURE_E911;
legacy_provider_to_feature(<<"port_notifier">>) -> ?FEATURE_PORT;
legacy_provider_to_feature(<<"telnyx_cnam">>) -> ?FEATURE_CNAM;
legacy_provider_to_feature(<<"telnyx_e911">>) -> ?FEATURE_E911;
legacy_provider_to_feature(<<"vitelity_cnam">>) -> ?FEATURE_CNAM;
legacy_provider_to_feature(<<"vitelity_e911">>) -> ?FEATURE_E911;
legacy_provider_to_feature(Else) ->
    lager:debug("letting ~p through", [Else]),
    Else.

%%--------------------------------------------------------------------
%% @public
%% @doc
%% The name of the billable service associated with a feature.
%% @end
%%--------------------------------------------------------------------
-spec service_name(ne_binary(), ne_binary()) -> ne_binary().
service_name(?FEATURE_E911, AccountId) ->
    service_name(?E911_PROVIDER(AccountId));
service_name(?FEATURE_CNAM, AccountId) ->
    service_name(?CNAM_PROVIDER(AccountId));
service_name(Feature, _) ->
    service_name(Feature).

%%--------------------------------------------------------------------
%% @public
%% @doc
%% Util function to get E911 caller name defaults.
%% @end
%%--------------------------------------------------------------------
-spec e911_caller_name(knm_number:knm_number(), api_ne_binary()) -> ne_binary().
-ifdef(TEST).
e911_caller_name(_Number, ?NE_BINARY=Name) -> Name;
e911_caller_name(_Number, 'undefined') -> ?E911_NAME_DEFAULT.
-else.
e911_caller_name(_Number, ?NE_BINARY=Name) -> Name;
e911_caller_name(Number, 'undefined') ->
    AccountId = knm_phone_number:assigned_to(knm_number:phone_number(Number)),
    case kz_account:fetch(AccountId) of
        {'ok', JObj} -> kz_account:name(JObj, ?E911_NAME_DEFAULT);
        {'error', _Error} ->
            lager:error('error opening account doc ~p', [AccountId]),
            ?E911_NAME_DEFAULT
    end.
-endif.

%%%===================================================================
%%% Internal functions
%%%===================================================================

-spec service_name(ne_binary()) -> ne_binary().
service_name(<<"knm_dash_e911">>) -> <<"dash_e911">>;
service_name(<<"knm_telnyx_e911">>) -> <<"telnyx_e911">>;
service_name(<<"knm_vitelity_e911">>) -> <<"vitelity_e911">>;
service_name(<<"knm_cnam_notifier">>) -> <<"cnam">>;
service_name(<<"knm_telnyx_cnam">>) -> <<"telnyx_cnam">>;
service_name(<<"knm_vitelity_cnam">>) -> <<"vitelity_cnam">>;
service_name(Feature) -> Feature.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% @end
%%--------------------------------------------------------------------
-spec provider_modules(knm_number:knm_number()) -> ne_binaries().
provider_modules(Number) ->
    PhoneNumber = knm_number:phone_number(Number),
    AccountId = knm_phone_number:assigned_to(PhoneNumber),
    Possible0 = kz_json:get_keys(knm_phone_number:doc(PhoneNumber)),
    Possible = lists:usort(Possible0 ++ knm_phone_number:features_list(PhoneNumber)),
    AllowedBase = allowed_features(PhoneNumber),
    Allowed = case lists:member(?FEATURE_E911, Possible0) of
                  true -> AllowedBase;
                  false ->
                      %% For backward compatibility
                      AllowedBase ++ [<<"dash_e911">>, <<"vitelity_e911">>]
              end,
    lager:debug("allowed ~p, possible ~p", [Allowed, Possible]),
    [provider_module(Feature, AccountId)
     || Feature <- Possible,
        lists:member(Feature, Allowed)
    ].

-spec provider_module(ne_binary(), api_ne_binary()) -> ne_binary().
provider_module(?FEATURE_CNAM, ?MATCH_ACCOUNT_RAW(AccountId)) ->
    cnam_provider(AccountId);
provider_module(?FEATURE_E911, ?MATCH_ACCOUNT_RAW(AccountId)) ->
    e911_provider(AccountId);
provider_module(?FEATURE_PREPEND, _) ->
    <<"knm_prepend">>;
provider_module(?FEATURE_PORT, _) ->
    <<"knm_port_notifier">>;
provider_module(?FEATURE_FAILOVER, _) ->
    <<"knm_failover">>;
provider_module(Other, _) ->
    lager:warning("unmatched feature provider '~s', allowing", [Other]),
    Other.

-ifdef(TEST).
e911_provider(?RESELLER_ACCOUNT_ID) -> <<"knm_telnyx_e911">>;
e911_provider(AccountId) -> ?E911_PROVIDER(AccountId).
-else.
e911_provider(AccountId) -> ?E911_PROVIDER(AccountId).
-endif.

-ifdef(TEST).
cnam_provider(?RESELLER_ACCOUNT_ID) -> <<"knm_telnyx_cnam">>;
cnam_provider(AccountId) -> ?CNAM_PROVIDER(AccountId).
-else.
cnam_provider(AccountId) -> ?CNAM_PROVIDER(AccountId).
-endif.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% @end
%%--------------------------------------------------------------------
-type exec_action() :: 'save' | 'delete'.
-spec exec(knm_number:knm_number(), exec_action()) ->
                  knm_number:knm_number().
-spec exec(knm_number:knm_number(), exec_action(), ne_binaries()) ->
                  knm_number:knm_number().

exec(Number, Action) ->
    Number1 = fix_old_fields_names(Number),
    exec(Number1, Action, provider_modules(Number)).

%% @private
fix_old_fields_names(Number) ->
    PN = knm_number:phone_number(Number),
    Doc = knm_phone_number:doc(PN),
    Values = props:filter_undefined(
               [{?FEATURE_E911, kz_json:get_ne_value(<<"dash_e911">>, Doc)}
               ,{?FEATURE_E911, kz_json:get_ne_value(<<"vitelity_e911">>, Doc)}
               ]),
    ToDelete = [<<"dash_e911">>, <<"vitelity_e911">>],
    NewDoc = kz_json:set_values(Values, kz_json:delete_keys(ToDelete, Doc)),
    NewPN = knm_phone_number:update_doc(PN, NewDoc),
    knm_number:set_phone_number(Number, NewPN).

exec(Number, Action, Providers) ->
    lists:foldl(fun (Provider, N) ->
                        case apply_action(N, Action, Provider) of
                            {'true', NewN} -> NewN;
                            'false' -> N
                        end
                end
               ,Number
               ,Providers
               ).

-spec apply_action(knm_number:knm_number(), exec_action(), ne_binary()) ->
                          {'true', any()} | 'false'.
apply_action(Number, Action, Provider) ->
    case kz_util:try_load_module(Provider) of
        'false' ->
            lager:debug("provider ~s is unknown, skipping", [Provider]),
            'false';
        Module ->
            lager:debug("attempting ~s:~s/1", [Module, Action]),
            Ret = erlang:apply(Module, Action, [Number]),
            {'true', Ret}
    end.
