%% business logic gen_server (previously package_transfer)

-module(business_logic).
-behaviour(gen_server).



%% API
-export([start/0,start/3,stop/0, put_package/2,get_location/1,put_location/2,get_lat_long/1,location_request/1]).

-export([put_delivered/1]).
%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

%%%===================================================================
%%% API
%%%===================================================================
%%% 
%%% 
%%% 



%%--------------------------------------------------------------------
%% @doc
%% Starts the server assuming there is only one server started for 
%% this module. The server is registered locally with the registered
%% name being the name of the module.
%%
%% @end
%%--------------------------------------------------------------------
-spec start() -> {ok, pid()} | ignore | {error, term()}.
start() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).
%%--------------------------------------------------------------------
%% @doc
%% Starts a server using this module and registers the server using
%% the name given.
%% Registration_type can be local or global.
%%
%% Args is a list containing any data to be passed to the gen_server's
%% init function.
%%
%% @end
%%--------------------------------------------------------------------
-spec start(atom(),atom(),atom()) -> {ok, pid()} | ignore | {error, term()}.
start(Registration_type,Name,Args) ->
    gen_server:start_link({Registration_type, Name}, ?MODULE, Args, []).


%%--------------------------------------------------------------------
%% @doc
%% Stops the server gracefully
%%
%% @end
%%--------------------------------------------------------------------
-spec stop() -> {ok}|{error, term()}.
stop() -> gen_server:call(?MODULE, stop).

%% Any other API functions go here.

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%put a package and location in, return location id from package
put_package(Package_ID,Location_ID)-> 
    gen_server:cast(?MODULE,{transfer_package,Package_ID,Location_ID}).
get_location(Package_ID) ->
    gen_server:call(?MODULE,{get_location, Package_ID}).


% put delivered status into riak
put_delivered(Package_ID)-> 
    gen_server:cast(?MODULE,{deliver,Package_ID}).


% put a location with lat/long in riak, or return a lat/long from location ID
put_location(Location_ID, {Latitude,Longitude}) ->
    gen_server:cast(?MODULE,{put_location, Location_ID, {Latitude,Longitude}}).
get_lat_long(Location_ID) ->
    gen_server:call(?MODULE,{get_lat_long, Location_ID}).



location_request(Package_ID) ->
    {ok,Location_ID} = get_location(Package_ID),
    get_lat_long(Location_ID).


%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initializes the server
%%
%% @end
%%--------------------------------------------------------------------
-spec init(term()) -> {ok, term()}|{ok, term(), number()}|ignore |{stop, term()}.
init([]) ->


        %{Success, Riak_PID} = riakc_pb_socket:start_link("rdb.fordark.org", 8087).
            case riakc_pb_socket:start_link("db.thomasjamiesonprograms.com", 8087) of 
             {ok,Riak_Pid} -> {ok,Riak_Pid};
             _ -> {stop,link_failure}
        end.
%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%%
%% @end
%%--------------------------------------------------------------------
-spec handle_call(Request::term(), From::pid(), State::term()) ->
                                  {reply, term(), term()} |
                                  {reply, term(), term(), integer()} |
                                  {noreply, term()} |
                                  {noreply, term(), integer()} |
                                  {stop, term(), term(), integer()} | 
                                  {stop, term(), term()}.
%% package transfer
handle_call({get_location, PackageId}, _From, Db_PID) ->
    case db_api:get_location(PackageId, Db_PID) of
        {ok, Package} ->
            {reply, {ok, Package}, Db_PID};
        {error,notfound} ->
            {reply, {error, notfound}, Db_PID}
    end;

%% package delivered (check status)
handle_call({status, Package_ID}, _From, Db_PID) ->
    case Package_ID =:= <<"">> of
            true ->
                {reply,{fail,empty_key},Db_PID};
            _ ->
                {reply, db_api:get_status(Package_ID,Db_PID),Db_PID}
        end;

%% location_request
handle_call({get_lat_long, Location_ID}, _From, Db_PID) ->
    case Location_ID =:= <<"">> of
            true ->
                {reply, fail, Db_PID};
            _ ->
                {reply, db_api:get_lat_long(Location_ID,Db_PID),Db_PID}
        end;

%% stop server
handle_call(stop, _From, _State) ->
        {stop,normal,
                replace_stopped,
          down}. %% setting the server's internal state to down

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling cast messages
%%
%% @end
%%--------------------------------------------------------------------
-spec handle_cast(Msg::term(), State::term()) -> {noreply, term()} |
    {noreply, term(), integer()} |
    {stop, term(), term()}.

