%% Pruebas del gemelo. Primero la prueba, despues la regla.
:- module(reglas_tests, []).
:- use_module(library(plunit)).
:- use_module(library(lists)).
:- use_module('../src/gemelo').

:- begin_tests(situacion_1).

% La escolta entro a B y el unico lector de salida lleva 60 min en silencio:
% no se sabe si sigue dentro (no consta que salio, pero tampoco que sigue).
test(escolta_no_se_sabe_por_lector_en_silencio) :-
    situacion(escolta1, consta_dentro(b, no_se_sabe), Evidencia),
    assertion(memberchk(lector_sin_reporte(lector_lateral_b, 60), Evidencia)).

% Con la escolta en duda, el acceso se aplaza y se dice que dato lo resuelve.
test(tecnico_con_escolta_dudosa_se_aplaza) :-
    once(decide(s_tecnico, Decision, Explicacion)),
    assertion(Decision = aplazar(_)),
    assertion(memberchk(estado_escolta(escolta1, no_se_sabe), Explicacion)),
    falta(s_tecnico, Falta),
    assertion(Falta = salida_registrada(escolta1, b)).

% Con el lector de salida en linea y sin salida registrada, consta dentro.
test(escolta_presente_con_lectores_salida_sanos,
     [setup((gemelo:retractall(sin_reporte(lector_lateral_b, _)),
             gemelo:assertz(en_linea(lector_lateral_b)))),
      cleanup((gemelo:retract(en_linea(lector_lateral_b)),
               gemelo:assertz(sin_reporte(lector_lateral_b, 60))))]) :-
    situacion(escolta1, consta_dentro(b, presente), _),
    once(decide(s_tecnico, permitir, _)).

% Borde: el silencio de exactamente 30 min NO supera el umbral; sigue presente.
test(silencio_exactamente_30_no_es_dudoso,
     [setup((gemelo:retractall(sin_reporte(lector_lateral_b, _)),
             gemelo:assertz(sin_reporte(lector_lateral_b, 30)),
             gemelo:assertz(en_linea(lector_lateral_b)))),
      cleanup((gemelo:retract(en_linea(lector_lateral_b)),
               gemelo:retract(sin_reporte(lector_lateral_b, 30)),
               gemelo:assertz(sin_reporte(lector_lateral_b, 60))))]) :-
    situacion(escolta1, consta_dentro(b, presente), _).

% Borde: una salida a exactamente 5 min de la entrada es indeterminable.
test(margen_de_reloj_de_5_minutos_es_indeterminable,
     [setup(gemelo:assertz(evento(e_salida_margen, lector_lateral_b, tarjeta, escolta1, 115, 115))),
      cleanup(gemelo:retract(evento(e_salida_margen, lector_lateral_b, tarjeta, escolta1, 115, 115)))]) :-
    situacion(escolta1, consta_dentro(b, no_se_sabe), _).

% Borde: el lector vuelve a estar en linea pero NO registra salida: presente.
test(lector_vuelve_en_linea_sin_salida_es_presente,
     [setup((gemelo:retractall(sin_reporte(lector_lateral_b, _)),
             gemelo:assertz(en_linea(lector_lateral_b)))),
      cleanup((gemelo:retract(en_linea(lector_lateral_b)),
               gemelo:assertz(sin_reporte(lector_lateral_b, 60))))]) :-
    situacion(escolta1, consta_dentro(b, presente), _).

% Si el lector lateral vuelve y registra la salida, consta ausente y se niega.
test(escolta_ausente_si_el_lector_registra_salida,
     [setup(gemelo:assertz(evento(e_escolta_salida, lector_lateral_b, tarjeta, escolta1, 120, 120))),
      cleanup(gemelo:retract(evento(e_escolta_salida, lector_lateral_b, tarjeta, escolta1, 120, 120)))]) :-
    situacion(escolta1, consta_dentro(b, ausente), _),
    once(decide(s_tecnico, Decision, _)),
    assertion(Decision = negar(_)).

% Sin credencial vigente el tecnico no entra aunque la escolta este presente.
test(tecnico_sin_credencial_vigente_se_niega,
     [setup(gemelo:retract(credencial(tecnico, 3, 500))),
      cleanup(gemelo:assertz(credencial(tecnico, 3, 500)))]) :-
    once(decide(s_tecnico, Decision, _)),
    assertion(Decision = negar(_)).

% El nivel es exactamente B-3: un nivel superior no se admite como sustituto.
test(nivel_superior_a_b3_no_se_admite,
     [setup((gemelo:retract(credencial(tecnico, 3, 500)),
             gemelo:assertz(credencial(tecnico, 4, 500)))),
      cleanup((gemelo:retract(credencial(tecnico, 4, 500)),
               gemelo:assertz(credencial(tecnico, 3, 500))))]) :-
    once(decide(s_tecnico, Decision, _)),
    assertion(Decision = negar(requisitos_incumplidos(Faltantes))),
    assertion(memberchk(credencial, Faltantes)).

:- end_tests(situacion_1).
