import '../../domain/models/models.dart';

/// Tutoriais gerais (plano, seção 6.13). Conteúdo prático e independente de
/// marca/modelo das máquinas.
const List<Tutorial> tutoriaisVision = [
  Tutorial(
    id: 't1',
    titulo: 'Como reservar, confirmar o uso e usar o cronômetro',
    resumo: 'O caminho completo no Lavanderon, da reserva ao aviso de roupa pronta.',
    categoria: 'Primeiros passos',
    minutos: 3,
    passos: [
      PassoTutorial(
        titulo: 'Reserve um horário',
        texto:
            'Em Reservar, escolha lavadora ou secadora, o dia e o horário. Cada horário dura 1 hora e você pode reservar até 7 dias à frente. O app escolhe a máquina menos usada, mas você pode trocar.',
        dica: 'Cada apartamento pode ter 2 lavagens e 2 secagens por dia.',
      ),
      PassoTutorial(
        titulo: 'Confirme o uso quando chegar',
        texto:
            'Toque em Confirmar uso a partir de 10 minutos antes do horário e até 15 minutos depois. Sem confirmação nesse prazo, o horário é liberado para outros moradores.',
      ),
      PassoTutorial(
        titulo: 'Informe o tempo do visor',
        texto:
            'Escolha o programa (por exemplo Normal, 45 min) ou digite o tempo que a máquina mostra. É esse tempo que liga o cronômetro e avisa todo mundo quando a máquina vai liberar.',
      ),
      PassoTutorial(
        titulo: 'Acompanhe e retire a roupa',
        texto:
            'O app avisa 5 minutos antes e quando a roupa fica pronta. Se o ciclo demorar mais, use +5 min ou Corrigir tempo. Ao retirar a roupa, toque em Já retirei.',
        dica: 'Se passar de 10 minutos do fim, outro morador pode retirar sua roupa e deixá-la no balcão.',
      ),
    ],
  ),
  Tutorial(
    id: 't2',
    titulo: 'Como usar uma lavadora',
    resumo: 'Preparo das roupas, escolha do programa e o que esperar de cada ciclo.',
    categoria: 'Lavadoras',
    tipoMaquina: TipoMaquina.lavadora,
    minutos: 4,
    passos: [
      PassoTutorial(
        titulo: 'Prepare as roupas',
        texto:
            'Esvazie os bolsos, feche zíperes e botões, e vire do avesso peças que soltam fiapos ou desbotam. Tire moedas, grampos e papéis, que podem entupir a bomba da máquina.',
      ),
      PassoTutorial(
        titulo: 'Carregue sem apertar',
        texto:
            'Coloque a roupa solta, sem socar. O tambor deve ficar cheio até cerca de três quartos, com espaço para a roupa se movimentar e enxaguar bem.',
      ),
      PassoTutorial(
        titulo: 'Coloque os produtos',
        texto:
            'Use a gaveta de sabão e a de amaciante, respeitando a dose da embalagem. Nunca despeje amaciante direto sobre as roupas.',
      ),
      PassoTutorial(
        titulo: 'Escolha o programa',
        texto:
            'Rápido (cerca de 30 min) serve para roupas pouco sujas e de uso leve. Normal (cerca de 45 min) atende o dia a dia. Pesado (cerca de 70 min) é para roupas muito sujas, toalhas e roupa de cama.',
        dica: 'Confira no visor o tempo real do ciclo e informe no app.',
      ),
      PassoTutorial(
        titulo: 'Ao terminar',
        texto:
            'Retire as roupas logo que o app avisar e deixe a porta aberta para a máquina ventilar. Passe um pano na borracha da porta se estiver molhada.',
      ),
    ],
  ),
  Tutorial(
    id: 't3',
    titulo: 'Como usar uma secadora',
    resumo: 'Temperatura certa e o que nunca deve ir para a secadora.',
    categoria: 'Secadoras',
    tipoMaquina: TipoMaquina.secadora,
    minutos: 4,
    passos: [
      PassoTutorial(
        titulo: 'Limpe o filtro de fiapos',
        texto:
            'Antes de cada uso, retire o filtro, tire os fiapos com a mão e recoloque. Filtro entupido deixa a secagem lenta e aumenta o risco de incêndio.',
      ),
      PassoTutorial(
        titulo: 'Confira a etiqueta das peças',
        texto:
            'O símbolo de quadrado com círculo indica que a peça pode ir à secadora. Um ponto significa temperatura baixa e dois pontos, média. Peça sem o símbolo ou com ele riscado deve secar na sombra.',
      ),
      PassoTutorial(
        titulo: 'O que não colocar',
        texto:
            'Não coloque tênis com cola ou borracha, roupas com espuma, lã, seda, peças com elástico delicado ou enfeites de plástico. Nunca seque roupas com manchas de óleo, gasolina, álcool, acetona ou tinta, pois podem pegar fogo.',
      ),
      PassoTutorial(
        titulo: 'Carregue até a metade',
        texto:
            'Encha o tambor até cerca de metade ou dois terços. Roupa apertada seca mal e amassa. Separe toalhas de roupas leves, pois secam em tempos diferentes.',
      ),
      PassoTutorial(
        titulo: 'Escolha o tempo',
        texto:
            'Delicada (cerca de 40 min) para peças leves, Normal (cerca de 60 min) para o dia a dia e Pesada (cerca de 80 min) para toalhas e roupa de cama.',
        dica: 'Se ainda estiver úmido, prefira prolongar o ciclo a lotar a máquina.',
      ),
    ],
  ),
  Tutorial(
    id: 't4',
    titulo: 'Limpeza do filtro de fiapos da secadora',
    resumo: 'Dois minutos que evitam incêndio e deixam a secagem mais rápida.',
    categoria: 'Cuidados e segurança',
    tipoMaquina: TipoMaquina.secadora,
    minutos: 2,
    passos: [
      PassoTutorial(
        titulo: 'Localize o filtro',
        texto:
            'Costuma ficar na borda da porta ou logo dentro do tambor. É uma tela fina, geralmente com uma alça.',
      ),
      PassoTutorial(
        titulo: 'Retire e limpe',
        texto:
            'Puxe o filtro e passe a mão sobre ele para tirar o tapete de fiapos. Se estiver com camada fina e grudada, lave com água morna e sabão neutro e deixe secar por completo antes de recolocar.',
      ),
      PassoTutorial(
        titulo: 'Recoloque até encaixar',
        texto:
            'O filtro deve entrar completamente. Nunca use a secadora sem ele.',
      ),
      PassoTutorial(
        titulo: 'Repita depois do uso',
        texto:
            'Limpe também ao terminar, para deixar a máquina pronta para o próximo morador. Fiapos acumulados são combustíveis.',
        dica: 'Se sentir cheiro de queimado, pare a máquina e avise o zelador pelo app.',
      ),
    ],
  ),
  Tutorial(
    id: 't5',
    titulo: 'Sabão e amaciante: quanto usar',
    resumo: 'O condomínio não fornece produtos. Veja como dosar sem danificar a máquina.',
    categoria: 'Dosagem de produtos',
    minutos: 3,
    passos: [
      PassoTutorial(
        titulo: 'Traga seus próprios produtos',
        texto:
            'A lavanderia não fornece sabão nem amaciante. Leve a quantidade que vai usar e não deixe frascos para trás.',
      ),
      PassoTutorial(
        titulo: 'Siga a dose da embalagem',
        texto:
            'Use a medida indicada pelo fabricante para o tamanho da carga. Em geral, uma carga média pede uma medida. Mais sabão não lava melhor.',
      ),
      PassoTutorial(
        titulo: 'Cuidado com o excesso',
        texto:
            'Sabão demais gera espuma que atrapalha o enxágue, deixa resíduo nas roupas, irrita a pele e danifica a máquina. Se a roupa sair com espuma ou cheiro de sabão, reduza a dose na próxima.',
      ),
      PassoTutorial(
        titulo: 'Amaciante só no compartimento',
        texto:
            'Coloque no local próprio da gaveta. Direto na roupa, mancha e prejudica tecidos esportivos e toalhas, que perdem absorção.',
      ),
      PassoTutorial(
        titulo: 'Nunca misture produtos',
        texto:
            'Não misture água sanitária com outros produtos (vinagre, amoníaco, desinfetantes): eles liberam gases tóxicos. Se usar alvejante, siga a etiqueta e aplique sozinho.',
      ),
    ],
  ),
  Tutorial(
    id: 't6',
    titulo: 'Capacidade: não sobrecarregue as máquinas',
    resumo: 'Como saber se está cheio demais e por que isso importa.',
    categoria: 'Lavadoras',
    minutos: 2,
    passos: [
      PassoTutorial(
        titulo: 'Regra da mão aberta',
        texto:
            'Depois de carregar, você deve conseguir encaixar uma mão aberta entre a roupa e o topo do tambor. Se não couber, retire algumas peças.',
      ),
      PassoTutorial(
        titulo: 'Lavadora: até três quartos',
        texto:
            'A roupa precisa de espaço para se mover. Tambor apertado lava mal, enxágua mal e pode desequilibrar a centrifugação.',
      ),
      PassoTutorial(
        titulo: 'Secadora: até a metade ou dois terços',
        texto:
            'O ar quente precisa circular. Cargas cheias demais demoram o dobro e saem amassadas e úmidas.',
      ),
      PassoTutorial(
        titulo: 'Divida em duas cargas',
        texto:
            'Se tiver muita roupa, use duas reservas em vez de lotar uma máquina. O limite diário é de 2 lavagens e 2 secagens por apartamento.',
      ),
    ],
  ),
  Tutorial(
    id: 't7',
    titulo: 'Como separar as roupas',
    resumo: 'Cores, tecidos e peças delicadas: separar evita manchas e desgaste.',
    categoria: 'Lavadoras',
    minutos: 3,
    passos: [
      PassoTutorial(
        titulo: 'Separe por cor',
        texto:
            'Faça três montes: brancas, claras e coloridas/escuras. Roupas novas e muito coloridas soltam tinta nas primeiras lavagens e devem ir sozinhas ou com cores parecidas.',
      ),
      PassoTutorial(
        titulo: 'Separe por tecido e sujeira',
        texto:
            'Toalhas e roupas de cama soltam muitos fiapos e devem lavar à parte de roupas leves ou sintéticas. Roupas muito sujas, como as de academia, vão separadas das pouco usadas.',
      ),
      PassoTutorial(
        titulo: 'Proteja as peças delicadas',
        texto:
            'Lingerie, meias finas e peças com bojo ou renda vão dentro de um saquinho de lavagem, no programa mais suave e com água fria.',
      ),
      PassoTutorial(
        titulo: 'Confira a etiqueta',
        texto:
            'Se houver um balde com número, é a temperatura máxima da água em graus Celsius. Na dúvida, escolha a temperatura mais baixa.',
      ),
    ],
  ),
  Tutorial(
    id: 't8',
    titulo: 'Símbolos de etiqueta de lavagem',
    resumo: 'O que significam os desenhos das etiquetas das roupas.',
    categoria: 'Etiquetas e símbolos',
    minutos: 3,
    passos: [
      PassoTutorial(
        titulo: 'Balde com água: lavar',
        texto:
            'O número dentro do balde é a temperatura máxima, em graus Celsius. Uma mão dentro do balde pede lavagem à mão. O balde riscado com um X indica que a peça não pode ser lavada em água.',
      ),
      PassoTutorial(
        titulo: 'Triângulo: alvejante',
        texto:
            'Triângulo vazio permite alvejante. Triângulo riscado proíbe qualquer alvejante. Triângulo com listras indica alvejante sem cloro.',
      ),
      PassoTutorial(
        titulo: 'Quadrado com círculo: secagem em máquina',
        texto:
            'Um ponto no círculo significa temperatura baixa e dois pontos, média. Se o desenho estiver riscado, não vá à secadora. Linhas dentro do quadrado indicam secagem natural (varal ou na sombra).',
      ),
      PassoTutorial(
        titulo: 'Ferro de passar',
        texto:
            'Os pontos indicam a temperatura máxima: um ponto é baixa, dois são média e três são alta. Ferro riscado: não passe.',
      ),
      PassoTutorial(
        titulo: 'Círculo: limpeza a seco',
        texto:
            'Um círculo (com letra dentro) indica limpeza profissional a seco. Nesse caso, não lave em casa nem na lavanderia do condomínio.',
        dica: 'Sem etiqueta? Use água fria e programa delicado.',
      ),
    ],
  ),
  Tutorial(
    id: 't9',
    titulo: 'Itens grandes: edredom, tapete e tênis',
    resumo: 'O que pode e o que não pode ir às máquinas, e como cuidar.',
    categoria: 'Perguntas frequentes',
    minutos: 4,
    passos: [
      PassoTutorial(
        titulo: 'Edredom e cobertor',
        texto:
            'Confira se cabe sem apertar e se a etiqueta permite lavar à máquina. Use o ciclo pesado ou delicado sem lotar. Para secar, leve à secadora em temperatura baixa e interrompa para soltar e afofar. Peças com enchimento precisam secar por completo para não criar mofo.',
        dica: 'Duas bolas de tênis limpas na secadora ajudam a afofar.',
      ),
      PassoTutorial(
        titulo: 'Tapetes',
        texto:
            'Só lave os que a etiqueta permite e que não tenham base de borracha ou látex, que ressecam e esfarelam. Lave sozinho e seque na sombra, esticado.',
      ),
      PassoTutorial(
        titulo: 'Tênis',
        texto:
            'Tire cadarços e palmilhas, sacuda a sujeira e lave dentro de um saquinho, em ciclo delicado com água fria. Nunca coloque na secadora, pois o calor derrete colas e deforma o solado. Seque na sombra, com papel dentro para absorver a umidade.',
      ),
      PassoTutorial(
        titulo: 'Roupas de pet e muito sujas de lama',
        texto:
            'Sacuda e enxágue antes em casa para tirar pelos e terra. Eles entopem o ralo da máquina e sobrecarregam o filtro.',
      ),
    ],
  ),
  Tutorial(
    id: 't10',
    titulo: 'Boas práticas de convivência',
    resumo: 'Pequenos hábitos que deixam a lavanderia boa para todos.',
    categoria: 'Cuidados e segurança',
    minutos: 3,
    passos: [
      PassoTutorial(
        titulo: 'Seja pontual',
        texto:
            'Confirme o uso até 15 minutos depois do início do horário. Se não puder ir, cancele pelo app: outro morador aproveita o horário.',
      ),
      PassoTutorial(
        titulo: 'Retire a roupa quando o app avisar',
        texto:
            'Ao fim do ciclo, tire a roupa em até 10 minutos. Assim a máquina fica livre para o próximo horário.',
      ),
      PassoTutorial(
        titulo: 'Deixe as portas abertas',
        texto:
            'Depois de retirar a roupa, deixe a porta da lavadora aberta para ventilar e evitar mofo e mau cheiro. Limpe o filtro da secadora.',
      ),
      PassoTutorial(
        titulo: 'Encontrou roupa esquecida?',
        texto:
            'Espere o prazo de 10 minutos, retire com cuidado, deixe no balcão e registre no app. O dono será avisado. Retirar antes do prazo é considerado mau uso e o síndico é informado.',
      ),
      PassoTutorial(
        titulo: 'Viu algum problema? Relate',
        texto:
            'Máquina com defeito, lâmpada queimada ou piso molhado: use Relatar. Quanto mais cedo o síndico souber, mais rápido resolve.',
      ),
    ],
  ),
];