%%TRANSFER
% If either key is empty, it doesn't put_package
%% package transferred
%% 

handle_cast({transfer_package, <<"">>, _Location_ID}, Riak_PID) ->
    {noreply, Riak_PID};
handle_cast({transfer_package, _Package_ID, <<"">>}, Riak_PID) ->
    {noreply, Riak_PID};
handle_cast({transfer_package, Package_ID, Location_ID}, Riak_PID) ->
    db_api:put_package(Package_ID, Location_ID, Riak_PID),
    {noreply, Riak_PID};


%% package_delivered
handle_cast({deliver, <<"">>}, Db_PID) ->
    {noreply, Db_PID};
handle_cast({deliver, Package_ID}, Db_PID) ->
    db_api:deliver_package(Package_ID, Db_PID),
    {noreply, Db_PID};

%% location update
handle_cast({put_location, <<"">>, {_Latitude, _Longitude}}, Db_PID) ->
    {noreply, Db_PID};
handle_cast({put_location, _Location_ID, {<<"">>, _Longitude}}, Db_PID) ->
    {noreply, Db_PID};
handle_cast({put_location, _Location_ID, {_Latitude, <<"">>}}, Db_PID) ->
    {noreply, Db_PID};
handle_cast({put_location, Location_ID, {Latitude, Longitude}}, Db_PID) ->
    db_api:put_location(Location_ID, {Latitude, Longitude}, Db_PID),
    {noreply, Db_PID};
    
handle_cast(_Msg, State) ->
    {noreply, State}.
    
%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling all non call/cast messages
%%
%% @end
-spec handle_info(Info::term(), State::term()) -> {noreply, term()} |
                                   {noreply, term(), integer()} |
                                   {stop, term(), term()}.
