%% Gemelo digital de "Manufacturas Mesa de Otay" (escenario del ejercicio #69).
%% Unidades de tiempo: minutos desde una fecha de referencia; el "ahora" es un
%% hecho, nunca el reloj del sistema. Reglas puras, sin get_time ni random.
:- module(gemelo, [
    decide/3,
    situacion/3,
    falta/2,
    consta_dentro/3
]).

:- use_module(library(lists)).

%% ---------------------------------------------------------------------------
%% Hechos del escenario (Situacion 1)
%% ---------------------------------------------------------------------------

:- dynamic sin_reporte/2.
:- dynamic evento/6.
:- dynamic credencial/3.
:- dynamic desfase/3.
:- dynamic en_linea/1.

ahora(130).

% Supuestos propios del estudiante (no vienen fijados por el enunciado).
umbral_silencio(30).
margen_reloj(5).
nivel_boveda(3).
max_contratistas_escolta(2).

% En el edificio B el unico lector de salida es el lateral.
puerta(p_boveda, b, entrada).
puerta(p_muelle_b, b, entrada).
puerta(p_lateral_b, b, salida).

dispositivo(lector_boveda, lector, b).
dispositivo(lector_muelle_b, lector, b).
dispositivo(lector_lateral_b, lector, b).
dispositivo(sensor_lateral_b, sensor_puerta, b).

puerta_lector(p_boveda, lector_boveda).
puerta_lector(p_muelle_b, lector_muelle_b).
puerta_lector(p_lateral_b, lector_lateral_b).

persona(tecnico, contratista, jefe_mantenimiento).
persona(escolta1, planta, jefe_turno).

credencial(tecnico, 3, 500).
credencial(escolta1, 3, 500).

capacitacion(tecnico, boveda, 500).

turno(tecnico, 120, 180).
turno(escolta1, 120, 180).

escolta_de(tecnico, escolta1).

% La escolta paso la tarjeta en el muelle a la 1:50 (minuto 110).
evento(e_escolta_entrada, lector_muelle_b, tarjeta, escolta1, 110, 110).

% El lector lateral lleva 60 minutos sin reportar; el umbral es 30.
sin_reporte(lector_lateral_b, 60).

solicitud(s_tecnico, tecnico, acceso(boveda), 130, 140, reparacion_urgente).

%% ---------------------------------------------------------------------------
%% Tiempo y eventos
%% ---------------------------------------------------------------------------

% Atraso positivo = el reloj del dispositivo va atrasado; se suma al corregir.
instante_corregido(Id, Corregido) :-
    evento(Id, Disp, _Tipo, _Detalle, Td, _Tl),
    (   desfase(Disp, Atraso, _)
    ->  Corregido is Td + Atraso
    ;   Corregido = Td
    ).

evento_persona(Id, Persona, Edificio, Sentido, T) :-
    evento(Id, Disp, tarjeta, Persona, _, _),
    dispositivo(Disp, lector, Edificio),
    puerta_lector(Puerta, Disp),
    puerta(Puerta, Edificio, Sentido),
    instante_corregido(Id, T).

entrada_en(Persona, Edificio, T) :-
    evento_persona(_Id, Persona, Edificio, entrada, T).

salida_en(Persona, Edificio, T) :-
    evento_persona(_Id, Persona, Edificio, salida, T).

despues(T2, T1) :-
    margen_reloj(Margen),
    T2 - T1 > Margen.

ambigua(T2, T1) :-
    margen_reloj(Margen),
    abs(T2 - T1) =< Margen.

salida_posterior(Persona, Edificio) :-
    entrada_en(Persona, Edificio, Te),
    salida_en(Persona, Edificio, Ts),
    despues(Ts, Te).

salida_ambigua(Persona, Edificio) :-
    entrada_en(Persona, Edificio, Te),
    salida_en(Persona, Edificio, Ts),
    ambigua(Ts, Te).

%% ---------------------------------------------------------------------------
%% Presencia (consta dentro)
%% ---------------------------------------------------------------------------

lectores_salida(Edificio, Lectores) :-
    findall(D,
        (puerta(P, Edificio, salida), puerta_lector(P, D)),
        Lectores).

lector_sin_reporte(Dispositivo) :-
    sin_reporte(Dispositivo, Minutos),
    umbral_silencio(Umbral),
    Minutos > Umbral.

% Los lectores de salida son sanos solo si existen y ninguno supera el
% umbral de silencio. No se usa negacion por fallo: la ausencia de evento de
% salida con un lector caido no prueba que la persona siga adentro.
lector_sano(Dispositivo) :-
    en_linea(Dispositivo),
    \+ lector_sin_reporte(Dispositivo).

lectores_salida_sanos(Edificio) :-
    lectores_salida(Edificio, Lectores),
    Lectores \= [],
    forall(member(D, Lectores), lector_sano(D)).

consta_dentro(Persona, Edificio, Estado) :-
    entrada_en(Persona, Edificio, _),
    (   salida_posterior(Persona, Edificio)
    ->  Estado = ausente
    ;   salida_ambigua(Persona, Edificio)
    ->  Estado = no_se_sabe
    ;   lectores_salida_sanos(Edificio)
    ->  Estado = presente
    ;   Estado = no_se_sabe
    ).

situacion(Persona, consta_dentro(Edificio, Estado), Evidencia) :-
    once(consta_dentro(Persona, Edificio, Estado)),
    evidencia_presencia(Persona, Edificio, Estado, Evidencia).

evidencia_presencia(Persona, Edificio, Estado, Evidencia) :-
    findall(entrada(Persona, Edificio, T), entrada_en(Persona, Edificio, T), Entradas),
    findall(salida(Persona, Edificio, T), salida_en(Persona, Edificio, T), Salidas),
    lectores_salida(Edificio, Lectores),
    findall(lector_sin_reporte(D, M),
        (member(D, Lectores), sin_reporte(D, M), lector_sin_reporte(D)),
        SinReporte),
    umbral_silencio(Umbral),
    margen_reloj(Margen),
    append([Entradas, Salidas,
            [estado(Estado), umbral_silencio(Umbral), margen_reloj(Margen)],
            SinReporte], Evidencia).

%% ---------------------------------------------------------------------------
%% Requisitos de acceso y escolta
%% ---------------------------------------------------------------------------

credencial_vigente(Persona, NivelRequerido) :-
    credencial(Persona, Nivel, Vence),
    ahora(Ahora),
    Vence >= Ahora,
    Nivel =:= NivelRequerido.

capacitacion_vigente(Persona, Area) :-
    capacitacion(Persona, Area, Vence),
    ahora(Ahora),
    Vence >= Ahora.

turno_vigente(Persona) :-
    turno(Persona, Desde, Hasta),
    ahora(Ahora),
    Ahora >= Desde,
    Ahora =< Hasta.

requisitos_acceso(Persona, boveda, Faltantes) :-
    nivel_boveda(Nivel),
    findall(F, requisito_faltante(Persona, Nivel, F), Faltantes).

requisito_faltante(Persona, Nivel, credencial) :-
    \+ credencial_vigente(Persona, Nivel).
requisito_faltante(Persona, _Nivel, capacitacion) :-
    \+ capacitacion_vigente(Persona, boveda).
requisito_faltante(Persona, _Nivel, turno) :-
    \+ turno_vigente(Persona).

cupo_escolta(Escolta) :-
    findall(C, escolta_de(C, Escolta), Contratistas),
    length(Contratistas, N),
    max_contratistas_escolta(Max),
    N =< Max.

escolta_valida(Contratista, Escolta) :-
    escolta_de(Contratista, Escolta),
    persona(Escolta, planta, _),
    nivel_boveda(Nivel),
    credencial_vigente(Escolta, Nivel),
    cupo_escolta(Escolta).

%% ---------------------------------------------------------------------------
%% Decision central
%% ---------------------------------------------------------------------------

decide(Solicitud, Decision, Explicacion) :-
    solicitud_id(Solicitud, Id),
    solicitud(Id, Solicitante, Objetivo, _Desde, _Hasta, _Motivo),
    decidir(Objetivo, Id, Solicitante, Decision, Explicacion).

solicitud_id(solicitud(Id, _, _, _, _, _), Id) :- !.
solicitud_id(Id, Id) :- atom(Id).

decidir(acceso(boveda), Id, Solicitante, Decision, Explicacion) :-
    requisitos_acceso(Solicitante, boveda, Faltantes),
    (   Faltantes = [_|_]
    ->  Decision = negar(requisitos_incumplidos(Faltantes)),
        Explicacion = [
            solicitud(Id, Solicitante, acceso(boveda)),
            requisitos_incumplidos(Solicitante, Faltantes)
        ]
    ;   escolta_de(Solicitante, Escolta)
    ->  decidir_con_escolta(Id, Solicitante, Escolta, Decision, Explicacion)
    ;   Decision = negar(sin_escolta_asignada),
        Explicacion = [
            solicitud(Id, Solicitante, acceso(boveda)),
            falta(escolta_de_planta(Solicitante))
        ]
    ).
decidir(Objetivo, _Id, _Solicitante, negar(objetivo_no_soportado(Objetivo)),
        [objetivo_no_soportado(Objetivo)]).

decidir_con_escolta(Id, Solicitante, Escolta, Decision, Explicacion) :-
    once(consta_dentro(Escolta, b, Estado)),
    evidencia_presencia(Escolta, b, Estado, Evidencia),
    Base = [
        solicitud(Id, Solicitante, acceso(boveda)),
        escolta_asignada(Solicitante, Escolta),
        estado_escolta(Escolta, Estado)
    ],
    (   Estado = ausente
    ->  Decision = negar(escolta_ausente(Escolta)),
        append(Base, Evidencia, Explicacion)
    ;   Estado = no_se_sabe
    ->  Decision = aplazar(salida_registrada(Escolta, b)),
        append(Base,
               [falta(salida_registrada(Escolta, b)) | Evidencia],
               Explicacion)
    ;   Estado = presente
    ->  (   escolta_valida(Solicitante, Escolta)
        ->  Decision = permitir,
            append(Base, [escolta_valida(Escolta) | Evidencia], Explicacion)
        ;   Decision = negar(escolta_invalida(Escolta)),
            append(Base, [escolta_invalida(Escolta) | Evidencia], Explicacion)
        )
    ).

% Que falta para que cambie una decision que hoy no es definitiva.
falta(Solicitud, Falta) :-
    once(decide(Solicitud, Decision, _)),
    (   Decision = aplazar(Falta)
    ->  true
    ;   Decision = condicionar(Falta)
    ->  true
    ;   fail
    ).
