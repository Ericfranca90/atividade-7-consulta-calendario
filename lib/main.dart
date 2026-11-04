import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const AplicativoCalendario());
}

class AplicativoCalendario extends StatelessWidget {
  const AplicativoCalendario({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: TelaCompromissos(),
    );
  }
}

class CompromissoCalendario {
  final Event evento;
  final String nomeCalendario;

  const CompromissoCalendario({
    required this.evento,
    required this.nomeCalendario,
  });
}

class TelaCompromissos extends StatefulWidget {
  const TelaCompromissos({super.key});

  @override
  State<TelaCompromissos> createState() => _TelaCompromissosState();
}

class _TelaCompromissosState extends State<TelaCompromissos> {
  final DeviceCalendarPlugin _calendario = DeviceCalendarPlugin();
  final List<CompromissoCalendario> _compromissos = [];

  bool _carregando = false;
  String _mensagem = 'Toque no botão para consultar os compromissos.';

  Future<void> _consultarCompromissos() async {
    if (_carregando) return;

    setState(() {
      _carregando = true;
      _compromissos.clear();
      _mensagem = '';
    });

    try {
      final resultadoPermissao = await _calendario.hasPermissions();
      if (!mounted) return;

      if (resultadoPermissao.hasErrors || resultadoPermissao.data == null) {
        throw Exception('Falha ao verificar a permissão.');
      }

      bool acessoPermitido = resultadoPermissao.data!;

      if (!acessoPermitido) {
        final solicitacao = await _calendario.requestPermissions();
        if (!mounted) return;

        if (solicitacao.hasErrors || solicitacao.data == null) {
          final novaVerificacao = await _calendario.hasPermissions();
          if (!mounted) return;

          if (novaVerificacao.hasErrors || novaVerificacao.data == null) {
            throw Exception('Falha ao solicitar a permissão.');
          }

          acessoPermitido = novaVerificacao.data!;
        } else {
          acessoPermitido = solicitacao.data!;
        }
      }

      if (!acessoPermitido) {
        setState(() {
          _mensagem = 'O acesso ao calendário foi negado.';
        });
        return;
      }

      final resultadoCalendarios = await _calendario.retrieveCalendars();
      if (!mounted) return;

      if (resultadoCalendarios.hasErrors || resultadoCalendarios.data == null) {
        throw Exception('Falha ao consultar os calendários.');
      }

      final agora = DateTime.now();
      final inicio = DateTime(agora.year, agora.month, agora.day);
      final fim = DateTime(
        inicio.year,
        inicio.month,
        inicio.day + 7,
      ).subtract(const Duration(milliseconds: 1));

      final encontrados = <CompromissoCalendario>[];

      for (final calendario in resultadoCalendarios.data!) {
        final id = calendario.id;
        if (id == null || id.isEmpty) continue;

        final resultadoEventos = await _calendario.retrieveEvents(
          id,
          RetrieveEventsParams(startDate: inicio, endDate: fim),
        );
        if (!mounted) return;

        if (resultadoEventos.hasErrors || resultadoEventos.data == null) {
          throw Exception('Falha ao consultar os compromissos.');
        }

        final nomeCalendario = _textoOuPadrao(
          calendario.name,
          'Calendário sem nome',
        );

        for (final evento in resultadoEventos.data!) {
          encontrados.add(
            CompromissoCalendario(
              evento: evento,
              nomeCalendario: nomeCalendario,
            ),
          );
        }
      }

      encontrados.sort((a, b) {
        final inicioA = a.evento.start;
        final inicioB = b.evento.start;

        if (inicioA == null && inicioB == null) return 0;
        if (inicioA == null) return 1;
        if (inicioB == null) return -1;
        return inicioA.compareTo(inicioB);
      });

      setState(() {
        _compromissos.addAll(encontrados);
        _mensagem = encontrados.isEmpty
            ? 'Nenhum compromisso encontrado nos próximos sete dias.'
            : '';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _mensagem = 'Ocorreu uma falha ao consultar os compromissos.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _carregando = false;
        });
      }
    }
  }

  String _textoOuPadrao(String? texto, String padrao) {
    if (texto == null || texto.trim().isEmpty) return padrao;
    return texto;
  }

  String _doisDigitos(int valor) => valor.toString().padLeft(2, '0');

  String _formatarDataHora(DateTime? data, bool diaInteiro) {
    if (data == null) return 'Não informado';

    final dataLocal = data.toLocal();
    final dataFormatada =
        '${_doisDigitos(dataLocal.day)}/'
        '${_doisDigitos(dataLocal.month)}/${dataLocal.year}';

    if (diaInteiro) return '$dataFormatada (dia inteiro)';

    return '$dataFormatada '
        '${_doisDigitos(dataLocal.hour)}:${_doisDigitos(dataLocal.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Compromissos do calendário')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: _carregando ? null : _consultarCompromissos,
              child: const Text('Consultar compromissos'),
            ),
            const SizedBox(height: 16),
            if (_carregando)
              const Center(child: CircularProgressIndicator())
            else if (_mensagem.isNotEmpty)
              Text(_mensagem, textAlign: TextAlign.center),
            if (!_carregando && _compromissos.isNotEmpty)
              Expanded(
                child: ListView.separated(
                  itemCount: _compromissos.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final compromisso = _compromissos[index];
                    final evento = compromisso.evento;
                    final diaInteiro = evento.allDay == true;

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _textoOuPadrao(evento.title, 'Sem título'),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text('Calendário: ${compromisso.nomeCalendario}'),
                            Text(
                              'Início: ${_formatarDataHora(evento.start, diaInteiro)}',
                            ),
                            Text(
                              'Fim: ${_formatarDataHora(evento.end, diaInteiro)}',
                            ),
                            Text(
                              'Tipo: ${diaInteiro ? 'Dia inteiro' : 'Com horário'}',
                            ),
                            Text(
                              'Local: ${_textoOuPadrao(evento.location, 'Não informado')}',
                            ),
                            Text(
                              'Descrição: ${_textoOuPadrao(evento.description, 'Não informada')}',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