handle_info(_Info, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
%%
%% @end
%%--------------------------------------------------------------------
-spec terminate(Reason::term(), term()) -> term().
terminate(_Reason, _State) ->
    ok.
    
%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%%
%% @end
%%--------------------------------------------------------------------
-spec code_change(term(), term(), term()) -> {ok, term()}.
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.
    
%%%===================================================================
%%% Internal functions
%%%===================================================================



-ifdef(EUNIT).
%%
%% Unit tests go here. 
%%
-include_lib("eunit/include/eunit.hrl").


transfer_test_() ->
    {setup,
     fun() ->
         % This setup fun is run once before the tests are run.
         meck:new(db_api),
         meck:expect(db_api, put_package, fun(_Package_ID, _Location_ID, _Pid) -> worked end),
         meck:expect(db_api, get_location, fun(Package_ID, _Pid) ->
             case Package_ID of
                 <<"4">> -> <<"Detroit">>;
                 <<"5">> -> <<"Truck101">>;
                 <<"6">> -> <<"Chicago">>;
                 _ -> fail
             end
         end),
         ok
     end,
     fun(_) ->
         % This is the teardown fun.
         meck:unload(db_api)
     end,
     [
         % Add the packages into the mock database
         fun() ->
             business_logic:handle_cast({transfer, <<"4">>, <<"Detroit">>}, some_Db_PID),
             business_logic:handle_cast({transfer, <<"5">>, <<"Truck101">>}, some_Db_PID),
             business_logic:handle_cast({transfer, <<"6">>, <<"Chicago">>}, some_Db_PID),
             business_logic:handle_cast({transfer, <<"">>, <<"">>}, some_Db_PID),
             ok
         end,
         
         % Use get location call function to check where the packages are. Only for unit testing!
         fun() ->
             ?assertEqual({reply, <<"Detroit">>, some_Db_PID},
                          business_logic:handle_call({get_location, <<"4">>}, some_from_pid, some_Db_PID))
         end,
         fun() ->
             ?assertEqual({reply, <<"Truck101">>, some_Db_PID},
                          business_logic:handle_call({get_location, <<"5">>}, some_from_pid, some_Db_PID))
         end,
        fun() ->
             ?assertEqual({reply, {fail, empty_key}, some_Db_PID},
                          business_logic:handle_call({get_location, <<"">>}, some_from_pid, some_Db_PID))
         end
     ]}.

delivered_test_() ->
{setup,
    fun() ->
        % This setup fun is run once before the tests are run.
        meck:new(db_api),
        meck:expect(db_api, deliver_package, fun(_Package_ID, _Pid) -> worked end),
        meck:expect(db_api, get_status, fun(Package_ID, _Pid) ->
            case Package_ID of
                <<"4">> -> <<"Delivered">>;
                <<"5">> -> <<"Delivered">>;
                <<"6">> -> <<"Delivered">>;
                _ -> fail
            end
        end),
        ok
    end,
    fun(_) ->
        % This is the teardown fun.
        meck:unload(db_api)
    end,
    [
        % Add the packages into the mock database
        fun() ->
            business_logic:handle_cast({deliver, <<"4">>}, some_Db_PID),
            business_logic:handle_cast({deliver, <<"5">>}, some_Db_PID),
            business_logic:handle_cast({deliver, <<"6">>}, some_Db_PID),
            business_logic:handle_cast({deliver, <<"">>}, some_Db_PID),
            ok
        end,
        
        % Use get location call function to check where the packages are. Only for unit testing!
        fun() ->
            ?assertEqual({reply, <<"Delivered">>, some_Db_PID},
                        business_logic:handle_call({status, <<"4">>}, some_from_pid, some_Db_PID))
        end,
        fun() ->
            ?assertEqual({reply, <<"Delivered">>, some_Db_PID},
                        business_logic:handle_call({status, <<"5">>}, some_from_pid, some_Db_PID))
        end,
        fun() ->
            ?assertEqual({reply, <<"Delivered">>, some_Db_PID},
                        business_logic:handle_call({status, <<"6">>}, some_from_pid, some_Db_PID))
        end,
    fun() ->
            ?assertEqual({reply, {fail, empty_key}, some_Db_PID},
                        business_logic:handle_call({status, <<"">>}, some_from_pid, some_Db_PID))
        end
    ]}.

loc_updt_test_() ->
    {setup,
        fun() ->
            % This setup fun is run once before the tests are run.
            meck:new(db_api),
            meck:expect(db_api, put_location, fun(_Location_ID, _Latitude, _Longitude, _Pid) -> worked end),
            ok
        end,
        fun(_) ->
            % This is the teardown fun.
            meck:unload(db_api)
        end,
        [
            % Add the packages into the mock database
            fun() ->
            ?assertEqual({noreply,worked,some_Db_PID},
                business_logic:handle_cast({update, <<"Truck101">>, <<"67.2">>, <<"57.3">>}, some_Db_PID)),
                ?assertEqual({noreply,failed,some_Db_PID},
                business_logic:handle_cast({update, <<"Plane201">>, <<"67.3">>, <<"">>}, some_Db_PID)),
                ?assertEqual({noreply,failed,some_Db_PID},
                business_logic:handle_cast({update, <<"Ship301">>, <<"">>, <<"57.5">>}, some_Db_PID)),
                ?assertEqual({noreply,failed,some_Db_PID},
                business_logic:handle_cast({update, <<"">>, <<"67.5">>, <<"57.2">>}, some_Db_PID))
            end
        ]}.
    
loc_req_test_() ->
    {setup,
        fun() ->
            % This setup fun is run once before the tests are run.
            meck:new(db_api),
            meck:expect(db_api, get_location, fun(Package_ID, _Pid) -> 
            case Package_ID of
                <<"4">> -> <<"Truck101">>;
                <<"5">> -> <<"Plane201">>;
                _ -> fail
            end
        end),
            meck:expect(db_api, get_lat_long, fun(Location_ID, _Pid) ->
                case Location_ID of
                    <<"Truck101">> -> {<<"67.2">>, <<"101.5">>};
                    <<"Plane201">> -> {<<"87.3">>, <<"130.1">>};
                    _ -> fail
                end
            end),
            ok
        end,
        fun(_) ->
            % This is the teardown fun.
            meck:unload(db_api)
        end,
        [
            
            % Use get location call function to check where the packages are. Only for unit testing!
            fun() ->
                ?assertEqual({reply, {<<"67.2">>, <<"101.5">>}, some_Db_PID},
                            business_logic:handle_call({get_loc, <<"4">>}, some_from_pid, some_Db_PID))
            end,
            fun() ->
                ?assertEqual({reply, {<<"87.3">>, <<"130.1">>}, some_Db_PID},
                            business_logic:handle_call({get_loc, <<"5">>}, some_from_pid, some_Db_PID))
            end,
        fun() ->
                ?assertEqual({reply, fail, some_Db_PID},
                            business_logic:handle_call({get_loc, <<"">>}, some_from_pid, some_Db_PID))
            end
        ]}.

riakc_connection_test_() ->
    {ok, Pid} = riakc_pb_socket:start_link("db.thomasjamiesonprograms.com", 8087),
    ?assertEqual(pong, riakc_pb_socket:ping(Pid)),
    ok.

-endif.