/// Notícias iniciais. Datas relativas a [agora].
List<Noticia> noticiasVision(DateTime agora) {
  DateTime atras(int dias, int h, int m) {
    final d = agora.subtract(Duration(days: dias));
    return DateTime(d.year, d.month, d.day, h, m);
  }

  return [
    Noticia(
      id: 'n1',
      titulo: 'Dedetização no sábado, 08:00–12:00',
      resumo:
          'A lavanderia fica fechada para a dedetização das áreas comuns no sábado, das 08:00 às 12:00.',
      corpo: 'No próximo sábado, das 08:00 às 12:00, será feita a dedetização das áreas comuns do condomínio, incluindo a lavanderia.\n\n'
          '## O que muda\n\n'
          '- A lavanderia ficará fechada nesse período.\n'
          '- Reservas que caírem no horário serão canceladas sem penalidade.\n'
          '- Depois do meio-dia, as máquinas voltam ao normal.\n\n'
          '## Como se preparar\n\n'
          'Retire suas roupas das máquinas antes das 08:00 e evite deixar produtos abertos no balcão. A empresa pede que as áreas fiquem ventiladas por cerca de 2 horas antes de reabrir.\n\n'
          'Em caso de dúvida, fale com o síndico.',
      prioridade: PrioridadeNoticia.urgente,
      publicadaEm: atras(1, 10, 0),
      fixada: true,
      autor: 'Síndico',
      leituras: 61,
    ),
    Noticia(
      id: 'n2',
      titulo: 'Bem-vindos ao Lavanderon',
      resumo:
          'Reserve máquinas, acompanhe o cronômetro e receba aviso quando sua roupa ficar pronta.',
      corpo: 'O Lavanderon é o novo sistema da lavanderia do Condomínio Vision. Funciona 24 horas por dia e foi feito para acabar com a fila e com o "quem estava usando a máquina?".\n\n'
          '## Como funciona\n\n'
          '- Entre com o número do seu apartamento e o seu nome.\n'
          '- Reserve um horário de 1 hora, até 7 dias à frente.\n'
          '- Cada apartamento pode fazer 2 lavagens e 2 secagens por dia.\n'
          '- Quem faz a reserva é o apartamento: qualquer morador pode confirmar ou cancelar.\n\n'
          '## No dia da reserva\n\n'
          'Toque em Confirmar uso entre 10 minutos antes e 15 minutos depois do horário. Informe o tempo que o visor da máquina mostra e o cronômetro avisa todos quando a máquina vai liberar.\n\n'
          'Se você não confirmar até 15 minutos depois do início, o horário é liberado para outros moradores.\n\n'
          '## Quando a roupa fica pronta\n\n'
          '- Você recebe um aviso 5 minutos antes e outro quando termina.\n'
          '- Tem 10 minutos para retirar a roupa.\n'
          '- Depois disso, outro morador pode retirá-la e deixá-la no balcão. Você será avisado de onde ela está.\n\n'
          '## Algo deu errado?\n\n'
          '- Máquina ocupada no seu horário: toque em A máquina está ocupada e troque na hora.\n'
          '- Problema na máquina ou na lavanderia: use Relatar.\n'
          '- Tem uma ideia? Mande uma sugestão e vote nas dos vizinhos.\n\n'
          'Não há multas nem advertências. O síndico só é informado quando alguma regra de convivência não é respeitada.',
      prioridade: PrioridadeNoticia.importante,
      publicadaEm: atras(5, 9, 0),
      autor: 'Síndico',
      leituras: 84,
    ),
    Noticia(
      id: 'n3',
      titulo: 'Secadora 5 em manutenção',
      resumo:
          'Troca da correia: a Secadora 5 deve voltar em cerca de 6 dias. As reservas foram remanejadas.',
      corpo: 'A Secadora 5 está fora de uso para a troca da correia do tambor. A previsão de retorno é de 6 dias.\n\n'
          'Quem tinha reserva nessa máquina foi movido automaticamente para outra secadora livre, no mesmo horário. Se não havia máquina livre, o app avisou para escolher outro horário.\n\n'
          'Enquanto isso, use as demais secadoras.',
      prioridade: PrioridadeNoticia.importante,
      publicadaEm: atras(2, 15, 30),
      autor: 'Síndico',
      leituras: 47,
    ),
    Noticia(
      id: 'n4',
      titulo: 'Limpe o filtro de fiapos da secadora',
      resumo:
          'Antes e depois de cada uso. Leva dois minutos e evita risco de incêndio.',
      corpo: 'Fiapos acumulados no filtro da secadora fazem a máquina secar mais devagar e podem pegar fogo.\n\n'
          'Antes e depois de cada uso, retire o filtro, passe a mão para tirar os fiapos e recoloque até encaixar.\n\n'
          'Veja o passo a passo em Tutoriais, "Limpeza do filtro de fiapos da secadora".',
      prioridade: PrioridadeNoticia.informativo,
      publicadaEm: atras(8, 11, 0),
      autor: 'Zelador',
      leituras: 38,
    ),
  ];
}

