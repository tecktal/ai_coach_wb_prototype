const Map<String, String> pt = {
  // ── General ─────────────────────────────────────────────────────────────
  'appName': 'Treinador de Ensino IA',
  'ok': 'OK',
  'cancel': 'Cancelar',
  'save': 'Salvar',
  'delete': 'Excluir',
  'edit': 'Editar',
  'close': 'Fechar',
  'retry': 'Tentar novamente',
  'loading': 'Carregando…',
  'error': 'Erro',
  'success': 'Sucesso',
  'or': 'OU',
  'sort': 'Ordenar',
  'all': 'Todos',
  'yes': 'Sim',
  'no': 'Não',
  'back': 'Voltar',
  'next': 'Próximo',
  'done': 'Concluído',
  'search': 'Pesquisar',
  'copy': 'Copiar',
  'copiedToClipboard': 'Copiado para a área de transferência',
  'notSet': 'Não definido',
  'comingSoon': 'Em Breve',

  // ── Offline Banner ──────────────────────────────────────────────────────
  'offlineMessage': 'Sem conexão com a internet',

  // ── Auth — Login ────────────────────────────────────────────────────────
  'welcomeBack': 'Bem-vindo de Volta',
  'signInSubtitle': 'Inicie sessão para continuar a sua análise de aulas.',
  'username': 'Utilizador',
  'usernameHint': 'nome_professor',
  'password': 'Palavra-passe',
  'signIn': 'Entrar',
  'forgotPassword': 'Esqueceu a palavra-passe?',
  'newUser': 'Novo utilizador?',
  'createAccount': 'Criar uma conta',
  'loginFailed': 'Falha no login',
  'enterUsername': 'Por favor, insira o seu nome de utilizador',
  'enterPassword': 'Por favor, insira a sua palavra-passe',
  'copyright': '© 2024 Treinador de Ensino IA',

  // ── Auth — Register ─────────────────────────────────────────────────────
  'createAccountTitle': 'Criar Conta',
  'joinCoach': 'Junte-se ao Treinador de Ensino IA',
  'firstName': 'Primeiro Nome',
  'lastName': 'Apelido',
  'email': 'E-mail',
  'emailOptional': 'E-mail (Opcional)',
  'schoolName': 'Nome da Escola',
  'schoolNameOptional': 'Nome da Escola (Opcional)',
  'country': 'País',
  'register': 'Registar',
  'registrationFailed': 'Falha no registo',
  'enterFirstName': 'Por favor, insira o seu primeiro nome',
  'enterLastName': 'Por favor, insira o seu apelido',
  'enterEmail': 'Por favor, insira um e-mail válido',
  'passwordMinLength': 'A palavra-passe deve ter pelo menos 8 caracteres',
  'selectCountry': 'Por favor selecione o seu país',
  'regStepCountryTitle': 'Onde ensina?',
  'regStepDetailsTitle': 'Os seus dados',
  'regStepAccountTitle': 'A sua conta',
  'regStepIndicator': 'Passo {current} de {total}',

  // ── Auth — Forgot / Reset Password ──────────────────────────────────────
  'forgotPasswordTitle': 'Esqueceu a Palavra-passe',
  'forgotPasswordSubtitle': 'Insira o seu e-mail para receber um código de redefinição.',
  'sendResetLink': 'Enviar Link de Redefinição',
  'resetPassword': 'Redefinir Palavra-passe',
  'newPassword': 'Nova Palavra-passe',
  'confirmNewPassword': 'Confirmar Nova Palavra-passe',
  'passwordsDoNotMatch': 'As palavras-passe não coincidem',

  // ── Onboarding ──────────────────────────────────────────────────────────
  'onboardingWelcome': 'Bem-vindo ao Treinador de Ensino IA!',
  'onboardingSubtitle': 'Vamos conhecê-lo melhor. Esta informação ajudará a personalizar a sua experiência.',
  'onboardingContinue': 'Continuar',
  'onboardingInfo': 'As suas gravações serão guardadas com o seu nome e escola para fácil identificação.',
  'enterSchoolName': 'Por favor, insira o nome da sua escola',

  // ── Bottom Nav ──────────────────────────────────────────────────────────
  'navRecord': 'Gravar',
  'navMyLessons': 'Minhas Aulas',
  'navChats': 'Conversas',
  'navProfile': 'Perfil',

  // ── Home / Recording Tab — Idle ─────────────────────────────────────────
  'tapToRecord': 'Toque para começar a gravar',
  'tapToRecordSub': 'Grave a sua aula e receba feedback com IA',
  'tapToRecordButton': 'Toque para Gravar',
  'captureAudio': 'Capture o áudio da sua sala de aula',
  'importAudio': 'Importar Ficheiro de Áudio',
  'importAudioSub': 'Selecione um ficheiro de aula pré-gravado',

  // ── Home / Recording Tab — Recording ────────────────────────────────────
  'recording': 'A gravar',
  'recordingActive': 'A gravar a sua aula...',
  'recordingPaused': 'Gravação Pausada',
  'pauseRecording': 'Pausar',
  'resumeRecording': 'Retomar',
  'stopRecording': 'Parar',
  'discardRecording': 'Descartar gravação?',
  'discardRecordingMessage': 'A gravação atual será perdida.',
  'keep': 'Manter',
  'discard': 'Descartar',
  'lockTooltip': 'Bloquear ecrã',
  'unlockTooltip': 'Desbloquear ecrã',

  // ── Home / Recording Tab — Review ───────────────────────────────────────
  'reviewRecording': 'Rever Gravação',
  'lessonTitle': 'Título da Aula',
  'subject': 'Disciplina',
  'gradeLevel': 'Nível de Ensino',
  'saveAndAnalyze': 'Salvar e Analisar Agora',
  'saveLater': 'Salvar para Mais Tarde',
  'enterLessonTitle': 'Por favor, insira um título para a aula',
  'selectSubject': 'Por favor, selecione uma disciplina',
  'uploadingLesson': 'A carregar a sua aula…',
  'uploadingSubtitle': 'A análise com IA está a começar. Isto pode demorar um momento — por favor, mantenha a aplicação aberta.',
  'lessonSaved': '📱 Aula guardada. Abra em Minhas Aulas para analisar mais tarde.',
  'uploadingForAnalysis': 'A carregar para análise. Verifique Minhas Aulas para o progresso.',
  'failedToSave': 'Falha ao salvar',
  'failedToSaveLesson': 'Falha ao salvar a aula',
  'noInternetTitle': 'Sem conexão com a internet',
  'noInternetAnalysis': 'Precisa de internet para executar a análise.\n\nDeseja salvar esta aula localmente e analisá-la mais tarde?',
  'saveForLater': 'Salvar para Mais Tarde',
  'recordingSavedToDevice': 'Gravação guardada com sucesso no armazenamento do dispositivo',
  'couldNotSaveRecording': 'Não foi possível guardar a gravação permanentemente. Verifique as permissões.',
  'importedAudioCopied': 'Áudio importado copiado com segurança para o armazenamento do dispositivo',

  // ── Subjects ────────────────────────────────────────────────────────────
  'subjectMath': 'Matemática',
  'subjectScience': 'Ciências',
  'subjectEnglish': 'Inglês',
  'subjectHistory': 'História',
  'subjectArt': 'Arte',
  'subjectOther': 'Outro',

  // ── My Lessons (Recordings List) ────────────────────────────────────────
  'myLessons': 'Minhas Aulas',
  'searchLessons': 'Pesquisar aulas...',
  'noLessonsFound': 'Nenhuma aula encontrada',
  'analyzed': 'Analisadas',
  'notAnalyzed': 'Não Analisadas',
  'sortBy': 'Ordenar Por',
  'sortAlphabeticalAZ': 'Alfabético (A-Z)',
  'sortAlphabeticalZA': 'Alfabético (Z-A)',
  'sortDateNewest': 'Data (Mais Recente)',
  'sortDateOldest': 'Data (Mais Antiga)',
  'deleteRecording': 'Excluir Gravação?',
  'deleteRecordingMessage': 'Isto irá excluir permanentemente a gravação e a sua análise.',
  'recordingDeleted': 'Gravação excluída.',
  'analysisReady': 'análise está pronta. Toque para ver os seus resultados.',
  'analysisCouldNotComplete': 'A análise não pôde ser concluída para',
  'tapToSeeDetails': 'Toque para ver detalhes.',
  'fetchingAnalysis': 'A obter detalhes da análise…',
  'lessonBeingAnalyzed': 'Esta aula está a ser analisada. Por favor, aguarde.',
  'noAnalysisFound': 'Nenhuma análise encontrada. Tente puxar para baixo para atualizar.',
  'analysisInProgress': 'Análise em progresso…',
  'uploadingDrafts': 'A carregar rascunhos…',
  'analysisNotStarted': 'Análise não iniciada',
  'analysisNotStartedMessage': 'Esta aula foi carregada mas a análise ainda não começou. Deseja iniciá-la agora?',
  'runAnalysis': 'Executar Análise',
  'analysisStarted': 'Análise iniciada. Verifique Minhas Aulas para o progresso.',
  'failedToStartAnalysis': 'Falha ao iniciar a análise. Tente novamente.',

  // ── Analysis Screen ─────────────────────────────────────────────────────
  'lessonAnalysis': 'Análise da Aula',
  'analysis': 'Análise',
  'overallScore': 'Pontuação Geral',
  'keyTakeaways': 'PONTOS PRINCIPAIS',
  'strengths': 'Pontos Fortes',
  'areasForImprovement': 'Áreas de Melhoria',
  'recommendations': 'Recomendações',
  'teachFramework': 'FRAMEWORK TEACH',
  'scienceOfLearning': 'CIÊNCIA DA APRENDIZAGEM',
  'transcript': 'TRANSCRIÇÃO',
  'transcriptComingSoon': 'As transcrições estarão disponíveis numa atualização futura.',
  'talkToCoach': 'Falar com o Treinador',
  'copyAllFeedback': 'Copiar todo o feedback',
  'analysisCopied': 'Análise copiada para a área de transferência',
  'lessonAudio': 'Áudio da Aula',
  'untitledLesson': 'Aula Sem Título',
  'shortRecording': 'Gravação Curta',
  'limitedTeachingActivity': 'Atividade de Ensino Limitada Detectada',
  'lowAudioQuality': 'Baixa Qualidade de Áudio',
  'analysisNote': 'Nota de Análise',
  'coachFeedback': 'FEEDBACK DO TREINADOR',
  'pros': 'PRÓS',
  'cons': 'CONTRAS',

  // ── Analysis — Element Detail ───────────────────────────────────────────
  'evidence': 'Evidência',
  'behaviorFilter': 'Filtrar por Comportamento',
  'askCoachAbout': 'Perguntar ao Treinador sobre isto',

  // ── Chat Screen ─────────────────────────────────────────────────────────
  'aiCoach': 'Treinador IA',
  'viewLessonAnalysis': 'Ver Análise da Aula',
  'askAnything': 'Pergunte-me qualquer coisa sobre a sua aula\nou prática de ensino.',
  'typeMessage': 'Pergunte ao seu treinador…',
  'deleteConversation': 'Excluir Conversa?',
  'deleteConversationMessage': 'Isto irá remover permanentemente esta conversa e todas as suas mensagens.',
  'deleteConversationAction': 'Excluir Conversa',
  'permanentlyRemoveChat': 'Remover permanentemente esta conversa',
  'copyLogs': 'Copiar Registos',
  'copyLogsSubtitle': 'Copiar registos de depuração para a área de transferência',
  'logLinesCopied': 'linhas de registo copiadas para a área de transferência',

  // ── Chat Suggestions ────────────────────────────────────────────────────
  'suggestionEngagement': 'Como posso melhorar o envolvimento?',
  'suggestionFocusNext': 'Em que devo focar para melhorar a seguir?',
  'suggestionExample': 'Dê-me um exemplo específico',
  'suggestionDidWell': 'O que fiz bem?',

  // ── Chat List Screen ────────────────────────────────────────────────────
  'coaching': 'Treinamento',
  'newChat': 'Nova Conversa',
  'noChatsYet': 'Ainda sem conversas',
  'startConversation': 'Inicie uma conversa com o seu treinador IA',
  'selectLesson': 'Selecionar uma Aula',
  'generalChat': 'Conversa Geral',
  'generalChatSubtitle': 'Conversar sem vincular uma aula',

  // ── Profile Screen ──────────────────────────────────────────────────────
  'editProfile': 'Editar Perfil',
  'school': 'Escola',
  'darkMode': 'Modo Escuro',
  'changePassword': 'Alterar Palavra-passe',
  'logOut': 'Sair',
  'logOutConfirm': 'Tem a certeza de que deseja sair?',
  'saveChanges': 'Salvar Alterações',
  'nameUpdated': 'Nome atualizado com sucesso!',
  'updateFailed': 'Atualização falhou',
  'language': 'Idioma',

  // ── Profile — Change Password ───────────────────────────────────────────
  'changePasswordTitle': 'Alterar Palavra-passe',
  'changePasswordSubtitle': 'A sua nova palavra-passe deve ter pelo menos 6 caracteres.',
  'currentPassword': 'Palavra-passe Atual',
  'updatePassword': 'Atualizar Palavra-passe',
  'enterCurrentPassword': 'Insira a sua palavra-passe atual',
  'enterNewPassword': 'Insira uma nova palavra-passe',
  'atLeast6Chars': 'Pelo menos 6 caracteres',
  'newPasswordMustDiffer': 'A nova palavra-passe deve ser diferente da atual',
  'passwordChanged': 'Palavra-passe alterada com sucesso!',
  'failedToChangePassword': 'Falha ao alterar a palavra-passe',

  // ── Email Verification ──────────────────────────────────────────────────
  'verifyEmail': 'Verificar E-mail',
  'verificationCode': 'Código de Verificação',
  'resendCode': 'Reenviar Código',
  'emailVerified': 'E-mail verificado!',

  // ── Recording Screen (separate) ─────────────────────────────────────────
  'recordLesson': 'Gravar Aula',

  // ── Local Draft Detail ──────────────────────────────────────────────────
  'localDraft': 'Rascunho Local',
  'savedLocally': 'Guardado localmente',
  'uploadAndAnalyze': 'Carregar e Analisar',

  // ── Language Names ──────────────────────────────────────────────────────
  'langEnglish': 'English',
  'langPortuguese': 'Português',
  'langFrench': 'Français',
  'langAmharic': 'አማርኛ',
  'langSwahili': 'Kiswahili',

  // ── Element Detail ──────────────────────────────────────────────────────
  // Faixa do elemento. A mesma escala de três palavras dos selos de
  // comportamento (B/M/A), por extenso. A nota numérica de 1 a 5 permanece
  // oculta, conforme pedido do Banco Mundial.
  'scaleHigh': 'Alto',
  'scaleMedium': 'Médio',
  'scaleLow': 'Baixo',
  'rationale': 'Justificativa',
  'notObserved': 'Não observado nesta aula',
  'tryThis': 'Tente Isso',
  'askTheCoach': 'Perguntar ao Treinador →',
  'askCoachTip': 'Fale com seu treinador de IA para estratégias concretas e exemplos para este comportamento.',
  'rating': 'Classificação',
  'evidenceFound': 'Evidência encontrada',
  'screenLocked': 'Tela bloqueada',

  //Email verification
  'verifyYourEmail': 'Verifique seu e-mail',
  'tapToSecureAccount': 'Toque para proteger sua conta',
  'verifyButton': 'Verificar',
  'newRecording': 'Nova Gravação',

  // ── Analysis UI Labels ────────────────────────────────────────────────────
  'notObservedSection': 'NÃO OBSERVADO',
  'tapToViewElements': 'Toque para ver {count} elementos',
  'noneIdentified': 'Nenhum identificado',
  'growthAreas': 'Áreas de Crescimento',
  'nextSteps': 'PRÓXIMOS PASSOS',
  'example': 'EXEMPLO',
  'domainClassroomCulture': 'Cultura da Sala de Aula',
  'domainInstruction': 'Instrução',
  'domainSocioemotionalSkills': 'Habilidades Socioemocionais',
  'noDetailedAnalysis': 'Não há análise detalhada disponível para esta categoria.',

  // ── Letras de classificação (apenas exibição; valores gravados seguem H/M/L)
  // B/M/A = Baixo / Médio / Alto, conforme solicitado pelos coordenadores de
  // Mato Grosso. Atenção: 'A' (Alto) corresponde ao 'H' gravado.
  'ratingHigh': 'A',
  'ratingMedium': 'M',
  'ratingLow': 'B',

  // ── Elementos TEACH ───────────────────────────────────────────────────────
  // TODO(W2b): conferir termo a termo com o formulário oficial brasileiro.
  'teachElementSupportiveEnvironment': 'Ambiente de Aprendizagem Acolhedor',
  'teachElementPositiveExpectations': 'Expectativas Comportamentais Positivas',
  'teachElementLessonFacilitation': 'Facilitação da Aula',
  'teachElementChecksUnderstanding': 'Verificação da Compreensão',
  'teachElementFeedback': 'Feedback',
  'teachElementCriticalThinking': 'Pensamento Crítico',
  'teachElementAutonomy': 'Autonomia',
  'teachElementPerseverance': 'Perseverança',
  'teachElementSocialCollaborative': 'Habilidades Sociais e Colaborativas',

  // ── Comportamentos TEACH ──────────────────────────────────────────────────
  'teachBehaviorTreatsRespectfully': 'Trata os Alunos com Respeito',
  'teachBehaviorPositiveLanguage': 'Usa Linguagem Positiva',
  'teachBehaviorRespondsToNeeds': 'Responde às Necessidades dos Alunos',
  'teachBehaviorNoBias': 'Não Demonstra Viés / Questiona Estereótipos',
  'teachBehaviorSetsClearExpectations': 'Estabelece Expectativas Comportamentais Claras',
  'teachBehaviorAcknowledgesPositiveBehavior': 'Reconhece o Comportamento Positivo',
  'teachBehaviorRedirectsMisbehavior': 'Redireciona o Mau Comportamento',
  'teachBehaviorArticulatesObjectives': 'Explicita os Objetivos da Aula',
  'teachBehaviorMultipleRepresentations': 'Utiliza Múltiplas Formas de Representação',
  'teachBehaviorMakesConnections': 'Faz Conexões',
  'teachBehaviorModels': 'Modela Procedimentos ou Raciocínio',
  'teachBehaviorQuestionsPromptsToCheck': 'Faz Perguntas para Verificar a Compreensão',
  'teachBehaviorMonitorsIndependentWork': 'Monitora Durante o Trabalho Independente',
  'teachBehaviorAdjustsTeaching': 'Ajusta o Ensino',
  'teachBehaviorFeedbackMisunderstandings': 'Feedback sobre Equívocos',
  'teachBehaviorFeedbackSuccesses': 'Feedback sobre Acertos',
  'teachBehaviorOpenEndedQuestions': 'Faz Perguntas Abertas',
  'teachBehaviorThinkingTasks': 'Propõe Tarefas de Reflexão',
  'teachBehaviorStudentsAskQuestions': 'Alunos Fazem Perguntas ou Realizam Tarefas',
  'teachBehaviorProvidesChoices': 'Oferece Escolhas',
  'teachBehaviorOpportunitiesForRoles': 'Oferece Oportunidades de Assumir Papéis',
  'teachBehaviorStudentsVolunteer': 'Alunos se Voluntariam',
  'teachBehaviorAcknowledgesEfforts': 'Reconhece o Esforço dos Alunos',
  'teachBehaviorPositiveAttitude': 'Atitude Positiva Diante dos Desafios',
  'teachBehaviorEncouragesGoalSetting': 'Incentiva a Definição de Metas',
  'teachBehaviorPromotesCollaboration': 'Promove a Colaboração',
  'teachBehaviorPromotesInterpersonalSkills': 'Promove Habilidades Interpessoais',
  'teachBehaviorStudentsCollaborate': 'Alunos Colaboram entre Si',

  // ── Dicas de coaching, por chave canônica do elemento ─────────────────────
  'teachTip_supportive_environment':
      'Estabeleça um acordo com a turma: erros são oportunidades de aprendizagem, não fracassos. Dê o exemplo narrando em voz alta os seus próprios equívocos de raciocínio durante as demonstrações.',
  'teachTip_positive_expectations':
      'Defina de 2 a 3 regras de convivência específicas e formuladas de forma positiva, e deixe-as visíveis. No início de cada atividade, reserve 30 segundos para lembrar qual regra se aplica. A referência constante funciona melhor do que a correção.',
  'teachTip_lesson_facilitation':
      'Comece cada etapa da aula com um objetivo de aprendizagem claro escrito no quadro: "Ao final desta atividade, você será capaz de..." Os alunos se envolvem mais quando sabem aonde a aula quer chegar.',
  'teachTip_checks_understanding':
      'Use bilhetes de saída: ao final da aula, peça que cada aluno escreva uma coisa que aprendeu e uma coisa que ainda ficou confusa. Leia-os antes da próxima aula.',
  'teachTip_feedback':
      'Troque o "Muito bem!" por um feedback específico: "Percebi que você conferiu o seu resultado duas vezes — é exatamente isso que um bom matemático faz." Nomeie o comportamento, não apenas o resultado.',
  'teachTip_critical_thinking':
      'Apresente um dilema real relacionado ao tema e peça que os alunos defendam os dois lados antes de revelar a resposta aceita. A controvérsia ativa um pensamento mais profundo.',
  'teachTip_autonomy':
      'Permita que os alunos escolham como demonstrar o que aprenderam — escrevendo, desenhando, falando ou apresentando. Mesmo pequenas escolhas aumentam bastante o senso de pertencimento e a motivação.',
  'teachTip_perseverance':
      'Quando um aluno travar, diga "Você ainda não resolveu" (enfatizando o ainda). Em seguida, pergunte "O que você já tentou até agora?" para dar apoio sem resolver por ele.',
  'teachTip_social_collaborative':
      'Use um protocolo estruturado de grupo: cada integrante recebe um papel específico (mediador, relator, apresentador, cronometrista). Alternar os papéis garante que todos participem igualmente.',
  'clarityAndCognitiveLoad': 'Clareza e Carga Cognitiva',
  'engagementAndRetrieval': 'Engajamento e Recuperação',
  'feedbackAndMetacognition': 'Feedback e Metacognição',

  // ── Local Draft Detail Screen ──────────────────────────────────────────────
  'draftSectionLessonDetails': 'DETALHES DA AULA',
  'draftSectionLessonAudio': 'ÁUDIO DA AULA',
  'draftSectionAnalysis': 'ANÁLISE',
  'draftInfoTitle': 'Título',
  'draftInfoSubject': 'Disciplina',
  'draftInfoGrade': 'Nível',
  'draftInfoRecorded': 'Gravado',
  'draftInfoDuration': 'Duração',
  'draftInfoNotes': 'Notas',
  'draftStatusSavedLocally': 'Esta aula está guardada localmente e ainda não foi analisada.',
  'draftStatusPending': 'Aula carregada mas a análise ainda não foi iniciada. Toque em Executar Análise abaixo.',
  'draftStatusFailed': 'A análise de IA não foi concluída desta vez — isto é geralmente um problema temporário e a sua gravação está segura. Tente novamente abaixo ou volte em alguns minutos.',
  'draftStatusTooShort': 'A gravação foi muito curta para uma análise completa. Certifique-se de que a sua gravação tem pelo menos 1 minuto de ensino real.',
  'draftUploadFailed': 'Falha no envio: {error}',
  'draftUploadedAnalyzing': 'Aula carregada. A análise está a correr em segundo plano.',
  'draftAnalysisRetriggered': 'Análise reiniciada. Verifique Minhas Aulas para o progresso.',
  'draftRetryAnalysis': 'Tentar Análise Novamente',
  'draftUploadingWait': 'A carregar… Aguarde',
  'draftStarting': 'A iniciar…',
  'draftUploadInProgress': 'Carregamento em progresso — pode sair deste ecrã com segurança. A análise continuará em segundo plano.',
  'draftIfKeepsFailing': 'Se continuar a falhar, aguarde alguns minutos e tente novamente. A sua gravação está guardada com segurança e não será perdida.',
  'draftNoInternet': 'Sem conexão com a internet',
  'draftNoInternetDetail': 'Ligue-se à internet e toque no botão abaixo para executar a análise.',
  'draftDataPersistenceNotice': 'Ao executar a análise, o seu áudio é carregado para o nosso servidor. Pode eliminá-lo com segurança do seu telemóvel — o seu feedback, pontuações e histórico de conversas permanecerão na aplicação.',
  'draftLessonAudioLabel': 'Áudio da Aula',

  // ── Ecrã de erro da análise ───────────────────────────────────────────────
  'analysisFailed': 'A Análise Falhou',
  'analysisCouldNotCompleteTitle': 'Não Foi Possível Concluir a Análise',
  'retryAnalysis': 'Tentar Analisar Novamente',
  'deleteRecordingAction': 'Excluir Gravação',
  'analysisResubmitted': 'Análise reenviada. Você será notificado quando estiver pronta.',
  'retryFailed': 'A nova tentativa falhou. Por favor, tente novamente.',
  'actionCannotBeUndone': 'Esta ação não pode ser desfeita.',
  'deleteFailed': 'Falha ao excluir: {error}',

  // Motivos de falha, correspondentes aos códigos failure_reason do servidor.
  'errTooShortWithDuration':
      'A sua gravação tem apenas {seconds} segundos. Grave pelo menos 30 segundos de atividade em sala de aula para obter uma análise significativa.',
  'errTooShort':
      'A sua gravação é demasiado curta. Grave pelo menos 30 segundos de atividade em sala de aula para obter uma análise significativa.',
  'errFileTooSmall':
      'O ficheiro de áudio parece estar vazio ou corrompido. Tente gravar novamente e certifique-se de que a gravação foi guardada corretamente antes de enviar.',
  'errFileTooLarge':
      'O ficheiro da sua gravação é demasiado grande. Utilize um formato de áudio comprimido (M4A ou MP3) para reduzir o tamanho e tente novamente.',
  'errPoorAudio':
      'Não foi detetado áudio da sala de aula nesta gravação. O microfone pode ter estado bloqueado ou demasiado longe da área de ensino. Tente novamente — coloque o dispositivo mais perto de onde está a ensinar.',
  'errInsufficientContent':
      'A IA não conseguiu detetar interação suficiente na sala de aula para concluir uma análise completa. Isto pode acontecer se o microfone estiver longe da ação ou se a maior parte da gravação captar atividades que não são de ensino. Tente gravar durante um momento ativo da aula e coloque o dispositivo mais perto de si.',
  'errTokenLimit':
      'A análise gerou demasiado detalhe e excedeu o limite de processamento da IA. Isto pode acontecer com gravações muito longas. Tente novamente — a IA produzirá uma resposta mais concisa.',
  'errAiService':
      'O serviço de análise por IA está temporariamente indisponível. Aguarde um momento e toque em "Tentar Analisar Novamente" abaixo.',
  'errNetwork':
      'Tivemos dificuldade em descarregar a sua gravação para análise. Verifique a sua ligação à internet e toque em "Tentar Analisar Novamente" abaixo.',
  'errSystem':
      'Ocorreu um erro de sistema ao processar a sua gravação. Não está relacionado com a sua aula. Toque em "Tentar Analisar Novamente" — normalmente funciona à segunda tentativa.',
  'errUnknown':
      'Ocorreu um erro inesperado durante a análise. Toque em "Tentar Analisar Novamente" abaixo.',

  // ── Autenticação ──────────────────────────────────────────────────────────
  'emailVerifiedSuccess': 'E-mail verificado com sucesso!',
  'verificationCodeSent': 'Código de verificação enviado!',
  'resetLinkSentIfExists': 'Se o e-mail existir, foi enviado um link de redefinição.',
  'togglePasswordVisibility': 'Mostrar ou ocultar a palavra-passe',
  'resetTokenLabel': 'Código de Redefinição',
  'resetTokenHelper': 'Cole o código do link enviado para o seu e-mail',
  'confirmPassword': 'Confirmar Palavra-passe',
  'passwordResetSuccessLogin': 'Palavra-passe redefinida com sucesso! Faça login.',

  // ── Conversa ──────────────────────────────────────────────────────────────
  'deleteChatTitled': 'Excluir "{title}"?',
  'scrollToBottom': 'Ir para o fim',
  'moreOptions': 'Mais opções',

  // ── Início / gravação ─────────────────────────────────────────────────────
  'genericError': 'Erro: {error}',
  'errorImportingFile': 'Erro ao importar o ficheiro: {error}',
  'discardRecordingTooltip': 'Descartar gravação',
  'subjectHint': 'ex.: Geografia, Educação Física…',
  'openProfile': 'Abrir perfil',
  'startRecordingLabel': 'Iniciar gravação',
  'stopRecordingLabel': 'Parar gravação',
  'lastLesson': 'Última Aula',
  'weeklyStreak': 'Sequência Semanal',
  'pleaseRecordOrSelect': 'Grave ou selecione um ficheiro de áudio',
  'startRecordingButton': 'Iniciar Gravação',
  'uploadFile': 'Carregar Ficheiro',
  'descriptionOptional': 'Descrição (Opcional)',
  'subjectOptional': 'Disciplina (Opcional)',
  'gradeLevelOptional': 'Ano de Escolaridade (Opcional)',

  // ── Progresso ─────────────────────────────────────────────────────────────
  'completeAnalysesToSeeProgress': 'Conclua algumas análises para ver o seu progresso',
  'totalAnalyses': 'Total de Análises',
  'averageScore': 'Pontuação Média',

  // ── Notificações ──────────────────────────────────────────────────────────
  'notifAnalysisReady': 'Análise Pronta',
  'notifAnalysisUnsuccessful': 'A Análise Não Foi Concluída',
  'notifHintTooShort': 'A gravação foi demasiado curta para uma análise completa.',
  'notifHintPoorAudio': 'A qualidade do áudio foi baixa. Tente aproximar o dispositivo.',
  'notifHintFileTooLarge': 'O ficheiro da gravação era demasiado grande. Use um formato comprimido.',

  // ── Verificação de e-mail ─────────────────────────────────────────────────
  'verificationFailed': 'A verificação falhou',
  'failedToResendCode': 'Não foi possível reenviar o código',
  'enterSixDigitCode': 'Introduza o código de 6 dígitos enviado para o seu e-mail.',
  'pleaseEnterSixDigitCode': 'Introduza um código de 6 dígitos',
  'devPhaseEmailNotice':
      '⚠️ Fase de desenvolvimento — O envio de e-mails está limitado a contas de teste pré-aprovadas. Pode continuar a usar a aplicação sem verificar o seu e-mail.',

  // ── Validação da redefinição de palavra-passe ─────────────────────────────
  'pleaseEnterResetToken': 'Introduza o código de redefinição',
  'pleaseEnterNewPassword': 'Introduza uma nova palavra-passe',
  'passwordMinSixChars': 'A palavra-passe deve ter pelo menos 6 caracteres',
  'pleaseConfirmPassword': 'Confirme a sua palavra-passe',

  // ── Erros de rede / API ───────────────────────────────────────────────────
  'errCannotReachServer': 'Não foi possível contactar o servidor. Verifique a sua ligação à internet.',
  'errWrongCredentials': 'Nome de utilizador ou palavra-passe incorretos.',
  'errAccountExists': 'Já existe uma conta com este e-mail ou nome de utilizador.',
  'errCheckInformation': 'Verifique os seus dados e tente novamente.',
  'errServerError': 'O servidor encontrou um erro. Tente novamente dentro de momentos.',
  'errSomethingWentWrong': 'Algo correu mal. Tente novamente.',
  'errCurrentPasswordIncorrect': 'A palavra-passe atual está incorreta.',

  // ── Corpo das notificações ────────────────────────────────────────────────
  'notifBodyAnalysed': '"{title}" foi analisada. Toque para ver os resultados.',
  'notifBodyFailedWithReason': 'Não foi possível analisar "{title}". {reason}',
  'notifBodyFailed': 'Não foi possível analisar "{title}". Toque para ver os detalhes.',
  'notifDefaultLessonTitle': 'Aula',

  // ── Destinatário do feedback ──────────────────────────────────────────────
  'feedbackStyle': 'Estilo do feedback',
  'feedbackStyleTeacher': 'Escrito para mim',
  'feedbackStyleCoordinator': 'Escrito para eu discutir com um professor',
  'feedbackStyleHelp':
      'Altera a forma como a IA redige o feedback. Aplica-se apenas a novas análises — as aulas já analisadas mantêm a redação com que foram escritas.',

  // ── Conversa de coaching (fluxo do coordenador) ───────────────────────────
  'coachConversation': 'Conversa de coaching',
  'coachConversationSubtitle': 'Prepare uma conversa com o professor sobre uma competência',
  'coachPrepareButton': 'Preparar conversa',
  'coachChooseFocalSkill': 'Escolha a competência foco',
  'coachChooseFocalSkillHelp':
      'Selecione a prática a trabalhar nesta conversa. Pode preparar mais do que uma.',
  'coachPrepared': 'Preparada',
  'coachGenerating': 'A preparar a conversa…',
  'coachGenerateFailed': 'Não foi possível preparar a conversa. Tente novamente.',
  'coachRegenerate': 'Preparar novamente',
  'coachRegenerateConfirm':
      'Isto substitui a conversa atual por uma nova redação. Continuar?',
  'coachNotAnalysedYet': 'Esta aula ainda não foi analisada.',
  'coachCopied': 'Conversa copiada',

  // Os sete blocos, na ordem em que o coordenador os utiliza.
  'coachBlockEvidence': 'Evidências observadas',
  'coachBlockMeaning': 'O que isso indica',
  'coachBlockQuestion': 'Pergunta para iniciar',
  'coachBlockFollowUps': 'Perguntas de aprofundamento',
  'coachBlockModel': 'Modelo possível',
  'coachBlockPractice': 'Prática',
  'coachBlockNextStep': 'Próximo passo',

  // Professor observado
  'observedTeacher': 'Professor observado',
  'observedTeacherHint': 'Nome do professor que lecionou esta aula',

  // ── Terminologia do coordenador ───────────────────────────────────────────
  'navObserve': 'Observar',
  'navObservedLessons': 'Aulas Observadas',
  'tapToObserve': 'Toque para registar uma observação',
  'tapToObserveSub':
      'Grave uma aula que está a observar e prepare a conversa com o professor',
  'noObservationsYet': 'Ainda não há observações',

  // ── Registo: função ───────────────────────────────────────────────────────
  'roleQuestion': 'Como vai utilizar o AI Coach?',
  'roleTeacher': 'Leciono as minhas próprias aulas',
  'roleTeacherHelp': 'Grave as suas aulas e receba feedback sobre o seu ensino',
  'roleCoordinator': 'Observo e acompanho outros professores',
  'roleCoordinatorHelp':
      'Grave aulas que observa e prepare conversas de coaching com os professores',

  // ── Áreas de coaching ─────────────────────────────────────────────────────
  'coachArea_clarity_and_cognitive_load': 'Clareza e Carga Cognitiva',
  'coachArea_student_engagement_and_retrieval_practice': 'Engajamento e Recuperação',
  'coachArea_feedback_and_metacognition': 'Feedback e Metacognição',
  'coachArea_checks_understanding': 'Verificar a Compreensão',
  'coachArea_feedback': 'Dar Feedback',

  // TODO(W2b): confirmar o nome da secção com o glossário oficial — depende do
  // que "HPE" designa no programa de Mato Grosso.
  'prioritySkills': 'Habilidades Prioritárias',
  'statePriorities': 'Prioridades do estado',
  'allTeachElements': 'Todos os elementos TEACH',
};
