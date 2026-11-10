%% Verificacion pura de la cadena de hashes de eventos y de la cadena de
%% checkpoints de retencion. Los eventos eliminados por retencion no se pueden
%% recalcular (ya no existen), pero su hash queda en el libro de hashes para
%% mantener el eslabonamiento. Los eventos presentes se recalculan completos.
-module(p69_cadena).

-export([
  hash_checkpoint/2,
  verificar/2,
  verificar_checkpoints/1,
  verificar_ledger/1
]).

-export_type([fila/0, checkpoint/0]).

-type fila() :: {Seq :: non_neg_integer(), Evento :: map() | undefined,
                 Hash :: binary(), HashPrev :: binary()}.
-type checkpoint() :: map().

-spec hash_checkpoint(binary(), checkpoint()) -> binary().
hash_checkpoint(HashPrev, Cp) when is_binary(HashPrev) ->
  crypto:hash(sha256, <<HashPrev/binary, (canonico_checkpoint(Cp))/binary>>).

-spec verificar([fila()], [checkpoint()]) -> {ok, map()} | {error, map()}.
verificar(Filas, Checkpoints) ->
  case verificar_checkpoints(Checkpoints) of
    ok ->
      case verificar_ledger(Filas) of
        {ok, Resumen} ->
          {ok, Resumen#{checkpoints => length(Checkpoints)}};
        Error ->
          Error
      end;
    Error ->
      Error
  end.

-spec verificar_checkpoints([checkpoint()]) -> ok | {error, map()}.
verificar_checkpoints([]) ->
  ok;
verificar_checkpoints(Cps) ->
  Ordenados = lists:sort(fun(A, B) -> maps:get(cp_seq, A) =< maps:get(cp_seq, B) end, Cps),
  [Primero | Resto] = Ordenados,
  verificar_cp(Primero, maps:get(hash_prev, Primero), Resto).

verificar_cp(Cp, PrevEsperado, Resto) ->
  case maps:get(hash, Cp) =:= hash_checkpoint(PrevEsperado, Cp) of
    false ->
      {error, #{motivo => checkpoint_alterado, cp_seq => maps:get(cp_seq, Cp)}};
    true ->
      case Resto of
        [] -> ok;
        [Siguiente | Cola] ->
          verificar_cp(Siguiente, maps:get(hash, Cp), Cola)
      end
  end.

-spec verificar_ledger([fila()]) -> {ok, map()} | {error, map()}.
verificar_ledger([]) ->
  {ok, #{eventos => 0, eliminados => 0, ultimo_seq => 0}};
verificar_ledger(Filas) ->
  verificar_filas(Filas, 1, <<>>, 0, 0, 0).

verificar_filas([], _SeqEsperado, _Prev, Presentes, Eliminados, Ultimo) ->
  {ok, #{eventos => Presentes, eliminados => Eliminados, ultimo_seq => Ultimo}};
verificar_filas([{Seq, Evento, Hash, HashPrev} | Resto], SeqEsperado, Prev,
    Presentes, Eliminados, _Ultimo) ->
  if
    Seq =/= SeqEsperado ->
      {error, #{motivo => secuencia_incompleta, esperado => SeqEsperado, encontrado => Seq}};
    HashPrev =/= Prev ->
      {error, #{motivo => eslabon_roto, seq => Seq}};
    true ->
      case Evento of
        undefined ->
          verificar_filas(Resto, Seq + 1, Hash, Presentes, Eliminados + 1, Seq);
        _ ->
          case p69_evento:verificar_hash(Evento) andalso maps:get(hash, Evento) =:= Hash of
            false -> {error, #{motivo => evento_alterado, seq => Seq}};
            true -> verificar_filas(Resto, Seq + 1, Hash, Presentes + 1, Eliminados, Seq)
          end
      end
  end.

canonico_checkpoint(Cp) ->
  iolist_to_binary([
    "cp_seq=", integer_to_binary(maps:get(cp_seq, Cp)),
    "|tipo=", atom_to_binary(maps:get(tipo, Cp), utf8),
    "|segmento=", integer_to_binary(maps:get(segmento, Cp)),
    "|primer_seq=", integer_to_binary(maps:get(primer_seq, Cp, 0)),
    "|ultimo_seq=", integer_to_binary(maps:get(ultimo_seq, Cp, 0)),
    "|eventos=", integer_to_binary(maps:get(eventos, Cp, 0)),
    "|hash_ultimo=", maps:get(hash_ultimo_evento, Cp, <<>>),
    "|ts=", integer_to_binary(maps:get(ts, Cp))
  ]).