/// Sugestões iniciais.
List<Sugestao> sugestoesVision(DateTime agora) => [
      Sugestao(
        id: 's1',
        titulo: 'Colocar um varal dentro da lavanderia',
        descricao:
            'Para peças que não podem ir à secadora, como tênis e lã. Poderia ser um varal retrátil perto da janela.',
        categoria: 'Espaço',
        status: StatusSugestao.planejada,
        votos: 23,
        resposta:
            'Boa ideia. Vamos pedir orçamento do varal retrátil na próxima reunião do conselho.',
        aptoAutor: '214',
        criadaEm: agora.subtract(const Duration(days: 12)),
      ),
      Sugestao(
        id: 's2',
        titulo: 'Lembrete de roupa pronta também por WhatsApp',
        descricao:
            'Nem todo mundo mantém o app aberto. Um aviso no WhatsApp ajudaria a não esquecer a roupa.',
        categoria: 'Aplicativo',
        status: StatusSugestao.emAvaliacao,
        votos: 17,
        resposta: 'Estamos avaliando o custo e as regras de privacidade.',
        aptoAutor: '409',
        criadaEm: agora.subtract(const Duration(days: 9)),
      ),
      Sugestao(
        id: 's3',
        titulo: 'Mais um cesto para roupas retiradas',
        descricao:
            'Às vezes o balcão fica cheio. Um cesto identificado por andar ajudaria.',
        categoria: 'Espaço',
        status: StatusSugestao.implementada,
        votos: 12,
        resposta: 'Instalamos um cesto extra ao lado do balcão. Obrigado!',
        aptoAutor: '317',
        criadaEm: agora.subtract(const Duration(days: 27)),
      ),
      Sugestao(
        id: 's4',
        titulo: 'Horário de silêncio entre 23:00 e 06:00',
        descricao:
            'As máquinas fazem barulho e a lavanderia fica embaixo de alguns apartamentos. Poderíamos limitar o uso de madrugada.',
        categoria: 'Regras',
        status: StatusSugestao.recusada,
        votos: 5,
        resposta:
            'A lavanderia foi definida como 24 horas pela assembleia. Vamos reforçar o aviso de portas fechadas e vedação da sala.',
        aptoAutor: '112',
        criadaEm: agora.subtract(const Duration(days: 20)),
      ),
      Sugestao(
        id: 's5',
        titulo: 'Ganchos para pendurar roupas na parede',
        descricao:
            'Alguns ganchos facilitariam dobrar e esperar a roupa sem deixar no chão ou no balcão.',
        categoria: 'Espaço',
        status: StatusSugestao.recebida,
        votos: 3,
        aptoAutor: '506',
        criadaEm: agora.subtract(const Duration(days: 2)),
      ),
    ];
