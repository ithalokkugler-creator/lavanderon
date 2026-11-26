/// Ponto único de importação do domínio para as telas.
/// As telas só conhecem o contrato (modelos + repositório + providers),
/// nunca a implementação de demonstração. Trocar pela versão Firebase não afeta a UI.
library;

export 'package:lavanderon/app/providers.dart';
export 'package:lavanderon/data/demo/seed_vision.dart' show usuariosDemo;
export 'package:lavanderon/domain/app_erro.dart';
export 'package:lavanderon/domain/lavanderon_repository.dart';
export 'package:lavanderon/domain/models/models.dart';
