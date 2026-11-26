import '../../core/formatos.dart';
import '../../domain/models/models.dart';
import 'derivacao.dart';
import 'estado_demo.dart';

/// Rotina de cada minuto simulado (seção 10.5 / `tick` do plano).
/// É idempotente: cada notificação usa uma marca em `EstadoDemo.flags`.
class Tick {
  Tick(this.e, this.d);
  final EstadoDemo e;
  final Derivacao d;

  /// Roda a rotina para o instante [agora] (já fixado em `e.agoraForcado`).
  /// Devolve `true` se algo mudou.
  bool executar() {
    final agora = e.agora;
    var mudou = false;
    bool uma(String chave) {
      if (e.flags.contains(chave)) return false;
      e.flags.add(chave);
      return true;
    }

    // Fim de bloqueio: a máquina volta sozinha (manutenção não volta).
    for (final m in e.maquinas.values.toList()) {
      if (m.status == StatusMaquina.bloqueadaHoje &&
          m.indisponivelAte != null &&
          !agora.isBefore(m.indisponivelAte!)) {
        e.maquinas[m.id] = m.copyWith(
          status: StatusMaquina.disponivel,
          motivoIndisponivel: null,
          indisponivelAte: null,
        );
        mudou = true;
      }
    }
    // "Ocupada (uso não registrado)" expira.
    final expiradas = e.ocupadaAte.entries
        .where((en) => !agora.isBefore(en.value))
        .map((en) => en.key)
        .toList();
    for (final k in expiradas) {
      e.ocupadaAte.remove(k);
      mudou = true;
    }
    // Fechamentos agendados com fim.
    for (var i = 0; i < e.fechamentos.length; i++) {
      final f = e.fechamentos[i];
      if (f.ativo && f.fim != null && !agora.isBefore(f.fim!)) {
        e.fechamentos[i] = f.copyWith(ativo: false);
        mudou = true;
      }
    }

    final toler = Duration(minutes: e.config.toleranciaMin);
    for (final r in e.reservas.values.toList()) {
      switch (r.status) {
        case StatusReserva.agendada:
          // Lembrete 15 min antes.
          if (agora.isBefore(r.inicio) &&
              !agora.isBefore(r.inicio.subtract(const Duration(minutes: 15))) &&
              uma('lembrete:${r.id}')) {
            e.avisar(
              r.aptoId,
              'Sua reserva começa em 15 min',
              '${r.maquinaNome} às ${hora(r.inicio)}. Você pode confirmar o uso a partir das ${hora(r.inicio.subtract(Duration(minutes: e.config.checkinAntesMin)))}.',
              CategoriaAviso.reserva,
              rota: '/reserva/${r.id}',
            );
            mudou = true;
          }
          // Ainda não confirmou (início + 5 min).
          if (!agora.isBefore(r.inicio.add(const Duration(minutes: 5))) &&
              agora.isBefore(r.inicio.add(toler)) &&
              uma('naoconf:${r.id}')) {
            e.avisar(
              r.aptoId,
              'Você ainda não confirmou o uso',
              'Confirme o uso da ${r.maquinaNome} até ${hora(r.inicio.add(toler))} ou o horário será liberado.',
              CategoriaAviso.reserva,
              rota: '/reserva/${r.id}',
            );
            mudou = true;
          }
          // RN-07: não comparecimento.
          if (!agora.isBefore(r.inicio.add(toler))) {
            e.salvarReserva(r.copyWith(
              status: StatusReserva.naoCompareceu,
              historico: [
                ...r.historico,
                e.linha('Não compareceu: sem confirmação até ${hora(r.inicio.add(toler))}', agora),
              ],
            ));
            e.avisar(
              r.aptoId,
              'Reserva não utilizada',
              'Você não confirmou o uso da ${r.maquinaNome} às ${hora(r.inicio)}. O horário foi liberado.',
              CategoriaAviso.reserva,
              rota: '/reserva/${r.id}',
            );
            _verificarReincidencia(r.aptoId, agora);
            mudou = true;
          }
        case StatusReserva.emUso:
          final c = r.cronometro;
          if (c != null) {
            if (agora.isBefore(c.terminaEm) &&
                !agora.isBefore(
                    c.terminaEm.subtract(Duration(minutes: e.config.avisoAntesMin))) &&
                uma('cron5:${r.id}')) {
              e.avisar(
                r.aptoId,
                'Sua roupa fica pronta em ${e.config.avisoAntesMin} min',
                'Sua roupa na ${r.maquinaNome} fica pronta em ${e.config.avisoAntesMin} minutos.',
                CategoriaAviso.cronometro,
                rota: '/reserva/${r.id}',
              );
              mudou = true;
            }
            if (!agora.isBefore(c.terminaEm) && uma('pronta:${r.id}')) {
              e.aguardando[r.maquinaId] = Aguardando(
                reservaId: r.id,
                aptoId: r.aptoId,
                desde: c.terminaEm,
              );
              final secLivre = r.tipo == TipoMaquina.lavadora &&
                  d
                      .alternativas(TipoMaquina.secadora, e.inicioDoSlot(agora))
                      .isNotEmpty;
              e.avisar(
                r.aptoId,
                'Sua roupa está pronta!',
                'Sua roupa está pronta! Retire da ${r.maquinaNome}.${secLivre ? ' Há secadoras livres agora.' : ''}',
                CategoriaAviso.cronometro,
                rota: '/reserva/${r.id}',
              );
              mudou = true;
            }
          }
          // Fim do horário: em uso vira concluída (a roupa pode continuar lá).
          if (!agora.isBefore(r.fim)) {
            e.salvarReserva(r.copyWith(
              status: StatusReserva.concluida,
              historico: [
                ...r.historico,
                e.linha('Horário encerrado', agora),
              ],
            ));
            mudou = true;
          }
        case StatusReserva.precisaAcao:
          if (!agora.isBefore(r.inicio)) {
            e.salvarReserva(r.copyWith(
              status: StatusReserva.cancelada,
              motivoCancelamento:
                  'Sem ação até o início do horário (sem penalidade)',
              historico: [
                ...r.historico,
                e.linha('Cancelada: sem ação até o início, sem penalidade', agora),
              ],
            ));
            e.avisar(
              r.aptoId,
              'Reserva cancelada',
              'Sua reserva das ${hora(r.inicio)} na ${r.maquinaNome} foi cancelada porque não houve ação até o início. Sem penalidade.',
              CategoriaAviso.reserva,
              rota: '/reserva/${r.id}',
            );
            mudou = true;
          }
        default:
          break;
      }
    }

    // Prazo de retirada da roupa pronta (RN-15).
    for (final ag in e.aguardando.values.toList()) {
      final limite =
          ag.desde.add(Duration(minutes: e.config.prazoRetiradaMin));
      if (!agora.isBefore(limite) && uma('prazo:${ag.reservaId}')) {
        final r = e.reservas[ag.reservaId];
        final nome = r?.maquinaNome ?? 'máquina';
        e.avisar(
          ag.aptoId,
          'Sua roupa está esperando há ${e.config.prazoRetiradaMin} min',
          'Sua roupa está pronta há ${e.config.prazoRetiradaMin} minutos na $nome. Agora outro morador pode retirá-la e deixá-la no balcão.',
          CategoriaAviso.roupa,
          rota: r != null ? '/reserva/${r.id}' : null,
        );
        mudou = true;
      }
    }
    return mudou;
  }

  /// RN-10: 3 não comparecimentos em 30 dias.
  void _verificarReincidencia(String aptoId, DateTime agora) {
    final desde = agora.subtract(const Duration(days: 30));
    final n = e.reservas.values
        .where((x) =>
            x.aptoId == aptoId &&
            x.status == StatusReserva.naoCompareceu &&
            x.inicio.isAfter(desde))
        .length;
    final chave = 'reinc:$aptoId:$n';
    if (n >= 3 && !e.flags.contains(chave)) {
      e.flags.add(chave);
      e.avisar(
        aptoId,
        'Aviso de conduta',
        'Seu apartamento teve $n não comparecimentos em 30 dias. O síndico foi informado.',
        CategoriaAviso.conduta,
      );
      e.avisar(
        'sindico',
        'Reincidência de não comparecimento',
        'O Ap $aptoId teve $n não comparecimentos em 30 dias.',
        CategoriaAviso.sistema,
      );
    }
  }
}
